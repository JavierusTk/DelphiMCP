unit AutomationInputSimulation;

{
  Automation Input Simulation Tools

  Provides low-level keyboard and mouse input simulation via Windows SendInput API.
  Ported from DelphiMCP_UI_Agent uInputSim.pas with Automation Framework adaptations.

  Tools Implemented:
  - ui.send_keys: Send keyboard input (Unicode text + special keys)
  - ui.mouse_move: Move mouse cursor to screen coordinates
  - ui.mouse_click: Click mouse button at current position
  - ui.mouse_dblclick: Double-click mouse button
  - ui.mouse_wheel: Scroll mouse wheel

  Thread Safety: All operations are already in main thread via MCPServerThread synchronization
}

interface

uses
  Winapi.Windows,
  System.Types,
  System.SysUtils,
  System.Math,
  System.JSON;

// Tool implementations (called from MCPCoreTools)
procedure Tool_SendKeys(const Params: TJSONObject; out Result: TJSONObject);
procedure Tool_MouseMove(const Params: TJSONObject; out Result: TJSONObject);
procedure Tool_MouseClick(const Params: TJSONObject; out Result: TJSONObject);
procedure Tool_MouseDblClick(const Params: TJSONObject; out Result: TJSONObject);
procedure Tool_MouseWheel(const Params: TJSONObject; out Result: TJSONObject);

// Schema creators
function CreateSchema_SendKeys: TJSONObject;
function CreateSchema_MouseMove: TJSONObject;
function CreateSchema_MouseClick: TJSONObject;
function CreateSchema_MouseDblClick: TJSONObject;
function CreateSchema_MouseWheel: TJSONObject;

implementation

const
  MOUSEEVENTF_VIRTUALDESK = $4000;

// ============================================================================
// Low-Level Input Simulation (ported from uInputSim.pas)
// ============================================================================

procedure SendInputs(const Inputs: array of TInput);
begin
  if Length(Inputs) > 0 then
    if SendInput(Length(Inputs), @Inputs[0], SizeOf(TInput)) = 0 then
      RaiseLastOSError;
end;

procedure SendUnicodeText(const S: string);
var
  Inputs: TArray<TInput>;
  i, n: Integer;
begin
  n := Length(S);
  SetLength(Inputs, n * 2);
  for i := 0 to n - 1 do
  begin
    Inputs[i * 2].Itype := INPUT_KEYBOARD;
    Inputs[i * 2].ki.wVk := 0;
    Inputs[i * 2].ki.wScan := Word(S[i + 1]);
    Inputs[i * 2].ki.dwFlags := KEYEVENTF_UNICODE;

    Inputs[i * 2 + 1].Itype := INPUT_KEYBOARD;
    Inputs[i * 2 + 1].ki.wVk := 0;
    Inputs[i * 2 + 1].ki.wScan := Word(S[i + 1]);
    Inputs[i * 2 + 1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
  end;
  SendInputs(Inputs);
end;

procedure KeyDown(vk: WORD);
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_KEYBOARD;
  I.ki.wVk := vk;
  SendInputs([I]);
end;

procedure KeyUp(vk: WORD);
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_KEYBOARD;
  I.ki.wVk := vk;
  I.ki.dwFlags := KEYEVENTF_KEYUP;
  SendInputs([I]);
end;

procedure Tap(vk: WORD);
begin
  KeyDown(vk);
  KeyUp(vk);
end;

function VirtualScreenRect: TRect;
begin
  Result.Left := GetSystemMetrics(SM_XVIRTUALSCREEN);
  Result.Top := GetSystemMetrics(SM_YVIRTUALSCREEN);
  Result.Right := Result.Left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
  Result.Bottom := Result.Top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
end;

procedure ScreenToAbsolute(const Pt: TPoint; out AbsX, AbsY: Integer);
var
  vr: TRect;
begin
  vr := VirtualScreenRect;
  AbsX := Round((Pt.X - vr.Left) * 65535.0 / Max(1, vr.Right - vr.Left - 1));
  AbsY := Round((Pt.Y - vr.Top) * 65535.0 / Max(1, vr.Bottom - vr.Top - 1));
end;

procedure MouseMoveAbs(const Pt: TPoint);
var
  Inp: TInput;
  ax, ay: Integer;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_MOUSE;
  ScreenToAbsolute(Pt, ax, ay);
  Inp.mi.dwFlags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE or MOUSEEVENTF_VIRTUALDESK;
  Inp.mi.dx := ax;
  Inp.mi.dy := ay;
  SendInputs([Inp]);
end;

procedure MouseLeftDown;
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_MOUSE;
  I.mi.dwFlags := MOUSEEVENTF_LEFTDOWN;
  SendInputs([I]);
end;

procedure MouseLeftUp;
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_MOUSE;
  I.mi.dwFlags := MOUSEEVENTF_LEFTUP;
  SendInputs([I]);
end;

procedure MouseRightDown;
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_MOUSE;
  I.mi.dwFlags := MOUSEEVENTF_RIGHTDOWN;
  SendInputs([I]);
end;

procedure MouseRightUp;
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_MOUSE;
  I.mi.dwFlags := MOUSEEVENTF_RIGHTUP;
  SendInputs([I]);
end;

procedure MouseLeftClick;
begin
  MouseLeftDown;
  MouseLeftUp;
end;

procedure MouseRightClick;
begin
  MouseRightDown;
  MouseRightUp;
end;

procedure MouseLeftDblClick;
begin
  MouseLeftClick;
  Sleep(GetDoubleClickTime div 2);
  MouseLeftClick;
end;

procedure MouseWheelDelta(Delta: Integer);
var
  I: TInput;
begin
  ZeroMemory(@I, SizeOf(I));
  I.Itype := INPUT_MOUSE;
  I.mi.mouseData := Delta;
  I.mi.dwFlags := MOUSEEVENTF_WHEEL;
  SendInputs([I]);
end;

// ============================================================================
// Special Key Parsing
// ============================================================================

function ParseSpecialKey(const KeyName: string): WORD;
begin
  if SameText(KeyName, 'ENTER') or SameText(KeyName, 'RETURN') then
    Result := VK_RETURN
  else if SameText(KeyName, 'TAB') then
    Result := VK_TAB
  else if SameText(KeyName, 'ESC') or SameText(KeyName, 'ESCAPE') then
    Result := VK_ESCAPE
  else if SameText(KeyName, 'BACKSPACE') or SameText(KeyName, 'BACK') then
    Result := VK_BACK
  else if SameText(KeyName, 'DELETE') or SameText(KeyName, 'DEL') then
    Result := VK_DELETE
  else if SameText(KeyName, 'UP') then
    Result := VK_UP
  else if SameText(KeyName, 'DOWN') then
    Result := VK_DOWN
  else if SameText(KeyName, 'LEFT') then
    Result := VK_LEFT
  else if SameText(KeyName, 'RIGHT') then
    Result := VK_RIGHT
  else if SameText(KeyName, 'HOME') then
    Result := VK_HOME
  else if SameText(KeyName, 'END') then
    Result := VK_END
  else if SameText(KeyName, 'PAGEUP') or SameText(KeyName, 'PGUP') then
    Result := VK_PRIOR
  else if SameText(KeyName, 'PAGEDOWN') or SameText(KeyName, 'PGDN') then
    Result := VK_NEXT
  else if (Length(KeyName) = 2) and (KeyName[1] = 'F') and CharInSet(KeyName[2], ['1'..'9']) then
    Result := VK_F1 + Ord(KeyName[2]) - Ord('1')
  else if (Length(KeyName) = 3) and (KeyName[1] = 'F') and (KeyName[2] = '1') and CharInSet(KeyName[3], ['0'..'2']) then
    Result := VK_F10 + Ord(KeyName[3]) - Ord('0')
  else
    Result := 0; // Unknown special key
end;

procedure SendKeysSequence(const Sequence: string);
var
  i: Integer;
  inBracket: Boolean;
  bracketContent: string;
  vk: WORD;
begin
  i := 1;
  inBracket := False;
  bracketContent := '';

  while i <= Length(Sequence) do
  begin
    if Sequence[i] = '{' then
    begin
      inBracket := True;
      bracketContent := '';
    end
    else if Sequence[i] = '}' then
    begin
      if inBracket then
      begin
        // Process special key
        vk := ParseSpecialKey(bracketContent);
        if vk <> 0 then
          Tap(vk)
        else
          raise Exception.CreateFmt('Unknown special key: {%s}', [bracketContent]);
        inBracket := False;
        bracketContent := '';
      end;
    end
    else if inBracket then
    begin
      bracketContent := bracketContent + Sequence[i];
    end
    else
    begin
      // Regular character - send as Unicode
      SendUnicodeText(Sequence[i]);
    end;
    Inc(i);
  end;
end;

// ============================================================================
// MCP Tool Implementations
// ============================================================================

procedure Tool_SendKeys(const Params: TJSONObject; out Result: TJSONObject);
var
  Keys: string;
  TargetHandle: Integer;
  PrevForeground: HWND;
  FocusSet: Boolean;
begin
  Result := TJSONObject.Create;
  try
    if not Params.TryGetValue<string>('keys', Keys) then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Missing required parameter: keys');
      Exit;
    end;

    // Optional: target a specific window by handle
    if Params.TryGetValue<Integer>('target_handle', TargetHandle) and (TargetHandle <> 0) then
    begin
      // Check if target window is already foreground
      PrevForeground := GetForegroundWindow;

      if PrevForeground = HWND(TargetHandle) then
      begin
        // Target is already foreground - just send keys directly
        SendKeysSequence(Keys);
        Result.AddPair('success', TJSONBool.Create(True));
        Result.AddPair('keys_sent', Keys);
        Result.AddPair('targeted_window', TJSONNumber.Create(TargetHandle));
        Result.AddPair('was_already_foreground', TJSONBool.Create(True));
        OutputDebugString(PChar(Format('MCP.SendKeys: Sent keys to foreground window %d - %s', [TargetHandle, Keys])));
      end
      else
      begin
        // Try to set focus to target window
        FocusSet := SetForegroundWindow(HWND(TargetHandle));

        if FocusSet then
        begin
          // Give window time to process focus change
          Sleep(100);

          // Send keys
          SendKeysSequence(Keys);

          // Restore previous foreground window
          if PrevForeground <> 0 then
            SetForegroundWindow(PrevForeground);

          Result.AddPair('success', TJSONBool.Create(True));
          Result.AddPair('keys_sent', Keys);
          Result.AddPair('targeted_window', TJSONNumber.Create(TargetHandle));
          Result.AddPair('was_already_foreground', TJSONBool.Create(False));
          OutputDebugString(PChar(Format('MCP.SendKeys: Sent keys to window %d - %s', [TargetHandle, Keys])));
        end
        else
        begin
          Result.AddPair('success', TJSONBool.Create(False));
          Result.AddPair('error', Format('Failed to set focus to window handle %d (use target_handle only if window is already foreground)', [TargetHandle]));
        end;
      end;
    end
    else
    begin
      // No target specified - send to current foreground window
      SendKeysSequence(Keys);
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('keys_sent', Keys);
      OutputDebugString(PChar('MCP.SendKeys: Sent keys - ' + Keys));
    end;
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

procedure Tool_MouseMove(const Params: TJSONObject; out Result: TJSONObject);
var
  X, Y: Integer;
  Pt: TPoint;
begin
  Result := TJSONObject.Create;
  try
    if not Params.TryGetValue<Integer>('x', X) then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Missing required parameter: x');
      Exit;
    end;

    if not Params.TryGetValue<Integer>('y', Y) then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Missing required parameter: y');
      Exit;
    end;

    Pt.X := X;
    Pt.Y := Y;
    MouseMoveAbs(Pt);

    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('x', TJSONNumber.Create(X));
    Result.AddPair('y', TJSONNumber.Create(Y));
    OutputDebugString(PChar(Format('MCP.MouseMove: Moved to (%d, %d)', [X, Y])));
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

procedure Tool_MouseClick(const Params: TJSONObject; out Result: TJSONObject);
var
  Button: string;
begin
  Result := TJSONObject.Create;
  try
    // Optional button parameter (default: left)
    if not Params.TryGetValue<string>('button', Button) then
      Button := 'left';

    if SameText(Button, 'left') then
      MouseLeftClick
    else if SameText(Button, 'right') then
      MouseRightClick
    else
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Invalid button: ' + Button + ' (use "left" or "right")');
      Exit;
    end;

    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('button', Button);
    OutputDebugString(PChar('MCP.MouseClick: ' + Button + ' button'));
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

procedure Tool_MouseDblClick(const Params: TJSONObject; out Result: TJSONObject);
begin
  Result := TJSONObject.Create;
  try
    MouseLeftDblClick;

    Result.AddPair('success', TJSONBool.Create(True));
    OutputDebugString('MCP.MouseDblClick: Double-clicked');
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

procedure Tool_MouseWheel(const Params: TJSONObject; out Result: TJSONObject);
var
  Delta: Integer;
begin
  Result := TJSONObject.Create;
  try
    if not Params.TryGetValue<Integer>('delta', Delta) then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Missing required parameter: delta');
      Exit;
    end;

    MouseWheelDelta(Delta);

    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('delta', TJSONNumber.Create(Delta));
    OutputDebugString(PChar(Format('MCP.MouseWheel: Delta %d', [Delta])));
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

// ============================================================================
// Schema Creators
// ============================================================================

function CreateSchema_SendKeys: TJSONObject;
var
  Props, Keys, TargetHandle: TJSONObject;
  Required: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');

  Props := TJSONObject.Create;

  Keys := TJSONObject.Create;
  Keys.AddPair('type', 'string');
  Keys.AddPair('description', 'Keyboard sequence to send. Plain text + special keys in {braces}.' + sLineBreak +
    'Special keys: {ENTER}, {TAB}, {ESC}, {BACKSPACE}, {DELETE}, {UP}, {DOWN}, {LEFT}, {RIGHT}, ' +
    '{HOME}, {END}, {PAGEUP}, {PAGEDOWN}, {F1}-{F12}' + sLineBreak +
    'Example: "Hello{TAB}World{ENTER}"');
  Props.AddPair('keys', Keys);

  TargetHandle := TJSONObject.Create;
  TargetHandle.AddPair('type', 'number');
  TargetHandle.AddPair('description', 'Optional: Window handle to send keys to. ' +
    'If specified, the window will be brought to foreground, keys sent, then previous window restored. ' +
    'Useful for sending keys to non-VCL modal windows (TOpenDialog, MessageDlg, etc.)');
  Props.AddPair('target_handle', TargetHandle);

  Result.AddPair('properties', Props);

  Required := TJSONArray.Create;
  Required.Add('keys');
  Result.AddPair('required', Required);
end;

function CreateSchema_MouseMove: TJSONObject;
var
  Props, X, Y: TJSONObject;
  Required: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');

  Props := TJSONObject.Create;

  X := TJSONObject.Create;
  X.AddPair('type', 'number');
  X.AddPair('description', 'Screen X coordinate (absolute)');
  Props.AddPair('x', X);

  Y := TJSONObject.Create;
  Y.AddPair('type', 'number');
  Y.AddPair('description', 'Screen Y coordinate (absolute)');
  Props.AddPair('y', Y);

  Result.AddPair('properties', Props);

  Required := TJSONArray.Create;
  Required.Add('x');
  Required.Add('y');
  Result.AddPair('required', Required);
end;

function CreateSchema_MouseClick: TJSONObject;
var
  Props, Button: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');

  Props := TJSONObject.Create;

  Button := TJSONObject.Create;
  Button.AddPair('type', 'string');
  Button.AddPair('description', 'Mouse button to click: "left" or "right" (default: "left")');
  Props.AddPair('button', Button);

  Result.AddPair('properties', Props);
end;

function CreateSchema_MouseDblClick: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', TJSONObject.Create);
end;

function CreateSchema_MouseWheel: TJSONObject;
var
  Props, Delta: TJSONObject;
  Required: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');

  Props := TJSONObject.Create;

  Delta := TJSONObject.Create;
  Delta.AddPair('type', 'number');
  Delta.AddPair('description', 'Scroll delta (positive = up, negative = down). Standard value: 120 for one notch.');
  Props.AddPair('delta', Delta);

  Result.AddPair('properties', Props);

  Required := TJSONArray.Create;
  Required.Add('delta');
  Result.AddPair('required', Required);
end;

end.
