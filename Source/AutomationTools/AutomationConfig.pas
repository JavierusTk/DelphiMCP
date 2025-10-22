unit AutomationConfig;

{
  Automation Framework - Configuration

  PURPOSE:
  - Centralized configuration for automation server
  - Type-safe configuration values
  - Validation and defaults
  - Reduces parameter passing complexity

  USAGE:
    var
      Config: TAutomationConfig;
    begin
      Config := TAutomationConfig.Default;
      Config.PipeName := '\\.\pipe\MyApp_Automation';
      Config.LogLevel := llDebug;

      if Config.IsValid then
        AutomationServer.Start(Config);
    end;
}

interface

uses
  System.SysUtils,
  AutomationLogger;

type
  /// <summary>
  /// Configuration record for automation server
  /// </summary>
  TAutomationConfig = record
    /// <summary>
    /// Named pipe name for MCP communication
    /// </summary>
    /// <remarks>
    /// Format: \\.\pipe\Name
    /// Default: \\.\pipe\DelphiApp_MCP_Request
    /// </remarks>
    PipeName: string;

    /// <summary>
    /// Timeout in milliseconds for pipe operations
    /// </summary>
    /// <remarks>
    /// Default: 30000 (30 seconds)
    /// </remarks>
    Timeout: Integer;

    /// <summary>
    /// Rate limit: Maximum requests per second
    /// </summary>
    /// <remarks>
    /// Default: 50 RPS
    /// Set to 0 to disable rate limiting
    /// </remarks>
    RateLimitRPS: Integer;

    /// <summary>
    /// Logging level for automation framework
    /// </summary>
    /// <remarks>
    /// Default: llInfo
    /// </remarks>
    LogLevel: TLogLevel;

    /// <summary>
    /// Enable modal-safe execution using AutomationBroker
    /// </summary>
    /// <remarks>
    /// Default: False (use TThread.Synchronize - faster, blocks on modals)
    /// Set to True for modal window support (uses PostMessage - slightly slower)
    /// </remarks>
    EnableModalSupport: Boolean;

    /// <summary>
    /// Creates default configuration
    /// </summary>
    class function Default: TAutomationConfig; static;

    /// <summary>
    /// Creates configuration for development/debugging
    /// </summary>
    /// <remarks>
    /// - Debug logging enabled
    /// - Increased timeout
    /// - No rate limiting
    /// </remarks>
    class function Debug: TAutomationConfig; static;

    /// <summary>
    /// Creates configuration for production
    /// </summary>
    /// <remarks>
    /// - Info logging
    /// - Standard timeout
    /// - Rate limiting enabled
    /// </remarks>
    class function Production: TAutomationConfig; static;

    /// <summary>
    /// Validates configuration values
    /// </summary>
    /// <returns>True if configuration is valid</returns>
    function IsValid: Boolean;

    /// <summary>
    /// Validates configuration and returns error message if invalid
    /// </summary>
    /// <param name="ErrorMsg">Error description if invalid</param>
    /// <returns>True if valid, False if invalid</returns>
    function Validate(out ErrorMsg: string): Boolean;
  end;

implementation

const
  DEFAULT_PIPE_NAME = '\\.\pipe\DelphiApp_MCP_Request';
  DEFAULT_TIMEOUT = 30000;  // 30 seconds
  DEFAULT_RATE_LIMIT = 50;  // 50 requests per second
  DEFAULT_LOG_LEVEL = llInfo;

  DEBUG_TIMEOUT = 120000;  // 2 minutes (for debugging)
  DEBUG_RATE_LIMIT = 0;    // No rate limiting in debug mode

  MIN_TIMEOUT = 1000;      // Minimum 1 second
  MAX_TIMEOUT = 600000;    // Maximum 10 minutes
  MIN_RATE_LIMIT = 0;      // 0 = disabled
  MAX_RATE_LIMIT = 1000;   // Maximum 1000 RPS

{ TAutomationConfig }

class function TAutomationConfig.Default: TAutomationConfig;
begin
  Result.PipeName := DEFAULT_PIPE_NAME;
  Result.Timeout := DEFAULT_TIMEOUT;
  Result.RateLimitRPS := DEFAULT_RATE_LIMIT;
  Result.LogLevel := DEFAULT_LOG_LEVEL;
  Result.EnableModalSupport := False;  // Backward compatible, better performance
end;

class function TAutomationConfig.Debug: TAutomationConfig;
begin
  Result.PipeName := DEFAULT_PIPE_NAME;
  Result.Timeout := DEBUG_TIMEOUT;
  Result.RateLimitRPS := DEBUG_RATE_LIMIT;
  Result.LogLevel := llDebug;
  Result.EnableModalSupport := True;  // Helpful for debugging with modal dialogs
end;

class function TAutomationConfig.Production: TAutomationConfig;
begin
  Result.PipeName := DEFAULT_PIPE_NAME;
  Result.Timeout := DEFAULT_TIMEOUT;
  Result.RateLimitRPS := DEFAULT_RATE_LIMIT;
  Result.LogLevel := llInfo;
  Result.EnableModalSupport := False;  // Performance over modal support in production
end;

function TAutomationConfig.IsValid: Boolean;
var
  ErrorMsg: string;
begin
  Result := Validate(ErrorMsg);
end;

function TAutomationConfig.Validate(out ErrorMsg: string): Boolean;
begin
  Result := False;
  ErrorMsg := '';

  // Validate pipe name
  if Trim(PipeName) = '' then
  begin
    ErrorMsg := 'PipeName cannot be empty';
    Exit;
  end;

  if not PipeName.StartsWith('\\.\pipe\') then
  begin
    ErrorMsg := 'PipeName must start with "\\.\pipe\"';
    Exit;
  end;

  // Validate timeout
  if (Timeout < MIN_TIMEOUT) or (Timeout > MAX_TIMEOUT) then
  begin
    ErrorMsg := Format('Timeout must be between %d and %d ms', [MIN_TIMEOUT, MAX_TIMEOUT]);
    Exit;
  end;

  // Validate rate limit
  if (RateLimitRPS < MIN_RATE_LIMIT) or (RateLimitRPS > MAX_RATE_LIMIT) then
  begin
    ErrorMsg := Format('RateLimitRPS must be between %d and %d', [MIN_RATE_LIMIT, MAX_RATE_LIMIT]);
    Exit;
  end;

  // All validation passed
  Result := True;
end;

end.
