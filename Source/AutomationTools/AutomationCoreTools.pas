unit AutomationCoreTools;

{
  Automation Core Tools - Registration of built-in generic automation tools

  PURPOSE:
  - Registers all core automation tools with the registry
  - Provides handlers for visual inspection, control interaction, synchronization
  - Implements tool logic using existing automation utility units

  ARCHITECTURE:
  - Called during application initialization
  - Tools are stateless and thread-safe (use TThread.Synchronize)
  - Each tool handler implements the TAutomationToolHandler signature

  TOOLS REGISTERED (30 generic tools):
  - Utility (2): echo, list-tools
  - Visual Inspection (9): take-screenshot, get-form-info, list-open-forms,
    list-controls, find-control, get-control, ui.get_tree_diff, ui.focus.get,
    ui.value.get, ui.color.get
  - Control Interaction (7): set-control-value, ui.set_text_verified, click-button,
    select-combo-item, select-tab, close-form, set-focus
  - Keyboard/Mouse (5): ui.send_keys, ui.mouse_move, ui.mouse_click,
    ui.mouse_dblclick, ui.mouse_wheel
  - Synchronization (4): wait.idle, wait.focus, wait.text, wait.when
  - Development (2): analyze-form-taborder, list-focusable-forms (via Tabulator)
}

interface

procedure RegisterCoreAutomationTools;

implementation

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.JSON, System.DateUtils, System.NetEncoding,
  System.StrUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.ExtCtrls,
  AutomationToolRegistry,
  AutomationScreenshot,
  AutomationFormIntrospection,
  AutomationControlInteraction,
  AutomationSynchronization,
  AutomationInputSimulation,
  AutomationTabulator;

{ Tool Handlers }

procedure Tool_Echo(const Params: TJSONObject; out Result: TJSONObject);
var
  Message: string;
begin
  Result := TJSONObject.Create;

  if (Params <> nil) and Params.TryGetValue<string>('message', Message) then
  begin
    Result.AddPair('echo', Message);
    Result.AddPair('timestamp', DateTimeToStr(Now));
  end
  else
  begin
    Result.AddPair('echo', 'No message provided');
  end;
end;

procedure Tool_TakeScreenshot(const Params: TJSONObject; out Result: TJSONObject);
const
  HELP_MESSAGE =
    'Screenshot tool requires exactly 2 parameters:'#13#10 +
    #13#10 +
    '1. ''target'' (required): What to capture'#13#10 +
    '   - ''screen'' or ''full'' - entire screen'#13#10 +
    '   - ''active'' or ''focus'' - active form'#13#10 +
    '   - ''wincontrol'' - focused control'#13#10 +
    '   - ''wincontrol+N'' - focused control with N pixel margin'#13#10 +
    '   - ''wincontrol.parent+N'' - parent with margin'#13#10 +
    '   - ''FormName'' - specific form by name'#13#10 +
    #13#10 +
    '2. ''output'' (required): Output mode'#13#10 +
    '   - ''base64'' - return base64-encoded PNG in response'#13#10 +
    '   - ''/path/to/file.png'' - save PNG to file path';
var
  Target, OutputMode: string;
  ScreenshotResult: TScreenshotResult;
  Bytes: TBytes;
  Stream: TFileStream;
  ParamCount: Integer;
begin
  Result := TJSONObject.Create;

  // Count provided parameters
  ParamCount := 0;
  if (Params <> nil) then
  begin
    if Params.GetValue('target') <> nil then Inc(ParamCount);
    if Params.GetValue('output') <> nil then Inc(ParamCount);
  end;

  // Check for exactly 2 parameters
  if ParamCount <> 2 then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Invalid parameters');
    Result.AddPair('help', HELP_MESSAGE);
    Exit;
  end;

  // Extract required parameters
  Params.TryGetValue<string>('target', Target);
  Params.TryGetValue<string>('output', OutputMode);

  // Take the screenshot
  ScreenshotResult := AutomationScreenshot.TakeScreenshot(Target);
  Result.AddPair('success', TJSONBool.Create(ScreenshotResult.Success));

  if ScreenshotResult.Success then
  begin
    // Check output mode: 'base64' or file path
    if SameText(OutputMode, 'base64') then
    begin
      // Return base64-encoded image
      Result.AddPair('image', ScreenshotResult.Base64Data);
      Result.AddPair('width', TJSONNumber.Create(ScreenshotResult.Width));
      Result.AddPair('height', TJSONNumber.Create(ScreenshotResult.Height));
      Result.AddPair('format', 'png');
      Result.AddPair('encoding', 'base64');
    end
    else
    begin
      // Save to file
      try
        Bytes := TNetEncoding.Base64.DecodeStringToBytes(ScreenshotResult.Base64Data);
        Stream := TFileStream.Create(OutputMode, fmCreate);
        try
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
          Result.AddPair('saved', TJSONBool.Create(True));
          Result.AddPair('path', OutputMode);
          Result.AddPair('width', TJSONNumber.Create(ScreenshotResult.Width));
          Result.AddPair('height', TJSONNumber.Create(ScreenshotResult.Height));
          Result.AddPair('format', 'png');
        finally
          Stream.Free;
        end;
      except
        on E: Exception do
        begin
          Result.AddPair('saved', TJSONBool.Create(False));
          Result.AddPair('save_error', E.Message);
        end;
      end;
    end;
  end
  else
    Result.AddPair('error', ScreenshotResult.ErrorMessage);
end;

procedure Tool_GetFormInfo(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, Root, FormJSON: string;
  FormData: TJSONValue;
  Form: TForm;
  UseETag, MinimalMode, IncludeHwnd: Boolean;
  Depth: Integer;
begin
  Result := TJSONObject.Create;

  if (Params <> nil) and Params.TryGetValue<string>('form', FormName) then
  else
    FormName := 'active';

  if (Params <> nil) and Params.TryGetValue<string>('root', Root) then
  else
    Root := '';

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_etag', UseETag) then
  else
    UseETag := True; // Default: include ETag

  if (Params <> nil) and Params.TryGetValue<Boolean>('minimal', MinimalMode) then
  else
    MinimalMode := True; // Default: minimal mode for token efficiency

  if (Params <> nil) and Params.TryGetValue<Integer>('depth', Depth) then
  else
    Depth := 1; // Default: shallow (1 level)

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_hwnd', IncludeHwnd) then
  else
    IncludeHwnd := False; // Default: exclude hwnd to save tokens

  // Always use ETag version now (supports all parameters)
  TThread.Synchronize(nil, procedure
  begin
    Form := AutomationFormIntrospection.FindForm(FormName);
    if Form <> nil then
      FormJSON := AutomationFormIntrospection.DescribeFormWithETag(Form, Root, MinimalMode, Depth, IncludeHwnd)
    else
      FormJSON := '{"error": "Form not found: ' + FormName + '"}';
  end);

  FormData := TJSONObject.ParseJSONValue(FormJSON);
  if FormData <> nil then
    Result.AddPair('form', FormData)
  else
    Result.AddPair('error', 'Failed to parse form description');
end;

procedure Tool_ListOpenForms(const Params: TJSONObject; out Result: TJSONObject);
var
  FormsJSON: string;
  FormsArray: TJSONValue;
begin
  Result := TJSONObject.Create;
  FormsJSON := AutomationFormIntrospection.ListOpenForms;
  FormsArray := TJSONObject.ParseJSONValue(FormsJSON);
  if FormsArray <> nil then
    Result.AddPair('forms', FormsArray)
  else
    Result.AddPair('error', 'Failed to parse forms list');
end;

{ New Optimized Tools }

procedure Tool_ListControls(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, Root, ControlsJSON: string;
  Depth: Integer;
  IncludeHwnd: Boolean;
  Form: TForm;
  ControlsData: TJSONValue;
begin
  Result := TJSONObject.Create;

  // Extract parameters
  if (Params <> nil) and Params.TryGetValue<string>('form', FormName) then
  else
    FormName := 'active';

  if (Params <> nil) and Params.TryGetValue<string>('root', Root) then
  else
    Root := '';

  if (Params <> nil) and Params.TryGetValue<Integer>('depth', Depth) then
  else
    Depth := 1; // Default: shallow (1 level)

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_hwnd', IncludeHwnd) then
  else
    IncludeHwnd := False; // Default: exclude hwnd to save tokens

  TThread.Synchronize(nil, procedure
  begin
    Form := AutomationFormIntrospection.FindForm(FormName);
    if Form <> nil then
      ControlsJSON := AutomationFormIntrospection.ListFormControls(Form, Root, Depth, IncludeHwnd)
    else
      ControlsJSON := '{"error": "Form not found: ' + FormName + '"}';
  end);

  ControlsData := TJSONObject.ParseJSONValue(ControlsJSON);
  if ControlsData <> nil then
  begin
    Result.AddPair('data', ControlsData);
    Result.AddPair('success', TJSONBool.Create(True));
  end
  else
    Result.AddPair('error', 'Failed to parse controls list');
end;

procedure Tool_FindControl(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, NamePattern, CaptionPattern, TypeFilter, FindJSON: string;
  IncludeHwnd: Boolean;
  Form: TForm;
  FindData: TJSONValue;
begin
  Result := TJSONObject.Create;

  // Extract parameters
  if (Params <> nil) and Params.TryGetValue<string>('form', FormName) then
  else
    FormName := 'active';

  if (Params <> nil) and Params.TryGetValue<string>('name_pattern', NamePattern) then
  else
    NamePattern := '';

  if (Params <> nil) and Params.TryGetValue<string>('caption_pattern', CaptionPattern) then
  else
    CaptionPattern := '';

  if (Params <> nil) and Params.TryGetValue<string>('type', TypeFilter) then
  else
    TypeFilter := '';

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_hwnd', IncludeHwnd) then
  else
    IncludeHwnd := False; // Default: exclude hwnd to save tokens

  TThread.Synchronize(nil, procedure
  begin
    Form := AutomationFormIntrospection.FindForm(FormName);
    if Form <> nil then
      FindJSON := AutomationFormIntrospection.FindControlByPattern(Form, NamePattern, CaptionPattern, TypeFilter, IncludeHwnd)
    else
      FindJSON := '{"error": "Form not found: ' + FormName + '"}';
  end);

  FindData := TJSONObject.ParseJSONValue(FindJSON);
  if FindData <> nil then
  begin
    Result.AddPair('data', FindData);
    Result.AddPair('success', TJSONBool.Create(True));
  end
  else
    Result.AddPair('error', 'Failed to parse find results');
end;

procedure Tool_GetControl(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, ControlJSON: string;
  IncludeChildren, IncludeHwnd: Boolean;
  Form: TForm;
  ControlData: TJSONValue;
begin
  Result := TJSONObject.Create;

  // Extract parameters
  if (Params <> nil) and Params.TryGetValue<string>('form', FormName) then
  else
    FormName := 'active';

  if (Params <> nil) and Params.TryGetValue<string>('control', ControlName) then
  else
  begin
    Result.AddPair('error', 'Missing required parameter: control');
    Exit;
  end;

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_children', IncludeChildren) then
  else
    IncludeChildren := True; // Default: include children

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_hwnd', IncludeHwnd) then
  else
    IncludeHwnd := False; // Default: exclude hwnd to save tokens

  TThread.Synchronize(nil, procedure
  begin
    Form := AutomationFormIntrospection.FindForm(FormName);
    if Form <> nil then
      ControlJSON := AutomationFormIntrospection.GetControlDetails(Form, ControlName, IncludeChildren, IncludeHwnd)
    else
      ControlJSON := '{"error": "Form not found: ' + FormName + '"}';
  end);

  ControlData := TJSONObject.ParseJSONValue(ControlJSON);
  if ControlData <> nil then
  begin
    Result.AddPair('data', ControlData);
    Result.AddPair('success', TJSONBool.Create(True));
  end
  else
    Result.AddPair('error', 'Failed to parse control details');
end;

procedure Tool_SetControlValue(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, Value: string;
  OpResult: TControlResult;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<string>('form', FormName) or
     not Params.TryGetValue<string>('control', ControlName) or
     not Params.TryGetValue<string>('value', Value) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: form, control, value');
    Exit;
  end;

  OpResult := AutomationControlInteraction.SetControlValue(FormName, ControlName, Value);
  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_ClickButton(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName: string;
  OpResult: TControlResult;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<string>('form', FormName) or
     not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: form, control');
    Exit;
  end;

  OpResult := AutomationControlInteraction.ClickButton(FormName, ControlName);
  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_SelectComboItem(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, ItemText: string;
  OpResult: TControlResult;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<string>('form', FormName) or
     not Params.TryGetValue<string>('control', ControlName) or
     not Params.TryGetValue<string>('item', ItemText) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: form, control, item');
    Exit;
  end;

  OpResult := AutomationControlInteraction.SelectComboItem(FormName, ControlName, ItemText);
  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_SelectTab(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, TabName: string;
  TabIndex: Integer;
  OpResult: TControlResult;
  UseIndex: Boolean;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<string>('form', FormName) or
     not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: form, control');
    Exit;
  end;

  UseIndex := Params.TryGetValue<Integer>('index', TabIndex);

  if UseIndex then
    OpResult := AutomationControlInteraction.SelectTabByIndex(FormName, ControlName, TabIndex)
  else if Params.TryGetValue<string>('name', TabName) then
    OpResult := AutomationControlInteraction.SelectTabByName(FormName, ControlName, TabName)
  else
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing parameter: index or name');
    Exit;
  end;

  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_CloseForm(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName: string;
  OpResult: TControlResult;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or not Params.TryGetValue<string>('form', FormName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: form');
    Exit;
  end;

  OpResult := AutomationControlInteraction.CloseForm(FormName);
  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_SetFocus(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName: string;
  OpResult: TControlResult;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<string>('form', FormName) or
     not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: form, control');
    Exit;
  end;

  OpResult := AutomationControlInteraction.SetFocus(FormName, ControlName);
  Result.AddPair('success', TJSONBool.Create(OpResult.Success));
  Result.AddPair('message', OpResult.Message);
end;

procedure Tool_ListTools(const Params: TJSONObject; out Result: TJSONObject);
var
  ToolListJSON: string;
  ToolListData: TJSONValue;
begin
  Result := TJSONObject.Create;

  try
    ToolListJSON := TAutomationToolRegistry.Instance.GetToolListJSON;
    ToolListData := TJSONObject.ParseJSONValue(ToolListJSON);
    if ToolListData <> nil then
      Result := ToolListData as TJSONObject
    else
      Result.AddPair('error', 'Failed to parse tool list');
  except
    on E: Exception do
      Result.AddPair('error', 'Exception listing tools: ' + E.Message);
  end;
end;

{ Phase 1 Enhancement Tools }

procedure Tool_GetTreeDiff(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, Root, SinceETag, CurrentETag: string;
  Form: TForm;
  MinimalMode, IncludeHwnd: Boolean;
  Depth: Integer;
begin
  Result := TJSONObject.Create;

  // Get parameters
  if (Params <> nil) and Params.TryGetValue<string>('form', FormName) then
  else
    FormName := 'active';

  if (Params <> nil) and Params.TryGetValue<string>('root', Root) then
  else
    Root := '';

  if (Params <> nil) and Params.TryGetValue<string>('since_etag', SinceETag) then
  else
    SinceETag := '';

  if (Params <> nil) and Params.TryGetValue<Boolean>('minimal', MinimalMode) then
  else
    MinimalMode := True; // Default: minimal mode for token efficiency

  if (Params <> nil) and Params.TryGetValue<Integer>('depth', Depth) then
  else
    Depth := 1; // Default: shallow (1 level)

  if (Params <> nil) and Params.TryGetValue<Boolean>('include_hwnd', IncludeHwnd) then
  else
    IncludeHwnd := False; // Default: exclude hwnd to save tokens

  // Find form
  TThread.Synchronize(nil, procedure
  begin
    Form := AutomationFormIntrospection.FindForm(FormName);
  end);

  if Form = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Form not found: ' + FormName);
    Exit;
  end;

  // Generate current ETag
  CurrentETag := AutomationFormIntrospection.GenerateControlsETag(Form, Root);
  Result.AddPair('etag', CurrentETag);

  // Check if changed
  if SameText(SinceETag, CurrentETag) then
  begin
    Result.AddPair('same', TJSONBool.Create(True));
    Result.AddPair('message', 'Tree unchanged since ' + SinceETag);
  end
  else
  begin
    Result.AddPair('same', TJSONBool.Create(False));

    // Return description with new ETag and minimal/depth/hwnd parameters
    var FormJSON := AutomationFormIntrospection.DescribeFormWithETag(Form, Root, MinimalMode, Depth, IncludeHwnd);
    var FormData := TJSONObject.ParseJSONValue(FormJSON);
    if FormData <> nil then
      Result.AddPair('form', FormData)
    else
      Result.AddPair('error', 'Failed to parse form description');
  end;
end;

procedure Tool_GetFocused(const Params: TJSONObject; out Result: TJSONObject);
var
  FocusedHWND: HWND;
  FocusedControl: TWinControl;
  gui: TGUIThreadInfo;
begin
  Result := TJSONObject.Create;

  // Get focused window handle
  FillChar(gui, SizeOf(gui), 0);
  gui.cbSize := SizeOf(gui);

  if GetGUIThreadInfo(0, gui) then
    FocusedHWND := gui.hwndFocus
  else
    FocusedHWND := 0;

  if FocusedHWND <> 0 then
  begin
    TThread.Synchronize(nil, procedure
    begin
      FocusedControl := FindControl(FocusedHWND);
    end);

    if FocusedControl <> nil then
    begin
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('hwnd', TJSONNumber.Create(FocusedHWND));
      Result.AddPair('name', FocusedControl.Name);
      Result.AddPair('class', FocusedControl.ClassName);

      if FocusedControl is TButton then
        Result.AddPair('caption', TButton(FocusedControl).Caption)
      else if FocusedControl is TCheckBox then
        Result.AddPair('caption', TCheckBox(FocusedControl).Caption);
    end
    else
    begin
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('hwnd', TJSONNumber.Create(FocusedHWND));
      Result.AddPair('message', 'Focused window not a VCL control');
    end;
  end
  else
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('message', 'No focused window');
  end;
end;

procedure Tool_WaitIdle(const Params: TJSONObject; out Result: TJSONObject);
var
  QuiesceMs, TimeoutMs: Integer;
  Success: Boolean;
begin
  Result := TJSONObject.Create;

  if (Params <> nil) and Params.TryGetValue<Integer>('quiesce_ms', QuiesceMs) then
  else
    QuiesceMs := 500; // Default: 500ms quiet

  if (Params <> nil) and Params.TryGetValue<Integer>('timeout_ms', TimeoutMs) then
  else
    TimeoutMs := 5000; // Default: 5s timeout

  Success := AutomationSynchronization.WaitIdle(QuiesceMs, TimeoutMs);

  Result.AddPair('success', TJSONBool.Create(Success));
  if Success then
    Result.AddPair('message', Format('Message queue idle for %dms', [QuiesceMs]))
  else
    Result.AddPair('message', Format('Timeout after %dms', [TimeoutMs]));
end;

procedure Tool_WaitFocus(const Params: TJSONObject; out Result: TJSONObject);
var
  Hwnd: THandle;
  HwndInt: Integer;
  TimeoutMs: Integer;
  Success: Boolean;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or not Params.TryGetValue<Integer>('hwnd', HwndInt) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: hwnd');
    Exit;
  end;
  Hwnd := THandle(HwndInt);

  if Params.TryGetValue<Integer>('timeout_ms', TimeoutMs) then
  else
    TimeoutMs := 3000; // Default: 3s timeout

  Success := AutomationSynchronization.WaitFocus(Hwnd, TimeoutMs);

  Result.AddPair('success', TJSONBool.Create(Success));
  if Success then
    Result.AddPair('message', Format('Control %d focused', [Hwnd]))
  else
    Result.AddPair('message', Format('Timeout after %dms', [TimeoutMs]));
end;

procedure Tool_WaitText(const Params: TJSONObject; out Result: TJSONObject);
var
  Hwnd: THandle;
  HwndInt: Integer;
  Contains: string;
  TimeoutMs: Integer;
  Success: Boolean;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or
     not Params.TryGetValue<Integer>('hwnd', HwndInt) or
     not Params.TryGetValue<string>('contains', Contains) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameters: hwnd, contains');
    Exit;
  end;
  Hwnd := THandle(HwndInt);

  if Params.TryGetValue<Integer>('timeout_ms', TimeoutMs) then
  else
    TimeoutMs := 3000; // Default: 3s timeout

  Success := AutomationSynchronization.WaitText(Hwnd, Contains, TimeoutMs);

  Result.AddPair('success', TJSONBool.Create(Success));
  if Success then
    Result.AddPair('message', Format('Text contains "%s"', [Contains]))
  else
    Result.AddPair('message', Format('Timeout after %dms', [TimeoutMs]));
end;

procedure Tool_WaitWhen(const Params: TJSONObject; out Result: TJSONObject);
var
  ConditionsArray: TJSONArray;
  Conditions: TArray<AutomationSynchronization.TCondition>;
  TimeoutMs: Integer;
  Success: Boolean;
begin
  Result := TJSONObject.Create;

  if (Params = nil) or not Params.TryGetValue<TJSONArray>('conditions', ConditionsArray) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: conditions (array)');
    Exit;
  end;

  if Params.TryGetValue<Integer>('timeout_ms', TimeoutMs) then
  else
    TimeoutMs := 5000; // Default: 5s timeout

  // Parse conditions
  Conditions := AutomationSynchronization.ParseConditions(ConditionsArray);

  Success := AutomationSynchronization.WaitWhen(Conditions, TimeoutMs);

  Result.AddPair('success', TJSONBool.Create(Success));
  if Success then
    Result.AddPair('message', Format('All %d conditions met', [Length(Conditions)]))
  else
    Result.AddPair('message', Format('Timeout after %dms', [TimeoutMs]));
end;

{ Additional Control Tools - ui.value.get, ui.color.get }

procedure Tool_GetValue(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName: string;
  Form: TForm;
  Control: TControl;
  TextValue: string;
begin
  Result := TJSONObject.Create;

  if not Params.TryGetValue<string>('form', FormName) then
    FormName := 'active';

  if not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: control');
    Exit;
  end;

  Form := AutomationControlInteraction.FindFormByName(FormName);
  if Form = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Form not found: ' + FormName);
    Exit;
  end;

  Control := Form.FindComponent(ControlName) as TControl;
  if Control = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Control not found: ' + ControlName);
    Exit;
  end;

  // Get text value based on control type
  TextValue := '';
  if Control is TEdit then
    TextValue := TEdit(Control).Text
  else if Control is TMemo then
    TextValue := TMemo(Control).Text
  else if Control is TLabel then
    TextValue := TLabel(Control).Caption
  else if Control is TCheckBox then
    TextValue := BoolToStr(TCheckBox(Control).Checked, True)
  else if Control is TComboBox then
    TextValue := TComboBox(Control).Text
  else
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Unsupported control type: ' + Control.ClassName);
    Exit;
  end;

  Result.AddPair('success', TJSONBool.Create(True));
  Result.AddPair('value', TextValue);
  Result.AddPair('control', ControlName);
  Result.AddPair('form', FormName);
end;

procedure Tool_GetColor(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, Which: string;
  Form: TForm;
  Control: TControl;
  FontColor, BackColor: TColor;
  FontColorRGB, BackColorRGB: Integer;
begin
  Result := TJSONObject.Create;

  if not Params.TryGetValue<string>('form', FormName) then
    FormName := 'active';

  if not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: control');
    Exit;
  end;

  if not Params.TryGetValue<string>('which', Which) then
    Which := 'both';

  Form := AutomationControlInteraction.FindFormByName(FormName);
  if Form = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Form not found: ' + FormName);
    Exit;
  end;

  Control := Form.FindComponent(ControlName) as TControl;
  if Control = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Control not found: ' + ControlName);
    Exit;
  end;

  Result.AddPair('success', TJSONBool.Create(True));
  Result.AddPair('control', ControlName);

  // Get colors based on control type - need to check specific types with public Font/Color properties
  if (SameText(Which, 'font') or SameText(Which, 'both')) then
  begin
    if Control is TLabel then
      FontColor := TLabel(Control).Font.Color
    else if Control is TEdit then
      FontColor := TEdit(Control).Font.Color
    else if Control is TMemo then
      FontColor := TMemo(Control).Font.Color
    else if Control is TButton then
      FontColor := TButton(Control).Font.Color
    else if Control is TPanel then
      FontColor := TPanel(Control).Font.Color
    else
      FontColor := clWindowText; // Default

    FontColorRGB := ColorToRGB(FontColor);
    Result.AddPair('font_rgb', Format('#%6.6x', [FontColorRGB]));
  end;

  if (SameText(Which, 'back') or SameText(Which, 'both')) then
  begin
    if Control is TEdit then
      BackColor := TEdit(Control).Color
    else if Control is TMemo then
      BackColor := TMemo(Control).Color
    else if Control is TPanel then
      BackColor := TPanel(Control).Color
    else if Control is TForm then
      BackColor := TForm(Control).Color
    else
      BackColor := clBtnFace; // Default

    BackColorRGB := ColorToRGB(BackColor);
    Result.AddPair('back_rgb', Format('#%6.6x', [BackColorRGB]));
  end;
end;

{ Enhanced Set-Control-Value with Verification }

procedure Tool_SetControlValueVerified(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName, ControlName, Value: string;
  VerifyTimeoutMs: Integer;
  Form: TForm;
  Control: TControl;
  t0: UInt64;
  CurrentValue: string;
  Success: Boolean;
begin
  Result := TJSONObject.Create;

  if not Params.TryGetValue<string>('form', FormName) then
    FormName := 'active';

  if not Params.TryGetValue<string>('control', ControlName) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: control');
    Exit;
  end;

  if not Params.TryGetValue<string>('value', Value) then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Missing required parameter: value');
    Exit;
  end;

  if not Params.TryGetValue<Integer>('verify_timeout_ms', VerifyTimeoutMs) then
    VerifyTimeoutMs := 0; // No verification by default

  Form := AutomationControlInteraction.FindFormByName(FormName);
  if Form = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Form not found: ' + FormName);
    Exit;
  end;

  Control := Form.FindComponent(ControlName) as TControl;
  if Control = nil then
  begin
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', 'Control not found: ' + ControlName);
    Exit;
  end;

  // Set the value
  AutomationControlInteraction.SetControlValue(FormName, ControlName, Value);

  // Verify if requested
  if VerifyTimeoutMs > 0 then
  begin
    t0 := GetTickCount64;
    Success := False;

    while GetTickCount64 - t0 < VerifyTimeoutMs do
    begin
      // Read current value
      if Control is TEdit then
        CurrentValue := TEdit(Control).Text
      else if Control is TMemo then
        CurrentValue := TMemo(Control).Text
      else if Control is TComboBox then
        CurrentValue := TComboBox(Control).Text
      else
        Break; // Can't verify this control type

      if SameText(CurrentValue, Value) then
      begin
        Success := True;
        Break;
      end;

      Sleep(10); // Poll every 10ms
    end;

    Result.AddPair('verified', TJSONBool.Create(Success));
    if not Success then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Verification failed: value did not update');
      Exit;
    end;
  end;

  Result.AddPair('success', TJSONBool.Create(True));
  Result.AddPair('control', ControlName);
  Result.AddPair('value', Value);
end;

{ Schema Helpers }

function CreateSchema_TakeScreenshot: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');

  Props := TJSONObject.Create;

  // target parameter
  Props.AddPair('target', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description',
      'What to capture:'#13#10 +
      '- "screen" or "full" - entire screen'#13#10 +
      '- "active" or "focus" - active form'#13#10 +
      '- "wincontrol" - focused control'#13#10 +
      '- "wincontrol+N" - focused control with N pixel margin'#13#10 +
      '- "wincontrol.parent+N" - parent with margin'#13#10 +
      '- "FormName" - specific form by name'));

  // output parameter
  Props.AddPair('output', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description',
      'Where to save the screenshot:'#13#10 +
      '- "/path/to/file.png" - save PNG to file (recommended)'#13#10 +
      '- "base64" - rarely used: return base64-encoded PNG in response'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('target').Add('output'));
end;

function CreateSchema_Echo: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('message', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Message to echo back'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('message'));
end;

function CreateSchema_UIFocusGet: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', TJSONObject.Create);
  // No parameters - empty schema
end;

{ Visual/Interaction Tool Schemas }

function CreateSchema_GetFormInfo: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form identifier: "active" (default), "main" (MDI parent), or handle number from list-open-forms'));

  Props.AddPair('root', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Root control name to start from (optional, default: form root)'));

  Props.AddPair('include_etag', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include ETag hash for change detection (default: true)'));

  Props.AddPair('minimal', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Use minimal mode - only essential fields, ~70% token reduction (default: true)'));

  Props.AddPair('depth', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum nesting depth for control tree (default: 1, max: 3)'));

  Props.AddPair('include_hwnd', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include hwnd field for wait_* tools (default: false to save tokens)'));

  Result.AddPair('properties', Props);
  // All parameters are optional
end;

function CreateSchema_ListOpenForms: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', TJSONObject.Create);
  // No parameters
end;

function CreateSchema_SetControlValue: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name containing the control'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to set value'));

  Props.AddPair('value', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Value to set (for Edit/Memo: text, CheckBox: "true"/"false", ComboBox: item text)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form').Add('control').Add('value'));
end;

function CreateSchema_ClickButton: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name containing the button'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Button control name (Button/BitBtn/SpeedButton)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form').Add('control'));
end;

function CreateSchema_SelectComboItem: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name containing the ComboBox'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'ComboBox control name'));

  Props.AddPair('item', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Item text to select'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form').Add('control').Add('item'));
end;

function CreateSchema_SelectTab: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name containing the tab control'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'PageControl/TabControl name'));

  Props.AddPair('index', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Tab index (0-based, use this OR name)'));

  Props.AddPair('name', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Tab caption/name (use this OR index)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form').Add('control'));
  // Note: Must have either 'index' or 'name', validated in handler
end;

function CreateSchema_CloseForm: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name to close'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form'));
end;

function CreateSchema_SetFocus: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name containing the control'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to receive focus'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('form').Add('control'));
end;

{ Wait/Synchronization Tool Schemas }

function CreateSchema_WaitIdle: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('quiesce_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Milliseconds of idle time required (default: 500)'));

  Props.AddPair('timeout_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum wait time in milliseconds (default: 5000)'));

  Result.AddPair('properties', Props);
  // All parameters optional
end;

function CreateSchema_WaitFocus: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('hwnd', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Window handle of control to wait for focus'));

  Props.AddPair('timeout_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum wait time in milliseconds (default: 3000)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('hwnd'));
end;

function CreateSchema_WaitText: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('hwnd', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Window handle of control to monitor'));

  Props.AddPair('contains', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Substring that control text must contain'));

  Props.AddPair('timeout_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum wait time in milliseconds (default: 3000)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('hwnd').Add('contains'));
end;

function CreateSchema_WaitWhen: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('conditions', TJSONObject.Create
    .AddPair('type', 'array')
    .AddPair('description', 'Array of condition objects: {type: "focus"|"text"|"idle", hwnd?: number, contains?: string}'));

  Props.AddPair('timeout_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum wait time in milliseconds (default: 5000)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('conditions'));
end;

function CreateSchema_ListTools: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Result.AddPair('properties', TJSONObject.Create);
  // No parameters
end;

{ Additional Control Tool Schemas }

function CreateSchema_GetValue: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name (default: "active")'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to read value from'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('control'));
end;

function CreateSchema_GetColor: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name (default: "active")'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to get colors from'));

  Props.AddPair('which', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Which color to get: "font", "back", or "both" (default: "both")'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('control'));
end;

function CreateSchema_SetControlValueVerified: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form name (default: "active")'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to set value'));

  Props.AddPair('value', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Value to set'));

  Props.AddPair('verify_timeout_ms', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Optional: Timeout in ms to verify value was set (default: 0 = no verification)'));

  Result.AddPair('properties', Props);
  Result.AddPair('required', TJSONArray.Create.Add('control').Add('value'));
end;

function CreateSchema_UIGetTreeDiff: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form identifier: "active" (default), "main" (MDI parent), or handle number from list-open-forms'));

  Props.AddPair('root', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Root control name to start from (optional)'));

  Props.AddPair('since_etag', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Previous ETag to compare against (returns "same: true" if unchanged)'));

  Props.AddPair('minimal', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Use minimal mode - only essential fields, ~70% token reduction (default: true)'));

  Props.AddPair('depth', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Maximum nesting depth for control tree (default: 1, max: 3)'));

  Props.AddPair('include_hwnd', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include hwnd field for wait_* tools (default: false to save tokens)'));

  Result.AddPair('properties', Props);
  // All parameters optional
end;

{ New Optimized Tool Schemas }

function CreateSchema_ListControls: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form identifier: "active" (default), "main" (MDI parent), or handle number from list-open-forms'));

  Props.AddPair('root', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Root control name to start from (optional)'));

  Props.AddPair('depth', TJSONObject.Create
    .AddPair('type', 'number')
    .AddPair('description', 'Nesting depth for control tree (default: 1, max: 3)'));

  Props.AddPair('include_hwnd', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include hwnd field for wait_* tools (default: false to save tokens)'));

  Result.AddPair('properties', Props);
  // All parameters optional
end;

function CreateSchema_FindControl: TJSONObject;
var
  Props: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form identifier: "active" (default), "main" (MDI parent), or handle number from list-open-forms'));

  Props.AddPair('name_pattern', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Substring to search in control names (case-insensitive)'));

  Props.AddPair('caption_pattern', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Substring to search in control captions (case-insensitive)'));

  Props.AddPair('type', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Filter by control type (e.g., "Button", "Edit", "TButton")'));

  Props.AddPair('include_hwnd', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include hwnd field for wait_* tools (default: false to save tokens)'));

  Result.AddPair('properties', Props);
  // All parameters optional
end;

function CreateSchema_GetControl: TJSONObject;
var
  Props: TJSONObject;
  RequiredArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  Props := TJSONObject.Create;

  Props.AddPair('form', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Form identifier: "active" (default), "main" (MDI parent), or handle number from list-open-forms'));

  Props.AddPair('control', TJSONObject.Create
    .AddPair('type', 'string')
    .AddPair('description', 'Control name to get details for (REQUIRED)'));

  Props.AddPair('include_children', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include child controls (default: true)'));

  Props.AddPair('include_hwnd', TJSONObject.Create
    .AddPair('type', 'boolean')
    .AddPair('description', 'Include hwnd field for wait_* tools (default: false to save tokens)'));

  Result.AddPair('properties', Props);

  // Mark 'control' as required
  RequiredArray := TJSONArray.Create;
  RequiredArray.Add('control');
  Result.AddPair('required', RequiredArray);
end;

{ Registration }

procedure RegisterCoreAutomationTools;
var
  Registry: TAutomationToolRegistry;
begin
  Registry := TAutomationToolRegistry.Instance;

  // Utility tools
  Registry.RegisterTool('echo', Tool_Echo,
    'Echo test tool - returns message parameter', 'utility', 'core',
    CreateSchema_Echo);
  Registry.RegisterTool('list-tools', Tool_ListTools,
    'List all registered automation tools with metadata', 'utility', 'core',
    CreateSchema_ListTools);

  // Visual inspection tools
  Registry.RegisterTool('take-screenshot', Tool_TakeScreenshot,
    'Capture screenshots (screen/form/control)', 'visual', 'core',
    CreateSchema_TakeScreenshot);
  Registry.RegisterAlias('screenshot', 'take-screenshot');

  Registry.RegisterTool('get-form-info', Tool_GetFormInfo,
    'Get form structure and control details via RTTI', 'visual', 'core',
    CreateSchema_GetFormInfo);
  Registry.RegisterAlias('describe-form', 'get-form-info');

  Registry.RegisterTool('list-open-forms', Tool_ListOpenForms,
    'List all currently open forms', 'visual', 'core',
    CreateSchema_ListOpenForms);
  Registry.RegisterAlias('list-forms', 'list-open-forms');

  // New optimized tools (minimal token usage)
  Registry.RegisterTool('list-controls', Tool_ListControls,
    'List form controls with minimal data (shallow, ~500 tokens)', 'visual', 'core',
    CreateSchema_ListControls);

  Registry.RegisterTool('find-control', Tool_FindControl,
    'Search for controls by name/caption/type pattern (~200 tokens)', 'visual', 'core',
    CreateSchema_FindControl);

  Registry.RegisterTool('get-control', Tool_GetControl,
    'Get details of a single control with children (~200 tokens)', 'visual', 'core',
    CreateSchema_GetControl);

  Registry.RegisterTool('ui.get_tree_diff', Tool_GetTreeDiff,
    'Get incremental form tree updates using ETag', 'visual', 'core',
    CreateSchema_UIGetTreeDiff);

  Registry.RegisterTool('ui.focus.get', Tool_GetFocused,
    'Get currently focused control', 'visual', 'core',
    CreateSchema_UIFocusGet);

  // Control interaction tools
  Registry.RegisterTool('set-control-value', Tool_SetControlValue,
    'Set value in Edit/Memo/CheckBox/ComboBox controls', 'interaction', 'core',
    CreateSchema_SetControlValue);
  Registry.RegisterAlias('set-value', 'set-control-value');

  Registry.RegisterTool('click-button', Tool_ClickButton,
    'Click Button/BitBtn/SpeedButton controls', 'interaction', 'core',
    CreateSchema_ClickButton);
  Registry.RegisterAlias('click', 'click-button');

  Registry.RegisterTool('select-combo-item', Tool_SelectComboItem,
    'Select item in ComboBox by text', 'interaction', 'core',
    CreateSchema_SelectComboItem);
  Registry.RegisterAlias('select-item', 'select-combo-item');

  Registry.RegisterTool('select-tab', Tool_SelectTab,
    'Select tab in PageControl/TabControl', 'interaction', 'core',
    CreateSchema_SelectTab);

  Registry.RegisterTool('close-form', Tool_CloseForm,
    'Close form by name', 'interaction', 'core',
    CreateSchema_CloseForm);

  Registry.RegisterTool('set-focus', Tool_SetFocus,
    'Set focus to control', 'interaction', 'core',
    CreateSchema_SetFocus);
  Registry.RegisterAlias('focus', 'set-focus');

  // Wait/synchronization tools
  Registry.RegisterTool('wait.idle', Tool_WaitIdle,
    'Wait for message queue quiescence', 'synchronization', 'core',
    CreateSchema_WaitIdle);

  Registry.RegisterTool('wait.focus', Tool_WaitFocus,
    'Wait for specific control to receive focus', 'synchronization', 'core',
    CreateSchema_WaitFocus);

  Registry.RegisterTool('wait.text', Tool_WaitText,
    'Wait for control text to contain substring', 'synchronization', 'core',
    CreateSchema_WaitText);

  Registry.RegisterTool('wait.when', Tool_WaitWhen,
    'Wait for compound conditions (atomic multi-condition sync)', 'synchronization', 'core',
    CreateSchema_WaitWhen);

  // Additional control tools
  Registry.RegisterTool('ui.value.get', Tool_GetValue,
    'Get control value/text (lightweight alternative to full tree)', 'interaction', 'core',
    CreateSchema_GetValue);
  Registry.RegisterAlias('get-value', 'ui.value.get');

  Registry.RegisterTool('ui.color.get', Tool_GetColor,
    'Get control font and background colors', 'visual', 'core',
    CreateSchema_GetColor);
  Registry.RegisterAlias('get-color', 'ui.color.get');

  Registry.RegisterTool('ui.set_text_verified', Tool_SetControlValueVerified,
    'Set control value with verification polling', 'interaction', 'core',
    CreateSchema_SetControlValueVerified);

  // Keyboard and mouse simulation tools
  Registry.RegisterTool('ui.send_keys', AutomationInputSimulation.Tool_SendKeys,
    'Send keyboard input (Unicode text + special keys)', 'interaction', 'core',
    AutomationInputSimulation.CreateSchema_SendKeys);
  Registry.RegisterAlias('send-keys', 'ui.send_keys');

  Registry.RegisterTool('ui.mouse_move', AutomationInputSimulation.Tool_MouseMove,
    'Move mouse cursor to screen coordinates', 'interaction', 'core',
    AutomationInputSimulation.CreateSchema_MouseMove);
  Registry.RegisterAlias('mouse-move', 'ui.mouse_move');

  Registry.RegisterTool('ui.mouse_click', AutomationInputSimulation.Tool_MouseClick,
    'Click mouse button at current position', 'interaction', 'core',
    AutomationInputSimulation.CreateSchema_MouseClick);
  Registry.RegisterAlias('mouse-click', 'ui.mouse_click');

  Registry.RegisterTool('ui.mouse_dblclick', AutomationInputSimulation.Tool_MouseDblClick,
    'Double-click mouse button at current position', 'interaction', 'core',
    AutomationInputSimulation.CreateSchema_MouseDblClick);
  Registry.RegisterAlias('mouse-dblclick', 'ui.mouse_dblclick');

  Registry.RegisterTool('ui.mouse_wheel', AutomationInputSimulation.Tool_MouseWheel,
    'Scroll mouse wheel', 'interaction', 'core',
    AutomationInputSimulation.CreateSchema_MouseWheel);
  Registry.RegisterAlias('mouse-wheel', 'ui.mouse_wheel');

  // Development tools (Tabulator)
  RegisterTabulatorAutomationTools;

  OutputDebugString('Automation.Core: Registered 30 core generic tools with 16 aliases (including Tabulator, keyboard/mouse)');
end;

end.
