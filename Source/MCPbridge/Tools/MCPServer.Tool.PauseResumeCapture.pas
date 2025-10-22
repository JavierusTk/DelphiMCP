unit MCPServer.Tool.PauseResumeCapture;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types,
  Winapi.Windows;

type
  TPauseResumeCaptureParams = class
  private
    FSessionId: string;
    FAction: string;
    FUpdateAllowedProcessIds: TArray<Integer>;
    FUpdateBlockedProcessIds: TArray<Integer>;
  public
    constructor Create;

    [SchemaDescription('The session ID returned from start_debug_capture')]
    property SessionId: string read FSessionId write FSessionId;

    [SchemaDescription('Action to perform: "pause" or "resume"')]
    property Action: string read FAction write FAction;

    [Optional]
    [SchemaDescription('Update the list of allowed process IDs (replaces existing)')]
    property UpdateAllowedProcessIds: TArray<Integer> read FUpdateAllowedProcessIds write FUpdateAllowedProcessIds;

    [Optional]
    [SchemaDescription('Update the list of blocked process IDs (replaces existing)')]
    property UpdateBlockedProcessIds: TArray<Integer> read FUpdateBlockedProcessIds write FUpdateBlockedProcessIds;
  end;

  TPauseResumeCaptureTool = class(TMCPToolBase<TPauseResumeCaptureParams>)
  protected
    function ExecuteWithParams(const Params: TPauseResumeCaptureParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types,
  System.StrUtils;

{ TPauseResumeCaptureParams }

constructor TPauseResumeCaptureParams.Create;
begin
  inherited;
  FAction := 'pause';
end;

{ TPauseResumeCaptureTool }

constructor TPauseResumeCaptureTool.Create;
begin
  inherited;
  FName := 'pause_resume_capture';
  FDescription := 'Pause or resume capture and optionally update process filters';
end;

function TPauseResumeCaptureTool.ExecuteWithParams(const Params: TPauseResumeCaptureParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  JSONResult: TJSONObject;
  Success: Boolean;
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

      if not SameText(Params.Action, 'pause') and not SameText(Params.Action, 'resume') then
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', 'Action must be "pause" or "resume"');
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

      if Length(Params.UpdateAllowedProcessIds) > 0 then
      begin
        var AllowedPIDs: TArray<DWORD>;
        SetLength(AllowedPIDs, Length(Params.UpdateAllowedProcessIds));
        for var I := 0 to High(Params.UpdateAllowedProcessIds) do
          AllowedPIDs[I] := DWORD(Params.UpdateAllowedProcessIds[I]);
        Session.SetAllowedProcessIds(AllowedPIDs);
      end;

      if Length(Params.UpdateBlockedProcessIds) > 0 then
      begin
        var BlockedPIDs: TArray<DWORD>;
        SetLength(BlockedPIDs, Length(Params.UpdateBlockedProcessIds));
        for var I := 0 to High(Params.UpdateBlockedProcessIds) do
          BlockedPIDs[I] := DWORD(Params.UpdateBlockedProcessIds[I]);
        Session.SetBlockedProcessIds(BlockedPIDs);
      end;

      if SameText(Params.Action, 'pause') then
        Success := Capture.PauseCapture(Params.SessionId)
      else
        Success := Capture.ResumeCapture(Params.SessionId);

      if Success then
      begin
        JSONResult.AddPair('success', TJSONBool.Create(True));
        JSONResult.AddPair('session_id', Params.SessionId);
        JSONResult.AddPair('action', Params.Action);
        JSONResult.AddPair('status', IfThen(SameText(Params.Action, 'pause'), 'paused', 'capturing'));

        if Session.AllowedProcessIds.Count > 0 then
          JSONResult.AddPair('allowed_process_count', TJSONNumber.Create(Session.AllowedProcessIds.Count));

        if Session.BlockedProcessIds.Count > 0 then
          JSONResult.AddPair('blocked_process_count', TJSONNumber.Create(Session.BlockedProcessIds.Count));
      end
      else
      begin
        JSONResult.AddPair('success', TJSONBool.Create(False));
        JSONResult.AddPair('error', 'Failed to ' + Params.Action + ' capture');
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
  TMCPRegistry.RegisterTool('pause_resume_capture',
    function: IMCPTool
    begin
      Result := TPauseResumeCaptureTool.Create;
    end
  );

end.
