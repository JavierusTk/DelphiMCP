unit AutomationWindowDetection;

{
  Window Detection - Detect non-VCL modal windows

  PURPOSE:
  - Detect Windows native dialogs (TOpenDialog, MessageDlg, etc.)
  - Find modal windows owned by the application but not in Screen.Forms
  - Provide window information for interaction via Windows API

  STRATEGY:
  1. Enumerate all top-level windows owned by this process
  2. Filter out VCL forms (already in Screen.Forms)
  3. Detect modal state and window class
  4. Return information about non-VCL modal windows

  USAGE:
    var Info: TNonVCLModalInfo;
    if DetectNonVCLModal(Info) then
      ShowMessage('Modal detected: ' + Info.WindowTitle);
}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.JSON,
  Vcl.Forms;

type
  /// <summary>
  /// Information about a non-VCL modal window
  /// </summary>
  TNonVCLModalInfo = record
    Detected: Boolean;        // True if a non-VCL modal was found
    WindowHandle: HWND;       // Handle of the modal window
    WindowTitle: string;      // Title/caption of the window
    WindowClass: string;      // Window class name
    IsModal: Boolean;         // True if window appears modal
    OwnerHandle: HWND;        // Handle of owner window (if any)
    ProcessID: DWORD;         // Process ID (should match current process)
  end;

/// <summary>
/// Detect if there's a non-VCL modal window currently active
/// </summary>
/// <param name="Info">Returns information about the detected modal</param>
/// <returns>True if a non-VCL modal was detected</returns>
function DetectNonVCLModal(out Info: TNonVCLModalInfo): Boolean;

/// <summary>
/// Get JSON description of all non-VCL windows owned by this application
/// </summary>
/// <returns>JSON array of non-VCL window information</returns>
function ListNonVCLWindows: string;

/// <summary>
/// Check if a specific HWND is a VCL form
/// </summary>
function IsVCLForm(WindowHandle: HWND): Boolean;

/// <summary>
/// Close a non-VCL modal window by sending WM_CLOSE message
/// </summary>
/// <param name="WindowHandle">Handle of the window to close</param>
/// <returns>True if the message was sent successfully</returns>
function CloseNonVCLModal(WindowHandle: HWND): Boolean;

implementation

uses
  System.SyncObjs;

type
  TEnumWindowsContext = record
    ProcessID: DWORD;
    Windows: TList;
  end;
  PEnumWindowsContext = ^TEnumWindowsContext;

  TWindowInfo = class
    Handle: HWND;
    Title: string;
    ClassName: string;
    IsEnabled: Boolean;
    IsVisible: Boolean;
    OwnerHandle: HWND;
    IsVCLForm: Boolean;
  end;

function GetWindowClassName(WindowHandle: HWND): string;
var
  Buffer: array[0..255] of Char;
begin
  if GetClassName(WindowHandle, Buffer, Length(Buffer)) > 0 then
    Result := string(Buffer)
  else
    Result := '';
end;

function GetWindowTitle(WindowHandle: HWND): string;
var
  Buffer: array[0..255] of Char;
begin
  if GetWindowText(WindowHandle, Buffer, Length(Buffer)) > 0 then
    Result := string(Buffer)
  else
    Result := '';
end;

function IsVCLForm(WindowHandle: HWND): Boolean;
var
  I: Integer;
begin
  Result := False;

  // Check if this HWND belongs to any form in Screen.Forms
  for I := 0 to Screen.FormCount - 1 do
  begin
    if Screen.Forms[I].Handle = WindowHandle then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function IsWindowModal(WindowHandle: HWND): Boolean;
var
  OwnerWnd: HWND;
  ForeWnd: HWND;
begin
  // A window is likely modal if:
  // 1. It has an owner window
  // 2. It's currently the foreground window
  // 3. Its owner is disabled (classic modal behavior)

  OwnerWnd := GetWindow(WindowHandle, GW_OWNER);
  ForeWnd := GetForegroundWindow;

  Result := (OwnerWnd <> 0) and
            (WindowHandle = ForeWnd) and
            (not IsWindowEnabled(OwnerWnd));
end;

function EnumWindowsCallback(WindowHandle: HWND; lParam: LPARAM): BOOL; stdcall;
var
  Context: PEnumWindowsContext;
  WindowPID: DWORD;
  Info: TWindowInfo;
begin
  Result := True; // Continue enumeration

  Context := PEnumWindowsContext(lParam);

  // Get process ID of this window
  GetWindowThreadProcessId(WindowHandle, WindowPID);

  // Only process windows from our process (if ProcessID != 0)
  if (Context.ProcessID <> 0) and (WindowPID <> Context.ProcessID) then
    Exit;

  // Skip invisible windows
  if not IsWindowVisible(WindowHandle) then
    Exit;

  // Create window info
  Info := TWindowInfo.Create;
  Info.Handle := WindowHandle;
  Info.Title := GetWindowTitle(WindowHandle);
  Info.ClassName := GetWindowClassName(WindowHandle);
  Info.IsEnabled := IsWindowEnabled(WindowHandle);
  Info.IsVisible := IsWindowVisible(WindowHandle);
  Info.OwnerHandle := GetWindow(WindowHandle, GW_OWNER);
  Info.IsVCLForm := IsVCLForm(WindowHandle);

  Context.Windows.Add(Info);
end;

function DetectNonVCLModal(out Info: TNonVCLModalInfo): Boolean;
var
  Context: TEnumWindowsContext;
  I: Integer;
  WinInfo: TWindowInfo;
  ForeWnd: HWND;
  IsCommonDialog: Boolean;
begin
  // Initialize result
  Info.Detected := False;
  Info.WindowHandle := 0;
  Info.WindowTitle := '';
  Info.WindowClass := '';
  Info.IsModal := False;
  Info.OwnerHandle := 0;
  Info.ProcessID := GetCurrentProcessId;

  // Enumerate ALL windows (not just our process)
  Context.ProcessID := 0; // Don't filter by process yet
  Context.Windows := TList.Create;
  try
    EnumWindows(@EnumWindowsCallback, LPARAM(@Context));

    // Get foreground window
    ForeWnd := GetForegroundWindow;

    // Look for non-VCL modal windows
    // Strategy: Find windows that:
    // 1. Are NOT VCL forms
    // 2. Have an owner that IS a VCL form OR TApplication
    // 3. Are either foreground OR are common dialog windows (class #32770)
    for I := 0 to Context.Windows.Count - 1 do
    begin
      WinInfo := TWindowInfo(Context.Windows[I]);

      // Skip VCL forms (we already list those separately)
      if WinInfo.IsVCLForm then
        Continue;

      // Skip if no owner
      if WinInfo.OwnerHandle = 0 then
        Continue;

      // Check if the owner is one of our VCL forms OR TApplication
      // TApplication is the main application window and can own common dialogs
      if not (IsVCLForm(WinInfo.OwnerHandle) or
              (GetWindowClassName(WinInfo.OwnerHandle) = 'TApplication')) then
        Continue;

      // Check if this is a common dialog
      // - #32770 = Old-style dialogs (XP, or legacy mode)
      // - DirectUIHWND = Vista+ IFileDialog dialogs
      IsCommonDialog := (WinInfo.ClassName = '#32770') or
                        (WinInfo.ClassName = 'DirectUIHWND');

      // Accept if: foreground window OR common dialog owned by our form OR owner is disabled
      if (WinInfo.Handle = ForeWnd) or
         IsCommonDialog or
         (not IsWindowEnabled(WinInfo.OwnerHandle)) then
      begin
        // This is a non-VCL modal window owned by our application!
        Info.Detected := True;
        Info.WindowHandle := WinInfo.Handle;
        Info.WindowTitle := WinInfo.Title;
        Info.WindowClass := WinInfo.ClassName;
        Info.IsModal := True;
        Info.OwnerHandle := WinInfo.OwnerHandle;
        Result := True;
        Exit;
      end;
    end;

    Result := False;

  finally
    // Clean up
    for I := 0 to Context.Windows.Count - 1 do
      TWindowInfo(Context.Windows[I]).Free;
    Context.Windows.Free;
  end;
end;

function ListNonVCLWindows: string;
var
  Context: TEnumWindowsContext;
  I: Integer;
  WinInfo: TWindowInfo;
  JSON: TJSONArray;
  Item: TJSONObject;
begin
  Context.ProcessID := GetCurrentProcessId;
  Context.Windows := TList.Create;
  try
    EnumWindows(@EnumWindowsCallback, LPARAM(@Context));

    JSON := TJSONArray.Create;
    try
      for I := 0 to Context.Windows.Count - 1 do
      begin
        WinInfo := TWindowInfo(Context.Windows[I]);

        // Skip VCL forms (already listed elsewhere)
        if WinInfo.IsVCLForm then
          Continue;

        Item := TJSONObject.Create;
        Item.AddPair('handle', TJSONNumber.Create(Integer(WinInfo.Handle)));
        Item.AddPair('title', WinInfo.Title);
        Item.AddPair('class', WinInfo.ClassName);
        Item.AddPair('enabled', TJSONBool.Create(WinInfo.IsEnabled));
        Item.AddPair('visible', TJSONBool.Create(WinInfo.IsVisible));
        if WinInfo.OwnerHandle <> 0 then
          Item.AddPair('owner_handle', TJSONNumber.Create(Integer(WinInfo.OwnerHandle)));
        Item.AddPair('is_modal', TJSONBool.Create(IsWindowModal(WinInfo.Handle)));

        JSON.AddElement(Item);
      end;

      Result := JSON.ToString;
    finally
      JSON.Free;
    end;

  finally
    for I := 0 to Context.Windows.Count - 1 do
      TWindowInfo(Context.Windows[I]).Free;
    Context.Windows.Free;
  end;
end;

function CloseNonVCLModal(WindowHandle: HWND): Boolean;
begin
  // Send WM_CLOSE message to the window
  // This is equivalent to clicking the X button or pressing Alt+F4
  Result := SendMessage(WindowHandle, WM_CLOSE, 0, 0) = 0;
end;

end.
