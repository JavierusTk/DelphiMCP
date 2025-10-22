unit MCPServer.Tool.StartDebugCapture;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  MCPServer.Tool.Base,
  MCPServer.Types,
  Winapi.Windows;

type
  TStartDebugCaptureParams = class
  private
    FBufferSize: Integer;
    FAutoResolveProcessNames: Boolean;
    FFilterCurrentProcess: Boolean;
    FAllowedProcessIds: TArray<Integer>;
    FBlockedProcessIds: TArray<Integer>;
  public
    constructor Create;

    [Optional]
    [SchemaDescription('Maximum messages to keep in memory (default: 10000)')]
    property BufferSize: Integer read FBufferSize write FBufferSize;

    [Optional]
    [SchemaDescription('Automatically resolve process IDs to process names (default: true)')]
    property AutoResolveProcessNames: Boolean read FAutoResolveProcessNames write FAutoResolveProcessNames;

    [Optional]
    [SchemaDescription('Filter out messages from the MCP server itself (default: false)')]
    property FilterCurrentProcess: Boolean read FFilterCurrentProcess write FFilterCurrentProcess;

    [Optional]
    [SchemaDescription('Only capture from these process IDs (empty = all processes)')]
    property AllowedProcessIds: TArray<Integer> read FAllowedProcessIds write FAllowedProcessIds;

    [Optional]
    [SchemaDescription('Never capture from these process IDs')]
    property BlockedProcessIds: TArray<Integer> read FBlockedProcessIds write FBlockedProcessIds;
  end;

  TStartDebugCaptureTool = class(TMCPToolBase<TStartDebugCaptureParams>)
  protected
    function ExecuteWithParams(const Params: TStartDebugCaptureParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration,
  MCPServer.DebugCapture.Core,
  MCPServer.DebugCapture.Types;

{ TStartDebugCaptureParams }

constructor TStartDebugCaptureParams.Create;
begin
  inherited;
  FBufferSize := 10000;
  FAutoResolveProcessNames := True;
  FFilterCurrentProcess := False;
end;

{ TStartDebugCaptureTool }

constructor TStartDebugCaptureTool.Create;
begin
  inherited;
  FName := 'start_debug_capture';
  FDescription := 'Begin capturing Windows OutputDebugString messages';
end;

function TStartDebugCaptureTool.ExecuteWithParams(const Params: TStartDebugCaptureParams): string;
var
  Capture: TOutputDebugStringCapture;
  Session: TCaptureSession;
  SessionId: string;
  JSONResult: TJSONObject;
  BufferSize: Integer;
begin
  JSONResult := TJSONObject.Create;
  try
    try
      if not Assigned(Params) then
        BufferSize := 10000
      else
        BufferSize := Params.BufferSize;

      if BufferSize <= 0 then
        BufferSize := 10000
      else if BufferSize > 100000 then
        BufferSize := 100000;

      Capture := TOutputDebugStringCapture.Instance;
      SessionId := Capture.StartCapture(
        BufferSize,
        Params.AutoResolveProcessNames,
        Params.FilterCurrentProcess
      );

      Session := Capture.GetSession(SessionId);
      if Assigned(Session) then
      begin
        if Length(Params.AllowedProcessIds) > 0 then
        begin
          var AllowedPIDs: TArray<DWORD>;
          SetLength(AllowedPIDs, Length(Params.AllowedProcessIds));
          for var I := 0 to High(Params.AllowedProcessIds) do
            AllowedPIDs[I] := DWORD(Params.AllowedProcessIds[I]);
          Session.SetAllowedProcessIds(AllowedPIDs);
        end;

        if Length(Params.BlockedProcessIds) > 0 then
        begin
          var BlockedPIDs: TArray<DWORD>;
          SetLength(BlockedPIDs, Length(Params.BlockedProcessIds));
          for var I := 0 to High(Params.BlockedProcessIds) do
            BlockedPIDs[I] := DWORD(Params.BlockedProcessIds[I]);
          Session.SetBlockedProcessIds(BlockedPIDs);
        end;
      end;

      JSONResult.AddPair('success', TJSONBool.Create(True));
      JSONResult.AddPair('session_id', SessionId);
      JSONResult.AddPair('status', 'capturing');
      JSONResult.AddPair('buffer_size', TJSONNumber.Create(BufferSize));
      JSONResult.AddPair('auto_resolve_process_names', TJSONBool.Create(Params.AutoResolveProcessNames));
      JSONResult.AddPair('filter_current_process', TJSONBool.Create(Params.FilterCurrentProcess));

      if Length(Params.AllowedProcessIds) > 0 then
        JSONResult.AddPair('allowed_process_count', TJSONNumber.Create(Length(Params.AllowedProcessIds)));

      if Length(Params.BlockedProcessIds) > 0 then
        JSONResult.AddPair('blocked_process_count', TJSONNumber.Create(Length(Params.BlockedProcessIds)));

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
  TMCPRegistry.RegisterTool('start_debug_capture',
    function: IMCPTool
    begin
      Result := TStartDebugCaptureTool.Create;
    end
  );

end.
