unit AutomationBroker;

{
  Automation Command Broker - Executes commands in main thread via window messages

  PURPOSE:
  - Enable automation commands to execute EVEN when modal dialogs are open
  - Replace TThread.Synchronize (which blocks during ShowModal)
  - Use PostMessage to hidden window (processed by ALL message loops)

  ARCHITECTURE:
  - Hidden HWND with custom WndProc in main thread
  - Thread-safe command queue (TThreadedQueue)
  - Background threads enqueue commands and wait for completion
  - WM_APP_AUTOMATION triggers command processing in main thread

  USAGE:
    var Cmd: IAutomationCommand;
    begin
      Cmd := TAutomationCommand.Create(
        procedure
        begin
          // VCL access here - runs in main thread
          ShowMessage('Hello from automation');
        end
      );
      TAutomationBroker.Instance.EnqueueAndWait(Cmd, 30000); // 30s timeout
      // Command completed, result in Cmd.Result
    end;
}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

const
  WM_APP_AUTOMATION = WM_APP + 42;

type
  /// <summary>
  /// Command interface for automation operations
  /// </summary>
  IAutomationCommand = interface
    ['{F8E7D6C5-B4A3-9281-7069-584736251403}']
    procedure Execute; // ALWAYS called in main thread
    function GetResult: string;
    procedure SetResult(const Value: string);
    function GetCompletionEvent: TEvent;
    property Result: string read GetResult write SetResult;
    property CompletionEvent: TEvent read GetCompletionEvent;
  end;

  /// <summary>
  /// Concrete command implementation
  /// </summary>
  TAutomationCommand = class(TInterfacedObject, IAutomationCommand)
  private
    FExecuteProc: TProc;
    FResult: string;
    FCompletionEvent: TEvent;
    FException: Exception;
  public
    constructor Create(const ExecuteProc: TProc);
    destructor Destroy; override;

    procedure Execute;
    function GetResult: string;
    procedure SetResult(const Value: string);
    function GetCompletionEvent: TEvent;

    property Result: string read GetResult write SetResult;
    property CompletionEvent: TEvent read GetCompletionEvent;
  end;

  /// <summary>
  /// Singleton broker managing command execution in main thread
  /// </summary>
  TAutomationBroker = class
  private
    class var FInstance: TAutomationBroker;
    class function GetInstance: TAutomationBroker; static;
  private
    FWnd: HWND;
    FQueue: TThreadedQueue<IAutomationCommand>;

    class function WndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; static; stdcall;
    procedure DrainQueue;
  public
    constructor Create;
    destructor Destroy; override;

    class property Instance: TAutomationBroker read GetInstance;

    /// <summary>
    /// Enqueue command and wait for completion
    /// </summary>
    /// <param name="Command">Command to execute</param>
    /// <param name="TimeoutMs">Timeout in milliseconds (default: 30000)</param>
    /// <returns>True if completed, False if timeout</returns>
    function EnqueueAndWait(const Command: IAutomationCommand; TimeoutMs: Cardinal = 30000): Boolean;

    /// <summary>
    /// Get broker window handle (for testing)
    /// </summary>
    function Handle: HWND;
  end;

/// <summary>
/// Global initialization/finalization procedures
/// </summary>
procedure InitAutomationBroker;
procedure DoneAutomationBroker;

implementation

uses
  AutomationLogger;

var
  WndClassAtom: ATOM = 0;

{ TAutomationCommand }

constructor TAutomationCommand.Create(const ExecuteProc: TProc);
begin
  inherited Create;
  FExecuteProc := ExecuteProc;
  FResult := '';
  FException := nil;
  FCompletionEvent := TEvent.Create(nil, True, False, ''); // Manual reset, initially non-signaled
end;

destructor TAutomationCommand.Destroy;
begin
  FCompletionEvent.Free;
  if Assigned(FException) then
    FException.Free;
  inherited;
end;

procedure TAutomationCommand.Execute;
begin
  try
    try
      if Assigned(FExecuteProc) then
        FExecuteProc;
    except
      on E: Exception do
      begin
        // Capture exception for re-raise in calling thread
        FException := Exception(AcquireExceptionObject);
        LogError('Command execution exception: ' + E.Message);
      end;
    end;
  finally
    // CRITICAL: Always signal completion, even if exception occurred
    // This prevents calling thread from waiting forever
    FCompletionEvent.SetEvent;
  end;
end;

function TAutomationCommand.GetResult: string;
begin
  Result := FResult;
end;

procedure TAutomationCommand.SetResult(const Value: string);
begin
  FResult := Value;
end;

function TAutomationCommand.GetCompletionEvent: TEvent;
begin
  Result := FCompletionEvent;
end;

{ TAutomationBroker }

constructor TAutomationBroker.Create;
var
  Wc: WNDCLASS;
  ErrorCode: DWORD;
begin
  inherited Create;

  FWnd := 0;
  FQueue := nil;

  try
    LogInfo('Creating automation broker...');

    // Create thread-safe command queue (capacity: 1024, push timeout: 1s, pop timeout: 1s)
    FQueue := TThreadedQueue<IAutomationCommand>.Create(1024, 1000, 1000);
    LogDebug('Broker: Command queue created (capacity: 1024)');

    // Register window class
    ZeroMemory(@Wc, SizeOf(Wc));
    Wc.style := 0;
    Wc.lpfnWndProc := @TAutomationBroker.WndProc;
    Wc.hInstance := HInstance;
    Wc.lpszClassName := 'AutomationBrokerWndClass';

    WndClassAtom := Winapi.Windows.RegisterClass(Wc);
    if WndClassAtom = 0 then
    begin
      ErrorCode := GetLastError;
      LogError('Broker: Failed to register window class (error: ' + IntToStr(ErrorCode) + ')');
      RaiseLastOSError;
    end;

    LogDebug('Broker: Window class registered (atom: ' + IntToStr(WndClassAtom) + ')');

    // Create hidden window
    FWnd := CreateWindowEx(
      0,                                // dwExStyle
      Wc.lpszClassName,                 // lpClassName
      'AutomationBrokerWnd',            // lpWindowName
      0,                                // dwStyle (no WS_VISIBLE)
      0, 0, 0, 0,                       // x, y, width, height
      0,                                // hWndParent
      0,                                // hMenu
      HInstance,                        // hInstance
      nil                               // lpParam
    );

    if FWnd = 0 then
    begin
      ErrorCode := GetLastError;
      LogError('Broker: Failed to create window (error: ' + IntToStr(ErrorCode) + ')');
      RaiseLastOSError;
    end;

    // Store Self pointer in window data
    SetWindowLongPtr(FWnd, GWLP_USERDATA, LONG_PTR(Self));

    LogInfo('Automation broker created successfully (HWND=' + IntToStr(FWnd) + ', Queue=1024)');

  except
    on E: Exception do
    begin
      LogError('CRITICAL: Failed to create automation broker: ' + E.Message);

      // Clean up partially-created resources
      if FWnd <> 0 then
      begin
        DestroyWindow(FWnd);
        FWnd := 0;
      end;

      if WndClassAtom <> 0 then
      begin
        Winapi.Windows.UnregisterClass('AutomationBrokerWndClass', HInstance);
        WndClassAtom := 0;
      end;

      if Assigned(FQueue) then
        FreeAndNil(FQueue);

      raise; // Re-raise exception
    end;
  end;
end;

destructor TAutomationBroker.Destroy;
var
  Cmd: IAutomationCommand;
  DrainedCount: Integer;
begin
  try
    LogInfo('Destroying automation broker...');

    // Drain any remaining commands in queue before shutdown
    if Assigned(FQueue) then
    begin
      DrainedCount := 0;
      while FQueue.PopItem(Cmd) = TWaitResult.wrSignaled do
      begin
        Inc(DrainedCount);
        if Assigned(Cmd) then
        begin
          try
            // Signal completion to unblock any waiting threads
            Cmd.CompletionEvent.SetEvent;
          except
            on E: Exception do
              LogError('Error signaling pending command during shutdown: ' + E.Message);
          end;
        end;
      end;

      if DrainedCount > 0 then
        LogWarning('Broker shutdown: Drained ' + IntToStr(DrainedCount) + ' pending commands');
    end;

    // Destroy window
    if FWnd <> 0 then
    begin
      LogDebug('Destroying broker window (HWND=' + IntToStr(FWnd) + ')');
      if not DestroyWindow(FWnd) then
        LogWarning('DestroyWindow failed (error: ' + IntToStr(GetLastError) + ')');
      FWnd := 0;
    end;

    // Unregister window class
    if WndClassAtom <> 0 then
    begin
      LogDebug('Unregistering broker window class');
      if not Winapi.Windows.UnregisterClass('AutomationBrokerWndClass', HInstance) then
        LogWarning('UnregisterClass failed (error: ' + IntToStr(GetLastError) + ')');
      WndClassAtom := 0;
    end;

    // Free queue
    if Assigned(FQueue) then
    begin
      LogDebug('Freeing broker command queue');
      FreeAndNil(FQueue);
    end;

    LogInfo('Automation broker destroyed successfully');

  except
    on E: Exception do
      LogError('Exception during broker destruction: ' + E.Message);
  end;

  inherited;
end;

class function TAutomationBroker.GetInstance: TAutomationBroker;
begin
  if FInstance = nil then
    FInstance := TAutomationBroker.Create;
  Result := FInstance;
end;

function TAutomationBroker.EnqueueAndWait(const Command: IAutomationCommand; TimeoutMs: Cardinal): Boolean;
var
  WaitResult: TWaitResult;
  PushResult: TWaitResult;
  PostResult: BOOL;
begin
  Result := False;

  if not Assigned(Command) then
  begin
    LogError('EnqueueAndWait: Command is nil');
    Exit;
  end;

  if FWnd = 0 then
  begin
    LogError('EnqueueAndWait: Broker window not initialized');
    Exit;
  end;

  // Enqueue command (timeout is set in queue constructor: 1000ms)
  LogDebug('EnqueueAndWait: Pushing command to queue...');
  PushResult := FQueue.PushItem(Command);

  if PushResult <> TWaitResult.wrSignaled then
  begin
    LogError('EnqueueAndWait: Failed to enqueue command (timeout or queue full)');
    raise Exception.Create('Automation command queue full or timeout waiting for queue space');
  end;

  LogDebug('EnqueueAndWait: Command enqueued, posting message to broker window...');

  // Signal broker window to process queue
  PostResult := PostMessage(FWnd, WM_APP_AUTOMATION, 0, 0);
  if not PostResult then
  begin
    LogError('EnqueueAndWait: PostMessage failed - HWND may be invalid');
    raise Exception.Create('Failed to signal broker window (PostMessage failed)');
  end;

  LogDebug('EnqueueAndWait: Waiting for command completion (timeout: ' + IntToStr(TimeoutMs) + 'ms)...');

  // Wait for command completion (timeout)
  WaitResult := Command.CompletionEvent.WaitFor(TimeoutMs);

  case WaitResult of
    wrSignaled:
      begin
        LogDebug('EnqueueAndWait: Command completed successfully');
        Result := True;
      end;
    wrTimeout:
      begin
        LogError('EnqueueAndWait: Command execution timeout after ' + IntToStr(TimeoutMs) + 'ms');
        Result := False;
      end;
    wrAbandoned:
      begin
        LogError('EnqueueAndWait: Wait abandoned (event destroyed)');
        Result := False;
      end;
    wrError:
      begin
        LogError('EnqueueAndWait: Wait error');
        Result := False;
      end;
  end;
end;

function TAutomationBroker.Handle: HWND;
begin
  Result := FWnd;
end;

procedure TAutomationBroker.DrainQueue;
var
  Cmd: IAutomationCommand;
  QueueDepth: Integer;
begin
  QueueDepth := 0;

  // Process all pending commands
  while FQueue.PopItem(Cmd) = TWaitResult.wrSignaled do
  begin
    Inc(QueueDepth);

    // CRITICAL: Double safety - ensure SetEvent is called even if Cmd.Execute fails catastrophically
    try
      try
        if Assigned(Cmd) then
        begin
          LogDebug('Broker executing command #' + IntToStr(QueueDepth));
          Cmd.Execute; // Execute in main thread (WndProc context)
          LogDebug('Broker command #' + IntToStr(QueueDepth) + ' completed');
        end
        else
          LogWarning('Broker received nil command in queue');
      except
        on E: Exception do
        begin
          LogError('CRITICAL: Exception in DrainQueue command execution: ' + E.Message);
          // Cmd.Execute should have already called SetEvent in its finally block
          // But if it didn't (catastrophic failure), force it here
          if Assigned(Cmd) then
          begin
            try
              Cmd.CompletionEvent.SetEvent;
              LogDebug('Emergency SetEvent called for failed command');
            except
              on E2: Exception do
                LogError('CRITICAL: SetEvent also failed: ' + E2.Message);
            end;
          end;
        end;
      end;
    except
      on E: Exception do
        LogError('CRITICAL: Outer exception handler in DrainQueue: ' + E.Message);
    end;
  end;

  if QueueDepth > 0 then
    LogDebug('Broker processed ' + IntToStr(QueueDepth) + ' commands from queue');
end;

class function TAutomationBroker.WndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  SelfPtr: TAutomationBroker;
begin
  // Default result
  Result := 0;

  try
    SelfPtr := TAutomationBroker(GetWindowLongPtr(hWnd, GWLP_USERDATA));

    if (uMsg = WM_APP_AUTOMATION) and Assigned(SelfPtr) then
    begin
      try
        // Process command queue in main thread
        LogDebug('WndProc: Received WM_APP_AUTOMATION, draining queue...');
        SelfPtr.DrainQueue;
        LogDebug('WndProc: Queue drained successfully');
      except
        on E: Exception do
        begin
          LogError('CRITICAL: Exception in WndProc DrainQueue: ' + E.Message);
          // Don't re-raise - WndProc must not throw exceptions
        end;
      end;
      Exit;
    end;

    // Default window procedure
    Result := DefWindowProc(hWnd, uMsg, wParam, lParam);

  except
    on E: Exception do
    begin
      LogError('CRITICAL: Outer exception in WndProc: ' + E.Message);
      Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
    end;
  end;
end;

procedure InitAutomationBroker;
begin
  LogInfo('Initializing automation broker...');
  TAutomationBroker.Instance; // Force creation
  LogInfo('Automation broker initialized - ready for modal-safe automation');
end;

procedure DoneAutomationBroker;
begin
  if Assigned(TAutomationBroker.FInstance) then
  begin
    LogInfo('Finalizing automation broker...');
    FreeAndNil(TAutomationBroker.FInstance);
    LogInfo('Automation broker finalized');
  end;
end;

initialization

finalization
  DoneAutomationBroker;

end.
