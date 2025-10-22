unit MCPServer.Tool.Time;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  MCPServer.Tool.Base,
  MCPServer.Types;

type
  TTimeParams = class
  private
    FFormat: string;
    FTimeZone: string;
    FIncludeMilliseconds: Boolean;
  public
    [Optional]
    [SchemaDescription('Date/time format string (default: yyyy-mm-dd hh:nn:ss)')]
    property Format: string read FFormat write FFormat;
    
    [Optional]
    [SchemaDescription('Time zone offset in hours (e.g., "+2" or "-5")')]
    property TimeZone: string read FTimeZone write FTimeZone;
    
    [Optional]
    [SchemaDescription('Include milliseconds in the output')]
    property IncludeMilliseconds: Boolean read FIncludeMilliseconds write FIncludeMilliseconds;
  end;

  TTimeTool = class(TMCPToolBase<TTimeParams>)
  protected
    function ExecuteWithParams(const Params: TTimeParams): string; override;
  public
    constructor Create; override;
  end;

implementation

uses
  MCPServer.Registration;

{ TTimeTool }

constructor TTimeTool.Create;
begin
  inherited;
  FName := 'mcp_time';
  FDescription := 'Get current system time with optional formatting and timezone';
end;

function TTimeTool.ExecuteWithParams(const Params: TTimeParams): string;
var
  Response: TStringList;
  CurrentTime: TDateTime;
  FormattedTime: string;
  TimeFormat: string;
  OffsetHours: Integer;
begin
  Response := TStringList.Create;
  try
    CurrentTime := Now;
    
    // Apply timezone offset if specified
    if Params.TimeZone <> '' then
    begin
      try
        OffsetHours := StrToInt(Params.TimeZone);
        CurrentTime := IncHour(CurrentTime, OffsetHours);
      except
        // Invalid timezone, use local time
      end;
    end;
    
    // Determine format
    if Params.Format <> '' then
      TimeFormat := Params.Format
    else if Params.IncludeMilliseconds then
      TimeFormat := 'yyyy-mm-dd hh:nn:ss.zzz'
    else
      TimeFormat := 'yyyy-mm-dd hh:nn:ss';
    
    FormattedTime := FormatDateTime(TimeFormat, CurrentTime);
    
    Response.Add('===== Time Service =====');
    Response.Add('');
    Response.Add('Current Time: ' + FormattedTime);
    Response.Add('');
    Response.Add('Details:');
    Response.Add('  Date: ' + FormatDateTime('dddd, mmmm d, yyyy', CurrentTime));
    Response.Add('  Time: ' + FormatDateTime('hh:nn:ss AM/PM', CurrentTime));
    Response.Add('  Week: ' + IntToStr(WeekOf(CurrentTime)) + ' of ' + IntToStr(YearOf(CurrentTime)));
    Response.Add('  Day of Year: ' + IntToStr(DayOfTheYear(CurrentTime)));
    
    if Params.TimeZone <> '' then
      Response.Add('  Time Zone Offset: ' + Params.TimeZone + ' hours')
    else
      Response.Add('  Time Zone: Local system time');
      
    Response.Add('');
    Response.Add('ISO 8601: ' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', CurrentTime));
    Response.Add('Unix Timestamp: ' + IntToStr(DateTimeToUnix(CurrentTime)));
    Response.Add('========================');
    
    Result := Response.Text;
  finally
    Response.Free;
  end;
end;

initialization
  TMCPRegistry.RegisterTool('mcp_time',
    function: IMCPTool
    begin
      Result := TTimeTool.Create;
    end
  );

end.
