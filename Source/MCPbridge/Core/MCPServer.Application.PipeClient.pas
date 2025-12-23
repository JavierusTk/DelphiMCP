/// Named Pipe Client Adapter for Indy/System.JSON
// - Wraps shared MCP.PipeClient with System.JSON types
// - Converts between TJSONObject and string JSON
unit MCPServer.Application.PipeClient;

interface

uses
  System.SysUtils,
  System.JSON,
  Winapi.Windows,
  MCP.PipeClient;

type
  /// Result of a pipe client operation (System.JSON types)
  TApplicationPipeResult = record
    Success: Boolean;
    ErrorMessage: string;
    JSONResponse: TJSONValue;
    constructor Create(ASuccess: Boolean; const AErrorMessage: string; AJSONResponse: TJSONValue);
  end;

/// Execute a tool on target application via named pipe
// - ToolName: Name of the target application tool to execute
// - Params: Parameters as JSON object (can be nil)
// - Returns: Pipe result with success status and response
function ExecuteApplicationTool(const ToolName: string; Params: TJSONObject): TApplicationPipeResult;

/// Check if target application is running and accessible via pipe
function IsApplicationRunning: Boolean;

/// Get the named pipe name used to connect to target application
function GetTargetPipeName: string;

/// Set the named pipe name to use for connecting to target application
procedure SetTargetPipeName(const PipeName: string);

const
  DEFAULT_MCP_PIPE_NAME = '\\.\pipe\DelphiApp_MCP_Request';
  PIPE_TIMEOUT_MS = 5000;

implementation

{ TApplicationPipeResult }

constructor TApplicationPipeResult.Create(ASuccess: Boolean;
  const AErrorMessage: string; AJSONResponse: TJSONValue);
begin
  Success := ASuccess;
  ErrorMessage := AErrorMessage;
  JSONResponse := AJSONResponse;
end;

procedure IndyLogCallback(const Message: string);
begin
  OutputDebugString(PChar('[PIPE] ' + Message));
end;

function ExecuteApplicationTool(const ToolName: string; Params: TJSONObject): TApplicationPipeResult;
var
  ParamsJson: string;
  RawResult: TPipeResultRaw;
  JSONResponse: TJSONValue;
  ErrorValue, ResultValue: TJSONValue;
begin
  Result := TApplicationPipeResult.Create(False, 'Unknown error', nil);

  // Convert Params to JSON string
  if Assigned(Params) then
    ParamsJson := Params.ToJSON
  else
    ParamsJson := '{}';

  // Execute via shared pipe client
  RawResult := ExecutePipeTool(ToolName, ParamsJson);

  if not RawResult.Success then
  begin
    Result.ErrorMessage := RawResult.ErrorMessage;
    Exit;
  end;

  // Parse JSON response
  JSONResponse := TJSONObject.ParseJSONValue(RawResult.ResponseJson);
  if not Assigned(JSONResponse) then
  begin
    Result.ErrorMessage := 'Invalid JSON response from target application';
    Exit;
  end;

  try
    if not (JSONResponse is TJSONObject) then
    begin
      Result.ErrorMessage := 'Response is not a JSON object';
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
      Exit;
    end;

    // Get result value
    ResultValue := TJSONObject(JSONResponse).GetValue('result');
    if not Assigned(ResultValue) then
    begin
      Result.ErrorMessage := 'No result in response from target application';
      Exit;
    end;

    // Success - clone the result
    Result.Success := True;
    Result.ErrorMessage := '';
    Result.JSONResponse := ResultValue.Clone as TJSONValue;

  finally
    JSONResponse.Free;
  end;
end;

function IsApplicationRunning: Boolean;
begin
  Result := IsPipeAvailable;
end;

function GetTargetPipeName: string;
begin
  Result := GetPipeName;
end;

procedure SetTargetPipeName(const PipeName: string);
begin
  SetPipeLogProc(IndyLogCallback);
  SetPipeName(PipeName);
end;

initialization
  SetPipeLogProc(IndyLogCallback);

end.
