unit AutomationSynchronization;

{
  Automation Wait Conditions - Synchronization primitives for automation

  PURPOSE:
  - Provide wait conditions for reliable UI automation
  - Support atomic compound conditions
  - Enable token-efficient polling

  FEATURES:
  - wait.idle - Wait for message queue quiescence
  - wait.focus - Wait for specific control focus
  - wait.text - Wait for text content
  - wait.when - Compound condition wait (atomic multi-condition sync)

  ORIGIN:
  - Extracted from CyberMAX MCP implementation
  - Pure VCL/Windows API (no dependencies to remove)
}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages,
  Vcl.Forms, Vcl.Controls;

type
  TConditionType = (ctFocus, ctTextContains, ctVisible, ctEnabled);

  TCondition = record
    CondType: TConditionType;
    Hwnd: HWND;
    Value: string;        // For text_contains
    BoolValue: Boolean;   // For visible, enabled
  end;

// Wait condition functions
function WaitIdle(QuiesceMs, TimeoutMs: Integer): Boolean;
function WaitFocus(hwnd: HWND; TimeoutMs: Integer): Boolean;
function WaitText(hwnd: HWND; const Contains: string; TimeoutMs: Integer): Boolean;
function WaitWhen(const Conditions: TArray<TCondition>; TimeoutMs: Integer): Boolean;

// Helper functions
function GetFocusedHWND: HWND;
function GetControlText(hwnd: HWND): string;
function ParseConditions(const JSONArray: TJSONArray): TArray<TCondition>;

implementation

uses
  System.StrUtils;

const
  // MsgWaitForMultipleObjectsEx flags
  MWMO_INPUTAVAILABLE = $0004;  // Return if input is available

{ Helper Functions }

function GetFocusedHWND: HWND;
var
  gui: TGUIThreadInfo;
begin
  FillChar(gui, SizeOf(gui), 0);
  gui.cbSize := SizeOf(gui);
  if GetGUIThreadInfo(0, gui) then
    Result := gui.hwndFocus
  else
    Result := 0;
end;

function GetControlText(hwnd: HWND): string;
var
  len: Integer;
  buf: array[0..1023] of Char;
begin
  len := SendMessage(hwnd, WM_GETTEXTLENGTH, 0, 0);
  if len > 0 then
  begin
    FillChar(buf, SizeOf(buf), 0);
    SendMessage(hwnd, WM_GETTEXT, Length(buf), LPARAM(@buf[0]));
    Result := buf;
  end
  else
    Result := '';
end;

function ParseConditions(const JSONArray: TJSONArray): TArray<TCondition>;
var
  I: Integer;
  CondObj: TJSONObject;
  CondType: string;
  Cond: TCondition;
begin
  SetLength(Result, JSONArray.Count);

  for I := 0 to JSONArray.Count - 1 do
  begin
    CondObj := JSONArray.Items[I] as TJSONObject;

    if CondObj.TryGetValue<string>('type', CondType) then
    begin
      if SameText(CondType, 'focus') then
        Cond.CondType := ctFocus
      else if SameText(CondType, 'text_contains') then
        Cond.CondType := ctTextContains
      else if SameText(CondType, 'visible') then
        Cond.CondType := ctVisible
      else if SameText(CondType, 'enabled') then
        Cond.CondType := ctEnabled
      else
        Continue; // Skip unknown types

      CondObj.TryGetValue<HWND>('hwnd', Cond.Hwnd);
      CondObj.TryGetValue<string>('contains', Cond.Value);
      CondObj.TryGetValue<string>('value', Cond.Value); // Alternative key
      CondObj.TryGetValue<Boolean>('bool_value', Cond.BoolValue);

      Result[I] := Cond;
    end;
  end;
end;

{ Wait Conditions }

function WaitIdle(QuiesceMs, TimeoutMs: Integer): Boolean;
var
  lastActive, t0: UInt64;
  res: DWORD;
begin
  t0 := GetTickCount64;
  lastActive := t0;

  while GetTickCount64 - t0 < TimeoutMs do
  begin
    // Wait for message or 30ms timeout
    res := MsgWaitForMultipleObjectsEx(0, nil^, 30, QS_ALLINPUT, MWMO_INPUTAVAILABLE);

    if res = WAIT_TIMEOUT then
    begin
      // No messages available
      if GetTickCount64 - lastActive >= QuiesceMs then
        Exit(True); // Quiet for required duration
    end
    else
    begin
      // Messages available - reset quiet timer
      lastActive := GetTickCount64;
      Application.ProcessMessages; // Drain queue
    end;
  end;

  Result := False; // Timeout
end;

function WaitFocus(hwnd: HWND; TimeoutMs: Integer): Boolean;
var
  t0: UInt64;
begin
  t0 := GetTickCount64;
  while GetTickCount64 - t0 < TimeoutMs do
  begin
    if GetFocusedHWND = hwnd then
      Exit(True);
    Sleep(30); // Poll every 30ms
  end;
  Result := False;
end;

function WaitText(hwnd: HWND; const Contains: string; TimeoutMs: Integer): Boolean;
var
  t0: UInt64;
  currentText: string;
begin
  t0 := GetTickCount64;
  while GetTickCount64 - t0 < TimeoutMs do
  begin
    currentText := GetControlText(hwnd);
    if ContainsText(currentText, Contains) then
      Exit(True);
    Sleep(30);
  end;
  Result := False;
end;

function WaitWhen(const Conditions: TArray<TCondition>; TimeoutMs: Integer): Boolean;
var
  t0: UInt64;
  allOk: Boolean;
  cond: TCondition;
  ctrl: TWinControl;
begin
  t0 := GetTickCount64;

  while GetTickCount64 - t0 < TimeoutMs do
  begin
    allOk := True;

    for cond in Conditions do
    begin
      case cond.CondType of
        ctFocus:
          if GetFocusedHWND <> cond.Hwnd then
          begin
            allOk := False;
            Break;
          end;

        ctTextContains:
          if not ContainsText(GetControlText(cond.Hwnd), cond.Value) then
          begin
            allOk := False;
            Break;
          end;

        ctVisible:
          begin
            ctrl := FindControl(cond.Hwnd);
            if (ctrl = nil) or (ctrl.Visible <> cond.BoolValue) then
            begin
              allOk := False;
              Break;
            end;
          end;

        ctEnabled:
          begin
            ctrl := FindControl(cond.Hwnd);
            if (ctrl = nil) or (ctrl.Enabled <> cond.BoolValue) then
            begin
              allOk := False;
              Break;
            end;
          end;
      end;
    end;

    if allOk then
      Exit(True);

    Sleep(30); // Poll every 30ms
  end;

  Result := False;
end;

end.
