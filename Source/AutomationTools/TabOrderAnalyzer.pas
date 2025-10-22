unit TabOrderAnalyzer;

{
  Tab Order Analyzer - Visual and Text Tab Order Documentation

  PURPOSE:
  - Simulate Tab key navigation through all controls on a form
  - Generate annotated screenshot showing tab order with numbered rectangles
  - Generate text file listing all controls in tab order with hierarchical names

  USAGE:
  - Call AnalyzeFormTabOrder from within any form
  - Generates:
    * [FormName]_TabOrder.png - Screenshot with numbered control rectangles
    * [FormName]_TabOrder.txt - Text list of controls in tab order

  EXAMPLE:
    AnalyzeFormTabOrder(Self);
}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Forms, Vcl.Controls, Vcl.Imaging.PngImage,
  Winapi.Windows, Winapi.Messages;

type
  TTabOrderInfo = record
    Control: TWinControl;
    TabOrder: Integer;
    FullName: string;
    ScreenRect: TRect;
  end;

procedure AnalyzeFormTabOrder(AForm: TForm; const OutputPath: string = '');

implementation

uses
  System.Types, System.Math;

// Send Tab key using SendInput
procedure SimulateTabKey;
var
  Inputs: array[0..1] of TInput;
begin
  ZeroMemory(@Inputs, SizeOf(Inputs));

  // Key down
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_TAB;
  Inputs[0].ki.dwFlags := 0;

  // Key up
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := VK_TAB;
  Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(2, Inputs[0], SizeOf(TInput));
end;

// Get hierarchical control name (Name.ParentName.ParentName... until Form)
function GetControlFullName(AControl: TWinControl; StopAtForm: TForm): string;
var
  Current: TWinControl;
  Parts: TStringList;
  I: Integer;
  ControlName: string;
begin
  Parts := TStringList.Create;
  try
    Current := AControl;

    while (Current <> nil) and (Current <> StopAtForm) do
    begin
      if Current.Name <> '' then
        ControlName := Current.Name
      else
        ControlName := '[' + Current.ClassName + ']';

      Parts.Insert(0, ControlName);
      Current := Current.Parent;
    end;

    Result := '';
    for I := 0 to Parts.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + '.';
      Result := Result + Parts[I];
    end;
  finally
    Parts.Free;
  end;
end;

// Collect tab order information by simulating Tab navigation
function CollectTabOrder(AForm: TForm): TList<TTabOrderInfo>;
var
  StartControl, CurrentControl: TWinControl;
  Info: TTabOrderInfo;
  TabIndex: Integer;
  MaxIterations: Integer;
  ClientPoint: TPoint;
begin
  Result := TList<TTabOrderInfo>.Create;

  // Focus the form first
  if AForm.CanFocus then
    AForm.SetFocus;

  // Give focus time to settle
  Application.ProcessMessages;
  Sleep(50);

  StartControl := Screen.ActiveControl;
  if StartControl = nil then
    Exit;

  TabIndex := 0;
  MaxIterations := 1000; // Safety limit

  repeat
    CurrentControl := Screen.ActiveControl;

    if CurrentControl <> nil then
    begin
      Info.Control := CurrentControl;
      Info.TabOrder := TabIndex;
      Info.FullName := GetControlFullName(CurrentControl, AForm);

      // Get screen coordinates
      ClientPoint := Point(0, 0);
      Info.ScreenRect.TopLeft := CurrentControl.ClientToScreen(ClientPoint);
      ClientPoint := Point(CurrentControl.Width, CurrentControl.Height);
      Info.ScreenRect.BottomRight := CurrentControl.ClientToScreen(ClientPoint);

      Result.Add(Info);
    end;

    // Simulate Tab key
    SimulateTabKey;
    Application.ProcessMessages;
    Sleep(50); // Allow focus to change

    Inc(TabIndex);
    Dec(MaxIterations);

  until (Screen.ActiveControl = StartControl) or (MaxIterations <= 0);
end;

// Capture form screenshot
function CaptureFormBitmap(AForm: TForm): Vcl.Graphics.TBitmap;
var
  FormRect: TRect;
  FormDC: HDC;
  MemDC: HDC;
  OldBitmap: HBITMAP;
begin
  GetWindowRect(AForm.Handle, FormRect);

  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf24bit;
    Result.Width := FormRect.Width;
    Result.Height := FormRect.Height;

    FormDC := GetDC(AForm.Handle);
    try
      MemDC := CreateCompatibleDC(FormDC);
      try
        OldBitmap := SelectObject(MemDC, Result.Handle);

        // Use BitBlt to capture the form
        BitBlt(MemDC, 0, 0, Result.Width, Result.Height,
               FormDC, 0, 0, SRCCOPY);

        SelectObject(MemDC, OldBitmap);
      finally
        DeleteDC(MemDC);
      end;
    finally
      ReleaseDC(AForm.Handle, FormDC);
    end;
  except
    Result.Free;
    raise;
  end;
end;

// Draw numbered rectangles on bitmap
procedure AnnotateBitmap(Bitmap: Vcl.Graphics.TBitmap; TabOrderList: TList<TTabOrderInfo>; FormScreenRect: TRect);
var
  I: Integer;
  Info: TTabOrderInfo;
  RelativeRect: TRect;
  NumberText: string;
  TextSize: TSize;
  TextRect: TRect;
  NumberX, NumberY: Integer;
begin
  Bitmap.Canvas.Brush.Style := bsClear;
  Bitmap.Canvas.Pen.Width := 2;
  Bitmap.Canvas.Font.Size := 10;
  Bitmap.Canvas.Font.Style := [fsBold];
  Bitmap.Canvas.Font.Color := clBlack;

  for I := 0 to TabOrderList.Count - 1 do
  begin
    Info := TabOrderList[I];

    // Convert screen coordinates to bitmap coordinates
    RelativeRect.Left := Info.ScreenRect.Left - FormScreenRect.Left;
    RelativeRect.Top := Info.ScreenRect.Top - FormScreenRect.Top;
    RelativeRect.Right := Info.ScreenRect.Right - FormScreenRect.Left;
    RelativeRect.Bottom := Info.ScreenRect.Bottom - FormScreenRect.Top;

    // Draw rectangle
    Bitmap.Canvas.Pen.Color := clRed;
    Bitmap.Canvas.Rectangle(RelativeRect);

    // Draw number
    NumberText := IntToStr(I + 1);
    TextSize := Bitmap.Canvas.TextExtent(NumberText);

    // Position number in top-left corner of control
    NumberX := RelativeRect.Left + 4;
    NumberY := RelativeRect.Top + 2;

    // Draw white background for number
    TextRect := Rect(NumberX - 2, NumberY - 1,
                     NumberX + TextSize.cx + 2, NumberY + TextSize.cy + 1);
    Bitmap.Canvas.Brush.Style := bsSolid;
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(TextRect);

    // Draw number text
    Bitmap.Canvas.Brush.Style := bsClear;
    Bitmap.Canvas.TextOut(NumberX, NumberY, NumberText);
  end;
end;

// Save text file with tab order listing
procedure SaveTabOrderText(const FileName: string; TabOrderList: TList<TTabOrderInfo>);
var
  F: TextFile;
  I: Integer;
  Info: TTabOrderInfo;
begin
  AssignFile(F, FileName);
  try
    Rewrite(F);
    try
      WriteLn(F, 'Tab Order Analysis');
      WriteLn(F, '==================');
      WriteLn(F, '');
      WriteLn(F, Format('Total controls: %d', [TabOrderList.Count]));
      WriteLn(F, '');

      for I := 0 to TabOrderList.Count - 1 do
      begin
        Info := TabOrderList[I];
        WriteLn(F, Format('%3d. %s', [I + 1, Info.FullName]));
      end;
    finally
      CloseFile(F);
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('Failed to save text file: %s', [E.Message]);
  end;
end;

procedure AnalyzeFormTabOrder(AForm: TForm; const OutputPath: string = '');
var
  TabOrderList: TList<TTabOrderInfo>;
  FormBitmap: Vcl.Graphics.TBitmap;
  PngImage: TPngImage;
  FormScreenRect: TRect;
  BaseFileName, ImageFileName, TextFileName: string;
  OutputDir: string;
begin
  if AForm = nil then
    raise Exception.Create('Form cannot be nil');

  TabOrderList := nil;
  FormBitmap := nil;
  PngImage := nil;

  try
    // Determine output path
    if OutputPath <> '' then
      OutputDir := IncludeTrailingPathDelimiter(OutputPath)
    else
      OutputDir := ExtractFilePath(ParamStr(0));

    // Base filename
    if AForm.Name <> '' then
      BaseFileName := AForm.Name
    else
      BaseFileName := AForm.ClassName;

    ImageFileName := OutputDir + BaseFileName + '_TabOrder.png';
    TextFileName := OutputDir + BaseFileName + '_TabOrder.txt';

    // Collect tab order by simulating navigation
    TabOrderList := CollectTabOrder(AForm);

    if TabOrderList.Count = 0 then
      raise Exception.Create('No controls found in tab order');

    // Get form screen coordinates
    GetWindowRect(AForm.Handle, FormScreenRect);

    // Capture form bitmap
    FormBitmap := CaptureFormBitmap(AForm);

    // Annotate with numbered rectangles
    AnnotateBitmap(FormBitmap, TabOrderList, FormScreenRect);

    // Save as PNG
    PngImage := TPngImage.Create;
    PngImage.Assign(FormBitmap);
    PngImage.SaveToFile(ImageFileName);

    // Save text file
    SaveTabOrderText(TextFileName, TabOrderList);

  finally
    TabOrderList.Free;
    FormBitmap.Free;
    PngImage.Free;
  end;
end;

end.
