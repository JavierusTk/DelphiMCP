unit AutomationFormIntrospection;

{
  Form Description Helper for MCP Automation

  PURPOSE:
  - Describe ANY form for AI automation (with or without IAutomationDescribable)
  - Use RTTI when interface not available
  - Provide consistent JSON structure

  STRATEGY:
  1. If form implements IAutomationDescribable → use it
  2. Otherwise → use RTTI introspection
  3. Support root parameter for drill-down

  USAGE:
  - DescribeForm(Form, Root) → JSON string
  - DescribeFormByName(FormName, Root) → JSON string
  - DescribeActiveForm(Root) → JSON string
}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Rtti, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids;

// High-level API
function DescribeForm(Form: TForm; const Root: string = ''): string;
function DescribeFormByName(const FormName: string; const Root: string = ''): string;
function DescribeActiveForm(const Root: string = ''): string;

// Get list of all open forms
function ListOpenForms: string; // Returns JSON array

// Helper functions
function FindForm(const FormIdentifier: string): TForm;

// ETag support for incremental updates (Phase 1 enhancement)
function GenerateControlsETag(Form: TForm; const Root: string = ''): string;
function DescribeFormWithETag(Form: TForm; const Root: string = ''; MinimalMode: Boolean = False; Depth: Integer = 3; IncludeHwnd: Boolean = False): string;

// New optimized tools (minimal token usage)
function ListFormControls(Form: TForm; const Root: string = ''; Depth: Integer = 1; IncludeHwnd: Boolean = False): string;
function FindControlByPattern(Form: TForm; const NamePattern, CaptionPattern, TypeFilter: string; IncludeHwnd: Boolean = False): string;
function GetControlDetails(Form: TForm; const ControlName: string; IncludeChildren: Boolean = True; IncludeHwnd: Boolean = False): string;

implementation

uses
  Winapi.Windows,
  AutomationDescribable;

const
  MAX_DEPTH = 3; // Maximum nesting depth for control tree (prevent huge JSONs)
  MAX_CHILDREN_PER_LEVEL = 50; // Maximum children to describe per level

type
  TDescriptionContext = record
    CurrentDepth: Integer;
    MaxDepth: Integer;
    RootControl: TControl;
    IncludeChildren: Boolean;
    MinimalMode: Boolean; // If True, return only essential fields
    IncludeHwnd: Boolean;  // If True, include hwnd field (for wait_* tools)
  end;

function DescribeControl(Control: TControl; const Context: TDescriptionContext): TJSONObject; forward;

function GetControlType(Control: TControl): string;
begin
  // Return friendly type name
  Result := Control.ClassName;
  if Copy(Result, 1, 1) = 'T' then
    Delete(Result, 1, 1); // Remove 'T' prefix
end;

function GetControlValue(Control: TControl): string;
begin
  Result := '';

  // Extract value based on control type
  if Control is TLabel then
    Result := TLabel(Control).Caption
  else if Control is TEdit then
    Result := TEdit(Control).Text
  else if Control is TMemo then
    Result := TMemo(Control).Lines.Text
  else if Control is TButton then
    Result := TButton(Control).Caption
  else if Control is TCheckBox then
    Result := BoolToStr(TCheckBox(Control).Checked, True)
  else if Control is TRadioButton then
    Result := BoolToStr(TRadioButton(Control).Checked, True)
  else if Control is TComboBox then
    Result := TComboBox(Control).Text
  else if Control is TListBox then
  begin
    if TListBox(Control).ItemIndex >= 0 then
      Result := TListBox(Control).Items[TListBox(Control).ItemIndex];
  end;
end;

// Minimal control descriptor - only essential fields (~90% token reduction)
function DescribeControlMinimal(Control: TControl; IncludeHwnd: Boolean = False): TJSONObject;
var
  Caption: string;
begin
  Result := TJSONObject.Create;

  // Essential fields only
  Result.AddPair('name', Control.Name);
  Result.AddPair('type', GetControlType(Control));

  // Caption/text if exists
  Caption := '';
  if Control is TLabel then
    Caption := TLabel(Control).Caption
  else if Control is TButton then
    Caption := TButton(Control).Caption
  else if Control is TCheckBox then
    Caption := TCheckBox(Control).Caption
  else if Control is TEdit then
    Caption := TEdit(Control).Text
  else if Control is TComboBox then
    Caption := TComboBox(Control).Text;

  if Caption <> '' then
    Result.AddPair('caption', Caption);

  // State - only if FALSE (assume true by default to save tokens)
  if not Control.Enabled then
    Result.AddPair('enabled', TJSONBool.Create(False));
  if not Control.Visible then
    Result.AddPair('visible', TJSONBool.Create(False));

  // hwnd ONLY if explicitly requested (for wait_* tools)
  if IncludeHwnd and (Control is TWinControl) then
    Result.AddPair('hwnd', TJSONNumber.Create(TWinControl(Control).Handle));

  // Note: children_count is added by DescribeControl when needed
end;

function DescribeControlBasic(Control: TControl): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Control.Name);
  Result.AddPair('type', GetControlType(Control));

  // Caption or hint
  if Control is TLabel then
    Result.AddPair('caption', TLabel(Control).Caption)
  else if Control is TButton then
    Result.AddPair('caption', TButton(Control).Caption)
  else if Control is TCheckBox then
    Result.AddPair('caption', TCheckBox(Control).Caption)
  else if Control.Hint <> '' then
    Result.AddPair('hint', Control.Hint);

  // State
  Result.AddPair('enabled', TJSONBool.Create(Control.Enabled));
  Result.AddPair('visible', TJSONBool.Create(Control.Visible));
  if Control is TWinControl then
    Result.AddPair('focused', TJSONBool.Create(TWinControl(Control).Focused))
  else
    Result.AddPair('focused', TJSONBool.Create(False));

  // Bounds
  Result.AddPair('bounds', TJSONObject.Create
    .AddPair('left', TJSONNumber.Create(Control.Left))
    .AddPair('top', TJSONNumber.Create(Control.Top))
    .AddPair('width', TJSONNumber.Create(Control.Width))
    .AddPair('height', TJSONNumber.Create(Control.Height)));

  // Tab order (if applicable)
  if Control is TWinControl then
    Result.AddPair('tab_order', TJSONNumber.Create(TWinControl(Control).TabOrder));

  // Value (if applicable)
  var Value := GetControlValue(Control);
  if Value <> '' then
    Result.AddPair('value', Value);
end;

function DescribeControl(Control: TControl; const Context: TDescriptionContext): TJSONObject;
var
  I: Integer;
  ChildArray: TJSONArray;
  WinControl: TWinControl;
  ChildCount: Integer;
begin
  // Use minimal or full descriptor based on context
  if Context.MinimalMode then
    Result := DescribeControlMinimal(Control, Context.IncludeHwnd)
  else
    Result := DescribeControlBasic(Control);

  // Check if this is a container with children
  if (Control is TWinControl) and Context.IncludeChildren then
  begin
    WinControl := TWinControl(Control);
    ChildCount := WinControl.ControlCount;

    if ChildCount > 0 then
    begin
      // Only recurse if within depth limit
      if Context.CurrentDepth < Context.MaxDepth then
      begin
        ChildArray := TJSONArray.Create;
        Result.AddPair('children', ChildArray);

        // Limit children to prevent huge JSONs
        for I := 0 to Min(ChildCount - 1, MAX_CHILDREN_PER_LEVEL - 1) do
        begin
          var ChildContext := Context;
          ChildContext.CurrentDepth := Context.CurrentDepth + 1;

          // In minimal mode with depth > 1, just add names instead of full objects
          if Context.MinimalMode and (Context.CurrentDepth > 0) then
            ChildArray.Add(WinControl.Controls[I].Name)
          else
            ChildArray.AddElement(DescribeControl(WinControl.Controls[I], ChildContext));
        end;

        if ChildCount > MAX_CHILDREN_PER_LEVEL then
          Result.AddPair('children_truncated', TJSONBool.Create(True));
      end
      else
      begin
        // Max depth reached - show count but not the children
        Result.AddPair('children_count', TJSONNumber.Create(ChildCount));
        Result.AddPair('max_depth_reached', TJSONBool.Create(True));
      end;
    end;
  end
  else if (Control is TWinControl) then
  begin
    // Not including children, but show count if container has any (for progressive discovery)
    ChildCount := TWinControl(Control).ControlCount;
    if ChildCount > 0 then
      Result.AddPair('children_count', TJSONNumber.Create(ChildCount));
  end;
end;

function DescribeFormObject(Form: TForm; const Root: string; MinimalMode: Boolean = False; Depth: Integer = MAX_DEPTH; IncludeHwnd: Boolean = False): TJSONObject;
var
  Context: TDescriptionContext;
  ControlsArray: TJSONArray;
  I: Integer;
  RootControl: TControl;
begin
  Result := TJSONObject.Create;

  // Form metadata
  Result.AddPair('name', Form.Name);
  Result.AddPair('caption', Form.Caption);
  Result.AddPair('class', Form.ClassName);
  Result.AddPair('handle', TJSONNumber.Create(Form.Handle));

  // Form state
  Result.AddPair('state', TJSONObject.Create
    .AddPair('visible', TJSONBool.Create(Form.Visible))
    .AddPair('enabled', TJSONBool.Create(Form.Enabled))
    .AddPair('focused', TJSONBool.Create(Form.Active))
    .AddPair('modal', TJSONBool.Create(fsModal in Form.FormState)));

  // Setup context
  Context.CurrentDepth := 0;
  Context.MaxDepth := Max(1, Min(Depth, MAX_DEPTH)); // Clamp between 1 and MAX_DEPTH
  Context.IncludeChildren := True;
  Context.MinimalMode := MinimalMode;
  Context.IncludeHwnd := IncludeHwnd;

  // Find root control if specified
  if Root <> '' then
  begin
    RootControl := Form.FindComponent(Root) as TControl;
    if RootControl = nil then
    begin
      Result.AddPair('error', 'Control not found: ' + Root);
      Exit;
    end;
    Context.RootControl := RootControl;
    Result.AddPair('root', Root);

    // Describe just this control
    Result.AddPair('control', DescribeControl(RootControl, Context));
  end
  else
  begin
    // Describe all top-level controls
    ControlsArray := TJSONArray.Create;
    Result.AddPair('controls', ControlsArray);
    Result.AddPair('control_count', TJSONNumber.Create(Form.ControlCount));

    for I := 0 to Min(Form.ControlCount - 1, MAX_CHILDREN_PER_LEVEL - 1) do
    begin
      ControlsArray.AddElement(DescribeControl(Form.Controls[I], Context));
    end;

    if Form.ControlCount > MAX_CHILDREN_PER_LEVEL then
      Result.AddPair('controls_truncated', TJSONBool.Create(True));
  end;
end;

function DescribeForm(Form: TForm; const Root: string): string;
var
  Describable: IAutomationDescribable;
  JSONObj: TJSONObject;
begin
  if Form = nil then
  begin
    Result := '{"error": "Form is nil"}';
    Exit;
  end;

  // Check if form implements IAutomationDescribable
  if Supports(Form, IAutomationDescribable, Describable) then
  begin
    Result := Describable.DescribeAsJSON(Root);
  end
  else
  begin
    // Fall back to RTTI introspection
    JSONObj := DescribeFormObject(Form, Root);
    try
      Result := JSONObj.ToString;
    finally
      JSONObj.Free;
    end;
  end;
end;

function FindForm(const FormIdentifier: string): TForm;
var
  HandleValue: THandle;
  I: Integer;
begin
  // Default: active form
  if (FormIdentifier = '') or SameText(FormIdentifier, 'active') or SameText(FormIdentifier, 'focus') then
    Result := Screen.ActiveForm

  // MDI main form
  else if SameText(FormIdentifier, 'main') then
    Result := Application.MainForm

  // By handle (from list-open-forms)
  else if TryStrToInt(FormIdentifier, Integer(HandleValue)) then
  begin
    Result := nil;
    for I := 0 to Screen.FormCount - 1 do
    begin
      if Screen.Forms[I].Handle = HandleValue then
      begin
        Result := Screen.Forms[I];
        Exit;
      end;
    end;
  end
  else
    Result := Screen.ActiveForm; // Fallback to active
end;

function DescribeFormByName(const FormName: string; const Root: string): string;
var
  Form: TForm;
begin
  Form := FindForm(FormName);

  if Form = nil then
    Result := '{"error": "Form not found: ' + FormName + '"}'
  else
    Result := DescribeForm(Form, Root);
end;

function DescribeActiveForm(const Root: string): string;
begin
  if Screen.ActiveForm = nil then
    Result := '{"error": "No active form"}'
  else
    Result := DescribeForm(Screen.ActiveForm, Root);
end;

function ListOpenForms: string;
var
  I: Integer;
  FormsArray: TJSONArray;
  FormObj: TJSONObject;
  Form: TForm;
begin
  FormsArray := TJSONArray.Create;
  try
    for I := 0 to Screen.FormCount - 1 do
    begin
      Form := Screen.Forms[I];
      FormObj := TJSONObject.Create;
      FormObj.AddPair('name', Form.Name);
      FormObj.AddPair('caption', Form.Caption);
      FormObj.AddPair('class', Form.ClassName);
      FormObj.AddPair('visible', TJSONBool.Create(Form.Visible));
      FormObj.AddPair('active', TJSONBool.Create(Form.Active));
      FormObj.AddPair('handle', TJSONNumber.Create(Form.Handle));
      FormsArray.AddElement(FormObj);
    end;

    Result := FormsArray.ToString;
  finally
    FormsArray.Free;
  end;
end;

// FNV-1a hash function for ETag generation (32-bit)
function FNV1aHash(const Data: string): UInt32;
const
  FNV_OFFSET_BASIS = 2166136261;
  FNV_PRIME = 16777619;
var
  I: Integer;
begin
  Result := FNV_OFFSET_BASIS;
  for I := 1 to Length(Data) do
    Result := (Result xor Ord(Data[I])) * FNV_PRIME;
end;

// Generate ETag by hashing structural properties (not volatile state)
procedure HashControlStructure(Control: TControl; var Accumulator: string);
var
  I: Integer;
  WinControl: TWinControl;
  ControlHandle: NativeInt;
begin
  // Hash: hwnd, name, type, position (structure, not state)
  // Handle only exists on TWinControl
  if Control is TWinControl then
    ControlHandle := TWinControl(Control).Handle
  else
    ControlHandle := 0;

  Accumulator := Accumulator +
    IntToStr(ControlHandle) +
    Control.Name +
    Control.ClassName +
    IntToStr(Control.Left) +
    IntToStr(Control.Top);

  // Recurse into children
  if Control is TWinControl then
  begin
    WinControl := TWinControl(Control);
    for I := 0 to WinControl.ControlCount - 1 do
      HashControlStructure(WinControl.Controls[I], Accumulator);
  end;
end;

function GenerateControlsETag(Form: TForm; const Root: string): string;
var
  Accumulator: string;
  Hash: UInt32;
  RootControl: TControl;
begin
  if Form = nil then
  begin
    Result := 'W/"00000000"';
    Exit;
  end;

  Accumulator := '';

  // Hash form itself
  Accumulator := IntToStr(Form.Handle) + Form.Name + Form.ClassName;

  // Find root control if specified
  if Root <> '' then
  begin
    RootControl := Form.FindComponent(Root) as TControl;
    if RootControl <> nil then
      HashControlStructure(RootControl, Accumulator)
    else
      Accumulator := Accumulator + 'ERROR:' + Root;
  end
  else
  begin
    // Hash all top-level controls
    var I: Integer;
    for I := 0 to Form.ControlCount - 1 do
      HashControlStructure(Form.Controls[I], Accumulator);
  end;

  Hash := FNV1aHash(Accumulator);
  Result := Format('W/"%8.8x"', [Hash]);
end;

function DescribeFormWithETag(Form: TForm; const Root: string; MinimalMode: Boolean; Depth: Integer; IncludeHwnd: Boolean): string;
var
  JSONObj: TJSONObject;
  ETag: string;
begin
  if Form = nil then
  begin
    Result := '{"error": "Form is nil"}';
    Exit;
  end;

  // Generate description with minimal mode, depth, and hwnd support
  JSONObj := DescribeFormObject(Form, Root, MinimalMode, Depth, IncludeHwnd);
  try
    // Add ETag
    ETag := GenerateControlsETag(Form, Root);
    JSONObj.AddPair('etag', ETag);

    Result := JSONObj.ToString;
  finally
    JSONObj.Free;
  end;
end;

{ New Optimized Tools - Minimal Token Usage }

// List controls with minimal data (shallow by default)
function ListFormControls(Form: TForm; const Root: string; Depth: Integer; IncludeHwnd: Boolean): string;
var
  Context: TDescriptionContext;
  ControlsArray: TJSONArray;
  ResultObj: TJSONObject;
  RootControl: TControl;
  I: Integer;
begin
  if Form = nil then
  begin
    Result := '{"error": "Form is nil"}';
    Exit;
  end;

  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('form', Form.Name);

    // Setup minimal context
    Context.CurrentDepth := 0;
    Context.MaxDepth := Max(1, Min(Depth, MAX_DEPTH)); // Clamp between 1 and MAX_DEPTH
    Context.IncludeChildren := (Depth > 0);
    Context.MinimalMode := True;
    Context.IncludeHwnd := IncludeHwnd;

    // Find root control if specified
    if Root <> '' then
    begin
      RootControl := Form.FindComponent(Root) as TControl;
      if RootControl = nil then
      begin
        Result := '{"error": "Control not found: ' + Root + '"}';
        Exit;
      end;
      ResultObj.AddPair('root', Root);
      ResultObj.AddPair('control', DescribeControl(RootControl, Context));
    end
    else
    begin
      // List all top-level controls
      ControlsArray := TJSONArray.Create;
      ResultObj.AddPair('controls', ControlsArray);

      for I := 0 to Min(Form.ControlCount - 1, MAX_CHILDREN_PER_LEVEL - 1) do
      begin
        ControlsArray.AddElement(DescribeControl(Form.Controls[I], Context));
      end;

      if Form.ControlCount > MAX_CHILDREN_PER_LEVEL then
        ResultObj.AddPair('truncated', TJSONBool.Create(True));
    end;

    Result := ResultObj.ToString;
  finally
    ResultObj.Free;
  end;
end;

// Find controls by pattern matching
function FindControlByPattern(Form: TForm; const NamePattern, CaptionPattern, TypeFilter: string; IncludeHwnd: Boolean): string;
var
  ResultArray: TJSONArray;
  ResultObj: TJSONObject;

  procedure SearchControl(Control: TControl);
  var
    I: Integer;
    ControlObj: TJSONObject;
    Caption: string;
    MatchesName, MatchesCaption, MatchesType: Boolean;
  begin
    // Check if control matches criteria
    MatchesName := (NamePattern = '') or
                   (Pos(LowerCase(NamePattern), LowerCase(Control.Name)) > 0);

    // Get caption
    Caption := '';
    if Control is TLabel then
      Caption := TLabel(Control).Caption
    else if Control is TButton then
      Caption := TButton(Control).Caption
    else if Control is TCheckBox then
      Caption := TCheckBox(Control).Caption;

    MatchesCaption := (CaptionPattern = '') or
                      (Pos(LowerCase(CaptionPattern), LowerCase(Caption)) > 0);

    MatchesType := (TypeFilter = '') or
                   SameText(GetControlType(Control), TypeFilter) or
                   SameText(Control.ClassName, TypeFilter);

    // If matches all criteria, add to results
    if MatchesName and MatchesCaption and MatchesType then
    begin
      ControlObj := DescribeControlMinimal(Control, IncludeHwnd);
      ResultArray.AddElement(ControlObj);
    end;

    // Recurse into children
    if Control is TWinControl then
    begin
      for I := 0 to TWinControl(Control).ControlCount - 1 do
        SearchControl(TWinControl(Control).Controls[I]);
    end;
  end;

var
  I: Integer;
begin
  if Form = nil then
  begin
    Result := '{"error": "Form is nil"}';
    Exit;
  end;

  ResultObj := TJSONObject.Create;
  try
    ResultArray := TJSONArray.Create;
    ResultObj.AddPair('matches', ResultArray);
    ResultObj.AddPair('form', Form.Name);

    // Search all controls recursively
    for I := 0 to Form.ControlCount - 1 do
      SearchControl(Form.Controls[I]);

    ResultObj.AddPair('count', TJSONNumber.Create(ResultArray.Count));
    Result := ResultObj.ToString;
  finally
    ResultObj.Free;
  end;
end;

// Get details of a single control
function GetControlDetails(Form: TForm; const ControlName: string; IncludeChildren: Boolean; IncludeHwnd: Boolean): string;
var
  Control: TControl;
  Context: TDescriptionContext;
  ResultObj: TJSONObject;
begin
  if Form = nil then
  begin
    Result := '{"error": "Form is nil"}';
    Exit;
  end;

  Control := Form.FindComponent(ControlName) as TControl;
  if Control = nil then
  begin
    Result := '{"error": "Control not found: ' + ControlName + '"}';
    Exit;
  end;

  // Setup context for detailed view
  Context.CurrentDepth := 0;
  Context.MaxDepth := 2; // Limited depth for single control
  Context.IncludeChildren := IncludeChildren;
  Context.MinimalMode := True;
  Context.IncludeHwnd := IncludeHwnd;

  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('form', Form.Name);
    ResultObj.AddPair('control', DescribeControl(Control, Context));
    Result := ResultObj.ToString;
  finally
    ResultObj.Free;
  end;
end;

end.
