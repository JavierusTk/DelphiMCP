# DelphiMCP - Delphi Model Context Protocol Framework

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Delphi Version](https://img.shields.io/badge/Delphi-12%2B-blue.svg)](https://www.embarcadero.com/products/delphi)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![GitHub Issues](https://img.shields.io/github/issues/JavierusTk/DelphiMCP)](https://github.com/JavierusTk/DelphiMCP/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Status](https://img.shields.io/badge/Status-WIP-yellow.svg)](https://github.com/JavierusTk/DelphiMCP)

**A work-in-progress framework for building MCP (Model Context Protocol) servers in Delphi**

> ⚠️ **Current Status: Work in Progress**
> Modal windows are not yet supported. The framework currently blocks when modal forms are displayed. This is actively being worked on.

## Overview

DelphiMCP is a **work-in-progress Generic VCL Automation Framework** for Delphi applications, enabling AI-driven automation via the Model Context Protocol (MCP).

**What This Is:**
- **Automation Framework**: 30 professional tools for VCL automation (visual inspection, control interaction, keyboard/mouse, synchronization)
- **MCP Bridge**: Connects framework to Claude Code via HTTP/SSE and named pipes
- **In Development**: Being developed alongside CyberMAX ERP system
- **Self-Contained**: No external dependencies beyond Delphi RTL/VCL

**Current Limitations:**
- ⚠️ **Modal windows not supported** - Framework blocks on ShowModal calls
- ⚠️ **Not production-ready** - Suitable for testing and development only
- ✅ **Non-modal forms work well** - Full automation support for regular forms

### Architecture Components

**This repository contains three main components:**

1. **AutomationTools** (Primary Product)
   - Location: `Source/AutomationTools/`
   - **2-Package Architecture**:
     - **AutomationBridge** (13 infrastructure units): Config, logging, registry, server, utilities
     - **AutomationTools** (30 automation tools): Visual inspection, control interaction, keyboard/mouse, synchronization
   - Named pipe server with JSON-RPC
   - Self-contained VCL automation (~6,000 lines)
   - Thread-safe VCL interaction
   - Works with ANY Delphi VCL application

2. **MCPBridge**
   - Location: `Source/MCPbridge/`
   - HTTP/SSE server (connects to Claude Code)
   - Dynamic tool proxy (forwards calls via named pipes)
   - 9 additional utility tools (debug capture, etc.)
   - Built on Delphi-MCP-Server framework

3. **Example Application**
   - Location: `Examples/SimpleVCLApp/`
   - Demonstrates framework integration
   - Shows typical usage pattern
   - Ready to run and test

### Key Features

- ✅ **30 Automation Tools** - Visual inspection, control interaction, keyboard/mouse, synchronization
- ⚠️ **Work in Progress** - Modal window support under development
- ✅ **Self-Contained** - No external dependencies beyond Delphi RTL/VCL
- ✅ **Easy Integration** - 2-line setup: `RegisterCoreAutomationTools; StartAutomationServer;`
- ✅ **Thread-Safe** - All VCL access via TThread.Synchronize
- ✅ **Extensible** - Add custom tools easily
- ✅ **HTTP/MCP Bridge** - Connects to Claude Code seamlessly
- ⚠️ **Not Production Ready** - Modal dialogs not yet supported (see Known Limitations below)

### Tool Categories

**Visual Inspection (9 tools):** take-screenshot, get-form-info, list-open-forms, list-controls, find-control, get-control, ui_get_tree_diff, ui_focus_get, ui_value_get

**Control Interaction (7 tools):** set-control-value, ui_set_text_verified, click-button, select-combo-item, select-tab, close-form, set-focus

**Keyboard/Mouse (5 tools):** ui_send_keys, ui_mouse_move, ui_mouse_click, ui_mouse_dblclick, ui_mouse_wheel

**Synchronization (4 tools):** wait_idle, wait_focus, wait_text, wait_when

**Development (2 tools):** analyze-form-taborder, list-focusable-forms

**Utility (2 tools):** echo, list-tools

**Bridge Tools (9 tools):** Debug capture tools, connectivity tests

### Quick Integration

**Minimal integration** (2 lines):
```pascal
uses AutomationServer, AutomationCoreTools;
begin
  Application.Initialize;
  Application.CreateForm(TfmMain, fmMain);

  RegisterCoreAutomationTools;  // Register 30 tools
  StartAutomationServer;        // Start server

  Application.Run;
end.
```

### Dependencies

**Required:**
- **Delphi 12** (RAD Studio 12 Athens) or later
- **Delphi-MCP-Server** framework (for bridge component)
  - Repository: https://github.com/GDKsoftware/delphi-mcp-server
  - Local path: `/mnt/w/Delphi-MCP-Server/`
  - HTTP/SSE server (using Indy, included with Delphi)
  - MCP protocol handling (JSON-RPC 2.0)

**No Other Dependencies:**
- AutomationFramework is self-contained (RTL/VCL only)
- No external libraries or components required

## Quick Start in 5 Minutes

Get DelphiMCP running with Claude Code in just a few steps:

### Step 1: Clone the Repository
```bash
git clone https://github.com/JavierusTk/DelphiMCP.git
cd DelphiMCP
```

### Step 2: Configure Dependencies
1. Install [Delphi-MCP-Server](https://github.com/GDKsoftware/delphi-mcp-server) framework
2. Update paths in `Packages/DelphiMCP.dpk` (see [Packages/CONFIGURATION.md](Packages/CONFIGURATION.md))

### Step 3: Build the Bridge Server
```bash
# Open in Delphi IDE
Source/MCPserver/DelphiMCPserver.dproj

# Or compile from command line
cd Source/MCPserver
dcc32 DelphiMCPserver.dpr
```

### Step 4: Run the Server
```bash
cd Binaries
./DelphiMCPserver.exe
```

### Step 5: Connect Claude Code

Add the MCP server from the command line:

```bash
# Add DelphiMCP server to Claude Code configuration
claude mcp add delphi-mcp http://localhost:3001/mcp -t http
```

**Test it:** Ask Claude Code: *"List available tools from delphi-mcp"*

---

## Compatibility

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| **Delphi** | 12 (29.0) | ✅ Tested | RAD Studio 12 Athens |
| **Delphi** | 11 | ⚠️ Not tested | Should work, not verified |
| **Delphi** | 10.4+ | ⚠️ Not tested | May work with adjustments |
| **Windows** | 10 (1809+) | ✅ Supported | Requires Windows 10 or later |
| **Windows** | 11 | ✅ Supported | Fully tested |
| **Windows Server** | 2019+ | ✅ Supported | Named pipes supported |
| **Indy** | 10.6+ | ✅ Required | Included with Delphi |
| **MCP Protocol** | 2024-11-05 | ✅ Supported | Latest specification |

### Platform Notes
- **Named pipes are Windows-specific** - This framework requires Windows
- **Indy is bundled** with Delphi - No separate installation needed
- **64-bit compilation** supported (Win64 platform)

---

## Detailed Setup

### Prerequisites

- **Delphi 12** (RAD Studio 12) or later
- **Windows** (named pipes are Windows-specific)
- **Delphi-MCP-Server** framework
  - Repository: https://github.com/GDKsoftware/delphi-mcp-server
  - Provides HTTP/SSE server using Indy (included with Delphi)
- **Target Application** with MCP server implementation (your Delphi application)

### Running DelphiMCPserver

1. **Start your target application** (with MCP server enabled)

2. **Run the bridge server**:
   ```bash
   cd Binaries
   ./DelphiMCPserver.exe
   ```

3. **Configure Claude Code**:
   ```bash
   claude mcp add delphi-mcp http://localhost:3001/mcp -t http
   ```

4. **Test the connection**:
   ```
   Claude, can you list the available tools?
   ```

## Architecture

```
Claude Code (AI Assistant)
       ↓ MCP Protocol (HTTP/SSE)
┌─────────────────────────────────────────┐
│ DelphiMCPserver.exe                     │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │ Delphi-MCP-Server (HTTP/Protocol)  │ │
│  │  - HTTP/SSE Server (Indy)          │ │
│  │  - MCP JSON-RPC 2.0 handling       │ │
│  │  - Tool/Resource management        │ │
│  └────────────────────────────────────┘ │
│               ↓                         │
│  ┌────────────────────────────────────┐ │
│  │ DelphiMCP (Tools & Proxy)          │ │
│  │  - Dynamic proxy logic             │ │
│  │  - Named pipe client               │ │
│  │  - Debug capture engine            │ │
│  │  - 9 built-in tools                │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
       ↓ Named Pipe (\\.\pipe\YourApp_MCP_Request)
Target Application (your Delphi application)
       ↓ JSON-RPC 2.0
Internal MCP Server (embedded in target)
```

**Dependency Structure:**
- **DelphiMCPserver.exe** = Delphi-MCP-Server (HTTP layer) + DelphiMCP (tools/proxy layer)
- **Indy HTTP Server** (included with Delphi) provides HTTP/SSE transport
- **Named pipes** provide IPC with target Delphi application

See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for detailed architecture.

## Installation

### Option 1: Use as Package

Install the DelphiMCP package in your Delphi IDE:

```
1. Open Packages/DelphiMCP.dpk in Delphi
2. Build the package
3. Add to your project's required packages
```

See [Packages/README.md](Packages/README.md) for detailed installation instructions.

### Option 2: Direct Source Usage (Recommended)

Add the MCPautomationBridge package to your project:

```
Project → Options → Packages → Runtime Packages
Add: MCPautomationBridge

Or add source directories to search path:
$(DelphiMCP)\Source\MCPbridge\Core;$(DelphiMCP)\Source\MCPbridge\Tools
```

## Core Components

### MCPautomationBridge Package (Source/MCPbridge/)

The automation bridge library that connects Delphi applications to MCP servers.

**Core Components** (`Source/MCPbridge/Core/`):
- **MCPServer.Application.DynamicProxy.pas** - Dynamic proxy for tool discovery
- **MCPServer.Application.PipeClient.pas** - Named pipe client for target application
- **MCPServer.DebugCapture.Core.pas** - OutputDebugString capture engine
- **MCPServer.DebugCapture.Types.pas** - Debug capture types and structures

**Built-in Tools** (`Source/MCPbridge/Tools/`):

1. **mcp_hello** - Test connectivity
2. **mcp_echo** - Echo messages (with optional uppercase)
3. **mcp_time** - Get system time with formatting
4. **start_debug_capture** - Begin capturing debug output
5. **get_debug_messages** - Retrieve captured messages with filtering
6. **stop_debug_capture** - Stop capture session
7. **get_capture_status** - Get capture session statistics
8. **pause_resume_capture** - Pause/resume capture
9. **get_process_summary** - Process statistics

## Debug Capture Features

The framework includes a powerful debug output capture system:

```pascal
// Start capturing debug output from all processes
start_debug_capture

// Filter by process name
get_debug_messages(processname="YourApp.exe")

// Filter by message content
get_debug_messages(messagecontains="[ERROR]")

// Filter by regex pattern
get_debug_messages(messageregex="\\[MCP\\].*")

// Get statistics
get_process_summary
```

See [Documentation/DEBUG-CAPTURE.md](Documentation/DEBUG-CAPTURE.md) for complete documentation.

## Extending the Framework

### Adding Custom Tools

1. Create a new unit in `Source/Tools/`:
   ```pascal
   unit MCPServer.Tool.MyCustomTool;

   interface

   uses MCPServer.Types;

   procedure RegisterMyCustomTool(Server: TMCPServer);

   implementation

   procedure RegisterMyCustomTool(Server: TMCPServer);
   begin
     Server.RegisterTool('my-custom-tool',
       procedure(Params: TJSONObject; out Result: TJSONObject)
       begin
         // Your tool implementation
       end,
       'Description of my custom tool'
     );
   end;

   end.
   ```

2. Register in `DelphiMCPserver.dpr`:
   ```pascal
   MCPServer.Tool.MyCustomTool.RegisterMyCustomTool(Server);
   ```

### Connecting to Different Applications

Modify `MCPServer.Application.PipeClient.pas` pipe name:

```pascal
const
  PIPE_NAME = '\\.\pipe\MyApp_MCP_Request';
```

## Configuration

Edit `Examples/DelphiMCPserver/settings.ini`:

```ini
[Server]
Port=3001
Host=localhost
Name=delphi-auto
Version=2.1.0
Endpoint=/mcp

[CORS]
Enabled=1
AllowedOrigins=http://localhost,http://127.0.0.1,https://localhost,https://127.0.0.1
```

## Examples

### DelphiMCPserver

Complete MCP bridge example for Delphi applications.

**Features**:
- HTTP server on port 3001
- Named pipe communication (configurable)
- All 9 built-in tools registered
- Debug capture enabled

**Location**: `Examples/DelphiMCPserver/`

**Note**: The example uses `\\.\pipe\YourApp_MCP_Request` as the default pipe name. Modify this in the source to match your application's pipe name.

## Documentation

- **[ARCHITECTURE.md](Documentation/ARCHITECTURE.md)** - Framework architecture and design
- **[DYNAMIC-PROXY.md](Documentation/DYNAMIC-PROXY.md)** - Dynamic proxy implementation details
- **[DEBUG-CAPTURE.md](Documentation/DEBUG-CAPTURE.md)** - Debug capture system documentation
- **[SETUP-GUIDE.md](Documentation/SETUP-GUIDE.md)** - Complete setup and configuration guide
- **[IMPLEMENTATION.md](Documentation/IMPLEMENTATION.md)** - Implementation history and decisions

## Development Examples

This framework is being actively developed and tested with real-world applications.

### Development Use Case: CyberMAX ERP

DelphiMCP is being developed alongside the CyberMAX ERP system for AI automation:

**Scale:**
- **28 core tools** (via target application)
- **9 bridge tools** (debug capture, echo, time)
- **413 operations** accessible via execute-internal
- **100+ commands** via command processor

**Current Status:**
- ✅ Non-modal form control and inspection working
- ⚠️ Modal dialogs cause blocking (under development)
- ✅ 70% token optimization for efficient API usage
- ⚠️ Not yet production-ready due to modal window limitation

**Note:** CyberMAX is a private system. This framework is being developed alongside it and generalized for public use.

## Testing

```bash
# Build the example
cd /mnt/w/Public/DelphiMCP/Examples/DelphiMCPserver/
# Use compiler-agent to compile

# Run tests
cd /mnt/w/Public/DelphiMCP/Binaries/
./DelphiMCPserver.exe

# Test with curl
curl http://localhost:3001/mcp
```

## Requirements

### Development

- **Delphi 12** (RAD Studio 12) or later
- **Windows 10/11**
- **Delphi-MCP-Server** framework (required dependency)
  - Located at: `/mnt/w/Delphi-MCP-Server/`
  - Provides: HTTP/SSE server, MCP protocol, tool management
  - Uses: Indy (included with Delphi)

### Runtime

- **Windows 10/11**
- **Delphi-MCP-Server** binaries
- **Target application** with MCP server implementation (your Delphi application)
- **Network port 3001** available (configurable via settings.ini)

## License

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0).
See [LICENSE](LICENSE) file for full details.

## Community & Support

### Getting Help

- 📖 **Documentation**: Start with [Documentation/](Documentation/) for comprehensive guides
- 🐛 **Bug Reports**: [Open an issue](https://github.com/JavierusTk/DelphiMCP/issues/new?template=bug_report.md) with the bug report template
- 💡 **Feature Requests**: [Suggest a feature](https://github.com/JavierusTk/DelphiMCP/issues/new?template=feature_request.md)
- ❓ **Questions**: [Ask a question](https://github.com/JavierusTk/DelphiMCP/issues/new?template=question.md) or check existing issues
- 💬 **Discussions**: Join [GitHub Discussions](https://github.com/JavierusTk/DelphiMCP/discussions) for general topics

### Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Reporting issues
- Submitting pull requests
- Code style and testing requirements
- Development workflow

### Staying Updated

- ⭐ **Star this repository** to show support and stay updated
- 👀 **Watch releases** for new versions and features
- 🔔 **Watch the repository** for notifications on issues and PRs

### Success Stories

Using DelphiMCP in production? We'd love to hear about it! Open an issue or discussion to share your experience.

## Version

**Current Version**: v3.2.0 (2025-10-12)

## Credits

Originally developed for CyberMAX ERP, now available as a general framework for connecting AI assistants to Delphi applications via the Model Context Protocol.

**Key Technologies**:
- Model Context Protocol (MCP) - https://modelcontextprotocol.io/
- Delphi-MCP-Server - HTTP/SSE server implementation
- Windows Named Pipes - IPC with target application
- Claude Code - AI coding assistant integration

## Known Limitations

### Critical Issues

- **⚠️ Modal Windows Not Supported**: The framework currently blocks when a modal form is displayed via `ShowModal()`. This affects:
  - Message boxes (ShowMessage, MessageDlg, etc.)
  - Modal dialogs (forms shown with ShowModal)
  - Any blocking UI operations
  - **Impact**: This is a critical limitation that prevents production use in many scenarios

### Minor Limitations

- **Single Connection**: Named pipe supports only one connection per pipe (no multi-connection support)
- **Windows Only**: Named pipes are Windows-specific (cross-platform support not planned)
- **Manual Restart**: Bridge server requires manual restart when target application restarts

### Roadmap

The modal window issue is the primary development focus. Once resolved, the framework will be considered production-ready.

---

**Status**: ⚠️ Work in Progress (Modal windows not supported)
**Version**: 3.2
**Last Updated**: 2025-10-12
