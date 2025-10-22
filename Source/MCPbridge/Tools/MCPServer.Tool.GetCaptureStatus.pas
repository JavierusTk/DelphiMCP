unit MCPServer.Tool.GetCaptureStatus;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  TGetCaptureStatusParams = class
  private
    FSessionId: string;
  public
    [SchemaDescription('The session ID returned from start_debug_capture')]
    property SessionId: string read FSessionId write FSessionId;
  end;

  TGetCaptureStatusTool = class(TMCPToolBase<TGetCaptureStatusParams>)
  protected
    function ExecuteWithParams(const Params: TGetCaptureStatusParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types,
  System.DateUtils,
  System.Generics.Collections;

{ TGetCaptureStatusTool }

constructor TGetCaptureStatusTool.Create;
begin
  inherited;
  FName := 'get_capture_status';
  FDescription := 'Get current capture session information and statistics';
end;

function TGetCaptureStatusTool.ExecuteWithParams(const Params: TGetCaptureStatusParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  JSONResult: TJSONObject;
  JSONArray: TJSONArray;
  StatusStr: string;
  ElapsedTime: Double;
  CaptureRate: Double;
  BufferUsage: Double;
  ProcessName: string;
  ProcessNames: TList<string>;
begin
  JSONResult := TJSONObject.Create;
  try
    try
      if not Assigned(Params) or (Params.SessionId = '') then
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', 'Session ID is required');
        Result := JSONResult.ToJSON;
        Exit;
      end;

      Capture := TOutputDebugStringCapture.Instance;
      Session := Capture.GetSession(Params.SessionId);

      if not Assigned(Session) then
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', 'Invalid session ID');
        Result := JSONResult.ToJSON;
        Exit;
      end;

      case Session.Status of
        csIdle: StatusStr := 'idle';
        csCapturing: StatusStr := 'capturing';
        csPaused: StatusStr := 'paused';
        csError: StatusStr := 'error';
      else
        StatusStr := 'unknown';
      end;

      ElapsedTime := SecondsBetween(Now, Session.StartTime);
      if ElapsedTime > 0 then
        CaptureRate := Session.MessagesCaptured / ElapsedTime
      else
        CaptureRate := 0;

      if Session.BufferSize > 0 then
        BufferUsage := (Session.MessagesCaptured / Session.BufferSize) * 100
      else
        BufferUsage := 0;

      if BufferUsage > 100 then
        BufferUsage := 100;

      ProcessNames := TList<string>.Create;
      try
        for ProcessName in Session.ProcessNameCache.Values do
          if not ProcessNames.Contains(ProcessName) then
            ProcessNames.Add(ProcessName);

        JSONArray := TJSONArray.Create;
        for ProcessName in ProcessNames do
          JSONArray.AddElement(TJSONString.Create(ProcessName));

        JSONResult.AddPair('success', TJSONBool.Create(True));
        JSONResult.AddPair('session_id', Params.SessionId);
        JSONResult.AddPair('status', StatusStr);
        JSONResult.AddPair('start_time', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Session.StartTime));
        JSONResult.AddPair('messages_captured', TJSONNumber.Create(Session.MessagesCaptured));
        JSONResult.AddPair('buffer_size', TJSONNumber.Create(Session.BufferSize));
        JSONResult.AddPair('buffer_usage_percent', TJSONNumber.Create(BufferUsage));
        JSONResult.AddPair('capture_rate_per_second', TJSONNumber.Create(CaptureRate));
        JSONResult.AddPair('elapsed_seconds', TJSONNumber.Create(ElapsedTime));
        JSONResult.AddPair('active_processes', JSONArray);
        JSONResult.AddPair('auto_resolve_process_names', TJSONBool.Create(Session.AutoResolveProcessNames));
        JSONResult.AddPair('filter_current_process', TJSONBool.Create(Session.FilterCurrentProcess));
      finally
        ProcessNames.Free;
      end;

      Result := JSONResult.ToJSON;
    except
      on E: Exception do
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', E.Message);
        Result := JSONResult.ToJSON;
      end;
    end;
  finally
    JSONResult.Free;
  end;
end;

initialization
  TMCPRegistry.RegisterTool('get_capture_status',
    function: IMCPTool
    begin
      Result := TGetCaptureStatusTool.Create;
    end
  );

end.
