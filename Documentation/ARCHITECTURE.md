# DelphiMCP Framework Architecture

## Overview

**DelphiMCP** is a work-in-progress **Generic VCL Automation Framework** for Delphi applications, enabling AI-driven automation via the Model Context Protocol (MCP).

⚠️ **Current Status**: Work in Progress - Modal windows not yet supported (framework blocks on ShowModal calls)

This repository contains **three main components**:
1. **AutomationTools** - 2-package architecture (AutomationBridge + AutomationTools) with 30 automation tools (primary product)
2. **MCPBridge** - HTTP/SSE bridge server connecting framework to Claude Code
3. **MCPServer** - HTTP/SSE infrastructure (built on Delphi-MCP-Server)

**Architecture Philosophy**: The framework enables ANY Delphi VCL application to become AI-controllable with minimal integration (2 lines of code: `RegisterCoreAutomationTools; StartAutomationServer;`).

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Claude Code (AI Assistant)                  │
│              Uses MCP tools via HTTP/SSE                 │
│                                                          │
│  39 Available Tools:                                     │
│  - 30 Automation Tools (from AutomationTools package)   │
│  - 9 Bridge Tools (debug capture, utilities)            │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP on port 3001
                         │ MCP Protocol (JSON-RPC 2.0)
                         ▼
┌─────────────────────────────────────────────────────────┐
│            DelphiMCP Bridge Server                       │
│            (HTTP/SSE Bridge + Dynamic Proxy)             │
│                                                          │
│  LAYER 1: HTTP/SSE Server (MCPServer)                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ - HTTP endpoint: http://localhost:3001/mcp         │ │
│  │ - Transport: Server-Sent Events (SSE)              │ │
│  │ - Protocol: MCP (Model Context Protocol)           │ │
│  │ - Framework: Delphi-MCP-Server (Indy-based)        │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  LAYER 2: Bridge Tools (MCPBridge)                      │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Dynamic Tool Proxy:                                │ │
│  │ - Auto-discovers tools from target app             │ │
│  │ - Forwards calls via named pipe                    │ │
│  │ - Zero maintenance when adding new tools           │ │
│  │                                                     │ │
│  │ Debug Capture Tools (5):                           │ │
│  │ - start_debug_capture, get_debug_messages          │ │
│  │ - stop_debug_capture, get_capture_status           │ │
│  │ - pause_resume_capture                             │ │
│  │                                                     │ │
│  │ Utility Tools (4):                                 │ │
│  │ - mcp_hello, mcp_echo, mcp_time                    │ │
│  │ - get_process_summary                              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Named Pipe Client:                                     │
│  - Pipe: \\.\pipe\YourApp_MCP_Request                   │
│  - Protocol: JSON-RPC 2.0                               │
│  - Timeout: 5 seconds (configurable)                    │
└────────────────────────┬────────────────────────────────┘
                         │ Named Pipe (JSON-RPC 2.0)
                         │ \\.\pipe\YourApp_MCP_Request
                         ▼
┌─────────────────────────────────────────────────────────┐
│            Target Delphi VCL Application                 │
│            (With Embedded AutomationFramework)           │
│                                                          │
│  LAYER 3: Automation Framework (2 Packages)            │
│  ┌────────────────────────────────────────────────────┐ │
│  │ AutomationBridge Package (13 infrastructure units):│ │
│  │                                                     │ │
│  │ Named Pipe Server:                                 │ │
│  │ - Background thread listening on named pipe        │ │
│  │ - JSON-RPC 2.0 request/response handler           │ │
│  │ - Thread-safe VCL access via TThread.Synchronize  │ │
│  │                                                     │ │
│  │ Tool Registry:                                     │ │
│  │ - Runtime registration system                      │ │
│  │ - Singleton pattern, thread-safe                   │ │
│  │ - Tool discovery and metadata                      │ │
│  │                                                     │ │
│  │ Automation Utilities:                              │ │
│  │ - Screenshot, FormIntrospection, ControlInteraction│ │
│  │ - InputSimulation, Synchronization, Tabulator      │ │
│  └────────────────────────────────────────────────────┘ │
│                         ↑ depends on                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │ AutomationTools Package (30 tool implementations): │ │
│  │                                                     │ │
│  │ 30 Generic Automation Tools:                       │ │
│  │ - Visual Inspection (9): screenshots, form info    │ │
│  │ - Control Interaction (7): set values, click       │ │
│  │ - Keyboard/Mouse (5): SendInput API                │ │
│  │ - Synchronization (4): wait primitives             │ │
│  │ - Development (2): tab order analysis              │ │
│  │ - Utility (2): echo, list-tools                    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Application Layer (Optional):                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Custom Application-Specific Tools:                 │ │
│  │ - Registered via tool registry                     │ │
│  │ - Business logic integration                       │ │
│  │ - Command processor commands (if using CyberMAX)   │ │
│  │ - Internals system (if using CyberMAX pattern)     │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  VCL Application Core:                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │ - Forms, Controls, DataModules                     │ │
│  │ - Business Logic                                   │ │
│  │ - Data Access                                      │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Package Architecture

DelphiMCP uses a **2-package architecture** for the automation framework:

```
┌────────────────────────────────────────────────────────────┐
│ AutomationTools (Package .dpk)                             │
│ - 30 automation tools (AutomationCoreTools.pas)            │
│ - Depends on: AutomationBridge                             │
└──────────────────────┬─────────────────────────────────────┘
                       │ requires
                       ▼
┌────────────────────────────────────────────────────────────┐
│ AutomationBridge (Package .dpk)                            │
│ - Core infrastructure (6 units):                           │
│   Config, Logger, Describable, Registry, Server,           │
│   ServerThread                                             │
│ - Automation utilities (7 units):                          │
│   Screenshot, FormIntrospection, ControlInteraction,       │
│   InputSimulation, Synchronization, Tabulator,             │
│   TabOrderAnalyzer                                         │
│ - Depends on: RTL, VCL, VCLIMG                             │
└────────────────────────────────────────────────────────────┘
```

**Benefits of This Architecture**:
- ✅ Clean separation between infrastructure and tool implementations
- ✅ Infrastructure units can be reused by other tool packages
- ✅ No circular dependencies (unidirectional: Tools → Bridge → RTL/VCL)
- ✅ Modular design enables future tool packages to depend on AutomationBridge
- ✅ Clear component responsibilities

**Integration Pattern**:
```pascal
uses AutomationServer, AutomationCoreTools;
begin
  RegisterCoreAutomationTools;  // Register 30 tools
  StartAutomationServer;        // Start server
end;
```

## Dependency Structure

### External Framework: Delphi-MCP-Server

**Location**: `/mnt/w/Delphi-MCP-Server/`

**Provides**:
- `MCPServer.IdHTTPServer` - HTTP/SSE server using Indy
- `MCPServer.Types` - MCP protocol types
- `MCPServer.Settings` - Configuration management
- `MCPServer.Logger` - Logging infrastructure
- `MCPServer.ManagerRegistry` - Manager registration
- `MCPServer.ToolsManager` - Tool registration and execution
- `MCPServer.CoreManager` - Core MCP capabilities
- `MCPServer.ResourcesManager` - Resource management

**Technology**: Indy HTTP Server (TIdHTTPServer, included with Delphi)

**Purpose**: Provides the HTTP/SSE transport layer and MCP protocol handling, allowing DelphiMCP to focus on tools and application integration.

## Core Components (DelphiMCP)

### 1. HTTP/SSE Server Integration

**Provided by**: Delphi-MCP-Server framework

**Key Features**:
- Standard MCP protocol implementation (JSON-RPC 2.0)
- Server-Sent Events (SSE) for real-time communication
- Tool call routing and dispatch
- Error handling and timeout management

**Usage in DelphiMCPserver.exe**:
```pascal
Server := TMCPIdHTTPServer.Create(nil);
Server.Settings := Settings;
Server.ManagerRegistry := ManagerRegistry;
Server.Start;
```

### 2. Dynamic Proxy (MCPServer.Application.DynamicProxy.pas)

**Purpose**: Route tool calls to appropriate handlers (local or remote)

**Routing Decision**:
```pascal
if IsLocalTool(ToolName) then
  ExecuteLocalTool(ToolName, Params)
else
  ForwardToTargetApp(ToolName, Params);
```

**Local Tools**:
- Debug capture tools (start_debug_capture, get_debug_messages, etc.)
- Utility tools (mcp_hello, mcp_echo, mcp_time)

**Remote Tools**:
- All tools from target application (forwarded via pipe)

### 3. Named Pipe Client (MCPServer.Application.PipeClient.pas)

**Purpose**: Communicate with target Delphi application

**Protocol**: JSON-RPC 2.0
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "method": "tool_name",
  "params": { /* tool parameters */ }
}
```

**Key Features**:
- Connection pooling
- Timeout handling
- Retry logic
- Error propagation

**Key Classes**:
- `TPipeClient` - Named pipe communication

### 4. Debug Capture Engine (MCPServer.DebugCapture.Core.pas)

**Purpose**: Capture and filter Windows OutputDebugString messages

**Architecture**:
```
DebugView Monitor (Windows API)
        ↓
TDebugCaptureSession (per-session state)
        ↓
Message Buffer (circular buffer)
        ↓
Filtering (process, content, regex)
        ↓
API Response (JSON)
```

**Key Features**:
- Multi-session support
- Process name resolution
- Content filtering (substring, regex)
- Time-based filtering
- Statistics and summaries

**Key Classes**:
- `TDebugCaptureEngine` - Main capture engine
- `TDebugCaptureSession` - Per-session state
- `TDebugMessage` - Individual message record

### 5. Tool System (MCPServer.Tool.*.pas)

**Purpose**: Implement individual MCP tools

**Tool Registration Pattern**:
```pascal
procedure RegisterMyTool(Server: TMCPServer);
begin
  Server.RegisterTool('tool-name',
    procedure(Params: TJSONObject; out Result: TJSONObject)
    begin
      // Tool implementation
      Result.AddPair('success', TJSONBool.Create(True));
    end,
    'Tool description for AI'
  );
end;
```

**Built-in Tools**:
1. `mcp_hello` - Connectivity test
2. `cyber_echo` - Echo with transformations
3. `cyber_time` - System time with formatting
4. `start_debug_capture` - Begin debug capture
5. `get_debug_messages` - Retrieve messages
6. `stop_debug_capture` - End capture
7. `get_capture_status` - Session statistics
8. `pause_resume_capture` - Pause/resume
9. `get_process_summary` - Process stats

## Data Flow

### Tool Call Flow (Remote Tool)

```
1. Claude Code → HTTP POST /mcp
   {
     "method": "tools/call",
     "params": {
       "name": "execute-internal",
       "arguments": {"code": "GESTION.CLIENTES"}
     }
   }

2. Dynamic Proxy → Named Pipe Client
   Check: IsLocalTool("execute-internal")? No
   Forward to target application

3. Named Pipe Client → Target App
   ConnectNamedPipe(\\.\pipe\YourApp_MCP_Request)
   WriteFile({JSON-RPC request})

4. Target App MCP Server → Internal Handler
   Parse JSON-RPC
   TThread.Synchronize(ExecuteTool)
   Execute internal: "GESTION.CLIENTES"

5. Target App → Named Pipe Client
   WriteFile({JSON-RPC response with result})

6. Named Pipe Client → Dynamic Proxy
   Parse response, extract result

7. Dynamic Proxy → Claude Code
   SSE event with tool result
```

### Tool Call Flow (Local Tool)

```
1. Claude Code → HTTP POST /mcp
   {
     "method": "tools/call",
     "params": {
       "name": "start_debug_capture",
       "arguments": {}
     }
   }

2. Dynamic Proxy → Debug Capture Engine
   Check: IsLocalTool("start_debug_capture")? Yes
   Execute locally

3. Debug Capture Engine → Windows API
   Start monitoring OutputDebugString
   Create new session
   Return session ID

4. Dynamic Proxy → Claude Code
   SSE event with session ID
```

## Configuration

### settings.ini Structure

```ini
[Server]
Port=3001                    # HTTP server port
Host=localhost               # Bind address
Name=delphi-mcp-server      # Server name for MCP
Version=1.0.0               # Server version
Endpoint=/mcp               # MCP endpoint path

[CORS]
Enabled=1                    # Enable CORS
AllowedOrigins=...          # Comma-separated origins

[SSL]
Enabled=0                    # SSL/TLS (optional)
CertFile=                    # Certificate path
KeyFile=                     # Key path
```

### Pipe Configuration

Hardcoded in source (can be modified):
```pascal
const
  PIPE_NAME = '\\.\pipe\YourApp_MCP_Request';
  PIPE_TIMEOUT = 30000; // 30 seconds
```

## Threading Model

### Bridge Server Threads

1. **Main Thread** - HTTP server event loop
2. **Request Handler Threads** - One per concurrent request (mORMot2 managed)
3. **Debug Monitor Thread** - Captures OutputDebugString messages

### Target Application Threads

1. **Main Thread (VCL)** - UI and business logic
2. **MCP Server Thread** - Named pipe listener
3. **Tool Execution** - Via `TThread.Synchronize` to main thread

## Performance Considerations

### Latency Sources

1. **HTTP/SSE Overhead**: ~5-10ms (network local)
2. **JSON Parsing**: ~1-5ms (small payloads)
3. **Named Pipe**: ~2-10ms (local IPC)
4. **Tool Execution**: Variable (depends on tool)

**Total Typical Latency**: 10-30ms for simple tools

### Optimization Strategies

1. **Connection Pooling** - Reuse named pipe connections
2. **Minimal JSON** - Use token-optimized responses
3. **Async Operations** - Non-blocking where possible
4. **Batch Operations** - Combine multiple tool calls when possible

## Security Considerations

### Local-Only Communication

- HTTP server binds to `localhost` (127.0.0.1)
- Named pipes are local-only (`\\.\pipe\` namespace)
- No network exposure by default

### Authentication

- No authentication required (assumes trusted local environment)
- CORS enabled for web-based clients
- Consider adding API key for production deployments

### Process Isolation

- Bridge runs as separate process
- Target application crash doesn't affect bridge
- Bridge crash doesn't affect target application

## Extension Points

### Adding New Local Tools

1. Create new unit in `Source/Tools/`
2. Implement tool logic
3. Register in main program
4. Update documentation

### Adding New Remote Tools

1. Implement in target application's MCP server
2. Register in target's tool registry
3. No bridge changes needed (automatic proxy)

### Custom Transports

1. Implement `IMCPTransport` interface
2. Replace HTTP/SSE server
3. Keep proxy and pipe client unchanged

## Error Handling

### Error Propagation

```
Target App Error
    ↓
Named Pipe (JSON-RPC error object)
    ↓
Dynamic Proxy (parse error)
    ↓
HTTP Response (MCP error format)
    ↓
Claude Code (displays error to user)
```

### Error Categories

1. **Connection Errors** - Pipe not available, timeout
2. **Tool Errors** - Tool not found, invalid parameters
3. **Execution Errors** - Tool execution failed
4. **Serialization Errors** - JSON parsing failed

## Monitoring & Debugging

### Debug Output

Bridge outputs to console:
```
[INFO] HTTP server started on port 3001
[DEBUG] Tool call: execute-internal
[DEBUG] Forwarding to target app via pipe
[DEBUG] Response received: 543 bytes
[ERROR] Pipe connection failed: timeout
```

### Debug Capture

Capture target application debug output:
```pascal
start_debug_capture
get_debug_messages(processname="YourApp.exe")
```

### Health Checks

```bash
# Check HTTP server
curl http://localhost:3001/mcp

# Check pipe availability
# (requires target app running)
```

## Dependencies

### Required Frameworks

- **Delphi-MCP-Server** (`/mnt/w/Delphi-MCP-Server/`)
  - HTTP/SSE server using Indy
  - MCP protocol implementation
  - Tool and resource management
  - Logging and configuration

### Required Libraries (Included with Delphi)

- **Indy** (Internet Direct) - HTTP/SSE server (TIdHTTPServer)
  - Included with Delphi IDE
  - No external installation required
- **System.JSON** - JSON parsing (Delphi RTL)
- **Windows API** - Named pipes, OutputDebugString

### Optional Libraries

- **TaurusTLS** - Modern OpenSSL 3.x support for HTTPS
  - Available via GetIt Package Manager
  - Alternative: Standard Indy SSL (OpenSSL 1.0.2)
- **System.RegularExpressions** - Debug message filtering (Delphi RTL)
- **System.Threading** - Async operations (Delphi RTL)

## Deployment

### Development

```
DelphiMCP/
├── Source/          # Edit source files
├── Examples/        # Test projects
└── Binaries/        # Compiled outputs
```

### Production

```
Deployment/
├── DelphiMCPserver.exe    # Bridge server
├── settings.ini           # Configuration
└── mormot*.dll           # Runtime dependencies (if needed)
```

## Future Enhancements

- **WebSocket transport** - Alternative to SSE
- **Authentication** - API key or token-based
- **Multi-target** - Connect to multiple applications simultaneously
- **Tool caching** - Cache tool metadata
- **Metrics** - Performance monitoring and statistics

---

**Version**: 2.1
**Last Updated**: 2025-10-07
**Status**: Production Ready
