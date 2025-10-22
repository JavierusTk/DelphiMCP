unit MCPServer.Tool.GetDebugMessages;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  TGetDebugMessagesParams = class
  private
    FSessionId: string;
    FLimit: Integer;
    FOffset: Integer;
    FSinceTimestamp: string;
    FProcessId: Integer;
    FProcessName: string;
    FMessageContains: string;
    FMessageRegex: string;
  public
    constructor Create;

    [SchemaDescription('The session ID returned from start_debug_capture')]
    property SessionId: string read FSessionId write FSessionId;

    [Optional]
    [SchemaDescription('Maximum messages to return (default: 100)')]
    property Limit: Integer read FLimit write FLimit;

    [Optional]
    [SchemaDescription('Pagination offset (default: 0)')]
    property Offset: Integer read FOffset write FOffset;

    [Optional]
    [SchemaDescription('Filter messages since this timestamp (ISO 8601 format)')]
    property SinceTimestamp: string read FSinceTimestamp write FSinceTimestamp;

    [Optional]
    [SchemaDescription('Filter by process ID')]
    property ProcessId: Integer read FProcessId write FProcessId;

    [Optional]
    [SchemaDescription('Filter by process name')]
    property ProcessName: string read FProcessName write FProcessName;

    [Optional]
    [SchemaDescription('Filter messages containing this text')]
    property MessageContains: string read FMessageContains write FMessageContains;

    [Optional]
    [SchemaDescription('Filter messages matching this regex pattern')]
    property MessageRegex: string read FMessageRegex write FMessageRegex;
  end;

  TGetDebugMessagesTool = class(TMCPToolBase<TGetDebugMessagesParams>)
  protected
    function ExecuteWithParams(const Params: TGetDebugMessagesParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types,
  System.DateUtils;

{ TGetDebugMessagesParams }

constructor TGetDebugMessagesParams.Create;
begin
  inherited;
  FLimit := 100;
  FOffset := 0;
  FProcessId := 0;
end;

{ TGetDebugMessagesTool }

constructor TGetDebugMessagesTool.Create;
begin
  inherited;
  FName := 'get_debug_messages';
  FDescription := 'Retrieve captured debug messages with filtering options';
end;

function TGetDebugMessagesTool.ExecuteWithParams(const Params: TGetDebugMessagesParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  Filter: TMessageFilter;
  Messages: TArray<TDebugMessage>;
  JSONResult, JSONMsg: TJSONObject;
  JSONArray: TJSONArray;
  Msg: TDebugMessage;
  SinceTime: TDateTime;
  TotalCount: Integer;
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

      FillChar(Filter, SizeOf(Filter), 0);
      Filter.Limit := Params.Limit;
      if Filter.Limit <= 0 then
        Filter.Limit := 100
      else if Filter.Limit > 10000 then
        Filter.Limit := 10000;

      Filter.Offset := Params.Offset;
      Filter.ProcessId := Params.ProcessId;
      Filter.ProcessName := Params.ProcessName;
      Filter.MessageContains := Params.MessageContains;
      Filter.MessageRegex := Params.MessageRegex;

      if Params.SinceTimestamp <> '' then
      begin
        try
          SinceTime := ISO8601ToDate(Params.SinceTimestamp);
          Filter.SinceTimestamp := SinceTime;
        except
          Filter.SinceTimestamp := 0;
        end;
      end
      else
        Filter.SinceTimestamp := 0;

      Messages := Capture.GetMessages(Params.SessionId, Filter);

      JSONArray := TJSONArray.Create;
      for Msg in Messages do
      begin
        JSONMsg := TJSONObject.Create;
        JSONMsg.AddPair('process_id', TJSONNumber.Create(Msg.ProcessId));
        JSONMsg.AddPair('process_name', Msg.ProcessName);
        JSONMsg.AddPair('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Msg.Timestamp));
        JSONMsg.AddPair('message', Msg.Message);
        if Msg.ThreadId > 0 then
          JSONMsg.AddPair('thread_id', TJSONNumber.Create(Msg.ThreadId));
        JSONArray.AddElement(JSONMsg);
      end;

      TotalCount := Session.MessagesCaptured;

      JSONResult.AddPair('success', TJSONBool.Create(True));
      JSONResult.AddPair('session_id', Params.SessionId);
      JSONResult.AddPair('messages', JSONArray);
      JSONResult.AddPair('total_count', TJSONNumber.Create(TotalCount));
      JSONResult.AddPair('filtered_count', TJSONNumber.Create(Length(Messages)));
      JSONResult.AddPair('offset', TJSONNumber.Create(Filter.Offset));
      JSONResult.AddPair('limit', TJSONNumber.Create(Filter.Limit));

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
  TMCPRegistry.RegisterTool('get_debug_messages',
    function: IMCPTool
    begin
      Result := TGetDebugMessagesTool.Create;
    end
  );

end.
