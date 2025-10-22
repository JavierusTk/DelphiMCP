# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

DelphiMCP is a framework for building MCP (Model Context Protocol) bridge servers that connect AI assistants like Claude Code with Delphi applications. It enables autonomous control and inspection of Delphi VCL applications through named pipe communication.

**✅ Current Status: Production Ready (with known limitations)**
- **Modal Window Support**: VCL modal forms and non-VCL dialogs (TOpenDialog, MessageDlg) fully supported
- **Control Path Resolution**: Navigate unnamed controls via index notation (e.g., `"edtFichero.#0"`)
- **41 Automation Tools**: Visual inspection, control interaction, keyboard/mouse, modal handling, synchronization
- **See**: `Documentation/CONTROL-PATHS-AND-MODALS.md` for latest features and known issues

**Key Capabilities:**
- 41-tool Automation Framework for VCL automation (visual inspection, control interaction, keyboard/mouse, synchronization, modal support)
- HTTP/SSE server for MCP protocol communication (port 3001)
- Named pipe client for connecting to Delphi applications
- Dynamic tool discovery and proxy forwarding
- Debug output capture (OutputDebugString monitoring)
- Control path resolution for unnamed controls
- Modal window detection and interaction (VCL and non-VCL)

## Repository Structure

This repository contains three main components:

### 1. AutomationTools (Primary Product)

**Location**: `/mnt/w/Public/DelphiMCP/Source/AutomationTools/`
**Purpose**: Generic VCL automation framework with 2-package architecture
**Files**: 14 units (~6,000 lines)

**Package Structure:**
- **AutomationBridge.dpk** (14 infrastructure units)
  - Core: Config, Logger, Registry, Server, ServerThread, Describable
  - Utilities: Screenshot, FormIntrospection, ControlInteraction, InputSimulation, Synchronization, Tabulator, TabOrderAnalyzer, WindowDetection, ControlResolver
- **AutomationTools.dpk** (1 tool unit with 34 tools)
  - AutomationCoreTools.pas - All 34 automation tool implementations
  - Depends on: AutomationBridge

The core automation framework provides:
- Named pipe server with JSON-RPC 2.0
- Tool registry (runtime, extensible)
- 41 automation tools (34 core + 6 CyberMAX + 1 debug)
- Thread-safe VCL interaction
- Logging abstraction
- Modal window support (VCL and non-VCL)
- Control path resolution for unnamed controls

**Integration Pattern:**
```pascal
// Typical usage (2 lines)
uses AutomationServer, AutomationCoreTools;
begin
  RegisterCoreAutomationTools;  // Register 34 core tools
  StartAutomationServer;        // Start server
end;
```

### 2. MCPBridge

**Location**: `/mnt/w/Public/DelphiMCP/Source/MCPbridge/`
**Purpose**: Bridge component (9 additional tools)
**Files**: 9 units + Delphi-MCP-Server dependency

Provides:
- Dynamic tool proxy (forwards calls to target app)
- Debug capture tools (5 tools)
- Utility tools (echo, time, hello)

### 3. MCPServer

**Location**: `/mnt/w/Public/DelphiMCP/Source/MCPserver/`
**Purpose**: HTTP/SSE bridge server
**Dependency**: Delphi-MCP-Server framework

Connects Automation Framework to Claude Code via:
- HTTP server (port 3001)
- MCP protocol implementation
- Server-Sent Events (SSE) transport

## Architecture

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Claude Code (AI Assistant)                 │
│              Uses MCP tools via HTTP/SSE                │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP on port 3001
                         │ MCP Protocol (JSON-RPC)
                         ▼
┌─────────────────────────────────────────────────────────┐
│               DelphiMCP Bridge Server                   │
│                                                         │
│  Layer 1: HTTP/SSE Server (MCPServer)                   │
│  - MCP protocol handler                                 │
│  - Port 3001, SSE transport                             │
│                                                         │
│  Layer 2: Bridge Tools (MCPBridge)                      │
│  - Dynamic tool proxy                                   │
│  - Debug capture tools (5)                              │
│  - Utility tools (4)                                    │
└────────────────────────┬────────────────────────────────┘
                         │ Named Pipe
                         │ \\.\pipe\YourApp_MCP_Request
                         ▼
┌─────────────────────────────────────────────────────────┐
│            Target Delphi Application                    │
│                                                         │
│  Layer 3: Automation Framework                          │
│  - 30 generic automation tools                          │
│  - Named pipe server                                    │
│  - Tool registry                                        │
│  - Thread-safe VCL interaction                          │
│                                                         │
│  Application Layer (Optional)                           │
│  - Custom application-specific tools                    │
│  - Business logic integration                           │
└─────────────────────────────────────────────────────────┘
```

**System Components:**
1. **Delphi-MCP-Server** (dependency at `/mnt/w/Delphi-MCP-Server/`)
   - Provides HTTP/SSE server using Indy (included with Delphi)
   - Handles MCP protocol (JSON-RPC 2.0)
   - Tool and resource management infrastructure

2. **AutomationTools** (this repository - primary product)
   - **2-Package Architecture**:
     - AutomationBridge (13 infrastructure units) - Core framework
     - AutomationTools (30 automation tools) - Tool implementations
   - Named pipe server (JSON-RPC 2.0)
   - Thread-safe VCL interaction
   - Self-contained (~6,000 lines)

3. **MCPBridge** (this repository)
   - Dynamic tool proxy (forwards calls to target app)
   - Debug capture engine
   - 9 utility tools (debug capture, echo, time, hello)

## Building and Running

### Compilation

Use the `/compile` slash command to build projects:

```bash
# Compile the DelphiMCP package
/compile Packages/DelphiMCP.dproj

# Compile the example bridge server
/compile Examples/DelphiMCPserver/DelphiMCPserver.dproj
```

**Important:** The example project has hardcoded paths to the Delphi-MCP-Server framework:
- Source path: `W:\Delphi-MCP-Server\src\` (Windows path mapping)
- Linux equivalent: `/mnt/w/Delphi-MCP-Server/src/`

### Running the Bridge Server

```bash
cd Binaries/
./DelphiMCPserver.exe
```

**Prerequisites:**
1. Target application must be running (configured with an embedded MCP server)
2. Named pipe must be accessible: `\\.\pipe\YourApp_MCP_Request`
3. Port 3001 must be available

**Configuration:** Edit `Binaries/settings.ini` or `Examples/DelphiMCPserver/settings.ini`:
```ini
[Server]
Port=3001
Host=0.0.0.0
Endpoint=/mcp

[CORS]
Enabled=1
AllowedOrigins=http://localhost,http://127.0.0.1
```

### Testing the Bridge

```bash
# Check HTTP server is running
curl http://localhost:3001/mcp

# Test with Claude Code (add to mcp_servers.json)
{
  "mcpServers": {
    "delphi-auto": {
      "type": "http",
      "url": "http://localhost:3001/mcp"
    }
  }
}
```

## Project Structure

```
DelphiMCP/
├── Source/
│   ├── AutomationTools/            # Primary product (2-package architecture)
│   │   ├── AutomationBridge.dpk/.dproj    # Infrastructure package (13 units)
│   │   ├── AutomationTools.dpk/.dproj     # Tools package (30 tools, depends on Bridge)
│   │   ├── AutomationCoreTools.pas        # 30 tool implementations
│   │   ├── AutomationServer.pas           # Server lifecycle
│   │   ├── AutomationServerThread.pas     # Named pipe listener
│   │   ├── AutomationToolRegistry.pas     # Runtime tool registration
│   │   ├── AutomationConfig.pas           # Configuration
│   │   ├── AutomationLogger.pas           # Logging abstraction
│   │   └── ... (7 more utility units)
│   │
│   ├── MCPbridge/                  # Bridge utilities
│   │   ├── Core/                   # Core framework components
│   │   │   ├── MCPServer.Application.DynamicProxy.pas # Dynamic tool discovery
│   │   │   ├── MCPServer.Application.PipeClient.pas   # Named pipe client
│   │   │   ├── MCPServer.DebugCapture.Core.pas        # Debug capture engine
│   │   │   └── MCPServer.DebugCapture.Types.pas       # Debug types
│   │   └── Tools/                  # Built-in tool implementations
│   │       ├── MCPServer.Tool.Hello.pas               # Connectivity test (mcp_hello)
│   │       ├── MCPServer.Tool.Echo.pas                # Echo tool (mcp_echo)
│   │       ├── MCPServer.Tool.Time.pas                # System time (mcp_time)
│   │       └── ... (6 more debug capture tools)
│   │
│   └── MCPserver/                  # HTTP/SSE bridge server
│       ├── DelphiMCPserver.dpr/.dproj    # Bridge server program
│       └── settings.ini            # Server configuration
│
├── Examples/
│   └── SimpleVCLApp/               # Framework integration example
│       ├── SimpleVCLApp.dpr        # Example application
│       └── MCPServerIntegration.pas # Integration wrapper
├── Binaries/                       # Compiled outputs (gitignored)
└── Documentation/                  # Detailed guides
    ├── ARCHITECTURE.md             # Framework architecture
    ├── DYNAMIC-PROXY.md           # Dynamic discovery system
    ├── DEBUG-CAPTURE.md           # Debug capture documentation
    └── SETUP-GUIDE.md             # Setup and configuration
```

## Key Architectural Concepts

### Dynamic Tool Discovery

The bridge **automatically discovers** all tools registered in the target application at startup:

1. Bridge queries target app: `list-tools` via named pipe
2. Target app returns tool metadata (name, description, category, module)
3. Bridge dynamically registers all tools with HTTP MCP server
4. Claude Code sees all tools without bridge code changes

**Benefits:**
- Zero maintenance when adding new tools
- Single source of truth (tools defined once in target app)
- Unlimited scalability (any module can register tools)
- 88% code reduction vs. hardcoded approach

**Implementation:** See `MCPServer.Application.DynamicProxy.pas` → `RegisterAllApplicationTools()`

### Named Pipe Communication

**Protocol:** JSON-RPC 2.0 over Windows named pipes

**Request format:**
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "method": "tool-name",
  "params": { "param1": "value1" }
}
```

**Key characteristics:**
- Local-only (no network exposure)
- Timeout: 5 seconds (configurable)
- Thread-safe VCL synchronization in target app
- Error propagation via JSON-RPC error objects

### Debug Capture System

Captures Windows `OutputDebugString` messages from all processes:

**Features:**
- Multi-session support (multiple capture sessions)
- Process name filtering
- Content filtering (substring and regex)
- Time-based filtering
- Statistics and summaries

**Tools:**
- `start_debug_capture` - Begin capturing
- `get_debug_messages` - Retrieve filtered messages
- `stop_debug_capture` - End session
- `get_capture_status` - Session statistics
- `pause_resume_capture` - Pause/resume
- `get_process_summary` - Process statistics

## Development Patterns

### Adding Tools to Bridge (Local Tools)

1. Create new tool unit in `Source/Tools/`:
```pascal
unit MCPServer.Tool.MyCustomTool;

interface

uses MCPServer.ToolsManager;

procedure RegisterMyCustomTool;

implementation

procedure RegisterMyCustomTool;
begin
  RegisterTool('my-custom-tool',
    function(const Params: TJSONObject): string
    begin
      // Implementation
      Result := '{"success": true}';
    end,
    'Tool description',
    'category');
end;

end.
```

2. Register in `DelphiMCPserver.dpr`:
```pascal
uses
  MCPServer.Tool.MyCustomTool;

begin
  RegisterMyCustomTool;
  // ... start server ...
end.
```

### Adding Tools to Target Application

Tools added to the target application are **automatically discovered** by the bridge:

```pascal
// In target application module:
initialization
  MCPTools.RegisterTool(
    'new-tool-name',
    @ToolImplementationFunction,
    'Tool description',
    'category',
    'ModuleName'
  );
```

**No bridge changes needed** - restart the bridge to pick up new tools.

### Connecting to Different Applications

Modify pipe name in `MCPServer.Application.PipeClient.pas`:

```pascal
const
  PIPE_NAME = '\\.\pipe\YourApp_MCP_Request';  // Change this
  PIPE_TIMEOUT_MS = 5000;
```

## Dependencies

### Required Frameworks
- **Delphi 12** (RAD Studio 12) or later
- **Delphi-MCP-Server** framework (at `/mnt/w/Delphi-MCP-Server/`)
  - Provides: HTTP/SSE server (Indy), MCP protocol, tool management
  - Indy is included with Delphi (no external installation)

### Search Paths
When building projects, ensure search paths include:
```
# For DelphiMCP framework
$(DelphiMCP)\Source\Core
$(DelphiMCP)\Source\Tools

# For Delphi-MCP-Server dependency
W:\Delphi-MCP-Server\src\Server
W:\Delphi-MCP-Server\src\Core
W:\Delphi-MCP-Server\src\Managers
W:\Delphi-MCP-Server\src\Protocol
W:\Delphi-MCP-Server\src\Resources
```

**Note:** Windows paths using `W:\` mapping (from WSL: `/mnt/w/`)

## Common Development Tasks

### Modify Bridge Configuration

Edit `settings.ini` to change server settings:
- Port number (default: 3001)
- CORS origins
- SSL/TLS settings (optional)

### Debug Bridge Communication

1. Check target application is running and MCP server is enabled
2. Verify named pipe is accessible: `\\.\pipe\YourApp_MCP_Request`
3. Test with curl: `curl http://localhost:3001/mcp`
4. Check bridge console output for error messages
5. Use debug capture tools to monitor OutputDebugString messages

### Extend Debug Capture Features

Key file: `MCPServer.DebugCapture.Core.pas`

Main class: `TDebugCaptureEngine`
- Manages capture sessions
- Provides filtering and querying
- Thread-safe message buffer

### Work with Tool Registry

The bridge uses the Delphi-MCP-Server tool registry system:

**Registration:**
```pascal
RegisterTool('tool-name', @ExecuteFunction, 'Description', 'Category');
```

**Tool implementation signature:**
```pascal
function ExecuteTool(const Params: TJSONObject): string;
```

## Development Use Case: CyberMAX ERP

This framework is being developed alongside the **CyberMAX ERP** system, demonstrating its intended capabilities:
- 28 core tools (dynamically discovered)
- 413 operations via `execute-internal` tool
- 100+ commands via command processor
- Full VCL form introspection and control
- 70% token optimization for efficient API usage

**Note**: The framework is designed to be application-agnostic and adaptable to any Delphi VCL application with an embedded MCP server. Modal window support (both VCL and non-VCL) is fully implemented. See `Documentation/CONTROL-PATHS-AND-MODALS.md` for details.

## Troubleshooting

### "Cannot connect to application" Error
**Cause:** Target application not running or MCP server disabled
**Solution:**
1. Start target application (ensure MCP server is enabled in your build configuration)
2. Verify named pipe exists
3. Restart bridge server

### "Port already in use" Error
**Cause:** Port 3001 already bound by another process
**Solution:**
1. Change port in `settings.ini`
2. Update Claude Code `mcp_servers.json` configuration
3. Check for other running instances

### Bridge Shows "0 tools discovered"
**Cause:** Cannot communicate with target application
**Solution:**
1. Verify target app is running
2. Check target app has MCP server enabled (depends on your build configuration)
3. Verify named pipe name matches in both bridge and target
4. Check Windows Event Viewer for pipe errors

### Tools Timeout
**Cause:** Tool execution takes longer than pipe timeout
**Solution:**
1. Increase timeout in `MCPServer.Application.PipeClient.pas`
2. Check target application is responsive
3. Debug tool implementation for infinite loops

## Documentation

**Essential Reading:**
- `README.md` - Quick start and overview
- `Documentation/ARCHITECTURE.md` - Complete architecture details
- `Documentation/DYNAMIC-PROXY.md` - Dynamic discovery system (important!)
- `Documentation/DEBUG-CAPTURE.md` - Debug capture system
- `Documentation/SETUP-GUIDE.md` - Configuration and setup

**Reference:**
- `Packages/README.md` - Package installation
- `Examples/DelphiMCPserver/README.md` - Example usage

## Version History

- **v2.2** (2025-10-22) - Control path resolution, modal window support (VCL + non-VCL), 41 tools, ui.focus.get_path
- **v2.1** (2025-10-07) - Framework extraction, debug capture, comprehensive docs
- **v2.0** (2025-10-06) - Registry-based architecture, token optimization
- **v1.0** (2025-10-04) - Initial production release

## Related Projects

- **Delphi-MCP-Server** - HTTP/SSE server and MCP protocol infrastructure
- **CyberMAX ERP** - Primary production use case for this framework

---

**Status:** ✅ Production Ready (with known limitations - see Documentation/CONTROL-PATHS-AND-MODALS.md)
**Platform:** Windows (named pipes are Windows-specific)
**Delphi Version:** RAD Studio 12 (Delphi 29.0)
**License:** MPL-2.0 (Mozilla Public License 2.0)

## Known Limitations

**See `Documentation/CONTROL-PATHS-AND-MODALS.md` for complete details.**

Summary of key limitations:
- **SendInput Focus Requirement**: `ui_send_keys` requires the target application to have focus (user must click on app once before automation begins)
- **ListBox Reading**: `TListBox` and `TListBoxMax` controls not yet supported by `ui_value_get` tool
- **Control Path Resolution**: Path-based clicking needs debugging (e.g., `"edtFichero.#0"` - resolver integrated but not fully tested)
- **Modal Edge Case**: One unidentified scenario caused server blocking (under investigation - most modal scenarios work correctly)
- **Single Connection**: Named pipe supports single connection per pipe (no multi-connection support yet)
- **Windows Only**: Named pipes are Windows-specific
