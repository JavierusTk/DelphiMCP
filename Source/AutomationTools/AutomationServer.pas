unit AutomationServer;

{
  Automation Server - Lifecycle Manager

  PURPOSE:
  - Manages creation, startup, and shutdown of automation server thread
  - Provides clean initialization and finalization
  - Handles errors gracefully
  - Configuration-based server setup

  USAGE:
    var
      Server: TAutomationServer;
      Config: TAutomationConfig;
    begin
      Server := TAutomationServer.Create;
      try
        Config := TAutomationConfig.Default;

        // Register your application's tools here
        // RegisterMyTools;

        if Server.Start(Config) then
          ShowMessage('Automation server started')
        else
          ShowMessage('Failed to start server');
      finally
        Server.Free;
      end;
    end;

  NOTE:
  - Tool registration must be done BEFORE calling Start()
  - See AutomationCoreTools.pas for registering generic tools
  - Application-specific tools should be registered separately
}

interface

uses
  System.SysUtils,
  AutomationConfig;

type
  /// <summary>
  /// Automation server lifecycle manager
  /// </summary>
  TAutomationServer = class
  private
    FServerThread: TObject;  // TAutomationServerThread (forward declaration issue)
    FRunning: Boolean;
    FConfig: TAutomationConfig;

  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Starts the automation server with given configuration
    /// </summary>
    /// <param name="Config">Server configuration</param>
    /// <returns>True if started successfully, False otherwise</returns>
    function Start(const Config: TAutomationConfig): Boolean;

    /// <summary>
    /// Stops the automation server gracefully
    /// </summary>
    procedure Stop;

    /// <summary>
    /// Checks if server is currently running
    /// </summary>
    function IsRunning: Boolean;

    /// <summary>
    /// Gets current configuration (only valid if running)
    /// </summary>
    function GetConfig: TAutomationConfig;
  end;

/// <summary>
/// Global convenience procedures for simple server management
/// Compatible with legacy MCPServerManager interface
/// </summary>
procedure StartAutomationServer;
procedure StopAutomationServer;
function IsAutomationServerRunning: Boolean;

implementation

uses
  Winapi.Windows,
  AutomationLogger,
  AutomationServerThread,
  AutomationBroker;  // For modal-safe execution (conditional usage)

{ TAutomationServer }

constructor TAutomationServer.Create;
begin
  inherited Create;
  FServerThread := nil;
  FRunning := False;
end;

destructor TAutomationServer.Destroy;
begin
  Stop;
  inherited;
end;

function TAutomationServer.Start(const Config: TAutomationConfig): Boolean;
var
  ErrorMsg: string;
  Thread: TAutomationServerThread;
begin
  Result := False;

  if FRunning then
  begin
    LogWarning('Automation server already running');
    Exit(True); // Already running is not an error
  end;

  // Validate configuration
  if not Config.Validate(ErrorMsg) then
  begin
    LogError('Invalid configuration: ' + ErrorMsg);
    Exit;
  end;

  try
    LogInfo('Starting automation server on pipe: ' + Config.PipeName);

    // Initialize broker BEFORE starting server thread (if enabled)
    if Config.EnableModalSupport then
    begin
      LogInfo('Initializing modal-safe broker');
      InitAutomationBroker;
    end;

    // Create and start server thread
    Thread := TAutomationServerThread.Create(Config.PipeName);
    FServerThread := Thread;
    Thread.Start;

    FConfig := Config;
    FRunning := True;

    if Config.EnableModalSupport then
      LogInfo('Automation server started successfully - ready for automation (modal-safe)')
    else
      LogInfo('Automation server started successfully - ready for automation');
    Result := True;

  except
    on E: Exception do
    begin
      LogError('Failed to start automation server: ' + E.Message);

      // Clean up broker on failure (if it was initialized)
      if Config.EnableModalSupport then
        DoneAutomationBroker;

      if Assigned(FServerThread) then
      begin
        FServerThread.Free;
        FServerThread := nil;
      end;

      FRunning := False;
      Result := False;
    end;
  end;
end;

procedure TAutomationServer.Stop;
var
  Thread: TAutomationServerThread;
  WaitResult: DWORD;
begin
  if not FRunning then
  begin
    LogDebug('No automation server to stop');
    Exit;
  end;

  if not Assigned(FServerThread) then
  begin
    LogWarning('Server marked as running but thread is nil');
    FRunning := False;
    Exit;
  end;

  try
    LogInfo('Stopping automation server...');

    Thread := TAutomationServerThread(FServerThread);
    Thread.SafeTerminate;

    // Wait for thread to finish with timeout
    WaitResult := WaitForSingleObject(Thread.Handle, 2000);
    if WaitResult = WAIT_TIMEOUT then
    begin
      LogWarning('Thread termination timeout - forcing shutdown');
    end
    else
    begin
      LogInfo('Thread terminated successfully');
    end;

    FreeAndNil(FServerThread);
    FRunning := False;

    // Finalize broker AFTER stopping thread (if it was enabled)
    if FConfig.EnableModalSupport then
    begin
      LogDebug('Finalizing modal-safe broker');
      DoneAutomationBroker;
    end;

    LogInfo('Automation server stopped');

  except
    on E: Exception do
    begin
      LogError('Error during server shutdown: ' + E.Message);

      // Force cleanup even if error occurred
      if Assigned(FServerThread) then
      begin
        FreeAndNil(FServerThread);
        FRunning := False;
      end;

      if FConfig.EnableModalSupport then
        DoneAutomationBroker;
    end;
  end;
end;

function TAutomationServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function TAutomationServer.GetConfig: TAutomationConfig;
begin
  if not FRunning then
    raise Exception.Create('Cannot get config - server not running');

  Result := FConfig;
end;

{ Global convenience procedures }

var
  GlobalAutomationServer: TAutomationServer = nil;

procedure StartAutomationServer;
var
  Config: TAutomationConfig;
begin
  if not Assigned(GlobalAutomationServer) then
    GlobalAutomationServer := TAutomationServer.Create;

  if not GlobalAutomationServer.IsRunning then
  begin
    // Note: Tools must be registered BEFORE calling this procedure
    // This includes both application-specific tools and core automation tools

    Config := TAutomationConfig.Default;
    GlobalAutomationServer.Start(Config);
  end;
end;

procedure StopAutomationServer;
begin
  if Assigned(GlobalAutomationServer) then
  begin
    GlobalAutomationServer.Stop;
    FreeAndNil(GlobalAutomationServer);
  end;
end;

function IsAutomationServerRunning: Boolean;
begin
  Result := Assigned(GlobalAutomationServer) and GlobalAutomationServer.IsRunning;
end;

initialization

finalization
  StopAutomationServer;

end.
