/// Indy Backend Adapter for Generic Tools
// - Wraps IMCPToolGeneric to work with the Indy-based MCP server
// - Converts between TJSONObject and string JSON
unit MCP.Tool.Adapter.Indy;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Rtti,
  MCPServer.Tool.Base,
  MCP.Tool.Generic;

type
  /// Adapter that wraps a generic tool for use with Indy backend
  // - Implements the IMCPTool interface expected by MCPServer.ToolsManager
  TMCPToolIndyAdapter = class(TInterfacedObject, IMCPTool)
  private
    FGenericTool: IMCPToolGeneric;
  public
    constructor Create(const AGenericTool: IMCPToolGeneric);

    // IMCPTool interface
    function GetName: string;
    function GetDescription: string;
    function GetInputSchema: TJSONObject;
    function GetOutputSchema: TJSONObject;
    function Execute(const Arguments: TJSONObject): TValue;

    property GenericTool: IMCPToolGeneric read FGenericTool;
  end;

/// Register a generic tool with the Indy MCP registry
// - ToolClass: Class of the generic tool to register
procedure RegisterGenericToolIndy(ToolClass: TMCPToolGenericClass);

/// Register all shared tools with the Indy MCP registry
procedure RegisterAllSharedToolsIndy;

implementation

uses
  MCPServer.Registration,
  // Shared tools
  MCP.Tool.Shared.Hello,
  MCP.Tool.Shared.Echo,
  MCP.Tool.Shared.Time,
  MCP.Tool.Shared.StartDebugCapture,
  MCP.Tool.Shared.StopDebugCapture,
  MCP.Tool.Shared.GetDebugMessages,
  MCP.Tool.Shared.GetCaptureStatus,
  MCP.Tool.Shared.GetProcessSummary,
  MCP.Tool.Shared.PauseResumeCapture;

{ TMCPToolIndyAdapter }

constructor TMCPToolIndyAdapter.Create(const AGenericTool: IMCPToolGeneric);
begin
  inherited Create;
  FGenericTool := AGenericTool;
end;

function TMCPToolIndyAdapter.GetName: string;
begin
  Result := FGenericTool.GetName;
end;

function TMCPToolIndyAdapter.GetDescription: string;
begin
  Result := FGenericTool.GetDescription;
end;

function TMCPToolIndyAdapter.GetInputSchema: TJSONObject;
var
  SchemaJson: string;
begin
  SchemaJson := FGenericTool.GetInputSchema;
  Result := TJSONObject.ParseJSONValue(SchemaJson) as TJSONObject;
  if Result = nil then
    Result := TJSONObject.Create;
end;

function TMCPToolIndyAdapter.GetOutputSchema: TJSONObject;
begin
  // Generic tools don't have output schema
  Result := nil;
end;

function TMCPToolIndyAdapter.Execute(const Arguments: TJSONObject): TValue;
var
  ArgsJson: string;
  ResultJson: string;
  ResultObj: TJSONValue;
  ContentArray: TJSONArray;
  ContentItem: TJSONObject;
  TextValue: TJSONValue;
  ResultText: string;
begin
  // Convert TJSONObject to string
  if Assigned(Arguments) then
    ArgsJson := Arguments.ToJSON
  else
    ArgsJson := '{}';

  // Execute generic tool
  ResultJson := FGenericTool.Execute(ArgsJson);

  // The generic tool returns a JSON string with {content: [...], isError: bool}
  // We need to extract just the text for the Indy backend
  ResultObj := TJSONObject.ParseJSONValue(ResultJson);
  try
    if Assigned(ResultObj) and (ResultObj is TJSONObject) then
    begin
      ContentArray := TJSONObject(ResultObj).GetValue('content') as TJSONArray;
      if Assigned(ContentArray) and (ContentArray.Count > 0) then
      begin
        ContentItem := ContentArray.Items[0] as TJSONObject;
        if Assigned(ContentItem) then
        begin
          TextValue := ContentItem.GetValue('text');
          if Assigned(TextValue) then
          begin
            ResultText := TextValue.Value;
            Result := TValue.From<string>(ResultText);
            Exit;
          end;
        end;
      end;
    end;
    // Fallback: return raw result
    Result := TValue.From<string>(ResultJson);
  finally
    ResultObj.Free;
  end;
end;

{ Registration helpers }

procedure RegisterGenericToolIndy(ToolClass: TMCPToolGenericClass);
var
  ToolInstance: TMCPToolGenericBase;
  ToolName: string;
begin
  // Create instance to get the name
  ToolInstance := ToolClass.Create;
  try
    ToolName := ToolInstance.GetName;
  finally
    ToolInstance.Free;
  end;

  // Register factory that creates adapter wrapping the generic tool
  TMCPRegistry.RegisterTool(ToolName,
    function: IMCPTool
    var
      GenericTool: IMCPToolGeneric;
    begin
      GenericTool := ToolClass.Create;
      Result := TMCPToolIndyAdapter.Create(GenericTool);
    end
  );
end;

procedure RegisterAllSharedToolsIndy;
begin
  // Register all 9 shared tools with the Indy backend
  // Utility tools (3)
  RegisterGenericToolIndy(TMCPToolSharedHello);
  RegisterGenericToolIndy(TMCPToolSharedEcho);
  RegisterGenericToolIndy(TMCPToolSharedTime);
  // Debug Capture tools (6)
  RegisterGenericToolIndy(TMCPToolSharedStartDebugCapture);
  RegisterGenericToolIndy(TMCPToolSharedStopDebugCapture);
  RegisterGenericToolIndy(TMCPToolSharedGetDebugMessages);
  RegisterGenericToolIndy(TMCPToolSharedGetCaptureStatus);
  RegisterGenericToolIndy(TMCPToolSharedGetProcessSummary);
  RegisterGenericToolIndy(TMCPToolSharedPauseResumeCapture);
end;

end.
