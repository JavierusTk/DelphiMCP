program DelphiMCPserver;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IniFiles,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF }
  System.SyncObjs,
  MCPServer.IdHTTPServer in 'W:\Delphi-MCP-Server\src\Server\MCPServer.IdHTTPServer.pas',
  MCPServer.Logger in 'W:\Delphi-MCP-Server\src\Core\MCPServer.Logger.pas',
  MCPServer.ManagerRegistry in 'W:\Delphi-MCP-Server\src\Core\MCPServer.ManagerRegistry.pas',
  MCPServer.Registration in 'W:\Delphi-MCP-Server\src\Core\MCPServer.Registration.pas',
  MCPServer.Settings in 'W:\Delphi-MCP-Server\src\Core\MCPServer.Settings.pas',
  MCPServer.Types in 'W:\Delphi-MCP-Server\src\Protocol\MCPServer.Types.pas',
  MCPServer.Schema.Generator in 'W:\Delphi-MCP-Server\src\Protocol\MCPServer.Schema.Generator.pas',
  MCPServer.Serializer in 'W:\Delphi-MCP-Server\src\Protocol\MCPServer.Serializer.pas',
  MCPServer.Tool.Base in 'W:\Delphi-MCP-Server\src\Tools\MCPServer.Tool.Base.pas',
  MCPServer.Resource.Base in 'W:\Delphi-MCP-Server\src\Resources\MCPServer.Resource.Base.pas',
  MCPServer.ResourcesManager in 'W:\Delphi-MCP-Server\src\Managers\MCPServer.ResourcesManager.pas',
  MCPServer.Resource.Server in 'W:\Delphi-MCP-Server\src\Resources\MCPServer.Resource.Server.pas',
  MCPServer.CoreManager in 'W:\Delphi-MCP-Server\src\Managers\MCPServer.CoreManager.pas',
  MCPServer.ToolsManager in 'W:\Delphi-MCP-Server\src\Managers\MCPServer.ToolsManager.pas',
  // Bridge infrastructure units (core bridge functionality)
  MCPServer.Application.PipeClient in '..\MCPbridge\Core\MCPServer.Application.PipeClient.pas',
  MCPServer.Application.DynamicProxy in '..\MCPbridge\Core\MCPServer.Application.DynamicProxy.pas',
  MCPServer.DebugCapture.Types in '..\MCPbridge\Core\MCPServer.DebugCapture.Types.pas',
  MCPServer.DebugCapture.Core in '..\MCPbridge\Core\MCPServer.DebugCapture.Core.pas',
  // Bridge tool implementations (9 tools)
  MCPServer.Tool.Hello in '..\MCPbridge\Tools\MCPServer.Tool.Hello.pas',
  MCPServer.Tool.Echo in '..\MCPbridge\Tools\MCPServer.Tool.Echo.pas',
  MCPServer.Tool.Time in '..\MCPbridge\Tools\MCPServer.Tool.Time.pas',
  MCPServer.Tool.StartDebugCapture in '..\MCPbridge\Tools\MCPServer.Tool.StartDebugCapture.pas',
  MCPServer.Tool.StopDebugCapture in '..\MCPbridge\Tools\MCPServer.Tool.StopDebugCapture.pas',
  MCPServer.Tool.GetDebugMessages in '..\MCPbridge\Tools\MCPServer.Tool.GetDebugMessages.pas',
  MCPServer.Tool.GetProcessSummary in '..\MCPbridge\Tools\MCPServer.Tool.GetProcessSummary.pas',
  MCPServer.Tool.GetCaptureStatus in '..\MCPbridge\Tools\MCPServer.Tool.GetCaptureStatus.pas',
  MCPServer.Tool.PauseResumeCapture in '..\MCPbridge\Tools\MCPServer.Tool.PauseResumeCapture.pas';

var
  Server: TMCPIdHTTPServer;
  Settings: TMCPSettings;
  ManagerRegistry: IMCPManagerRegistry;
  CoreManager: IMCPCapabilityManager;
  ToolsManager: IMCPCapabilityManager;
  ResourcesManager: IMCPCapabilityManager;
  ShutdownEvent: TEvent;

{$IFDEF MSWINDOWS}
function ConsoleCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  Result := True;
  case dwCtrlType of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT,
    CTRL_SHUTDOWN_EVENT:
    begin
      TLogger.Info('Shutdown signal received');
      if Assigned(ShutdownEvent) then
        ShutdownEvent.SetEvent;
    end;
  end;
end;
{$ENDIF}

procedure ShowHelp;
begin
  WriteLn('DelphiMCP Server - Model Context Protocol Bridge');
  WriteLn('');
  WriteLn('Usage: DelphiMCPserver.exe [/option:value ...]');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  /port:PORT           HTTP port (default: from settings.ini)');
  WriteLn('  /pipe:NAME           Target app pipe name (supports shortcuts)');
  WriteLn('  /?, /help            Show this help');
  WriteLn('');
  WriteLn('Pipe Name Formats:');
  WriteLn('  MyApp                → \\.\pipe\MyApp_MCP_Request (auto-expanded)');
  WriteLn('  MyApp_MCP_Request    → \\.\pipe\MyApp_MCP_Request (prefix added)');
  WriteLn('  \\.\pipe\MyApp       → \\.\pipe\MyApp (used as-is)');
  WriteLn('');
  WriteLn('Priority: Command-line > settings.ini > defaults');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  DelphiMCPserver.exe /port:3002');
  WriteLn('  DelphiMCPserver.exe /pipe:CyberMAX');
  WriteLn('  DelphiMCPserver.exe /port:3002 /pipe:MyApp');
  WriteLn('');
end;

procedure ParseCommandLine(var Port: Integer; var PipeName: string;
  var HasPortArg, HasPipeArg: Boolean);
var
  I: Integer;
  Param, Key, Value: string;
  ColonPos: Integer;
begin
  HasPortArg := False;
  HasPipeArg := False;

  I := 1;
  while I <= ParamCount do
  begin
    Param := ParamStr(I);

    // Check for help
    if (Param = '/?') or (Param = '/help') or (Param = '-help') or (Param = '--help') then
    begin
      ShowHelp;
      Halt(0);
    end;

    // Parse /key:value or /key value
    if (Length(Param) > 0) and ((Param[1] = '/') or (Param[1] = '-')) then
    begin
      // Remove leading / or -
      Param := Copy(Param, 2, Length(Param));

      // Check for colon separator
      ColonPos := Pos(':', Param);
      if ColonPos > 0 then
      begin
        Key := LowerCase(Copy(Param, 1, ColonPos - 1));
        Value := Copy(Param, ColonPos + 1, Length(Param));
      end
      else
      begin
        // Space separator - value is next parameter
        Key := LowerCase(Param);
        if I < ParamCount then
        begin
          Inc(I);
          Value := ParamStr(I);
        end
        else
          Value := '';
      end;

      // Process recognized keys
      if Key = 'port' then
      begin
        Port := StrToIntDef(Value, Port);
        HasPortArg := True;
      end
      else if Key = 'pipe' then
      begin
        PipeName := Value;
        HasPipeArg := True;
      end;
    end;

    Inc(I);
  end;
end;

procedure RunServer;
var
  IniFile: TIniFile;
  TargetPipe: string;
  CmdLinePort: Integer;
  CmdLinePipe: string;
  HasPortArg, HasPipeArg: Boolean;
  PortSource, PipeSource: string;
begin
  // Parse command-line arguments first (highest priority)
  CmdLinePort := 0;
  CmdLinePipe := '';
  ParseCommandLine(CmdLinePort, CmdLinePipe, HasPortArg, HasPipeArg);

  // Load settings from ini file
  Settings := TMCPSettings.Create;

  // Load target pipe name from settings.ini
  IniFile := TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'settings.ini');
  try
    TargetPipe := IniFile.ReadString('Target', 'PipeName', '\\.\pipe\DelphiApp_MCP_Request');
  finally
    IniFile.Free;
  end;

  // Apply command-line overrides with priority
  if HasPortArg then
  begin
    Settings.Port := CmdLinePort;
    PortSource := 'command-line';
  end
  else
    PortSource := 'settings.ini';

  if HasPipeArg then
  begin
    SetTargetPipeName(CmdLinePipe);
    PipeSource := 'command-line';
  end
  else
  begin
    if Trim(TargetPipe) <> '' then
      SetTargetPipeName(TargetPipe);
    PipeSource := 'settings.ini';
  end;

  WriteLn('========================================');
  WriteLn(' DelphiMCP Server v2.1');
  WriteLn('========================================');
  WriteLn('Model Context Protocol Server for Delphi Applications');
  WriteLn('');

  TLogger.Info('Starting DelphiMCP Server...');
  TLogger.Info('Listening on port ' + Settings.Port.ToString);
  TLogger.Info('Target application pipe: ' + GetTargetPipeName);

  // Discover and register target application tools dynamically BEFORE creating ToolsManager
  TLogger.Info('Discovering target application tools...');
  var ApplicationToolCount := RegisterAllApplicationTools;

  // Create managers (ToolsManager will pick up the dynamically registered tools)
  ManagerRegistry := TMCPManagerRegistry.Create;
  CoreManager := TMCPCoreManager.Create(Settings);
  ToolsManager := TMCPToolsManager.Create;
  ResourcesManager := TMCPResourcesManager.Create;

  // Register managers
  ManagerRegistry.RegisterManager(CoreManager);
  ManagerRegistry.RegisterManager(ToolsManager);
  ManagerRegistry.RegisterManager(ResourcesManager);
  if ApplicationToolCount > 0 then
    TLogger.Info('Registered ' + ApplicationToolCount.ToString + ' target application tools')
  else
    TLogger.Warning('No target application tools registered (target application may not be running)');

  // Create and configure server
  Server := TMCPIdHTTPServer.Create(nil);
  try
    Server.Settings := Settings;
    Server.ManagerRegistry := ManagerRegistry;
    Server.CoreManager := CoreManager;

    // Start server
    Server.Start;
    
    WriteLn('Server started successfully!');
    WriteLn('');
    WriteLn('Configuration:');
    WriteLn('  HTTP Port: ', Settings.Port, ' (', PortSource, ')');
    WriteLn('  Target Pipe: ', GetTargetPipeName, ' (', PipeSource, ')');
    WriteLn('');
    WriteLn('Available tools:');
    WriteLn('  Basic Tools:');
    WriteLn('    - mcp_hello            : Get greeting and target application info');
    WriteLn('    - mcp_echo             : Echo back your message');
    WriteLn('    - mcp_time             : Get current system time');
    WriteLn('');
    WriteLn('  Debug Capture Tools:');
    WriteLn('    - start_debug_capture  : Start capturing OutputDebugString');
    WriteLn('    - stop_debug_capture   : Stop capture session');
    WriteLn('    - get_debug_messages   : Retrieve captured messages');
    WriteLn('    - get_process_summary  : Get process statistics');
    WriteLn('    - get_capture_status   : Get session information');
    WriteLn('    - pause_resume_capture : Pause/resume capture');
    WriteLn('');
    if ApplicationToolCount > 0 then
    begin
      WriteLn('  Target Application Tools: ' + ApplicationToolCount.ToString + ' tools discovered and registered');
      WriteLn('    (All target application tools are dynamically discovered from running instance)');
      WriteLn('    Use MCP tools/list endpoint or list-tools to see all available tools');
    end
    else
    begin
      WriteLn('  Target Application Tools: Not available at startup');
      WriteLn('    Limitation: Currently requires restarting bridge server after starting target app');
      WriteLn('    (Dynamic reconnection feature planned for future release)');
    end;
    WriteLn('');
    WriteLn('Press CTRL+C to stop...');
    WriteLn('========================================');
    
    // Wait for shutdown signal
    ShutdownEvent.WaitFor(INFINITE);
    
    // Graceful shutdown
    TLogger.Info('Shutting down server...');
    Server.Stop;
    TLogger.Info('Server stopped successfully');
  finally
    Server.Free;
    Settings.Free;
  end;
end;

begin
  // Configure logger
  TLogger.LogToConsole := True;
  TLogger.MinLogLevel := TLogLevel.Info;
  
  ReportMemoryLeaksOnShutdown := True;
  IsMultiThread := True;
  
  // Create shutdown event
  ShutdownEvent := TEvent.Create(nil, True, False, '');
  try
    // Set up signal handlers
    {$IFDEF MSWINDOWS}
    SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);
    {$ENDIF}
    
    try
      TServerStatusResource.Initialize;
      RunServer;
    except
      on E: Exception do
      begin
        WriteLn('ERROR: ' + E.Message);
        TLogger.Error(E);
      end;
    end;
    
    {$IFDEF MSWINDOWS}
    SetConsoleCtrlHandler(@ConsoleCtrlHandler, False);
    {$ENDIF}
  finally
    ShutdownEvent.Free;
  end;
end.