unit MCPServer.Tool.GetProcessSummary;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  TGetProcessSummaryParams = class
  private
    FSessionId: string;
    FTimeWindowMinutes: Integer;
  public
    constructor Create;

    [SchemaDescription('The session ID returned from start_debug_capture')]
    property SessionId: string read FSessionId write FSessionId;

    [Optional]
    [SchemaDescription('Time window in minutes (0 for all time, default: 0)')]
    property TimeWindowMinutes: Integer read FTimeWindowMinutes write FTimeWindowMinutes;
  end;

  TGetProcessSummaryTool = class(TMCPToolBase<TGetProcessSummaryParams>)
  protected
    function ExecuteWithParams(const Params: TGetProcessSummaryParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types,
  System.DateUtils;

{ TGetProcessSummaryParams }

constructor TGetProcessSummaryParams.Create;
begin
  inherited;
  FTimeWindowMinutes := 0;
end;

{ TGetProcessSummaryTool }

constructor TGetProcessSummaryTool.Create;
begin
  inherited;
  FName := 'get_process_summary';
  FDescription := 'Get statistics about processes generating debug output';
end;

function TGetProcessSummaryTool.ExecuteWithParams(const Params: TGetProcessSummaryParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  ProcessStats: TArray<TProcessStats>;
  Stats: TProcessStats;
  JSONResult, JSONProc: TJSONObject;
  JSONArray: TJSONArray;
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

      ProcessStats := Capture.GetProcessSummary(Params.SessionId, Params.TimeWindowMinutes);

      JSONArray := TJSONArray.Create;
      for Stats in ProcessStats do
      begin
        JSONProc := TJSONObject.Create;
        JSONProc.AddPair('process_id', TJSONNumber.Create(Stats.ProcessId));
        JSONProc.AddPair('process_name', Stats.ProcessName);
        JSONProc.AddPair('message_count', TJSONNumber.Create(Stats.MessageCount));
        JSONProc.AddPair('first_seen', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Stats.FirstSeen));
        JSONProc.AddPair('last_seen', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Stats.LastSeen));
        JSONProc.AddPair('avg_messages_per_minute', TJSONNumber.Create(Stats.AvgMessagesPerMinute));
        JSONArray.AddElement(JSONProc);
      end;

      JSONResult.AddPair('success', TJSONBool.Create(True));
      JSONResult.AddPair('session_id', Params.SessionId);
      JSONResult.AddPair('processes', JSONArray);
      JSONResult.AddPair('process_count', TJSONNumber.Create(Length(ProcessStats)));
      if Params.TimeWindowMinutes > 0 then
        JSONResult.AddPair('time_window_minutes', TJSONNumber.Create(Params.TimeWindowMinutes));

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
  TMCPRegistry.RegisterTool('get_process_summary',
    function: IMCPTool
    begin
      Result := TGetProcessSummaryTool.Create;
    end
  );

end.
