unit AutomationToolRegistry;

{
  Automation Tool Registry - Runtime Registration System for Automation Tools

  PURPOSE:
  - Allows modules to register their own automation tools at runtime
  - Decouples tool implementations from AutomationServerThread
  - Enables modular, extensible automation functionality
  - Supports tool discovery and metadata

  ARCHITECTURE:
  - Singleton registry pattern
  - Thread-safe registration and lookup
  - Tool handlers executed via callbacks
  - JSON-RPC request/response abstraction

  USAGE:
  Module initialization:
    AutomationToolRegistry.RegisterTool('my-tool', @MyToolHandler, 'My tool description');

  Tool handler signature:
    procedure MyToolHandler(const Params: TJSONObject; out Result: TJSONObject);

  ORIGIN:
  - Extracted from CyberMAX MCP implementation
  - Originally MCPToolRegistry.pas (generic design, no changes needed)
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.SyncObjs;

type
  // Tool handler callback type
  TAutomationToolHandler = reference to procedure(const Params: TJSONObject; out Result: TJSONObject);

  // Tool metadata
  TAutomationToolInfo = record
    Name: string;
    Handler: TAutomationToolHandler;
    Description: string;
    Category: string;       // e.g., 'visual', 'interaction', 'discovery', 'database'
    Module: string;         // Module that registered the tool (e.g., 'core', 'TCConta', 'Almacen')
    Schema: TJSONObject;    // JSON Schema for tool parameters (owned by record)
    RegisteredAt: TDateTime;

    class function Create(const AName: string; AHandler: TAutomationToolHandler;
      const ADescription, ACategory, AModule: string; ASchema: TJSONObject = nil): TAutomationToolInfo; static;
  end;

  // Tool registry (singleton)
  TAutomationToolRegistry = class
  private
    class var FInstance: TAutomationToolRegistry;
    class constructor Create;
    class destructor Destroy;
  private
    FTools: TDictionary<string, TAutomationToolInfo>;  // Key: lowercase tool name
    FAliases: TDictionary<string, string>;      // Key: alias -> Value: canonical name
    FLock: TCriticalSection;

  public
    constructor Create;
    destructor Destroy; override;
  private

    function NormalizeName(const Name: string): string;
  public
    class function Instance: TAutomationToolRegistry;

    // Registration
    procedure RegisterTool(const Name: string; Handler: TAutomationToolHandler;
      const Description: string = ''; const Category: string = 'other';
      const Module: string = 'core'; Schema: TJSONObject = nil);
    procedure RegisterAlias(const Alias, CanonicalName: string);
    procedure UnregisterTool(const Name: string);

    // Lookup
    function FindTool(const Name: string; out ToolInfo: TAutomationToolInfo): Boolean;
    function ToolExists(const Name: string): Boolean;
    function GetToolNames: TArray<string>;
    function GetToolsByCategory(const Category: string): TArray<TAutomationToolInfo>;
    function GetToolsByModule(const Module: string): TArray<TAutomationToolInfo>;

    // Execution (calls handler with thread-safety)
    procedure ExecuteTool(const Name: string; const Params: TJSONObject; out Result: TJSONObject);

    // Metadata
    function GetToolCount: Integer;
    function GetCategoryCount: TDictionary<string, Integer>;
    function GetModuleCount: TDictionary<string, Integer>;

    // Discovery (returns JSON for list-tools automation command)
    function GetToolListJSON: string;
  end;

// Global accessor
function AutomationTools: TAutomationToolRegistry;

implementation

uses
  System.DateUtils;

{ Helper functions }

function AutomationTools: TAutomationToolRegistry;
begin
  Result := TAutomationToolRegistry.Instance;
end;

{ TAutomationToolInfo }

class function TAutomationToolInfo.Create(const AName: string; AHandler: TAutomationToolHandler;
  const ADescription, ACategory, AModule: string; ASchema: TJSONObject = nil): TAutomationToolInfo;
begin
  Result.Name := AName;
  Result.Handler := AHandler;
  Result.Description := ADescription;
  Result.Category := ACategory;
  Result.Module := AModule;
  Result.Schema := ASchema;  // Takes ownership
  Result.RegisteredAt := Now;
end;

{ TAutomationToolRegistry }

class constructor TAutomationToolRegistry.Create;
begin
  FInstance := nil;  // Lazy initialization
end;

class destructor TAutomationToolRegistry.Destroy;
begin
  if Assigned(FInstance) then
    FreeAndNil(FInstance);
end;

constructor TAutomationToolRegistry.Create;
begin
  inherited Create;
  FTools := TDictionary<string, TAutomationToolInfo>.Create;
  FAliases := TDictionary<string, string>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TAutomationToolRegistry.Destroy;
var
  ToolInfo: TAutomationToolInfo;
begin
  // Free all schemas
  if Assigned(FTools) then
  begin
    FLock.Enter;
    try
      for ToolInfo in FTools.Values do
        if Assigned(ToolInfo.Schema) then
          ToolInfo.Schema.Free;
    finally
      FLock.Leave;
    end;
  end;

  FreeAndNil(FLock);
  FreeAndNil(FAliases);
  FreeAndNil(FTools);
  inherited;
end;

class function TAutomationToolRegistry.Instance: TAutomationToolRegistry;
begin
  if FInstance = nil then
    FInstance := TAutomationToolRegistry.Create;
  Result := FInstance;
end;

function TAutomationToolRegistry.NormalizeName(const Name: string): string;
begin
  Result := LowerCase(Trim(Name));
end;

procedure TAutomationToolRegistry.RegisterTool(const Name: string; Handler: TAutomationToolHandler;
  const Description: string = ''; const Category: string = 'other';
  const Module: string = 'core'; Schema: TJSONObject = nil);
var
  NormalizedName: string;
  ToolInfo: TAutomationToolInfo;
  OldInfo: TAutomationToolInfo;
begin
  if not Assigned(Handler) then
    raise Exception.Create('Tool handler cannot be nil');

  NormalizedName := NormalizeName(Name);
  if NormalizedName = '' then
    raise Exception.Create('Tool name cannot be empty');

  FLock.Enter;
  try
    // If replacing existing tool, free its schema
    if FTools.TryGetValue(NormalizedName, OldInfo) then
      if Assigned(OldInfo.Schema) then
        OldInfo.Schema.Free;

    // Create tool info
    ToolInfo := TAutomationToolInfo.Create(Name, Handler, Description, Category, Module, Schema);

    // Register (replace if already exists)
    FTools.AddOrSetValue(NormalizedName, ToolInfo);

    OutputDebugString(PChar(Format('Automation.Registry: Registered tool "%s" [%s/%s]',
      [Name, Module, Category])));
  finally
    FLock.Leave;
  end;
end;

procedure TAutomationToolRegistry.RegisterAlias(const Alias, CanonicalName: string);
var
  NormalizedAlias, NormalizedCanonical: string;
begin
  NormalizedAlias := NormalizeName(Alias);
  NormalizedCanonical := NormalizeName(CanonicalName);

  if (NormalizedAlias = '') or (NormalizedCanonical = '') then
    raise Exception.Create('Alias and canonical name cannot be empty');

  FLock.Enter;
  try
    if not FTools.ContainsKey(NormalizedCanonical) then
      raise Exception.CreateFmt('Cannot create alias "%s" - tool "%s" not registered',
        [Alias, CanonicalName]);

    FAliases.AddOrSetValue(NormalizedAlias, NormalizedCanonical);

    OutputDebugString(PChar(Format('Automation.Registry: Registered alias "%s" -> "%s"',
      [Alias, CanonicalName])));
  finally
    FLock.Leave;
  end;
end;

procedure TAutomationToolRegistry.UnregisterTool(const Name: string);
var
  NormalizedName: string;
  AliasesToRemove: TList<string>;
  Alias: string;
  ToolInfo: TAutomationToolInfo;
begin
  NormalizedName := NormalizeName(Name);

  FLock.Enter;
  try
    if FTools.TryGetValue(NormalizedName, ToolInfo) then
    begin
      // Free schema if present
      if Assigned(ToolInfo.Schema) then
        ToolInfo.Schema.Free;

      FTools.Remove(NormalizedName);

      // Remove aliases pointing to this tool
      AliasesToRemove := TList<string>.Create;
      try
        for Alias in FAliases.Keys do
          if FAliases[Alias] = NormalizedName then
            AliasesToRemove.Add(Alias);

        for Alias in AliasesToRemove do
          FAliases.Remove(Alias);
      finally
        AliasesToRemove.Free;
      end;

      OutputDebugString(PChar(Format('Automation.Registry: Unregistered tool "%s"', [Name])));
    end;
  finally
    FLock.Leave;
  end;
end;

function TAutomationToolRegistry.FindTool(const Name: string; out ToolInfo: TAutomationToolInfo): Boolean;
var
  NormalizedName, CanonicalName: string;
begin
  Result := False;
  NormalizedName := NormalizeName(Name);

  FLock.Enter;
  try
    // Try direct lookup
    if FTools.TryGetValue(NormalizedName, ToolInfo) then
      Exit(True);

    // Try alias lookup
    if FAliases.TryGetValue(NormalizedName, CanonicalName) then
    begin
      if FTools.TryGetValue(CanonicalName, ToolInfo) then
        Exit(True);
    end;
  finally
    FLock.Leave;
  end;
end;

function TAutomationToolRegistry.ToolExists(const Name: string): Boolean;
var
  ToolInfo: TAutomationToolInfo;
begin
  Result := FindTool(Name, ToolInfo);
end;

function TAutomationToolRegistry.GetToolNames: TArray<string>;
var
  Names: TList<string>;
  ToolInfo: TAutomationToolInfo;
begin
  Names := TList<string>.Create;
  try
    FLock.Enter;
    try
      for ToolInfo in FTools.Values do
        Names.Add(ToolInfo.Name);
    finally
      FLock.Leave;
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

function TAutomationToolRegistry.GetToolsByCategory(const Category: string): TArray<TAutomationToolInfo>;
var
  Tools: TList<TAutomationToolInfo>;
  ToolInfo: TAutomationToolInfo;
  NormalizedCategory: string;
begin
  NormalizedCategory := LowerCase(Trim(Category));
  Tools := TList<TAutomationToolInfo>.Create;
  try
    FLock.Enter;
    try
      for ToolInfo in FTools.Values do
        if LowerCase(ToolInfo.Category) = NormalizedCategory then
          Tools.Add(ToolInfo);
    finally
      FLock.Leave;
    end;

    Result := Tools.ToArray;
  finally
    Tools.Free;
  end;
end;

function TAutomationToolRegistry.GetToolsByModule(const Module: string): TArray<TAutomationToolInfo>;
var
  Tools: TList<TAutomationToolInfo>;
  ToolInfo: TAutomationToolInfo;
  NormalizedModule: string;
begin
  NormalizedModule := LowerCase(Trim(Module));
  Tools := TList<TAutomationToolInfo>.Create;
  try
    FLock.Enter;
    try
      for ToolInfo in FTools.Values do
        if LowerCase(ToolInfo.Module) = NormalizedModule then
          Tools.Add(ToolInfo);
    finally
      FLock.Leave;
    end;

    Result := Tools.ToArray;
  finally
    Tools.Free;
  end;
end;

procedure TAutomationToolRegistry.ExecuteTool(const Name: string; const Params: TJSONObject;
  out Result: TJSONObject);
var
  ToolInfo: TAutomationToolInfo;
begin
  if not FindTool(Name, ToolInfo) then
    raise Exception.CreateFmt('Tool not found: %s', [Name]);

  // Execute handler (handler is responsible for thread safety if needed)
  ToolInfo.Handler(Params, Result);
end;

function TAutomationToolRegistry.GetToolCount: Integer;
begin
  FLock.Enter;
  try
    Result := FTools.Count;
  finally
    FLock.Leave;
  end;
end;

function TAutomationToolRegistry.GetCategoryCount: TDictionary<string, Integer>;
var
  ToolInfo: TAutomationToolInfo;
  Count: Integer;
begin
  Result := TDictionary<string, Integer>.Create;

  FLock.Enter;
  try
    for ToolInfo in FTools.Values do
    begin
      if Result.TryGetValue(ToolInfo.Category, Count) then
        Result.AddOrSetValue(ToolInfo.Category, Count + 1)
      else
        Result.Add(ToolInfo.Category, 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TAutomationToolRegistry.GetModuleCount: TDictionary<string, Integer>;
var
  ToolInfo: TAutomationToolInfo;
  Count: Integer;
begin
  Result := TDictionary<string, Integer>.Create;

  FLock.Enter;
  try
    for ToolInfo in FTools.Values do
    begin
      if Result.TryGetValue(ToolInfo.Module, Count) then
        Result.AddOrSetValue(ToolInfo.Module, Count + 1)
      else
        Result.Add(ToolInfo.Module, 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TAutomationToolRegistry.GetToolListJSON: string;
var
  RootObj: TJSONObject;
  ToolsArray: TJSONArray;
  ToolObj: TJSONObject;
  ToolInfo: TAutomationToolInfo;
  CategoryCount, ModuleCount: TDictionary<string, Integer>;
  Category: string;
begin
  RootObj := TJSONObject.Create;
  try
    FLock.Enter;
    try
      // Overall stats
      RootObj.AddPair('total_tools', TJSONNumber.Create(FTools.Count));
      RootObj.AddPair('total_aliases', TJSONNumber.Create(FAliases.Count));

      // Category counts
      CategoryCount := GetCategoryCount;
      try
        for Category in CategoryCount.Keys do
          RootObj.AddPair('category_' + Category, TJSONNumber.Create(CategoryCount[Category]));
      finally
        CategoryCount.Free;
      end;

      // Module counts
      ModuleCount := GetModuleCount;
      try
        for Category in ModuleCount.Keys do
          RootObj.AddPair('module_' + Category, TJSONNumber.Create(ModuleCount[Category]));
      finally
        ModuleCount.Free;
      end;

      // Tools list
      ToolsArray := TJSONArray.Create;
      for ToolInfo in FTools.Values do
      begin
        ToolObj := TJSONObject.Create;
        ToolObj.AddPair('name', ToolInfo.Name);
        ToolObj.AddPair('description', ToolInfo.Description);
        ToolObj.AddPair('category', ToolInfo.Category);
        ToolObj.AddPair('module', ToolInfo.Module);
        ToolObj.AddPair('registered_at', DateTimeToStr(ToolInfo.RegisteredAt));

        // Add schema if present
        if Assigned(ToolInfo.Schema) then
          ToolObj.AddPair('schema', ToolInfo.Schema.Clone as TJSONObject)
        else
          ToolObj.AddPair('schema', TJSONNull.Create);

        ToolsArray.Add(ToolObj);
      end;
      RootObj.AddPair('tools', ToolsArray);
    finally
      FLock.Leave;
    end;

    Result := RootObj.ToString;
  finally
    RootObj.Free;
  end;
end;

end.
