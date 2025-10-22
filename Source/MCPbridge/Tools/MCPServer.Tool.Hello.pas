unit MCPServer.Tool.Hello;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  THeloParams = class
    // No parameters needed for this tool
  end;

  THelloTool = class(TMCPToolBase<THeloParams>)
  private
    function GetAvailableModules: string;
  protected
    function ExecuteWithParams(const Params: THeloParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration;

{ THelloTool }

constructor THelloTool.Create;
begin
  inherited;
  FName := 'mcp_hello';
  FDescription := 'Get a greeting from the MCP server and verify connectivity';
end;

function THelloTool.GetAvailableModules: string;
begin
  // Generic bridge information - no application-specific detection
  // Application-specific information should come from the target app's own tools
  Result := 'Bridge Framework: DelphiMCP v2.1' + sLineBreak +
            'Transport: Named Pipes (Windows IPC)' + sLineBreak +
            'Protocol: JSON-RPC 2.0';
end;

function THelloTool.ExecuteWithParams(const Params: THeloParams): string;
var
  Response: TStringList;
begin
  Response := TStringList.Create;
  try
    Response.Add('========================================');
    Response.Add('Hello from MCP Server!');
    Response.Add('========================================');
    Response.Add('');
    Response.Add('This is a Model Context Protocol server');
    Response.Add('designed to explore and document the');
    Response.Add('target application.');
    Response.Add('');
    Response.Add('Server Version: 1.0.0');
    Response.Add('MCP Protocol: 2024-11-05');
    Response.Add('');
    Response.Add(GetAvailableModules);
    Response.Add('');
    Response.Add('Ready to assist with application exploration!');
    Response.Add('========================================');

    Result := Response.Text;
  finally
    Response.Free;
  end;
end;

initialization
  TMCPRegistry.RegisterTool('mcp_hello',
    function: IMCPTool
    begin
      Result := THelloTool.Create;
    end
  );

end.