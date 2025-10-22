unit MCPServer.Application.PipeClient;

{
  Shared named pipe client for communicating with target application MCP Server.

  This module provides reusable functions for all target application MCP tools to
  communicate with the running target application process via named pipes.
}

interface

uses
  System.SysUtils,
  System.JSON,
  System.Math,
  Winapi.Windows;

type
  /// <summary>
  /// Result of a pipe client operation
  /// </summary>
  TApplicationPipeResult = record
    Success: Boolean;
    ErrorMessage: string;
    JSONResponse: TJSONValue;
    constructor Create(ASuccess: Boolean; const AErrorMessage: string; AJSONResponse: TJSONValue);
  end;

/// <summary>
/// Execute a tool on target application via named pipe
/// </summary>
/// <param name="ToolName">Name of the target application tool to execute</param>
/// <param name="Params">Parameters as JSON object (can be nil)</param>
/// <returns>Pipe result with success status and response</returns>
function ExecuteApplicationTool(const ToolName: string; Params: TJSONObject): TApplicationPipeResult;

/// <summary>
/// Check if target application is running and accessible via pipe
/// </summary>
function IsApplicationRunning: Boolean;

/// <summary>
/// Get the named pipe name used to connect to target application
/// </summary>
function GetTargetPipeName: string;

/// <summary>
/// Set the named pipe name to use for connecting to target application
/// Call this before RegisterAllApplicationTools to override default
/// </summary>
procedure SetTargetPipeName(const PipeName: string);

/// <summary>
/// Normalize pipe name from various input formats to full pipe path
/// Supports shortcuts: "MyApp" -> "\\.\pipe\MyApp_MCP_Request"
/// </summary>
/// <param name="Input">Pipe name in any supported format</param>
/// <returns>Full pipe path (\\.\pipe\...)</returns>
function NormalizePipeName(const Input: string): string;

const
  DEFAULT_MCP_PIPE_NAME = '\\.\pipe\DelphiApp_MCP_Request';
  // This is the default pipe name used by AutomationFramework
  // Can be overridden via SetTargetPipeName() or loaded from settings.ini
  PIPE_TIMEOUT_MS = 5000;

implementation

var
  RequestIDCounter: Integer = 1;
  ConfiguredPipeName: string = '';

{ TApplicationPipeResult }

constructor TApplicationPipeResult.Create(ASuccess: Boolean;
  const AErrorMessage: string; AJSONResponse: TJSONValue);
begin
  Success := ASuccess;
  ErrorMessage := AErrorMessage;
  JSONResponse := AJSONResponse;
end;

function ConnectToPipe: THandle;
const
  MAX_RETRIES = 10;          // Increased from implicit infinite to explicit 10
  INITIAL_RETRY_DELAY_MS = 2; // Start with 2ms delays
  MAX_RETRY_DELAY_MS = 50;   // Cap at 50ms
var
  Attempt: Integer;
  ErrorCode: DWORD;
  StartTime: DWORD;
  RetryDelay: Integer;
begin
  StartTime := GetTickCount;
  RetryDelay := INITIAL_RETRY_DELAY_MS;

  // Aggressive retry with exponential backoff
  for Attempt := 1 to MAX_RETRIES do
  begin
    Result := CreateFile(
      PChar(GetTargetPipeName),
      GENERIC_READ or GENERIC_WRITE,
      0,
      nil,
      OPEN_EXISTING,
      0,
      0
    );

    if Result <> INVALID_HANDLE_VALUE then
      Exit; // Connected successfully!

    ErrorCode := GetLastError;

    // Check timeout
    if GetTickCount - StartTime > PIPE_TIMEOUT_MS then
      Exit; // Overall timeout reached

    // Handle different error cases
    case ErrorCode of
      ERROR_PIPE_BUSY,
      ERROR_FILE_NOT_FOUND,      // Pipe being recreated
      ERROR_PIPE_NOT_CONNECTED:  // Pipe between disconnect/reconnect
      begin
        // These errors indicate timing issues - retry with backoff
        if Attempt < MAX_RETRIES then
        begin
          // First try WaitNamedPipe (fast if pipe exists)
          if not WaitNamedPipe(PChar(GetTargetPipeName), RetryDelay) then
          begin
            // If WaitNamedPipe fails, use Sleep for exponential backoff
            Sleep(RetryDelay);
          end;

          // Exponential backoff: 2ms → 4ms → 8ms → 16ms → 32ms → 50ms (cap)
          RetryDelay := Min(RetryDelay * 2, MAX_RETRY_DELAY_MS);
        end;
      end;

    else
      // Other errors (access denied, invalid name, etc.) - don't retry
      Exit;
    end;
  end;

  // All retries exhausted
  Result := INVALID_HANDLE_VALUE;
end;

function ExecuteApplicationTool(const ToolName: string; Params: TJSONObject): TApplicationPipeResult;
var
  PipeHandle: THandle;
  Request: AnsiString;
  Response: AnsiString;
  Buffer: array[0..65535] of AnsiChar;
  BytesWritten: DWORD;
  BytesRead: DWORD;
  JSONRequest: TJSONObject;
  JSONResponse: TJSONValue;
  ResultValue: TJSONValue;
  ErrorValue: TJSONValue;
begin
  // Default failure result
  Result := TApplicationPipeResult.Create(False, 'Unknown error', nil);

  // Connect to pipe
  PipeHandle := ConnectToPipe;
  if PipeHandle = INVALID_HANDLE_VALUE then
  begin
    Result.ErrorMessage := 'Cannot connect to target application. Make sure target application is running with MCP server enabled.';
    Exit;
  end;

  try
    // Build JSON-RPC request
    JSONRequest := TJSONObject.Create;
    try
      JSONRequest.AddPair('jsonrpc', '2.0');
      JSONRequest.AddPair('id', TJSONNumber.Create(AtomicIncrement(RequestIDCounter)));
      JSONRequest.AddPair('method', ToolName);

      if Assigned(Params) then
        JSONRequest.AddPair('params', TJSONObject(Params.Clone))
      else
        JSONRequest.AddPair('params', TJSONObject.Create);

      Request := AnsiString(JSONRequest.ToString);
    finally
      JSONRequest.Free;
    end;

    // Send request
    if not WriteFile(PipeHandle, Request[1], Length(Request), BytesWritten, nil) then
    begin
      Result.ErrorMessage := 'Failed to send request to target application (Error: ' + IntToStr(GetLastError) + ')';
      Exit;
    end;

    FlushFileBuffers(PipeHandle);

    // Read response
    FillChar(Buffer, SizeOf(Buffer), 0);
    if not ReadFile(PipeHandle, Buffer, SizeOf(Buffer) - 1, BytesRead, nil) then
    begin
      Result.ErrorMessage := 'Failed to read response from target application (Error: ' + IntToStr(GetLastError) + ')';
      Exit;
    end;

    SetString(Response, PAnsiChar(@Buffer[0]), BytesRead);

    // Parse response
    JSONResponse := nil;
    try
      JSONResponse := TJSONObject.ParseJSONValue(string(Response));
      if not Assigned(JSONResponse) then
      begin
        Result.ErrorMessage := 'Invalid JSON response from target application';
        Exit;
      end;

      if not (JSONResponse is TJSONObject) then
      begin
        Result.ErrorMessage := 'Response is not a JSON object';
        JSONResponse.Free;
        Exit;
      end;

      // Check for error in response
      ErrorValue := TJSONObject(JSONResponse).GetValue('error');
      if Assigned(ErrorValue) then
      begin
        if ErrorValue is TJSONObject then
          Result.ErrorMessage := TJSONObject(ErrorValue).GetValue<string>('message', 'Unknown error from target application')
        else
          Result.ErrorMessage := 'Error from target application: ' + ErrorValue.ToString;
        JSONResponse.Free;
        Exit;
      end;

      // Get result value
      ResultValue := TJSONObject(JSONResponse).GetValue('result');
      if not Assigned(ResultValue) then
      begin
        Result.ErrorMessage := 'No result in response from target application';
        JSONResponse.Free;
        Exit;
      end;

      // Success - return the result
      Result.Success := True;
      Result.ErrorMessage := '';
      Result.JSONResponse := ResultValue.Clone as TJSONValue;

    finally
      if Assigned(JSONResponse) then
        JSONResponse.Free;
    end;

  finally
    CloseHandle(PipeHandle);
  end;
end;

function IsApplicationRunning: Boolean;
var
  PipeHandle: THandle;
begin
  PipeHandle := CreateFile(
    PChar(GetTargetPipeName),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    0,
    0
  );

  Result := PipeHandle <> INVALID_HANDLE_VALUE;

  if Result then
    CloseHandle(PipeHandle);
end;

function GetTargetPipeName: string;
begin
  if ConfiguredPipeName <> '' then
    Result := ConfiguredPipeName
  else
    Result := DEFAULT_MCP_PIPE_NAME;
end;

function NormalizePipeName(const Input: string): string;
var
  LowerInput: string;
  HasUnderscore: Boolean;
  HasMCP: Boolean;
  HasRequest: Boolean;
begin
  // Empty input -> use default
  if Trim(Input) = '' then
  begin
    Result := DEFAULT_MCP_PIPE_NAME;
    Exit;
  end;

  // Already a full pipe path -> use as-is
  if Input.StartsWith('\\.\pipe\', True) then
  begin
    Result := Input;
    Exit;
  end;

  LowerInput := LowerCase(Input);

  // Check for markers that indicate this is already a complete pipe name (not a shortcut)
  HasUnderscore := Pos('_', Input) > 0;
  HasMCP := (Pos('mcp', LowerInput) > 0);
  HasRequest := LowerInput.EndsWith('request');

  // If it has any marker, just add the \\.\pipe\ prefix
  if HasUnderscore or HasMCP or HasRequest then
  begin
    Result := '\\.\pipe\' + Input;
    Exit;
  end;

  // Simple name (like "MyApp" or "CyberMAX") -> expand with convention
  Result := '\\.\pipe\' + Input + '_MCP_Request';
end;

procedure SetTargetPipeName(const PipeName: string);
begin
  ConfiguredPipeName := NormalizePipeName(PipeName);
  OutputDebugString(PChar('[PIPE] Target pipe name set to: ' + ConfiguredPipeName));
end;

end.
