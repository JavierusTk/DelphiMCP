unit AutomationLogger;

{
  Automation Framework - Logging Abstraction

  PURPOSE:
  - Provides abstract logging interface for automation framework
  - Removes dependency on CyberMAX baseLog
  - Supports dependency injection for custom log handlers
  - Default implementation uses OutputDebugString

  USAGE:
    // Use default logging (OutputDebugString)
    Log(llInfo, 'Information message');
    Log(llWarning, 'Warning message');
    Log(llError, 'Error occurred');

    // Configure custom log handler
    AutomationLogHandler := procedure(Level: TLogLevel; const Msg: string)
    begin
      WriteLn(Format('[%s] %s', [LogLevelToString(Level), Msg]));
    end;

  MIGRATION FROM baseLog:
    baseLog.RegistrarInformacion(Msg) → Log(llInfo, Msg)
    baseLog.RegistrarError(Msg) → Log(llError, Msg)
    baseLog.RegistrarAdvertencia(Msg) → Log(llWarning, Msg)
}

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  /// <summary>
  /// Log severity level
  /// </summary>
  TLogLevel = (
    llDebug,    // Detailed debugging information
    llInfo,     // General informational messages
    llWarning,  // Warning messages (non-critical)
    llError     // Error messages (critical)
  );

  /// <summary>
  /// Log handler callback signature
  /// </summary>
  /// <param name="Level">Severity level of the log message</param>
  /// <param name="Message">Log message text</param>
  TLogHandler = reference to procedure(Level: TLogLevel; const Message: string);

var
  /// <summary>
  /// Global log handler - can be replaced via dependency injection
  /// </summary>
  AutomationLogHandler: TLogHandler;

/// <summary>
/// Converts log level to string representation
/// </summary>
function LogLevelToString(Level: TLogLevel): string;

/// <summary>
/// Main logging procedure - routes to configured handler
/// </summary>
/// <param name="Level">Severity level</param>
/// <param name="Message">Message to log</param>
procedure Log(Level: TLogLevel; const Message: string);

/// <summary>
/// Convenience procedure for info-level logging
/// </summary>
procedure LogInfo(const Message: string); inline;

/// <summary>
/// Convenience procedure for warning-level logging
/// </summary>
procedure LogWarning(const Message: string); inline;

/// <summary>
/// Convenience procedure for error-level logging
/// </summary>
procedure LogError(const Message: string); inline;

/// <summary>
/// Convenience procedure for debug-level logging
/// </summary>
procedure LogDebug(const Message: string); inline;

implementation

/// <summary>
/// Default log handler - outputs to debugger via OutputDebugString
/// </summary>
procedure DefaultLogHandler(Level: TLogLevel; const Message: string);
var
  FormattedMsg: string;
begin
  FormattedMsg := Format('[Automation:%s] %s', [LogLevelToString(Level), Message]);
  OutputDebugString(PChar(FormattedMsg));
end;

function LogLevelToString(Level: TLogLevel): string;
begin
  case Level of
    llDebug:   Result := 'DEBUG';
    llInfo:    Result := 'INFO';
    llWarning: Result := 'WARNING';
    llError:   Result := 'ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

procedure Log(Level: TLogLevel; const Message: string);
begin
  if Assigned(AutomationLogHandler) then
    AutomationLogHandler(Level, Message)
  else
    DefaultLogHandler(Level, Message);
end;

procedure LogInfo(const Message: string);
begin
  Log(llInfo, Message);
end;

procedure LogWarning(const Message: string);
begin
  Log(llWarning, Message);
end;

procedure LogError(const Message: string);
begin
  Log(llError, Message);
end;

procedure LogDebug(const Message: string);
begin
  Log(llDebug, Message);
end;

initialization
  // Set default handler
  AutomationLogHandler := DefaultLogHandler;

end.
