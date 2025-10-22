unit AutomationTabulator;

{
  Automation Tools for Tab Order Analyzer (Tabulator)

  Exposes Tabulator functionality via Automation MCP server, allowing
  AI to analyze form tab order remotely.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Vcl.Forms;

/// <summary>
/// Register all Tabulator automation tools with the Automation registry
/// </summary>
procedure RegisterTabulatorAutomationTools;

implementation

uses
  TabOrderAnalyzer,
  AutomationToolRegistry;  // Generic automation tool registry

procedure Tool_AnalyzeFormTabOrder(const Params: TJSONObject; out Result: TJSONObject);
var
  FormName: string;
  OutputPath: string;
  UseActiveForm: Boolean;
  Form: TForm;
  I: Integer;
  PNGFile, TXTFile: string;
  Report: TStringList;
begin
  // Initialize result
  Result := TJSONObject.Create;

  try
    // Extract parameters
    FormName := Params.GetValue<string>('form', 'active');
    OutputPath := Params.GetValue<string>('output', '');
    UseActiveForm := (FormName = 'active') or (FormName = 'focus');

    // Find the form
    Form := nil;
    if UseActiveForm then
    begin
      if Assigned(Screen.ActiveForm) then
        Form := Screen.ActiveForm
      else
      begin
        Result.AddPair('success', TJSONBool.Create(False));
        Result.AddPair('error', 'No active form found');
        Exit;
      end;
    end
    else
    begin
      // Find form by name
      for I := 0 to Screen.FormCount - 1 do
      begin
        if SameText(Screen.Forms[I].Name, FormName) or
           SameText(Screen.Forms[I].ClassName, FormName) then
        begin
          Form := Screen.Forms[I];
          Break;
        end;
      end;

      if Form = nil then
      begin
        Result.AddPair('success', TJSONBool.Create(False));
        Result.AddPair('error', 'Form not found: ' + FormName);
        Exit;
      end;
    end;

    // Set default output path if not specified
    if OutputPath = '' then
      OutputPath := ExtractFilePath(ParamStr(0));

    // Ensure output path ends with backslash
    if not OutputPath.EndsWith('\') then
      OutputPath := OutputPath + '\';

    // Analyze form tab order
    try
      AnalyzeFormTabOrder(Form, OutputPath);

      // Build file paths
      PNGFile := OutputPath + Form.Name + '_TabOrder.png';
      TXTFile := OutputPath + Form.Name + '_TabOrder.txt';

      // Success response
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('form_name', Form.Name);
      Result.AddPair('form_class', Form.ClassName);
      Result.AddPair('output_path', OutputPath);
      Result.AddPair('png_file', PNGFile);
      Result.AddPair('txt_file', TXTFile);

      // Read and include text report
      if FileExists(TXTFile) then
      begin
        Report := TStringList.Create;
        try
          Report.LoadFromFile(TXTFile);
          Result.AddPair('report', Report.Text);
        finally
          Report.Free;
        end;
      end;

    except
      on E: Exception do
      begin
        Result.AddPair('success', TJSONBool.Create(False));
        Result.AddPair('error', 'Analysis failed: ' + E.Message);
      end;
    end;

  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Parameter error: ' + E.Message);
    end;
  end;
end;

procedure Tool_ListFocusableForms(const Params: TJSONObject; out Result: TJSONObject);
var
  FormsArray: TJSONArray;
  I: Integer;
  FormObj: TJSONObject;
  Form: TForm;
begin
  Result := TJSONObject.Create;
  FormsArray := TJSONArray.Create;

  try
    for I := 0 to Screen.FormCount - 1 do
    begin
      Form := Screen.Forms[I];
      if Form.Visible then
      begin
        FormObj := TJSONObject.Create;
        FormObj.AddPair('name', Form.Name);
        FormObj.AddPair('class', Form.ClassName);
        FormObj.AddPair('caption', Form.Caption);
        FormObj.AddPair('visible', TJSONBool.Create(Form.Visible));
        FormObj.AddPair('is_active', TJSONBool.Create(Form = Screen.ActiveForm));
        FormsArray.Add(FormObj);
      end;
    end;

    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('forms', FormsArray);
  except
    on E: Exception do
    begin
      FormsArray.Free;
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

procedure RegisterTabulatorAutomationTools;
begin
  // Register analyze-form-taborder tool
  TAutomationToolRegistry.Instance.RegisterTool(
    'analyze-form-taborder',
    Tool_AnalyzeFormTabOrder,
    'Analyze and document the tab order of controls on a VCL form. ' +
    'Generates PNG screenshot with numbered controls and text report.',
    'development',
    'Tabulator'
  );

  // Register list-focusable-forms tool
  TAutomationToolRegistry.Instance.RegisterTool(
    'list-focusable-forms',
    Tool_ListFocusableForms,
    'List all visible forms that can be analyzed for tab order',
    'development',
    'Tabulator'
  );
end;

end.
