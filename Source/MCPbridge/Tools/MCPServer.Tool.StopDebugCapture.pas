unit MCPServer.Tool.StopDebugCapture;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  TStopDebugCaptureParams = class
  private
    FSessionId: string;
  public
    [SchemaDescription('The session ID returned from start_debug_capture')]
    property SessionId: string read FSessionId write FSessionId;
  end;

  TStopDebugCaptureTool = class(TMCPToolBase<TStopDebugCaptureParams>)
  protected
    function ExecuteWithParams(const Params: TStopDebugCaptureParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types,
  System.DateUtils;

{ TStopDebugCaptureTool }

constructor TStopDebugCaptureTool.Create;
begin
  inherited;
  FName := 'stop_debug_capture';
  FDescription := 'Stop capturing debug messages for a specific session';
end;

function TStopDebugCaptureTool.ExecuteWithParams(const Params: TStopDebugCaptureParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  JSONResult: TJSONObject;
  Duration: Double;
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

      Duration := SecondsBetween(Now, Session.StartTime);

      if Capture.StopCapture(Params.SessionId) then
      begin
        JSONResult.AddPair('success', TJSONBool.Create(True));
        JSONResult.AddPair('session_id', Params.SessionId);
        JSONResult.AddPair('messages_captured', TJSONNumber.Create(Session.MessagesCaptured));
        JSONResult.AddPair('duration_seconds', TJSONNumber.Create(Duration));
        JSONResult.AddPair('status', 'stopped');
      end
      else
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', 'Failed to stop capture session');
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
  TMCPRegistry.RegisterTool('stop_debug_capture',
    function: IMCPTool
    begin
      Result := TStopDebugCaptureTool.Create;
    end
  );

end.
