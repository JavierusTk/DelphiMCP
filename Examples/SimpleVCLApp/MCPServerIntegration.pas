unit MCPServerIntegration;

{
  Simple wrapper around AutomationFramework for SimpleVCLApp

  This demonstrates the minimal integration pattern for embedding
  the Automation Framework in a Delphi VCL application.
}

interface

uses
  System.SysUtils, System.JSON;

// Simple wrapper procedures for framework integration
function StartMCPServer: Boolean;
procedure StopMCPServer;
function GetMCPPipeName: string;
function IsMCPServerRunning: Boolean;

implementation

uses
  Winapi.Windows,        // For OutputDebugString
  AutomationServer,      // Framework server
  AutomationToolRegistry, // Tool registration
  AutomationConfig,      // Configuration
  AutomationCoreTools;   // Core 30 tools

const
  // Using default pipe name from AutomationFramework
  // To override: MCP_PIPE_NAME = '\\.\pipe\SimpleVCLApp_MCP_Request';
  MCP_PIPE_NAME = '\\.\pipe\DelphiApp_MCP_Request';

// Register SimpleVCLApp-specific tools (optional)
procedure RegisterSimpleVCLAppTools;
begin
  // Register custom tool: get-customer-count
  AutomationToolRegistry.TAutomationToolRegistry.Instance.RegisterTool(
    'get-customer-count',
    procedure(const Params: TJSONObject; out Result: TJSONObject)
    begin
      Result := TJSONObject.Create;
      Result.AddPair('count', TJSONNumber.Create(5));
      Result.AddPair('status', 'success');
    end,
    'Get total customer count',
    'Application',
    'SimpleVCLApp'
  );

  // Register custom tool: get-app-info
  AutomationToolRegistry.TAutomationToolRegistry.Instance.RegisterTool(
    'get-app-info',
    procedure(const Params: TJSONObject; out Result: TJSONObject)
    begin
      Result := TJSONObject.Create;
      Result.AddPair('name', 'SimpleVCLApp');
      Result.AddPair('version', '1.0.0');
      Result.AddPair('mcp_enabled', TJSONBool.Create(True));
      Result.AddPair('framework', 'AutomationFramework 3.0');
      Result.AddPair('tools', TJSONNumber.Create(32)); // 30 generic + 2 custom
    end,
    'Get application information',
    'Application',
    'SimpleVCLApp'
  );
end;

function StartMCPServer: Boolean;
begin
  try
    // Log server startup with pipe name
    OutputDebugString(PChar('SimpleVCLApp: Starting MCP Server on pipe: ' + MCP_PIPE_NAME));

    // Register core automation tools (30 generic VCL tools)
    RegisterCoreAutomationTools;

    // Optional: Register application-specific tools
    RegisterSimpleVCLAppTools;

    // Start server
    StartAutomationServer;

    OutputDebugString(PChar('SimpleVCLApp: MCP Server started successfully. 32 tools registered (30 framework + 2 custom).'));

    Result := True;
  except
    on E: Exception do
    begin
      // Log error
      OutputDebugString(PChar('SimpleVCLApp: ERROR - Failed to start MCP Server: ' + E.Message));
      Result := False;
    end;
  end;
end;

procedure StopMCPServer;
begin
  StopAutomationServer;
end;

function GetMCPPipeName: string;
begin
  Result := MCP_PIPE_NAME;
end;

function IsMCPServerRunning: Boolean;
begin
  Result := IsAutomationServerRunning;
end;

end.
