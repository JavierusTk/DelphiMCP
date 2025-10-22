unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TfmMain = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    btnShowCustomer: TButton;
    memoLog: TMemo;
    pnlBottom: TPanel;
    lblStatus: TLabel;
    edtCustomerName: TEdit;
    lblCustomerName: TLabel;
    edtCustomerEmail: TEdit;
    lblCustomerEmail: TLabel;
    btnSaveCustomer: TButton;
    btnClearLog: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnShowCustomerClick(Sender: TObject);
    procedure btnSaveCustomerClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
  private
    procedure Log(const Msg: string);
  public
    { Public declarations }
  end;

var
  fmMain: TfmMain;

implementation

{$R *.dfm}

uses
  CustomerForm, MCPServerIntegration;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  Log('Application started');
  Log('MCP Server starting...');

  // Initialize MCP Server (in a real app, you might do this conditionally)
  if StartMCPServer then
    Log('MCP Server started successfully on pipe: ' + GetMCPPipeName)
  else
    Log('Failed to start MCP Server');

  lblStatus.Caption := 'Ready';
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  Log('Stopping MCP Server...');
  StopMCPServer;
  Log('Application closing');
end;

procedure TfmMain.btnShowCustomerClick(Sender: TObject);
var
  CustomerForm: TfmCustomer;
begin
  Log('Opening Customer form...');
  CustomerForm := TfmCustomer.Create(Self);
  try
    CustomerForm.ShowModal;
    Log('Customer form closed');
  finally
    CustomerForm.Free;
  end;
end;

procedure TfmMain.btnSaveCustomerClick(Sender: TObject);
begin
  if Trim(edtCustomerName.Text) = '' then
  begin
    ShowMessage('Please enter a customer name');
    Exit;
  end;

  Log('Saving customer: ' + edtCustomerName.Text);

  // Simulate save operation
  Sleep(500);

  Log('Customer saved successfully');
  Log('  Name: ' + edtCustomerName.Text);
  Log('  Email: ' + edtCustomerEmail.Text);

  ShowMessage('Customer saved successfully!');
end;

procedure TfmMain.btnClearLogClick(Sender: TObject);
begin
  memoLog.Clear;
end;

procedure TfmMain.Log(const Msg: string);
begin
  memoLog.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] ' + Msg);
end;

end.
