unit AutomationServerThread;

{
  Automation Server Thread - Named Pipe Server for Automation Framework

  ARCHITECTURE:
  - Named pipe server receiving JSON-RPC requests from MCP bridge
  - Handles tool execution requests synchronously
  - Returns JSON-RPC responses with results or errors

  COMMUNICATION:
  - Request Pipe: Configurable (default: \\.\pipe\DelphiApp_MCP_Request)
  - Protocol: JSON-RPC 2.0
  - Pattern: Request/Response (synchronous)

  THREAD SAFETY:
  - All VCL operations executed in main thread via TThread.Synchronize
  - Pipe I/O runs in background thread with overlapped operations

  BASED ON:
  - VSCode-Switcher TPipeServerThread pattern
  - MCP protocol specification
  - Extracted from CyberMAX MCP implementation
}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.JSON, System.DateUtils, System.StrUtils;

type
  TAutomationServerThread = class(TThread)
  private
    FPipeName: string;
    FTerminating: Boolean;
    FPipeHandle: THandle;
    FEventHandle: THandle;

    procedure HandleAutomationRequest(const JSONData: string; out Response: string);
    procedure ExecuteTool(const ToolName: string; const Params: TJSONObject; out Result: TJSONObject);

  protected
    procedure Execute; override;

  public
    constructor Create(const PipeName: string);
    destructor Destroy; override;
    procedure SafeTerminate;
  end;

implementation

uses
  AutomationLogger,       // Logging abstraction
  AutomationToolRegistry; // Tool registry for dynamic dispatch

const
  AUTOMATION_VERSION = '1.0.0';  // Generic framework version

{ Rate Limiting }

var
  G_Rps: Integer = 50;                // Requests per second limit
  G_WindowStart: UInt64 = 0;          // Start of current window
  G_Count: Integer = 0;               // Requests in current window
  G_RateLimitCS: TRTLCriticalSection; // Thread-safe access

function CheckRateLimit: Boolean;
var
  now: UInt64;
begin
  EnterCriticalSection(G_RateLimitCS);
  try
    now := GetTickCount64;

    // Reset window if 1 second elapsed
    if now - G_WindowStart >= 1000 then
    begin
      G_WindowStart := now;
      G_Count := 0;
    end;

    Inc(G_Count);
    Result := (G_Count <= G_Rps);
  finally
    LeaveCriticalSection(G_RateLimitCS);
  end;
end;

{ TAutomationServerThread }

constructor TAutomationServerThread.Create(const PipeName: string);
begin
  FPipeName := PipeName;
  FTerminating := False;
  FPipeHandle := INVALID_HANDLE_VALUE;
  FEventHandle := 0;
  inherited Create(True); // Create suspended
  FreeOnTerminate := False;
  LogInfo('Automation Server Thread created for pipe: ' + PipeName);
end;

destructor TAutomationServerThread.Destroy;
begin
  LogInfo('Destroying automation server thread');
  FTerminating := True;

  // Close handles if still open
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    CancelIo(FPipeHandle);
    CloseHandle(FPipeHandle);
    FPipeHandle := INVALID_HANDLE_VALUE;
  end;

  if FEventHandle <> 0 then
  begin
    SetEvent(FEventHandle); // Signal event to wake up any waits
    CloseHandle(FEventHandle);
    FEventHandle := 0;
  end;

  inherited;
end;

procedure TAutomationServerThread.SafeTerminate;
begin
  LogInfo('SafeTerminate called');
  FTerminating := True;

  // Cancel any pending I/O operations
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    CancelIo(FPipeHandle);
    DisconnectNamedPipe(FPipeHandle);
  end;

  // Signal event to wake up any waits
  if FEventHandle <> 0 then
    SetEvent(FEventHandle);

  Terminate;
end;

procedure TAutomationServerThread.Execute;
const
  BUFFER_SIZE = 1048576; // 1MB buffer for large messages (screenshots)
var
  Buffer: PAnsiChar;
  BytesRead: DWORD;
  BytesWritten: DWORD;
  RequestMessage: string;
  ResponseMessage: string;
  Connected: Boolean;
  ErrorCode: DWORD;
  Overlapped: TOverlapped;
  WaitResult: DWORD;
  ResponseAnsi: AnsiString;
begin
  LogInfo('Automation Server Thread started');
  FPipeHandle := INVALID_HANDLE_VALUE;
  FEventHandle := CreateEvent(nil, True, False, nil);

  // Allocate buffer on heap (1MB is too large for stack)
  GetMem(Buffer, BUFFER_SIZE);

  try
    try
      // OUTER LOOP: Create pipe once, handle multiple connections
      while not Terminated and not FTerminating do
      begin
        LogDebug('Creating named pipe: ' + FPipeName);

        // Create duplex pipe for request/response
        FPipeHandle := CreateNamedPipe(
          PChar(FPipeName),
          PIPE_ACCESS_DUPLEX or FILE_FLAG_OVERLAPPED, // Bidirectional with overlapped I/O
          PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
          PIPE_UNLIMITED_INSTANCES,
          1048576, // Output buffer size (1MB for screenshots)
          1048576, // Input buffer size (1MB for large requests)
          100,     // Timeout in milliseconds
          nil
        );

        if FPipeHandle <> INVALID_HANDLE_VALUE then
        begin
          LogInfo('Pipe created successfully');

          // INNER LOOP: Reuse same pipe handle for multiple client connections
          // This eliminates the 50ms gap that caused "Cannot connect" errors
          while not Terminated and not FTerminating do
          begin
            try
              // Set up overlapped structure for cancellable wait
              FillChar(Overlapped, SizeOf(Overlapped), 0);
              Overlapped.hEvent := FEventHandle;
              ResetEvent(FEventHandle); // Reset event for new connection

              LogDebug('Waiting for client connection...');

              // Wait for automation client to connect
              Connected := ConnectNamedPipe(FPipeHandle, @Overlapped);
              ErrorCode := GetLastError;

              if not Connected and (ErrorCode = ERROR_IO_PENDING) then
              begin
                // Wait for connection or termination signal
                while not (Terminated or FTerminating) do
                begin
                  WaitResult := WaitForSingleObject(FEventHandle, 100);
                  if WaitResult = WAIT_OBJECT_0 then
                  begin
                    Connected := True;
                    Break;
                  end;
                end;
              end
              else if ErrorCode = ERROR_PIPE_CONNECTED then
              begin
                Connected := True;
              end;

              if Connected and not (Terminated or FTerminating) then
              begin
                LogInfo('Automation client connected to pipe');

                // Read the automation request
                FillChar(Buffer^, BUFFER_SIZE, 0);
                if ReadFile(FPipeHandle, Buffer^, BUFFER_SIZE - 1, BytesRead, nil) then
                begin
                  SetString(RequestMessage, Buffer, BytesRead);
                  LogDebug('Received ' + IntToStr(BytesRead) + ' bytes');
                  LogDebug('Request: ' + RequestMessage);

                  // Handle in main thread (CRITICAL for VCL/UI operations)
                  ResponseMessage := '';
                  Synchronize(
                    procedure
                    begin
                      HandleAutomationRequest(RequestMessage, ResponseMessage);
                    end
                  );

                  // Send response back through same pipe
                  if ResponseMessage <> '' then
                  begin
                    LogDebug('Response: ' + ResponseMessage);
                    ResponseAnsi := AnsiString(ResponseMessage);
                    if WriteFile(FPipeHandle, ResponseAnsi[1], Length(ResponseAnsi), BytesWritten, nil) then
                    begin
                      LogDebug('Sent ' + IntToStr(BytesWritten) + ' bytes back to client');
                      FlushFileBuffers(FPipeHandle);
                    end
                    else
                    begin
                      ErrorCode := GetLastError;
                      LogError('WriteFile failed: ' + SysErrorMessage(ErrorCode));
                    end;
                  end
                  else
                    LogWarning('Empty response generated');
                end
                else
                begin
                  ErrorCode := GetLastError;
                  LogError('ReadFile failed: ' + SysErrorMessage(ErrorCode));
                  // Break inner loop on read error - pipe may be broken
                  Break;
                end;

                // Disconnect THIS client (but keep pipe alive for next connection)
                DisconnectNamedPipe(FPipeHandle);
                LogDebug('Client disconnected, pipe ready for next connection');

                // Loop back to ConnectNamedPipe() immediately - NO SLEEP, NO GAP
              end
              else if not (Terminated or FTerminating) then
              begin
                // Connection failed
                LogError('ConnectNamedPipe failed - breaking inner loop');
                Break; // Exit inner loop to recreate pipe
              end;

            except
              on E: Exception do
              begin
                LogError('Exception in connection handler: ' + E.Message);
                Break; // Exit inner loop to recreate pipe
              end;
            end;
          end; // End INNER LOOP

          // Close pipe only when exiting inner loop (error or termination)
          LogDebug('Closing pipe handle');
          CloseHandle(FPipeHandle);
          FPipeHandle := INVALID_HANDLE_VALUE;
        end
        else
        begin
          ErrorCode := GetLastError;
          LogError('CreateNamedPipe failed: ' + SysErrorMessage(ErrorCode));
          // Wait before retrying
          if not (Terminated or FTerminating) then
            Sleep(100);
        end;

        // Small delay before recreating pipe (only after error or termination)
        if not Terminated and not FTerminating then
        begin
          Sleep(50);
        end;
      end; // End OUTER LOOP
    except
      on E: Exception do
        LogError('Exception in automation server thread: ' + E.Message);
    end;
  finally
    // Free heap-allocated buffer
    FreeMem(Buffer);

    if FEventHandle <> 0 then
    begin
      CloseHandle(FEventHandle);
      FEventHandle := 0;
    end;
  end;

  LogInfo('Automation Server Thread ending normally');
end;

procedure TAutomationServerThread.HandleAutomationRequest(const JSONData: string; out Response: string);
var
  RequestJSON: TJSONValue;
  RequestObj: TJSONObject;
  ResponseObj: TJSONObject;
  ResultObj: TJSONObject;
  ToolName: string;
  ParamsObj: TJSONObject;
  RequestID: TJSONValue;
begin
  Response := '';
  RequestJSON := nil;
  ResponseObj := nil;
  ResultObj := nil;

  try
    // Check rate limit
    if not CheckRateLimit then
    begin
      LogError('Rate limit exceeded');

      // Parse request to get ID for error response
      RequestJSON := TJSONObject.ParseJSONValue(JSONData);
      if (RequestJSON is TJSONObject) then
      begin
        RequestObj := TJSONObject(RequestJSON);
        RequestID := RequestObj.GetValue('id');

        ResponseObj := TJSONObject.Create;
        ResponseObj.AddPair('jsonrpc', '2.0');
        if RequestID <> nil then
          ResponseObj.AddPair('id', RequestID.Clone as TJSONValue)
        else
          ResponseObj.AddPair('id', TJSONNull.Create);

        ResponseObj.AddPair('error', TJSONObject.Create
          .AddPair('code', TJSONNumber.Create(-32000))
          .AddPair('message', Format('Rate limit exceeded (%d rps)', [G_Rps])));
        Response := ResponseObj.ToString;
      end;
      Exit;
    end;

    // Parse JSON-RPC request
    RequestJSON := TJSONObject.ParseJSONValue(JSONData);
    if not (RequestJSON is TJSONObject) then
    begin
      LogError('Invalid JSON request');
      Exit;
    end;

    RequestObj := TJSONObject(RequestJSON);

    // Extract request ID (required for JSON-RPC)
    RequestID := RequestObj.GetValue('id');
    if RequestID = nil then
    begin
      LogError('Missing request ID');
      Exit;
    end;

    // Extract method (tool name)
    if not RequestObj.TryGetValue<string>('method', ToolName) then
    begin
      LogError('Missing method name');

      // Return error response
      ResponseObj := TJSONObject.Create;
      ResponseObj.AddPair('jsonrpc', '2.0');
      ResponseObj.AddPair('id', RequestID.Clone as TJSONValue);
      ResponseObj.AddPair('error', TJSONObject.Create
        .AddPair('code', TJSONNumber.Create(-32600))
        .AddPair('message', 'Invalid Request - missing method'));
      Response := ResponseObj.ToString;
      Exit;
    end;

    LogInfo('Executing tool: ' + ToolName);

    // Extract params (optional)
    ParamsObj := RequestObj.GetValue('params') as TJSONObject;

    // Execute the tool
    try
      ExecuteTool(ToolName, ParamsObj, ResultObj);

      // Build success response
      ResponseObj := TJSONObject.Create;
      ResponseObj.AddPair('jsonrpc', '2.0');
      ResponseObj.AddPair('id', RequestID.Clone as TJSONValue);
      if ResultObj <> nil then
        ResponseObj.AddPair('result', ResultObj)
      else
        ResponseObj.AddPair('result', TJSONObject.Create); // Empty result

      Response := ResponseObj.ToString;

    except
      on E: Exception do
      begin
        LogError('Error executing tool: ' + E.Message);

        // Build error response
        ResponseObj := TJSONObject.Create;
        ResponseObj.AddPair('jsonrpc', '2.0');
        ResponseObj.AddPair('id', RequestID.Clone as TJSONValue);
        ResponseObj.AddPair('error', TJSONObject.Create
          .AddPair('code', TJSONNumber.Create(-32603))
          .AddPair('message', 'Internal error: ' + E.Message));
        Response := ResponseObj.ToString;
      end;
    end;

  finally
    if RequestJSON <> nil then
      RequestJSON.Free;
    if ResponseObj <> nil then
      ResponseObj.Free;
    // ResultObj is owned by ResponseObj, don't free separately
  end;
end;

procedure TAutomationServerThread.ExecuteTool(const ToolName: string;
  const Params: TJSONObject; out Result: TJSONObject);
begin
  Result := nil;

  // Delegate to registry (handles aliases, lookup, and execution)
  AutomationTools.ExecuteTool(ToolName, Params, Result);
end;

initialization
  InitializeCriticalSection(G_RateLimitCS);

finalization
  DeleteCriticalSection(G_RateLimitCS);

end.
