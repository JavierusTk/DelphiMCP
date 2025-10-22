program SimpleVCLApp;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {fmMain},
  CustomerForm in 'CustomerForm.pas' {fmCustomer},
  MCPServerIntegration in 'MCPServerIntegration.pas',
  // Automation Framework units
  AutomationServer in '..\..\Source\AutomationFramework\AutomationServer.pas',
  AutomationServerThread in '..\..\Source\AutomationFramework\AutomationServerThread.pas',
  AutomationToolRegistry in '..\..\Source\AutomationFramework\AutomationToolRegistry.pas',
  AutomationCoreTools in '..\..\Source\AutomationFramework\AutomationCoreTools.pas',
  AutomationConfig in '..\..\Source\AutomationFramework\AutomationConfig.pas',
  AutomationLogger in '..\..\Source\AutomationFramework\AutomationLogger.pas',
  AutomationDescribable in '..\..\Source\AutomationFramework\AutomationDescribable.pas',
  AutomationScreenshot in '..\..\Source\AutomationFramework\AutomationScreenshot.pas',
  AutomationFormIntrospection in '..\..\Source\AutomationFramework\AutomationFormIntrospection.pas',
  AutomationControlInteraction in '..\..\Source\AutomationFramework\AutomationControlInteraction.pas',
  AutomationInputSimulation in '..\..\Source\AutomationFramework\AutomationInputSimulation.pas',
  AutomationSynchronization in '..\..\Source\AutomationFramework\AutomationSynchronization.pas',
  AutomationTabulator in '..\..\Source\AutomationFramework\AutomationTabulator.pas',
  TabOrderAnalyzer in '..\..\Source\AutomationFramework\TabOrderAnalyzer.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmMain, fmMain);
  Application.Run;
end.
