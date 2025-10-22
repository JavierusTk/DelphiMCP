# Simple VCL App - MCP Integration Example

A minimal VCL application demonstrating how to integrate the DelphiMCP bridge server to enable AI-driven automation and control.

## Overview

This example shows how to:
- Embed an MCP server in a Delphi VCL application
- Create custom MCP tools for your application
- Handle named pipe communication with the bridge
- Enable Claude Code to interact with your application

## Application Structure

```
SimpleVCLApp/
├── SimpleVCLApp.dpr           # Main project file
├── SimpleVCLApp.dproj         # Delphi project configuration
├── MainForm.pas/dfm           # Main application form
├── CustomerForm.pas/dfm       # Customer management form (example)
├── MCPServerIntegration.pas   # MCP server implementation
└── README.md                  # This file
```

## Features

### Application Features
- **Main Form**: Simple UI with customer data entry and logging
- **Customer Form**: Grid-based customer list with search functionality
- **Activity Logging**: All operations logged with timestamps

### MCP Integration Features
- **Embedded MCP Server**: Named pipe server running in background thread
- **Custom Tools**: Application-specific tools accessible via MCP
- **JSON-RPC 2.0**: Standard protocol for tool communication

## Available MCP Tools

The application exposes these tools to Claude Code via the bridge:

1. **`list-tools`** - Returns list of all available tools
2. **`get-customer-count`** - Returns the total number of customers
3. **`get-app-info`** - Returns application name, version, and status

## How It Works

### Architecture

```
┌──────────────────┐
│   Claude Code    │  AI Assistant
└────────┬─────────┘
         │ HTTP/MCP
         ▼
┌──────────────────┐
│DelphiMCPserver   │  Bridge Server (port 3001)
└────────┬─────────┘
         │ Named Pipe: \\.\pipe\SimpleVCLApp_MCP_Request
         ▼
┌──────────────────┐
│ SimpleVCLApp.exe │  This Example Application
│  (VCL GUI)       │  - Embedded MCP Server
└──────────────────┘
```

### Key Components

#### 1. MCPServerIntegration.pas

This unit provides the MCP server implementation:

**Key Functions:**
- `StartMCPServer`: Initializes and starts the MCP server thread
- `StopMCPServer`: Gracefully stops the server
- `GetMCPPipeName`: Returns the named pipe identifier
- `IsMCPServerRunning`: Checks server status

**Implementation Details:**
- Creates a named pipe: `\\.\pipe\SimpleVCLApp_MCP_Request`
- Runs in a background thread (non-blocking)
- Handles JSON-RPC 2.0 requests
- Routes tool calls to appropriate handlers

#### 2. Tool Registration

Tools are registered in the `ProcessRequest` method:

```pascal
procedure TMCPServerThread.ProcessRequest(const Request: string; out Response: string);
begin
  // Parse JSON-RPC request
  Method := RequestJSON.GetValue<string>('method', '');

  // Route to appropriate tool handler
  if Method = 'get-customer-count' then
    // Handle tool execution
  else if Method = 'get-app-info' then
    // Handle tool execution
end;
```

#### 3. Application Integration

The main form initializes the MCP server on startup:

```pascal
procedure TfmMain.FormCreate(Sender: TObject);
begin
  if StartMCPServer then
    Log('MCP Server started successfully')
  else
    Log('Failed to start MCP Server');
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  StopMCPServer;
end;
```

## Building the Example

### Prerequisites

1. **Delphi 12** (RAD Studio 12) or later
2. **Windows** (named pipes are Windows-specific)

### Compilation

#### Using Delphi IDE:
1. Open `SimpleVCLApp.dproj` in Delphi IDE
2. Build → Build SimpleVCLApp
3. Run → Run (or F9)

#### Using Command Line:
```bash
cd /mnt/w/Public/DelphiMCP/Examples/SimpleVCLApp
dcc32 SimpleVCLApp.dpr
```

#### Using Claude Code:
```bash
/compile Examples/SimpleVCLApp/SimpleVCLApp.dproj
```

## Running the Example

### Step 1: Start the Application

```bash
cd /mnt/w/Public/DelphiMCP/Examples/SimpleVCLApp
./SimpleVCLApp.exe
```

**Expected behavior:**
- Application window opens
- Log shows "MCP Server started successfully"
- Named pipe `\\.\pipe\SimpleVCLApp_MCP_Request` is created

### Step 2: Start the Bridge Server

```bash
cd /mnt/w/Public/DelphiMCP/Binaries
./DelphiMCPserver.exe
```

**Expected output:**
```
DelphiMCP Bridge Server v2.1
Discovering application tools...
  Registered: get-customer-count (customers, SimpleVCLApp)
  Registered: get-app-info (system, SimpleVCLApp)
Successfully registered 2 application tools
Server started on port 3001
```

### Step 3: Configure Claude Code

Add to `~/.claude/mcp_servers.json`:

```json
{
  "mcpServers": {
    "simple-vcl-app": {
      "type": "http",
      "url": "http://localhost:3001/mcp",
      "description": "Simple VCL App Example"
    }
  }
}
```

### Step 4: Test with Claude Code

Ask Claude Code:

```
Use the get-app-info tool to show me information about the application
```

Claude should successfully call the tool and display:
```json
{
  "name": "SimpleVCLApp",
  "version": "1.0.0",
  "mcp_enabled": true
}
```

## Extending the Example

### Adding New Tools

1. **Define the tool handler** in `MCPServerIntegration.pas`:

```pascal
procedure TMCPServerThread.ProcessRequest(const Request: string; out Response: string);
begin
  // ... existing code ...

  else if Method = 'my-custom-tool' then
  begin
    var Result := TJSONObject.Create;
    Result.AddPair('message', 'Hello from custom tool!');
    ResponseJSON.AddPair('result', Result);
  end
end;
```

2. **Register in list-tools** response:

```pascal
if Method = 'list-tools' then
begin
  var Tools := TJSONArray.Create;

  // ... existing tools ...

  var CustomTool := TJSONObject.Create;
  CustomTool.AddPair('name', 'my-custom-tool');
  CustomTool.AddPair('description', 'My custom tool description');
  CustomTool.AddPair('category', 'custom');
  Tools.Add(CustomTool);

  // ... rest of code ...
end;
```

3. **Restart** the application and bridge server

4. **Test** the new tool with Claude Code

### Adding Form Control Tools

To enable Claude Code to control your forms:

1. **Add form introspection tool**:
```pascal
else if Method = 'list-open-forms' then
begin
  var FormsList := TJSONArray.Create;
  for var I := 0 to Screen.FormCount - 1 do
  begin
    var FormInfo := TJSONObject.Create;
    FormInfo.AddPair('name', Screen.Forms[I].Name);
    FormInfo.AddPair('caption', Screen.Forms[I].Caption);
    FormInfo.AddPair('visible', TJSONBool.Create(Screen.Forms[I].Visible));
    FormsList.Add(FormInfo);
  end;

  var Result := TJSONObject.Create;
  Result.AddPair('forms', FormsList);
  ResponseJSON.AddPair('result', Result);
end;
```

2. **Add control interaction tools** (set values, click buttons, etc.)

3. **Use TThread.Synchronize** for all VCL access from the MCP thread

## Troubleshooting

### Application fails to start MCP server

**Problem**: Log shows "Failed to start MCP Server"

**Causes:**
- Named pipe already in use by another process
- Insufficient permissions
- Port conflict

**Solutions:**
1. Close any other instances of the application
2. Run as Administrator (if needed)
3. Check Windows Event Viewer for pipe errors

### Bridge shows "0 tools discovered"

**Problem**: DelphiMCPserver cannot connect to application

**Causes:**
1. Application not running
2. Named pipe not created
3. Pipe name mismatch

**Solutions:**
1. Ensure SimpleVCLApp.exe is running
2. Check application log for "MCP Server started"
3. Verify pipe name in both application and bridge:
   - Application: `MCPServerIntegration.pas` → `MCP_PIPE_NAME`
   - Bridge: `MCPServer.Application.PipeClient.pas` → `DEFAULT_MCP_PIPE_NAME`

### Tools timeout or hang

**Problem**: Tool execution takes too long or freezes

**Causes:**
- Long-running operation in tool handler
- VCL thread blocking
- Deadlock in synchronization

**Solutions:**
1. Keep tool handlers fast (< 1 second)
2. Use TThread.Synchronize for VCL access
3. Offload heavy operations to background threads
4. Return immediately, provide status tools for long operations

## Best Practices

### Threading
- ✅ **Always** use `TThread.Synchronize` for VCL access from MCP thread
- ✅ Keep tool handlers fast and non-blocking
- ✅ Use background threads for long operations

### Error Handling
- ✅ Wrap tool handlers in try-except blocks
- ✅ Return JSON-RPC error objects for failures
- ✅ Log errors for debugging

### Tool Design
- ✅ Make tools stateless when possible
- ✅ Use clear, descriptive tool names
- ✅ Provide good tool descriptions
- ✅ Document parameters and return values

### Security
- ✅ Named pipes are local-only (secure by default)
- ✅ Validate all input parameters
- ✅ Don't expose sensitive operations without authentication
- ✅ Consider adding authentication for production use

## Production Considerations

### For Production Applications

This example demonstrates the basics. For production:

1. **Enhanced Tool Registry**
   - Use a registry pattern for tool management
   - Support dynamic tool registration from modules
   - Add parameter schema validation

2. **Better Error Handling**
   - Comprehensive exception handling
   - Detailed error messages
   - Error logging and monitoring

3. **Security**
   - Add authentication/authorization
   - Rate limiting
   - Audit logging

4. **Performance**
   - Connection pooling
   - Tool execution metrics
   - Resource management

5. **Deployment**
   - Configuration files (don't hardcode pipe names)
   - Logging configuration
   - Service mode support

## Related Documentation

- **DelphiMCP Framework**: `../../README.md`
- **Setup Guide**: `../../Documentation/SETUP-GUIDE.md`
- **Dynamic Proxy**: `../../Documentation/DYNAMIC-PROXY.md`
- **Architecture**: `../../Documentation/ARCHITECTURE.md`

## Production Example

For a real-world, production-ready implementation, see the **CyberMAX ERP** system which demonstrates:
- 28 core tools
- 413 operations via execute-internal
- Full VCL form introspection and control
- Complete autonomous workflow capabilities

## License

This example is part of the DelphiMCP framework.

**License:** MPL-2.0 (Mozilla Public License 2.0)

---

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Status**: Example / Educational
