# DelphiMCP Dynamic Proxy Architecture

## Overview

The DelphiMCP Bridge uses a **dynamic proxy architecture** that automatically discovers and exposes all tools registered in the target application's runtime registry. This eliminates the need for hardcoded tool implementations in the bridge.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude Code (AI)                     │
└─────────────────────────┬───────────────────────────────────┘
                          │ MCP over HTTP
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              DelphiMCPserver.exe (Bridge)                   │
│                                                             │
│  Startup:                                                   │
│  1. Query target application 'list-tools'                   │
│  2. Parse tool metadata (name, description, schema)         │
│  3. Dynamically register all tools with HTTP MCP server     │
│                                                             │
│  Execution:                                                 │
│  - Generic executor forwards all tool calls to target app   │
└─────────────────────────┬───────────────────────────────────┘
                          │ Named Pipe: \\.\pipe\YourApp_MCP_Request
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     YourApp.exe (Target)                    │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │         MCPToolRegistry (Runtime Registry)          │   │
│   │                                                     │   │
│   │  Core Tools:                                        │   │
│   │  - take-screenshot                                  │   │
│   │  - execute-command                                  │   │
│   │  - list-forms                                       │   │
│   │  - ... etc                                          │   │
│   │                                                     │   │
│   │  Module Tools (Unlimited):                          │   │
│   │  - get-customer-list     (Customers)                │   │
│   │  - check-inventory       (Warehouse)                │   │
│   │  - generate-report       (Reporting)                │   │
│   │  - ... any module can register tools                │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                             │
│   list-tools → Returns all registered tools with metadata   │
│   <tool-name> → Executes specific tool                      │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### 1. Target Application Side: Tool Registration

Modules register tools in their initialization:

```pascal
// In a module's initialization section:
procedure RegisterCustomerMCPTools;
begin
  MCPTools.RegisterTool(
    'get-customer-list',                    // Tool name
    @Tool_GetCustomerList,                  // Implementation function
    'Get list of customers',                // Description
    'customers',                            // Category
    'CustomerModule'                        // Module name
  );
end;

initialization
  RegisterCustomerMCPTools;
```

### 2. Bridge Side: Dynamic Discovery

The bridge queries the target application at startup:

```pascal
// DelphiMCPserver.dpr startup:
procedure RunServer;
begin
  // ... setup ...

  // Discover and register application tools dynamically
  var ToolCount := RegisterAllApplicationTools;

  // Start HTTP MCP server
  Server.Start;
end;

// MCPServer.Application.DynamicProxy.pas:
function RegisterAllApplicationTools: Integer;
begin
  // 1. Query target application for all registered tools
  PipeResult := ExecuteApplicationTool('list-tools', nil);

  // 2. Parse response
  ToolsArray := ExtractToolsArray(PipeResult);

  // 3. Register each tool dynamically
  for Tool in ToolsArray do
  begin
    TMCPRegistry.RegisterTool(
      Tool.Name,
      function: IMCPTool
      begin
        Result := TApplicationDynamicTool.Create(Tool.Name, Tool.Description);
      end
    );
  end;
end;
```

### 3. Execution Flow

When Claude Code calls a tool:

```
1. Claude Code: "Use get-customer-list with status=active"
   ↓
2. HTTP MCP Server: Receives tools/call request
   ↓
3. TApplicationDynamicTool.ExecuteWithParams:
   - Forwards to target application via named pipe
   - Sends: {"method":"get-customer-list","params":{"status":"active"}}
   ↓
4. Target Application MCP Server Thread:
   - Receives via pipe
   - Looks up tool in registry
   - Executes: Tool_GetCustomerList(Params)
   - Returns result via pipe
   ↓
5. Bridge: Returns result to Claude Code
```

## Key Components

### MCPServer.Application.PipeClient.pas

Handles named pipe communication:

```pascal
function ExecuteApplicationTool(const ToolName: string; Params: TJSONObject): TApplicationPipeResult;
```

- Connects to `\\.\pipe\YourApp_MCP_Request`
- Sends JSON-RPC 2.0 requests
- Receives and parses responses
- Handles errors and timeouts

### MCPServer.Application.DynamicProxy.pas

Dynamic tool discovery and registration:

```pascal
type
  TApplicationDynamicTool = class(TMCPToolBase<TJSONObject>)
  private
    FApplicationToolName: string;
  protected
    function ExecuteWithParams(const Params: TJSONObject): string; override;
  end;

function RegisterAllApplicationTools: Integer;
function GetApplicationToolCount: Integer;
```

**Features:**
- Queries `list-tools` from target application
- Parses tool metadata (name, description, category, module)
- Dynamically creates and registers tool wrappers
- Generic executor forwards all calls
- Graceful handling when target application not running

## Benefits

### ✅ Zero Maintenance

Module developers register tools in the target application, bridge discovers automatically:

```pascal
// Developer adds this to their module:
MCPTools.RegisterTool('new-awesome-tool', @MyFunction, 'Description', 'category', 'MyModule');

// Bridge automatically:
// - Discovers the tool on next startup
// - Exposes it via HTTP MCP
// - Routes calls to target application
// NO BRIDGE CODE CHANGES NEEDED!
```

### ✅ Single Source of Truth

Tools are defined once in the target application:

```
Before (Hardcoded):
  Target App: MCPTools.RegisterTool('take-screenshot', ...)
  Bridge:     MCPServer.Tool.TakeScreenshot.pas  ← Duplication!

After (Dynamic):
  Target App: MCPTools.RegisterTool('take-screenshot', ...)
  Bridge:     Automatically discovered             ✓ Single definition
```

### ✅ Unlimited Scalability

Any number of tools from any number of modules:

```
Core Module: 10 tools
Customer Module: 5 tools
Inventory Module: 8 tools
Reporting Module: 12 tools
Custom Module: 20 tools
─────────────────────────────
Total: 55 tools (automatically available)
```

### ✅ Simplified Codebase

**Before:**
- 16 files (1 pipe client + 15 hardcoded tools)
- ~1,500 lines of duplicated code
- Maintenance burden

**After:**
- 2 files (1 pipe client + 1 dynamic proxy)
- ~250 lines of generic code
- Zero maintenance

**88% code reduction!**

## How to Add New Tools

### For Module Developers

1. **Create tool implementation** in your module:

```pascal
// In your module (e.g., CustomerModule):
unit CustomerModule.MCP.Tools;

function Tool_GetCustomerList(const Params: TJSONObject): TJSONValue;
var
  Status: string;
  Customers: TJSONArray;
begin
  // Extract parameters
  Status := Params.GetValue<string>('status', 'active');

  // Execute business logic
  Customers := FetchCustomersByStatus(Status);

  // Return result as JSON
  Result := TJSONObject.Create;
  TJSONObject(Result).AddPair('status', Status);
  TJSONObject(Result).AddPair('customers', Customers);
end;
```

2. **Register tool** in initialization:

```pascal
initialization
  MCPTools.RegisterTool(
    'get-customer-list',                    // Unique tool name
    @Tool_GetCustomerList,                  // Function pointer
    'Get list of customers by status',      // Description
    'customers',                            // Category
    'CustomerModule'                        // Module name
  );
```

3. **Done!** The tool is now available:
   - Target application can call it via internal API
   - Bridge discovers it automatically on startup
   - Claude Code can call it via HTTP MCP

### Tool Naming Conventions

- Use lowercase with hyphens: `get-customer-list`
- Be descriptive but concise: `check-inventory` not `check-current-inventory-level-for-product`
- Namespace if needed: `customer-get-list` or `get-customer-list`

### Parameter Schema

Tools receive a `TJSONObject` with parameters:

```pascal
function MyTool(const Params: TJSONObject): TJSONValue;
var
  RequiredParam: string;
  OptionalParam: Integer;
begin
  // Required parameter (will raise exception if missing)
  RequiredParam := Params.GetValue<string>('required_param');

  // Optional parameter (returns default if missing)
  OptionalParam := Params.GetValue<Integer>('optional_param', 0);

  // ... implementation ...
end;
```

### Return Values

Tools return `TJSONValue` (object, array, string, number, etc.):

```pascal
// Return object
Result := TJSONObject.Create;
TJSONObject(Result).AddPair('status', 'success');
TJSONObject(Result).AddPair('data', DataArray);

// Return array
Result := TJSONArray.Create;
for Item in Items do
  TJSONArray(Result).Add(ItemToJSON(Item));

// Return simple value
Result := TJSONString.Create('Operation completed');
```

## Startup Behavior

### With Target Application Running

```
Starting DelphiMCP Bridge Server...
Listening on port 3001
Discovering application tools...
  Registered: take-screenshot (visual, core)
  Registered: execute-command (execution, core)
  Registered: list-forms (discovery, core)
  Registered: get-customer-list (customers, CustomerModule)
  Registered: check-inventory (inventory, InventoryModule)
  ... (all registered tools)
Successfully registered 15 application tools

Server started successfully!

Available tools:
  Basic Tools:
    - mcp_hello, mcp_echo, mcp_time

  Debug Capture Tools:
    - start_debug_capture, stop_debug_capture, etc.

  Application Tools: 15 tools discovered and registered
    (All tools are dynamically discovered from running application)
    Use MCP tools/list endpoint to see all available tools

Press CTRL+C to stop...
```

### Without Target Application Running

```
Starting DelphiMCP Bridge Server...
Listening on port 3001
Discovering application tools...
Target application is not running - tools cannot be discovered
Start YourApp.exe and restart this server
No application tools registered (target application may not be running)

Server started successfully!

Available tools:
  Basic Tools:
    - mcp_hello, mcp_echo, mcp_time

  Debug Capture Tools:
    - start_debug_capture, stop_debug_capture, etc.

  Application Tools: Not available
    Start YourApp.exe and restart this server to enable

Press CTRL+C to stop...
```

## Error Handling

### Target Application Not Running

Tools return clear error messages:

```
Error: Target application is not running or MCP server is not enabled.
Please start YourApp.exe and restart this MCP server.
```

### Tool Execution Fails

Errors from target application are forwarded:

```
Error from application: Customer '99999999' not found
```

### Pipe Communication Fails

Connection errors are reported:

```
Failed to send request to application (Error: 2)
Failed to read response from application (Error: 109)
```

## Configuration

### Target Application Side

Tools are registered in module initialization sections. No configuration files needed.

### Bridge Side

Server settings in `DelphiMCPserver.dpr`:

```pascal
Settings := TMCPSettings.Create;
Settings.Port := 3001;  // HTTP server port
```

### Pipe Settings

Defined in `MCPServer.Application.PipeClient.pas`:

```pascal
const
  PIPE_NAME = '\\.\pipe\YourApp_MCP_Request';  // Named pipe
  PIPE_TIMEOUT_MS = 5000;                       // 5 second timeout
```

## Troubleshooting

### Bridge shows "0 tools discovered"

**Causes:**
1. Target application not running
2. Target application MCP server not enabled/configured
3. Named pipe not accessible

**Solutions:**
- Start YourApp.exe
- Verify MCP server is enabled in target application
- Check Windows Event Viewer for pipe errors

### Tool calls fail with "Target application is not running"

**Cause:** Target application was running at bridge startup but has since stopped/crashed

**Solution:** Restart the bridge after restarting the target application

### Tools discovered but calls timeout

**Causes:**
1. Target application frozen/hung
2. Tool implementation has infinite loop
3. Pipe buffer full

**Solutions:**
- Check target application UI is responsive
- Debug tool implementation
- Restart both target application and bridge

## Performance

### Startup Time

- Without target application: ~100ms (pipe connection attempt fails fast)
- With target application (20 tools): ~200ms (query + parse + register)
- With target application (100 tools): ~500ms (scales linearly)

### Execution Overhead

Per tool call:
- Pipe communication: ~5ms
- JSON serialization: ~1ms
- Bridge routing: <1ms

**Total overhead: ~7ms** (negligible compared to tool execution time)

## Security Considerations

### Named Pipe Security

- Pipe is local-only (`\\.\pipe\`)
- No network exposure
- Accessible only to processes on same machine
- Requires both applications running under same user

### Tool Authorization

Tools should implement their own authorization:

```pascal
function Tool_SensitiveOperation(const Params: TJSONObject): TJSONValue;
begin
  // Check permissions before executing
  if not UserHasPermission(CurrentUser, 'sensitive_operation') then
  begin
    Result := TJSONObject.Create;
    TJSONObject(Result).AddPair('error', 'Permission denied');
    Exit;
  end;

  // ... execute operation ...
end;
```

### Input Validation

Always validate parameters:

```pascal
function Tool_Example(const Params: TJSONObject): TJSONValue;
var
  Account: string;
begin
  // Validate required parameters
  if not Params.TryGetValue<string>('account', Account) then
    raise Exception.Create('Parameter "account" is required');

  // Validate format
  if not IsValidAccountNumber(Account) then
    raise Exception.Create('Invalid account number format');

  // ... safe to execute ...
end;
```

## Best Practices

### Tool Design

✅ **DO:**
- Keep tools focused (single responsibility)
- Use clear, descriptive names
- Validate all inputs
- Return structured JSON
- Handle errors gracefully
- Log operations for debugging

❌ **DON'T:**
- Create tools with side effects without clear documentation
- Use generic names like "process" or "execute"
- Assume parameters are present
- Return raw strings (use JSON objects)
- Ignore errors

### Parameter Design

✅ **DO:**
- Use snake_case for parameter names: `account_number`
- Provide defaults for optional parameters
- Document parameter types and formats
- Validate ranges and formats

❌ **DON'T:**
- Use ambiguous names: `id`, `data`, `value`
- Make everything required
- Accept arbitrary types
- Skip validation

### Return Value Design

✅ **DO:**
- Return consistent structure
- Include status/success indicators
- Provide error details
- Use appropriate JSON types

❌ **DON'T:**
- Mix return types based on success/failure
- Return HTML or complex formatted strings
- Embed errors in data structure

## Examples

### Simple Tool (Return Value)

```pascal
function Tool_GetSystemTime(const Params: TJSONObject): TJSONValue;
begin
  Result := TJSONObject.Create;
  TJSONObject(Result).AddPair('timestamp', DateTimeToStr(Now));
  TJSONObject(Result).AddPair('timezone', 'UTC+1');
end;
```

### Complex Tool (With Parameters)

```pascal
function Tool_GenerateReport(const Params: TJSONObject): TJSONValue;
var
  ReportType, DateFrom, DateTo: string;
  IncludeDetails: Boolean;
  ReportData: TJSONArray;
begin
  // Extract parameters
  ReportType := Params.GetValue<string>('report_type');
  DateFrom := Params.GetValue<string>('date_from');
  DateTo := Params.GetValue<string>('date_to', DateTimeToStr(Now));
  IncludeDetails := Params.GetValue<Boolean>('include_details', False);

  // Validate
  if not IsValidReportType(ReportType) then
    raise Exception.Create('Invalid report type: ' + ReportType);

  // Generate report
  ReportData := GenerateReportData(ReportType, DateFrom, DateTo, IncludeDetails);

  // Return result
  Result := TJSONObject.Create;
  TJSONObject(Result).AddPair('report_type', ReportType);
  TJSONObject(Result).AddPair('period', DateFrom + ' - ' + DateTo);
  TJSONObject(Result).AddPair('data', ReportData);
  TJSONObject(Result).AddPair('generated_at', DateTimeToStr(Now));
end;
```

### Tool with Error Handling

```pascal
function Tool_ProcessInvoice(const Params: TJSONObject): TJSONValue;
var
  InvoiceID: string;
  Invoice: TInvoice;
begin
  Result := TJSONObject.Create;

  try
    // Get invoice ID
    InvoiceID := Params.GetValue<string>('invoice_id');

    // Load invoice
    Invoice := LoadInvoice(InvoiceID);
    if Invoice = nil then
    begin
      TJSONObject(Result).AddPair('success', TJSONBool.Create(False));
      TJSONObject(Result).AddPair('error', 'Invoice not found: ' + InvoiceID);
      Exit;
    end;

    // Process invoice
    ProcessInvoice(Invoice);

    // Success
    TJSONObject(Result).AddPair('success', TJSONBool.Create(True));
    TJSONObject(Result).AddPair('invoice_id', InvoiceID);
    TJSONObject(Result).AddPair('status', Invoice.Status);

  except
    on E: Exception do
    begin
      TJSONObject(Result).AddPair('success', TJSONBool.Create(False));
      TJSONObject(Result).AddPair('error', E.Message);
    end;
  end;
end;
```

## Future Enhancements

### Potential Improvements

1. **Hot Reload**: Detect when target application restarts and re-discover tools
2. **Tool Versioning**: Support multiple versions of the same tool
3. **Schema Validation**: Enforce parameter types at bridge level
4. **Caching**: Cache tool metadata to reduce startup time
5. **Metrics**: Track tool usage, execution time, error rates
6. **Tool Categories**: Better organization in MCP tools/list response

### Not Planned

❌ **Bidirectional Communication**: Tools can't push data to bridge (request/response only)
❌ **Streaming Results**: Large results must be buffered (no streaming)
❌ **Tool Composition**: Tools can't call other tools directly

## Related Documentation

- **DelphiMCP README**: `README.md`
- **Architecture Guide**: `ARCHITECTURE.md`
- **Setup Guide**: `SETUP-GUIDE.md`
- **Debug Capture System**: `DEBUG-CAPTURE.md`

---

**Version**: 2.0
**Last Updated**: 2025-10-11
**Status**: Production
**Architecture**: Dynamic Discovery
