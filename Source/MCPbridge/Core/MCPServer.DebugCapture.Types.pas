unit MCPServer.DebugCapture.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  Winapi.Windows;

type
  TDebugMessage = record
    ProcessId: DWORD;
    ProcessName: string;
    Timestamp: TDateTime;
    Message: string;
    ThreadId: DWORD;
  end;

  TDebugMessageList = TList<TDebugMessage>;

  TCaptureStatus = (csIdle, csCapturing, csPaused, csError);

  TMessageFilter = record
    ProcessId: Integer;
    ProcessName: string;
    MessageContains: string;
    MessageRegex: string;
    SinceTimestamp: TDateTime;
    Limit: Integer;
    Offset: Integer;
  end;

  TProcessStats = record
    ProcessId: DWORD;
    ProcessName: string;
    MessageCount: Integer;
    FirstSeen: TDateTime;
    LastSeen: TDateTime;
    AvgMessagesPerMinute: Double;
  end;

  TCaptureSession = class
  private
    FSessionId: string;
    FMessages: TDebugMessageList;
    FLock: TCriticalSection;
    FStatus: TCaptureStatus;
    FStartTime: TDateTime;
    FBufferSize: Integer;
    FAutoResolveProcessNames: Boolean;
    FFilterCurrentProcess: Boolean;
    FMessagesCaptured: Integer;
    FProcessNameCache: TDictionary<DWORD, string>;
    FAllowedProcessIds: TList<DWORD>;
    FBlockedProcessIds: TList<DWORD>;
  public
    constructor Create(BufferSize: Integer = 10000);
    destructor Destroy; override;

    procedure AddMessage(const Msg: TDebugMessage);
    function GetMessages(const Filter: TMessageFilter): TArray<TDebugMessage>;
    procedure ClearMessages;
    function GetProcessStats(TimeWindowMinutes: Integer = 0): TArray<TProcessStats>;

    procedure SetAllowedProcessIds(const ProcessIds: TArray<DWORD>);
    procedure SetBlockedProcessIds(const ProcessIds: TArray<DWORD>);
    function IsProcessAllowed(ProcessId: DWORD): Boolean;

    property SessionId: string read FSessionId;
    property Status: TCaptureStatus read FStatus write FStatus;
    property StartTime: TDateTime read FStartTime;
    property BufferSize: Integer read FBufferSize;
    property MessagesCaptured: Integer read FMessagesCaptured;
    property AutoResolveProcessNames: Boolean read FAutoResolveProcessNames write FAutoResolveProcessNames;
    property FilterCurrentProcess: Boolean read FFilterCurrentProcess write FFilterCurrentProcess;
    property ProcessNameCache: TDictionary<DWORD, string> read FProcessNameCache;
    property AllowedProcessIds: TList<DWORD> read FAllowedProcessIds;
    property BlockedProcessIds: TList<DWORD> read FBlockedProcessIds;
  end;

  TExportFormat = (efCSV, efJSON, efText);

implementation

uses
  System.RegularExpressions;

{ TCaptureSession }

constructor TCaptureSession.Create(BufferSize: Integer);
var
  GUID: TGUID;
begin
  inherited Create;
  FMessages := TDebugMessageList.Create;
  FLock := TCriticalSection.Create;
  FProcessNameCache := TDictionary<DWORD, string>.Create;
  FAllowedProcessIds := TList<DWORD>.Create;
  FBlockedProcessIds := TList<DWORD>.Create;

  CreateGUID(GUID);
  FSessionId := GUIDToString(GUID);
  FBufferSize := BufferSize;
  FStatus := csIdle;
  FStartTime := Now;
  FMessagesCaptured := 0;
  FAutoResolveProcessNames := True;
  FFilterCurrentProcess := False;
end;

destructor TCaptureSession.Destroy;
begin
  FBlockedProcessIds.Free;
  FAllowedProcessIds.Free;
  FProcessNameCache.Free;
  FMessages.Free;
  FLock.Free;
  inherited;
end;

procedure TCaptureSession.AddMessage(const Msg: TDebugMessage);
begin
  FLock.Enter;
  try
    if FMessages.Count >= FBufferSize then
      FMessages.Delete(0);

    FMessages.Add(Msg);
    Inc(FMessagesCaptured);

    if not FProcessNameCache.ContainsKey(Msg.ProcessId) then
      FProcessNameCache.AddOrSetValue(Msg.ProcessId, Msg.ProcessName);
  finally
    FLock.Leave;
  end;
end;

function TCaptureSession.GetMessages(const Filter: TMessageFilter): TArray<TDebugMessage>;
var
  FilteredList: TList<TDebugMessage>;
  Msg: TDebugMessage;
  Regex: TRegEx;
  UseRegex: Boolean;
  Count, StartIndex: Integer;
begin
  FLock.Enter;
  try
    FilteredList := TList<TDebugMessage>.Create;
    try
      UseRegex := Filter.MessageRegex <> '';
      if UseRegex then
        Regex := TRegEx.Create(Filter.MessageRegex);

      for Msg in FMessages do
      begin
        if (Filter.ProcessId > 0) and (Msg.ProcessId <> DWORD(Filter.ProcessId)) then
          Continue;

        if (Filter.ProcessName <> '') and
           not SameText(Msg.ProcessName, Filter.ProcessName) then
          Continue;

        if (Filter.SinceTimestamp > 0) and (Msg.Timestamp < Filter.SinceTimestamp) then
          Continue;

        if (Filter.MessageContains <> '') and
           not Msg.Message.Contains(Filter.MessageContains) then
          Continue;

        if UseRegex and not Regex.IsMatch(Msg.Message) then
          Continue;

        FilteredList.Add(Msg);
      end;

      StartIndex := Filter.Offset;
      if StartIndex < 0 then StartIndex := 0;
      if StartIndex >= FilteredList.Count then
      begin
        SetLength(Result, 0);
        Exit;
      end;

      Count := Filter.Limit;
      if (Count <= 0) or (Count > FilteredList.Count - StartIndex) then
        Count := FilteredList.Count - StartIndex;

      SetLength(Result, Count);
      if Count > 0 then
        Move(FilteredList.List[StartIndex], Result[0], Count * SizeOf(TDebugMessage));

    finally
      FilteredList.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCaptureSession.ClearMessages;
begin
  FLock.Enter;
  try
    FMessages.Clear;
  finally
    FLock.Leave;
  end;
end;

function TCaptureSession.GetProcessStats(TimeWindowMinutes: Integer): TArray<TProcessStats>;
var
  StatsDict: TDictionary<DWORD, TProcessStats>;
  Msg: TDebugMessage;
  Stats: TProcessStats;
  MinTime: TDateTime;
  ProcessId: DWORD;
begin
  FLock.Enter;
  try
    StatsDict := TDictionary<DWORD, TProcessStats>.Create;
    try
      if TimeWindowMinutes > 0 then
        MinTime := Now - (TimeWindowMinutes / (24 * 60))
      else
        MinTime := 0;

      for Msg in FMessages do
      begin
        if (MinTime > 0) and (Msg.Timestamp < MinTime) then
          Continue;

        if StatsDict.TryGetValue(Msg.ProcessId, Stats) then
        begin
          Inc(Stats.MessageCount);
          if Msg.Timestamp > Stats.LastSeen then
            Stats.LastSeen := Msg.Timestamp;
          StatsDict.AddOrSetValue(Msg.ProcessId, Stats);
        end
        else
        begin
          Stats.ProcessId := Msg.ProcessId;
          Stats.ProcessName := Msg.ProcessName;
          Stats.MessageCount := 1;
          Stats.FirstSeen := Msg.Timestamp;
          Stats.LastSeen := Msg.Timestamp;
          StatsDict.Add(Msg.ProcessId, Stats);
        end;
      end;

      SetLength(Result, StatsDict.Count);
      var Index := 0;
      for ProcessId in StatsDict.Keys do
      begin
        Stats := StatsDict[ProcessId];
        if Stats.LastSeen > Stats.FirstSeen then
        begin
          var Duration := (Stats.LastSeen - Stats.FirstSeen) * 24 * 60;
          if Duration > 0 then
            Stats.AvgMessagesPerMinute := Stats.MessageCount / Duration
          else
            Stats.AvgMessagesPerMinute := 0;
        end
        else
          Stats.AvgMessagesPerMinute := 0;

        Result[Index] := Stats;
        Inc(Index);
      end;

    finally
      StatsDict.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCaptureSession.SetAllowedProcessIds(const ProcessIds: TArray<DWORD>);
var
  PID: DWORD;
begin
  FLock.Enter;
  try
    FAllowedProcessIds.Clear;
    for PID in ProcessIds do
      FAllowedProcessIds.Add(PID);
  finally
    FLock.Leave;
  end;
end;

procedure TCaptureSession.SetBlockedProcessIds(const ProcessIds: TArray<DWORD>);
var
  PID: DWORD;
begin
  FLock.Enter;
  try
    FBlockedProcessIds.Clear;
    for PID in ProcessIds do
      FBlockedProcessIds.Add(PID);
  finally
    FLock.Leave;
  end;
end;

function TCaptureSession.IsProcessAllowed(ProcessId: DWORD): Boolean;
begin
  FLock.Enter;
  try
    // Check if filtering current process is enabled
    if FFilterCurrentProcess and (ProcessId = GetCurrentProcessId) then
    begin
      Result := False;
      Exit;
    end;

    // Check allowed list (if not empty, process must be in it)
    if FAllowedProcessIds.Count > 0 then
    begin
      Result := FAllowedProcessIds.Contains(ProcessId);
      if not Result then
        Exit;
    end;

    // Check blocked list (process must not be in it)
    Result := not FBlockedProcessIds.Contains(ProcessId);
  finally
    FLock.Leave;
  end;
end;

end.
