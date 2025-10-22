unit MCPServer.DebugCapture.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.AnsiStrings,
  Winapi.Windows,
  Winapi.PsAPI,
  System.DateUtils,
  MCPServer.DebugCapture.Types;

const
  DBWIN_BUFFER_SIZE = 4096;

type
  PDBWinBuffer = ^TDBWinBuffer;
  TDBWinBuffer = packed record
    ProcessId: DWORD;
    Data: array[0..DBWIN_BUFFER_SIZE - SizeOf(DWORD) - 1] of AnsiChar;
  end;

  TOutputDebugStringCapture = class;

  TCaptureThread = class(TThread)
  private
    FOwner: TOutputDebugStringCapture;
  protected
    procedure Execute; override;
  public
    constructor Create(Owner: TOutputDebugStringCapture);
  end;

  TOutputDebugStringCapture = class
  private
    FMutex: THandle;
    FBufferReadyEvent: THandle;
    FDataReadyEvent: THandle;
    FSharedFile: THandle;
    FSharedBuffer: PDBWinBuffer;
    FCaptureThread: TCaptureThread;
    FSessions: TDictionary<string, TCaptureSession>;
    FSessionsLock: TCriticalSection;
    FInitLock: TCriticalSection;
    FCurrentProcessId: DWORD;
    FIsCapturing: Boolean;
    FInitialized: Boolean;
    FInitError: string;

    function GetProcessName(ProcessId: DWORD): string;
    procedure ProcessDebugMessage(ProcessId: DWORD; const Message: AnsiString);
    function InitializeCapture: Boolean;
    procedure CleanupCapture;
    class var FInstance: TOutputDebugStringCapture;
  public
    constructor Create;
    destructor Destroy; override;

    function StartCapture(BufferSize: Integer; AutoResolveProcessNames: Boolean;
      FilterCurrentProcess: Boolean): string;
    function StopCapture(const SessionId: string): Boolean;
    function PauseCapture(const SessionId: string): Boolean;
    function ResumeCapture(const SessionId: string): Boolean;

    function GetSession(const SessionId: string): TCaptureSession;
    function GetMessages(const SessionId: string; const Filter: TMessageFilter): TArray<TDebugMessage>;
    function GetProcessSummary(const SessionId: string; TimeWindowMinutes: Integer): TArray<TProcessStats>;
    function GetCaptureStatus(const SessionId: string): TCaptureStatus;
    function IsCapturing: Boolean;

    procedure ClearMessages(const SessionId: string);
    function ExportMessages(const SessionId: string; const FileName: string;
      ExportFormat: TExportFormat; const Filter: TMessageFilter): Integer;

    class function Instance: TOutputDebugStringCapture;
    class procedure ReleaseInstance;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  MCPServer.Logger;

{ TCaptureThread }

constructor TCaptureThread.Create(Owner: TOutputDebugStringCapture);
begin
  inherited Create(True);
  FOwner := Owner;
  FreeOnTerminate := False;
end;

procedure TCaptureThread.Execute;
var
  WaitResult: DWORD;
  ProcessId: DWORD;
  Message: AnsiString;
  MessageCount: Integer;
begin
  MessageCount := 0;
  TLogger.Debug('Capture thread started');

  while not Terminated do
  begin
    // Check if capture is still initialized (thread-safe)
    FOwner.FInitLock.Enter;
    try
      if not FOwner.FInitialized then
      begin
        FOwner.FInitLock.Leave;
        Sleep(100);
        Continue;
      end;
    finally
      // Leave will be called in the finally block if we don't Continue
      if FOwner.FInitialized then
        FOwner.FInitLock.Leave;
    end;

    WaitResult := WaitForSingleObject(FOwner.FDataReadyEvent, 100);

    if WaitResult = WAIT_OBJECT_0 then
    begin
      if WaitForSingleObject(FOwner.FMutex, INFINITE) = WAIT_OBJECT_0 then
      begin
        try
          if Assigned(FOwner.FSharedBuffer) then
          begin
            ProcessId := FOwner.FSharedBuffer.ProcessId;
            SetString(Message, FOwner.FSharedBuffer.Data, System.AnsiStrings.StrLen(FOwner.FSharedBuffer.Data));
            Inc(MessageCount);
            TLogger.Debug(Format('Captured message #%d from PID %d: %s', [MessageCount, ProcessId, string(Message)]));
            FOwner.ProcessDebugMessage(ProcessId, Message);
          end;
        finally
          SetEvent(FOwner.FBufferReadyEvent);
          ReleaseMutex(FOwner.FMutex);
        end;
      end;
    end;
  end;

  TLogger.Debug(Format('Capture thread ending, captured %d messages', [MessageCount]));
end;

{ TOutputDebugStringCapture }

constructor TOutputDebugStringCapture.Create;
begin
  inherited;
  FSessions := TDictionary<string, TCaptureSession>.Create;
  FSessionsLock := TCriticalSection.Create;
  FInitLock := TCriticalSection.Create;
  FCurrentProcessId := GetCurrentProcessId;
  FIsCapturing := False;
  FInitialized := False;
  FInitError := '';

  // Initialize handles to zero
  FMutex := 0;
  FBufferReadyEvent := 0;
  FDataReadyEvent := 0;
  FSharedFile := 0;
  FSharedBuffer := nil;
end;

function TOutputDebugStringCapture.InitializeCapture: Boolean;
var
  LastError: DWORD;
  ExistingEvent: THandle;
begin
  Result := False;
  FInitError := '';

  FInitLock.Enter;
  try
    if FInitialized then
    begin
      TLogger.Info('Debug capture already initialized');
      Result := True;
      Exit;
    end;

    TLogger.Info('Initializing Windows debug capture...');

    // First check if another debugger is already capturing
    TLogger.Debug('Checking for existing debugger...');

    // Check global objects first (DebugView, etc use global)
    ExistingEvent := OpenEvent(SYNCHRONIZE, False, 'DBWIN_BUFFER_READY');
    if ExistingEvent <> 0 then
    begin
      CloseHandle(ExistingEvent);
      FInitError := 'Another debugger (like DebugView) is already capturing debug output. Please close it first.';
      TLogger.Warning(FInitError);
      Exit;
    end;

    // Check local objects (another instance of our server)
    ExistingEvent := OpenEvent(SYNCHRONIZE, False, 'Local\DBWIN_BUFFER_READY');
    if ExistingEvent <> 0 then
    begin
      CloseHandle(ExistingEvent);
      FInitError := 'Another instance of the debug capture is already running in this session.';
      TLogger.Warning(FInitError);
      Exit;
    end;

  try
    // Try to create mutex (should succeed if no other debugger)
    TLogger.Debug('Creating Local\\DBWIN_BUFFER_MUTEX');
    FMutex := CreateMutex(nil, False, 'Local\DBWIN_BUFFER_MUTEX');
    if FMutex = 0 then
    begin
      LastError := GetLastError;
      FInitError := Format('Failed to create DBWIN_BUFFER_MUTEX (Error: %d)', [LastError]);
      TLogger.Error(FInitError);
      Exit;
    end;
    TLogger.Debug('Created Local\DBWIN_BUFFER_MUTEX');

    // Create the events (we already checked they don't exist)
    TLogger.Debug('Creating Local\DBWIN_BUFFER_READY event');
    FBufferReadyEvent := CreateEvent(nil, False, True, 'Local\DBWIN_BUFFER_READY');
    if FBufferReadyEvent = 0 then
    begin
      LastError := GetLastError;
      if LastError = ERROR_ACCESS_DENIED then
        FInitError := 'Access denied creating DBWIN_BUFFER_READY. Try running without admin privileges.'
      else if LastError = ERROR_ALREADY_EXISTS then
        FInitError := 'Debug capture objects already exist. This should not happen.'
      else
        FInitError := Format('Failed to create DBWIN_BUFFER_READY event (Error: %d)', [LastError]);
      TLogger.Error(FInitError);
      CleanupCapture;
      Exit;
    end;
    TLogger.Debug('Created DBWIN_BUFFER_READY event');

    TLogger.Debug('Creating Local\DBWIN_DATA_READY event');
    FDataReadyEvent := CreateEvent(nil, False, False, 'Local\DBWIN_DATA_READY');
    if FDataReadyEvent = 0 then
    begin
      LastError := GetLastError;
      if LastError = ERROR_ACCESS_DENIED then
        FInitError := 'Access denied creating DBWIN_DATA_READY. Try running without admin privileges.'
      else if LastError = ERROR_ALREADY_EXISTS then
        FInitError := 'Debug capture objects already exist. This should not happen.'
      else
        FInitError := Format('Failed to create DBWIN_DATA_READY event (Error: %d)', [LastError]);
      TLogger.Error(FInitError);
      CleanupCapture;
      Exit;
    end;
    TLogger.Debug('Created DBWIN_DATA_READY event');

    // Create the shared memory buffer
    TLogger.Debug('Creating Local\DBWIN_BUFFER file mapping');
    FSharedFile := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE,
      0, DBWIN_BUFFER_SIZE, 'Local\DBWIN_BUFFER');
    if FSharedFile = 0 then
    begin
      LastError := GetLastError;
      if LastError = ERROR_ACCESS_DENIED then
        FInitError := 'Access denied creating DBWIN_BUFFER. Try running without admin privileges.'
      else if LastError = ERROR_ALREADY_EXISTS then
        FInitError := 'Debug capture buffer already exists. This should not happen.'
      else
        FInitError := Format('Failed to create DBWIN_BUFFER shared memory (Error: %d)', [LastError]);
      TLogger.Error(FInitError);
      CleanupCapture;
      Exit;
    end;
    TLogger.Debug('Created DBWIN_BUFFER file mapping');

    FSharedBuffer := MapViewOfFile(FSharedFile, FILE_MAP_ALL_ACCESS, 0, 0, 0);
    if not Assigned(FSharedBuffer) then
    begin
      LastError := GetLastError;
      FInitError := Format('Failed to map DBWIN_BUFFER shared memory (Error: %d)', [LastError]);
      TLogger.Error(FInitError);
      CleanupCapture;
      Exit;
    end;
    TLogger.Debug('Successfully mapped DBWIN_BUFFER to memory');

    FInitialized := True;
    Result := True;
    TLogger.Info('Debug capture initialization successful');
  except
    on E: Exception do
    begin
      FInitError := E.Message;
      TLogger.Error('Exception during initialization: ' + E.Message);
      CleanupCapture;
    end;
  end;
  finally
    FInitLock.Leave;
  end;
end;

procedure TOutputDebugStringCapture.CleanupCapture;
begin
  FInitLock.Enter;
  try
    if Assigned(FSharedBuffer) then
    begin
      UnmapViewOfFile(FSharedBuffer);
      FSharedBuffer := nil;
    end;

    if FSharedFile <> 0 then
    begin
      CloseHandle(FSharedFile);
      FSharedFile := 0;
    end;

    if FDataReadyEvent <> 0 then
    begin
      CloseHandle(FDataReadyEvent);
      FDataReadyEvent := 0;
    end;

    if FBufferReadyEvent <> 0 then
    begin
      CloseHandle(FBufferReadyEvent);
      FBufferReadyEvent := 0;
    end;

    if FMutex <> 0 then
    begin
      CloseHandle(FMutex);
      FMutex := 0;
    end;

    FInitialized := False;
  finally
    FInitLock.Leave;
  end;
end;

destructor TOutputDebugStringCapture.Destroy;
var
  Session: TCaptureSession;
begin
  if Assigned(FCaptureThread) then
  begin
    FCaptureThread.Terminate;
    FCaptureThread.WaitFor;
    FCaptureThread.Free;
  end;

  CleanupCapture;

  FSessionsLock.Enter;
  try
    for Session in FSessions.Values do
      Session.Free;
    FSessions.Free;
  finally
    FSessionsLock.Leave;
  end;

  FSessionsLock.Free;
  FInitLock.Free;
  inherited;
end;

function TOutputDebugStringCapture.GetProcessName(ProcessId: DWORD): string;
var
  Handle: THandle;
  ModuleName: array[0..MAX_PATH] of Char;
begin
  Handle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, ProcessId);
  if Handle <> 0 then
  begin
    try
      if GetModuleFileNameEx(Handle, 0, ModuleName, Length(ModuleName)) > 0 then
        Result := ExtractFileName(ModuleName)
      else
        Result := Format('PID_%d', [ProcessId]);
    finally
      CloseHandle(Handle);
    end;
  end
  else
    Result := Format('PID_%d', [ProcessId]);
end;

procedure TOutputDebugStringCapture.ProcessDebugMessage(ProcessId: DWORD; const Message: AnsiString);
var
  DebugMsg: TDebugMessage;
  Session: TCaptureSession;
  ProcessName: string;
begin
  FSessionsLock.Enter;
  try
    for Session in FSessions.Values do
    begin
      if Session.Status = csCapturing then
      begin
        // Use thread-safe method to check if process is allowed
        if not Session.IsProcessAllowed(ProcessId) then
          Continue;

        if Session.ProcessNameCache.TryGetValue(ProcessId, ProcessName) then
          DebugMsg.ProcessName := ProcessName
        else if Session.AutoResolveProcessNames then
        begin
          ProcessName := GetProcessName(ProcessId);
          Session.ProcessNameCache.AddOrSetValue(ProcessId, ProcessName);
          DebugMsg.ProcessName := ProcessName;
        end
        else
          DebugMsg.ProcessName := Format('PID_%d', [ProcessId]);

        DebugMsg.ProcessId := ProcessId;
        DebugMsg.Timestamp := Now;
        DebugMsg.Message := string(Message);
        DebugMsg.ThreadId := 0;

        Session.AddMessage(DebugMsg);
      end;
    end;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.StartCapture(BufferSize: Integer;
  AutoResolveProcessNames: Boolean; FilterCurrentProcess: Boolean): string;
var
  Session: TCaptureSession;
begin
  // Initialize capture resources if not already done
  if not FInitialized then
  begin
    if not InitializeCapture then
      raise Exception.Create('Failed to initialize debug capture: ' + FInitError);
  end;

  Session := TCaptureSession.Create(BufferSize);
  Session.AutoResolveProcessNames := AutoResolveProcessNames;
  Session.FilterCurrentProcess := FilterCurrentProcess;
  Session.Status := csCapturing;

  FSessionsLock.Enter;
  try
    FSessions.Add(Session.SessionId, Session);
    Result := Session.SessionId;

    if not FIsCapturing then
    begin
      FCaptureThread := TCaptureThread.Create(Self);
      FCaptureThread.Start;
      FIsCapturing := True;
    end;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.StopCapture(const SessionId: string): Boolean;
var
  Session: TCaptureSession;
  ActiveSessions: Integer;
begin
  Result := False;
  FSessionsLock.Enter;
  try
    if FSessions.TryGetValue(SessionId, Session) then
    begin
      Session.Status := csIdle;
      Result := True;

      ActiveSessions := 0;
      for Session in FSessions.Values do
        if Session.Status = csCapturing then
          Inc(ActiveSessions);

      if (ActiveSessions = 0) and FIsCapturing then
      begin
        FCaptureThread.Terminate;
        FCaptureThread.WaitFor;
        FreeAndNil(FCaptureThread);
        FIsCapturing := False;

        // Cleanup capture resources when no sessions are active
        CleanupCapture;
      end;
    end;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.PauseCapture(const SessionId: string): Boolean;
var
  Session: TCaptureSession;
begin
  Result := False;
  FSessionsLock.Enter;
  try
    if FSessions.TryGetValue(SessionId, Session) then
    begin
      if Session.Status = csCapturing then
      begin
        Session.Status := csPaused;
        Result := True;
      end;
    end;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.ResumeCapture(const SessionId: string): Boolean;
var
  Session: TCaptureSession;
begin
  Result := False;
  FSessionsLock.Enter;
  try
    if FSessions.TryGetValue(SessionId, Session) then
    begin
      if Session.Status = csPaused then
      begin
        Session.Status := csCapturing;
        Result := True;
      end;
    end;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.GetSession(const SessionId: string): TCaptureSession;
begin
  FSessionsLock.Enter;
  try
    if not FSessions.TryGetValue(SessionId, Result) then
      Result := nil;
  finally
    FSessionsLock.Leave;
  end;
end;

function TOutputDebugStringCapture.GetMessages(const SessionId: string;
  const Filter: TMessageFilter): TArray<TDebugMessage>;
var
  Session: TCaptureSession;
begin
  SetLength(Result, 0);
  Session := GetSession(SessionId);
  if Assigned(Session) then
    Result := Session.GetMessages(Filter);
end;

function TOutputDebugStringCapture.GetProcessSummary(const SessionId: string;
  TimeWindowMinutes: Integer): TArray<TProcessStats>;
var
  Session: TCaptureSession;
begin
  SetLength(Result, 0);
  Session := GetSession(SessionId);
  if Assigned(Session) then
    Result := Session.GetProcessStats(TimeWindowMinutes);
end;

function TOutputDebugStringCapture.GetCaptureStatus(const SessionId: string): TCaptureStatus;
var
  Session: TCaptureSession;
begin
  Result := csError;
  Session := GetSession(SessionId);
  if Assigned(Session) then
    Result := Session.Status;
end;

function TOutputDebugStringCapture.IsCapturing: Boolean;
begin
  Result := FIsCapturing;
end;

procedure TOutputDebugStringCapture.ClearMessages(const SessionId: string);
var
  Session: TCaptureSession;
begin
  Session := GetSession(SessionId);
  if Assigned(Session) then
    Session.ClearMessages;
end;

function TOutputDebugStringCapture.ExportMessages(const SessionId: string;
  const FileName: string; ExportFormat: TExportFormat; const Filter: TMessageFilter): Integer;
var
  Session: TCaptureSession;
  Messages: TArray<TDebugMessage>;
  FileContent: TStringList;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  Msg: TDebugMessage;
begin
  Result := 0;
  Session := GetSession(SessionId);
  if not Assigned(Session) then
    Exit;

  Messages := Session.GetMessages(Filter);
  if Length(Messages) = 0 then
    Exit;

  FileContent := TStringList.Create;
  try
    case ExportFormat of
      efCSV:
        begin
          FileContent.Add('ProcessId,ProcessName,Timestamp,Message');
          for Msg in Messages do
          begin
            FileContent.Add(Format('%d,"%s","%s","%s"',
              [Msg.ProcessId, Msg.ProcessName,
               DateTimeToStr(Msg.Timestamp),
               StringReplace(Msg.Message, '"', '""', [rfReplaceAll])]));
          end;
        end;

      efJSON:
        begin
          JSONArray := TJSONArray.Create;
          try
            for Msg in Messages do
            begin
              JSONObj := TJSONObject.Create;
              JSONObj.AddPair('ProcessId', TJSONNumber.Create(Msg.ProcessId));
              JSONObj.AddPair('ProcessName', Msg.ProcessName);
              JSONObj.AddPair('Timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Msg.Timestamp));
              JSONObj.AddPair('Message', Msg.Message);
              JSONArray.AddElement(JSONObj);
            end;
            FileContent.Text := JSONArray.ToJSON;
          finally
            JSONArray.Free;
          end;
        end;

      efText:
        begin
          for Msg in Messages do
          begin
            FileContent.Add(Format('[%s] %s (%d): %s',
              [DateTimeToStr(Msg.Timestamp), Msg.ProcessName,
               Msg.ProcessId, Msg.Message]));
          end;
        end;
    end;

    FileContent.SaveToFile(FileName);
    Result := Length(Messages);
  finally
    FileContent.Free;
  end;
end;

class function TOutputDebugStringCapture.Instance: TOutputDebugStringCapture;
begin
  if not Assigned(FInstance) then
    FInstance := TOutputDebugStringCapture.Create;
  Result := FInstance;
end;

class procedure TOutputDebugStringCapture.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

initialization

finalization
  TOutputDebugStringCapture.ReleaseInstance;

end.
