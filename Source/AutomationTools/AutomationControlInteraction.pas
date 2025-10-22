unit AutomationControlInteraction;

{
  Control Manipulation Utilities for MCP Automation

  PURPOSE:
  - Programmatically interact with VCL controls
  - Set values, click buttons, select items
  - Thread-safe execution (must be called from main thread)

  USAGE:
  - All functions return success/error messages
  - Control lookup by name within form
  - Type-safe operations with validation

  IMPORTANT:
  - These functions MUST be called from main thread via TThread.Synchronize
  - They simulate user interaction (not direct property access)
}

interface

uses
  System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls;

type
  TControlResult = record
    Success: Boolean;
    Message: string;
  end;

// Control manipulation functions
function SetControlValue(const FormName, ControlName, Value: string): TControlResult;
function ClickButton(const FormName, ControlName: string): TControlResult;
function SelectComboItem(const FormName, ControlName, ItemText: string): TControlResult;
function SelectTabByIndex(const FormName, ControlName: string; TabIndex: Integer): TControlResult;
function SelectTabByName(const FormName, ControlName, TabName: string): TControlResult;
function CloseForm(const FormName: string): TControlResult;
function SetFocus(const FormName, ControlName: string): TControlResult;

// Helper functions
function FindFormByName(const FormName: string): TForm;
function FindControlInForm(Form: TForm; const ControlName: string): TControl;

implementation

uses
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Buttons, Winapi.Windows, Winapi.Messages;

function FindFormByName(const FormName: string): TForm;
var
  I: Integer;
  Form: TForm;
begin
  Result := nil;

  // Handle special case: "active"
  if SameText(FormName, 'active') then
  begin
    Result := Screen.ActiveForm;
    Exit;
  end;

  // Search by name, class, or caption
  for I := 0 to Screen.FormCount - 1 do
  begin
    Form := Screen.Forms[I];
    if SameText(Form.Name, FormName) or
       SameText(Form.ClassName, FormName) or
       SameText(Form.Caption, FormName) then
    begin
      Result := Form;
      Exit;
    end;
  end;
end;

function FindControlInForm(Form: TForm; const ControlName: string): TControl;
var
  Component: TComponent;
begin
  Result := nil;

  if Form = nil then
    Exit;

  // Try FindComponent first (fastest)
  Component := Form.FindComponent(ControlName);
  if Component is TControl then
  begin
    Result := TControl(Component);
    Exit;
  end;

  // If not found, could implement recursive search here
  // For now, FindComponent should handle most cases
end;

function SetControlValue(const FormName, ControlName, Value: string): TControlResult;
var
  Form: TForm;
  Control: TControl;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Check if control is enabled
  if not Control.Enabled then
  begin
    Result.Message := 'Control is disabled: ' + ControlName;
    Exit;
  end;

  // Set value based on control type
  try
    if Control is TEdit then
    begin
      TEdit(Control).Text := Value;
      Result.Success := True;
      Result.Message := 'Value set successfully';
    end
    else if Control is TMemo then
    begin
      TMemo(Control).Lines.Text := Value;
      Result.Success := True;
      Result.Message := 'Value set successfully';
    end
    else if Control is TCheckBox then
    begin
      TCheckBox(Control).Checked := StrToBoolDef(Value, False);
      Result.Success := True;
      Result.Message := 'Value set successfully';
    end
    else if Control is TRadioButton then
    begin
      TRadioButton(Control).Checked := StrToBoolDef(Value, False);
      Result.Success := True;
      Result.Message := 'Value set successfully';
    end
    else if Control is TComboBox then
    begin
      TComboBox(Control).Text := Value;
      Result.Success := True;
      Result.Message := 'Value set successfully';
    end
    else if Control is TLabel then
    begin
      TLabel(Control).Caption := Value;
      Result.Success := True;
      Result.Message := 'Caption set successfully';
    end
    else
    begin
      Result.Message := 'Unsupported control type: ' + Control.ClassName;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error setting value: ' + E.Message;
    end;
  end;
end;

function ClickButton(const FormName, ControlName: string): TControlResult;
var
  Form: TForm;
  Control: TControl;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Check if control is enabled and visible
  if not Control.Enabled then
  begin
    Result.Message := 'Button is disabled: ' + ControlName;
    Exit;
  end;

  if not Control.Visible then
  begin
    Result.Message := 'Button is not visible: ' + ControlName;
    Exit;
  end;

  // Click based on control type
  try
    if Control is TButton then
    begin
      TButton(Control).Click;
      Result.Success := True;
      Result.Message := 'Button clicked';
    end
    else if Control is TBitBtn then
    begin
      TBitBtn(Control).Click;
      Result.Success := True;
      Result.Message := 'Button clicked';
    end
    else if Control is TSpeedButton then
    begin
      TSpeedButton(Control).Click;
      Result.Success := True;
      Result.Message := 'Button clicked';
    end
    else if Control is TCheckBox then
    begin
      // Use Windows message to click (Click method is protected)
      SendMessage(TWinControl(Control).Handle, BM_CLICK, 0, 0);
      Result.Success := True;
      Result.Message := 'Checkbox clicked';
    end
    else if Control is TRadioButton then
    begin
      // Use Windows message to click (Click method is protected)
      SendMessage(TWinControl(Control).Handle, BM_CLICK, 0, 0);
      Result.Success := True;
      Result.Message := 'Radio button clicked';
    end
    else
    begin
      Result.Message := 'Control is not clickable: ' + Control.ClassName;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error clicking control: ' + E.Message;
    end;
  end;
end;

function SelectComboItem(const FormName, ControlName, ItemText: string): TControlResult;
var
  Form: TForm;
  Control: TControl;
  ComboBox: TComboBox;
  Index: Integer;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Validate control type
  if not (Control is TComboBox) then
  begin
    Result.Message := 'Control is not a ComboBox: ' + Control.ClassName;
    Exit;
  end;

  ComboBox := TComboBox(Control);

  // Check if enabled
  if not ComboBox.Enabled then
  begin
    Result.Message := 'ComboBox is disabled';
    Exit;
  end;

  // Find item
  try
    Index := ComboBox.Items.IndexOf(ItemText);
    if Index >= 0 then
    begin
      ComboBox.ItemIndex := Index;
      // Trigger OnChange event
      if Assigned(ComboBox.OnChange) then
        ComboBox.OnChange(ComboBox);
      Result.Success := True;
      Result.Message := 'Item selected: ' + ItemText;
    end
    else
    begin
      Result.Message := 'Item not found in ComboBox: ' + ItemText;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error selecting item: ' + E.Message;
    end;
  end;
end;

function SelectTabByIndex(const FormName, ControlName: string; TabIndex: Integer): TControlResult;
var
  Form: TForm;
  Control: TControl;
  PageControl: TPageControl;
  TabControl: TTabControl;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Handle PageControl
  if Control is TPageControl then
  begin
    PageControl := TPageControl(Control);
    if (TabIndex >= 0) and (TabIndex < PageControl.PageCount) then
    begin
      PageControl.ActivePageIndex := TabIndex;
      // Trigger OnChange event
      if Assigned(PageControl.OnChange) then
        PageControl.OnChange(PageControl);
      Result.Success := True;
      Result.Message := 'Tab selected: ' + PageControl.Pages[TabIndex].Caption;
    end
    else
    begin
      Result.Message := Format('Tab index out of range: %d (0..%d)', [TabIndex, PageControl.PageCount - 1]);
    end;
  end
  // Handle TabControl
  else if Control is TTabControl then
  begin
    TabControl := TTabControl(Control);
    if (TabIndex >= 0) and (TabIndex < TabControl.Tabs.Count) then
    begin
      TabControl.TabIndex := TabIndex;
      // Trigger OnChange event
      if Assigned(TabControl.OnChange) then
        TabControl.OnChange(TabControl);
      Result.Success := True;
      Result.Message := 'Tab selected: ' + TabControl.Tabs[TabIndex];
    end
    else
    begin
      Result.Message := Format('Tab index out of range: %d (0..%d)', [TabIndex, TabControl.Tabs.Count - 1]);
    end;
  end
  else
  begin
    Result.Message := 'Control is not a PageControl or TabControl: ' + Control.ClassName;
  end;
end;

function SelectTabByName(const FormName, ControlName, TabName: string): TControlResult;
var
  Form: TForm;
  Control: TControl;
  PageControl: TPageControl;
  TabControl: TTabControl;
  I: Integer;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Handle PageControl
  if Control is TPageControl then
  begin
    PageControl := TPageControl(Control);
    for I := 0 to PageControl.PageCount - 1 do
    begin
      if SameText(PageControl.Pages[I].Caption, TabName) or
         SameText(PageControl.Pages[I].Name, TabName) then
      begin
        PageControl.ActivePageIndex := I;
        // Trigger OnChange event
        if Assigned(PageControl.OnChange) then
          PageControl.OnChange(PageControl);
        Result.Success := True;
        Result.Message := 'Tab selected: ' + PageControl.Pages[I].Caption;
        Exit;
      end;
    end;
    Result.Message := 'Tab not found: ' + TabName;
  end
  // Handle TabControl
  else if Control is TTabControl then
  begin
    TabControl := TTabControl(Control);
    I := TabControl.Tabs.IndexOf(TabName);
    if I >= 0 then
    begin
      TabControl.TabIndex := I;
      // Trigger OnChange event
      if Assigned(TabControl.OnChange) then
        TabControl.OnChange(TabControl);
      Result.Success := True;
      Result.Message := 'Tab selected: ' + TabName;
    end
    else
    begin
      Result.Message := 'Tab not found: ' + TabName;
    end;
  end
  else
  begin
    Result.Message := 'Control is not a PageControl or TabControl: ' + Control.ClassName;
  end;
end;

function CloseForm(const FormName: string): TControlResult;
var
  Form: TForm;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  try
    // Close the form (will trigger OnClose event if assigned)
    Form.Close;
    Result.Success := True;
    Result.Message := 'Form closed: ' + FormName;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error closing form: ' + E.Message;
    end;
  end;
end;

function SetFocus(const FormName, ControlName: string): TControlResult;
var
  Form: TForm;
  Control: TControl;
  WinControl: TWinControl;
begin
  Result.Success := False;
  Result.Message := '';

  // Find form
  Form := FindFormByName(FormName);
  if Form = nil then
  begin
    Result.Message := 'Form not found: ' + FormName;
    Exit;
  end;

  // Find control
  Control := FindControlInForm(Form, ControlName);
  if Control = nil then
  begin
    Result.Message := 'Control not found: ' + ControlName;
    Exit;
  end;

  // Check if control can receive focus
  if not (Control is TWinControl) then
  begin
    Result.Message := 'Control cannot receive focus: ' + Control.ClassName;
    Exit;
  end;

  WinControl := TWinControl(Control);

  // Check if enabled and visible
  if not WinControl.Enabled then
  begin
    Result.Message := 'Control is disabled';
    Exit;
  end;

  if not WinControl.Visible then
  begin
    Result.Message := 'Control is not visible';
    Exit;
  end;

  try
    if WinControl.CanFocus then
    begin
      WinControl.SetFocus;
      Result.Success := True;
      Result.Message := 'Focus set successfully';
    end
    else
    begin
      Result.Message := 'Control cannot receive focus';
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error setting focus: ' + E.Message;
    end;
  end;
end;

end.
