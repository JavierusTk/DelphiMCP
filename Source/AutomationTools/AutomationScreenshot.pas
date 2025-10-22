unit AutomationScreenshot;

{
  Screenshot Utilities for Automation Framework

  PURPOSE:
  - Capture screenshots for AI visual inspection
  - Support full screen, active form, specific form, or focused control
  - Return PNG image as base64-encoded string

  USAGE:
  - TakeScreenshot(Target, Base64Result)
  - Target can be:
    * 'screen' or 'full' - entire screen
    * 'active' or 'focus' - active form
    * 'wincontrol' - focused control
    * 'wincontrol+N' - focused control with N pixel margin
    * 'wincontrol.parent' - parent of focused control
    * 'wincontrol.parent+N' - parent with N pixel margin
    * 'wincontrol.parent.parent+N' - grandparent with margin
    * form name - specific form by name

  ORIGIN:
  - Extracted from CyberMAX MCP implementation
  - Pure Windows API + VCL (no dependencies to remove)
}

interface

uses
  System.SysUtils, System.Classes, System.Types, Vcl.Graphics, Vcl.Forms, Vcl.Imaging.PngImage,
  Winapi.Windows, Winapi.Messages;

type
  TScreenshotTarget = (stFullScreen, stActiveForm, stSpecificForm);

  TScreenshotResult = record
    Success: Boolean;
    Base64Data: string;
    Width: Integer;
    Height: Integer;
    ErrorMessage: string;
  end;

// High-level screenshot functions
function TakeScreenshot(const Target: string): TScreenshotResult;
function TakeFullScreenshot: TScreenshotResult;
function TakeActiveFormScreenshot: TScreenshotResult;
function TakeFormScreenshot(const FormName: string): TScreenshotResult;
function TakeFormScreenshotByHandle(FormHandle: HWND): TScreenshotResult;
function TakeWinControlScreenshot(ParentLevel: Integer; Margin: Integer): TScreenshotResult;

implementation

uses
  System.NetEncoding, Vcl.Controls;

// PrintWindow API declaration (not always available in Winapi.Windows)
function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll';

function BitmapToPngBase64(Bitmap: Vcl.Graphics.TBitmap): string;
var
  PngImage: TPngImage;
  MemStream: TMemoryStream;
  Bytes: TBytes;
begin
  Result := '';
  PngImage := TPngImage.Create;
  MemStream := TMemoryStream.Create;
  try
    PngImage.Assign(Bitmap);
    PngImage.SaveToStream(MemStream);

    MemStream.Position := 0;
    SetLength(Bytes, MemStream.Size);
    MemStream.ReadBuffer(Bytes[0], MemStream.Size);

    Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  finally
    PngImage.Free;
    MemStream.Free;
  end;
end;

function CaptureScreen(TargetRect: TRect): Vcl.Graphics.TBitmap;
var
  DC: HDC;
  MemDC: HDC;
  OldBitmap: HBITMAP;
begin
  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf24bit;
    Result.Width := TargetRect.Width;
    Result.Height := TargetRect.Height;

    DC := GetDC(0); // Get screen DC
    try
      MemDC := CreateCompatibleDC(DC);
      try
        OldBitmap := SelectObject(MemDC, Result.Handle);
        BitBlt(MemDC, 0, 0, TargetRect.Width, TargetRect.Height,
               DC, TargetRect.Left, TargetRect.Top, SRCCOPY);
        SelectObject(MemDC, OldBitmap);
      finally
        DeleteDC(MemDC);
      end;
    finally
      ReleaseDC(0, DC);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CaptureWindow(WindowHandle: HWND): Vcl.Graphics.TBitmap;
var
  WindowRect: TRect;
  WindowDC: HDC;
  MemDC: HDC;
  OldBitmap: HBITMAP;
  Width, Height: Integer;
begin
  if not GetWindowRect(WindowHandle, WindowRect) then
    raise Exception.Create('Failed to get window rectangle');

  Width := WindowRect.Width;
  Height := WindowRect.Height;

  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf24bit;
    Result.Width := Width;
    Result.Height := Height;

    WindowDC := GetDC(WindowHandle);
    try
      MemDC := CreateCompatibleDC(WindowDC);
      try
        OldBitmap := SelectObject(MemDC, Result.Handle);

        // Use PrintWindow for more reliable capture (works even if partially obscured)
        PrintWindow(WindowHandle, MemDC, 0);

        SelectObject(MemDC, OldBitmap);
      finally
        DeleteDC(MemDC);
      end;
    finally
      ReleaseDC(WindowHandle, WindowDC);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function FindFormByName(const FormName: string): TForm;
var
  I: Integer;
  Form: TForm;
begin
  Result := nil;

  for I := 0 to Screen.FormCount - 1 do
  begin
    Form := Screen.Forms[I];

    // Try matching by name, class name, or caption
    if SameText(Form.Name, FormName) or
       SameText(Form.ClassName, FormName) or
       SameText(Form.Caption, FormName) then
    begin
      Result := Form;
      Exit;
    end;
  end;
end;

function TakeFullScreenshot: TScreenshotResult;
var
  ScreenRect: TRect;
  Bitmap: Vcl.Graphics.TBitmap;
begin
  Result.Success := False;
  Result.Base64Data := '';
  Result.ErrorMessage := '';

  try
    ScreenRect := Rect(0, 0, Screen.Width, Screen.Height);
    Bitmap := CaptureScreen(ScreenRect);
    try
      Result.Width := Bitmap.Width;
      Result.Height := Bitmap.Height;
      Result.Base64Data := BitmapToPngBase64(Bitmap);
      Result.Success := True;
    finally
      Bitmap.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TakeActiveFormScreenshot: TScreenshotResult;
var
  ActiveForm: TForm;
begin
  Result.Success := False;
  Result.Base64Data := '';
  Result.ErrorMessage := '';

  try
    ActiveForm := Screen.ActiveForm;

    if ActiveForm = nil then
    begin
      Result.ErrorMessage := 'No active form';
      Exit;
    end;

    Result := TakeFormScreenshotByHandle(ActiveForm.Handle);
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TakeFormScreenshot(const FormName: string): TScreenshotResult;
var
  Form: TForm;
begin
  Result.Success := False;
  Result.Base64Data := '';
  Result.ErrorMessage := '';

  try
    Form := FindFormByName(FormName);

    if Form = nil then
    begin
      Result.ErrorMessage := 'Form not found: ' + FormName;
      Exit;
    end;

    Result := TakeFormScreenshotByHandle(Form.Handle);
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TakeFormScreenshotByHandle(FormHandle: HWND): TScreenshotResult;
var
  Bitmap: Vcl.Graphics.TBitmap;
begin
  Result.Success := False;
  Result.Base64Data := '';
  Result.ErrorMessage := '';

  try
    if not IsWindow(FormHandle) then
    begin
      Result.ErrorMessage := 'Invalid window handle';
      Exit;
    end;

    Bitmap := CaptureWindow(FormHandle);
    try
      Result.Width := Bitmap.Width;
      Result.Height := Bitmap.Height;
      Result.Base64Data := BitmapToPngBase64(Bitmap);
      Result.Success := True;
    finally
      Bitmap.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TakeWinControlScreenshot(ParentLevel: Integer; Margin: Integer): TScreenshotResult;
var
  Control: TWinControl;
  ControlRect: TRect;
  ScreenRect: TRect;
  TopLeft, BottomRight: TPoint;
  Bitmap: Vcl.Graphics.TBitmap;
  I: Integer;
begin
  Result.Success := False;
  Result.ErrorMessage := '';

  // Get the currently focused control
  Control := Screen.ActiveControl;

  if Control = nil then
  begin
    Result.ErrorMessage := 'No focused WinControl found';
    Exit;
  end;

  // Navigate up parent chain if requested
  for I := 1 to ParentLevel do
  begin
    if Control.Parent <> nil then
      Control := Control.Parent
    else
    begin
      Result.ErrorMessage := Format('Control does not have %d parent levels', [ParentLevel]);
      Exit;
    end;
  end;

  try
    // Get control bounds in client coordinates
    ControlRect := Control.BoundsRect;

    // Convert top-left to screen coordinates
    TopLeft := Control.ClientToScreen(Point(ControlRect.Left, ControlRect.Top));
    BottomRight := Control.ClientToScreen(Point(ControlRect.Right, ControlRect.Bottom));

    // Build screen rect with margin
    ScreenRect.Left := TopLeft.X - Margin;
    ScreenRect.Top := TopLeft.Y - Margin;
    ScreenRect.Right := BottomRight.X + Margin;
    ScreenRect.Bottom := BottomRight.Y + Margin;

    // Ensure rect is within screen bounds
    if ScreenRect.Left < 0 then ScreenRect.Left := 0;
    if ScreenRect.Top < 0 then ScreenRect.Top := 0;
    if ScreenRect.Right > Screen.Width then ScreenRect.Right := Screen.Width;
    if ScreenRect.Bottom > Screen.Height then ScreenRect.Bottom := Screen.Height;

    // Capture the screen region
    Bitmap := CaptureScreen(ScreenRect);
    try
      Result.Base64Data := BitmapToPngBase64(Bitmap);
      Result.Width := Bitmap.Width;
      Result.Height := Bitmap.Height;
      Result.Success := True;
    finally
      Bitmap.Free;
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Screenshot failed: ' + E.Message;
      Result.Success := False;
    end;
  end;
end;

function TakeScreenshot(const Target: string): TScreenshotResult;
var
  TargetLower: string;
  ParentLevel: Integer;
  Margin: Integer;
  PosParent, PosPlus: Integer;
  MarginStr: string;
begin
  TargetLower := LowerCase(Target);

  // Check for wincontrol target: wincontrol[.parent]*[+margin]
  if Pos('wincontrol', TargetLower) = 1 then
  begin
    ParentLevel := 0;
    Margin := 0;

    // Count .parent occurrences
    PosParent := Pos('.parent', TargetLower);
    while PosParent > 0 do
    begin
      Inc(ParentLevel);
      Delete(TargetLower, PosParent, 7); // Remove '.parent'
      PosParent := Pos('.parent', TargetLower);
    end;

    // Extract margin if present (e.g., +40)
    PosPlus := Pos('+', TargetLower);
    if PosPlus > 0 then
    begin
      MarginStr := Copy(TargetLower, PosPlus + 1, Length(TargetLower));
      Margin := StrToIntDef(MarginStr, 0);
    end;

    Result := TakeWinControlScreenshot(ParentLevel, Margin);
  end
  else if SameText(Target, 'screen') or SameText(Target, 'full') then
    Result := TakeFullScreenshot
  else if SameText(Target, 'active') or SameText(Target, 'focus') then
    Result := TakeActiveFormScreenshot
  else
    Result := TakeFormScreenshot(Target);
end;

end.
