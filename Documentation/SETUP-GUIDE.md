# DelphiMCP Setup Guide - Connecting AI to Delphi Applications

## Overview

This guide shows how to configure Claude Code to control your Delphi application autonomously via the Model Context Protocol (MCP).

## Architecture

```
┌──────────────────┐
│   Claude Code    │  AI Assistant
│    (claude.ai)   │
└────────┬─────────┘
         │ MCP over HTTP
         ▼
┌──────────────────┐
│DelphiMCPserver   │  MCP Server (port 3001)
│     (.exe)       │
└────────┬─────────┘
         │ Named Pipe: \\.\pipe\YourApp_MCP_Request
         ▼
┌──────────────────┐
│  YourApp.exe     │  Your Delphi application with MCP server
│  (your app)      │
└──────────────────┘
```

## Prerequisites

1. **Your Delphi application** with embedded MCP server (see framework documentation for embedding instructions)
2. **DelphiMCPserver.exe** compiled from `/mnt/w/Public/DelphiMCP/Examples/DelphiMCPserver/`
3. **Claude Code** installed and configured

## Step 1: Start Your Application

Your Delphi application must be running with the MCP server enabled:

```bash
# Start your Delphi application
cd /path/to/your/app
./YourApp.exe
```

**Verify MCP Server is Running:**
- The named pipe `\\.\pipe\YourApp_MCP_Request` should be accessible
- Check debug output for "MCP server started" message (if implemented in your app)

## Step 2: Start DelphiMCPserver

The MCP server acts as a bridge between Claude Code and your Delphi application:

```bash
cd /mnt/w/Public/DelphiMCP/Binaries
./DelphiMCPserver.exe
```

**Expected Output:**
```
========================================
 DelphiMCP Bridge Server v2.1
========================================
Model Context Protocol Bridge for Delphi Applications

Server started successfully!

Available tools:
  Basic Tools:
    - mcp_hello            : Get greeting and server info
    - mcp_echo             : Echo back your message
    - mcp_time             : Get current system time

  Debug Capture Tools:
    - start_debug_capture  : Start capturing OutputDebugString
    ...

  Application Control Tools (requires running target application):
    Visual Inspection:
      - app_take_screenshot      : Capture screenshots
      - app_get_form_info        : Get form structure
      - app_list_open_forms      : List all open forms
    Control Interaction:
      - app_set_control_value    : Set values in controls
      - app_click_button         : Click buttons
      - app_select_combo_item    : Select ComboBox items
      - app_select_tab           : Switch tabs
      - app_close_form           : Close forms
      - app_set_focus            : Set control focus
    Discovery & Execution:
      - app_list_tools           : List all registered tools
      - app_execute_operation    : Execute operations
      - app_get_application_state: Get current app state

Press CTRL+C to stop...
========================================
```

The server is now listening on **port 3001**.

## Step 3: Configure Claude Code

### Get Your WSL IP Address

From WSL terminal:

```bash
ip route | grep default | awk '{print $3}'
```

Example output: `172.24.48.1`

### Add MCP Server to Claude Code

Open Claude Code settings and add the MCP server configuration:

**~/.claude/mcp_servers.json** (or use Claude Code UI):

```json
{
  "mcpServers": {
    "delphi-app": {
      "type": "http",
      "url": "http://172.24.48.1:3001/mcp",
      "description": "Delphi Application Automation"
    }
  }
}
```

**Replace `172.24.48.1` with your actual WSL IP address.**

## Step 4: Verify Connection

In Claude Code, the tools should appear as:

- `mcp__delphi-app__take-screenshot`
- `mcp__delphi-app__get-form-info`
- `mcp__delphi-app__list-tools`
- etc.

**Note:** The exact list of tools depends on which tools your application has registered. The bridge **dynamically discovers** all tools registered in your application's runtime registry.

### Test the Connection

Ask Claude Code:

> "Use the list-tools tool to show me all available operations"

Claude should be able to call the tool and display all registered tools from your application.

## Available Tools (Dynamic Discovery)

The bridge uses **dynamic tool discovery** - all tools are automatically discovered from your application's runtime registry. The exact tools available depend on which tools your application has registered.

### Core Tools (Always Available)

**Visual Inspection:**
- `take-screenshot` - Capture screenshots of screen/forms/controls
- `get-form-info` - Get form structure via RTTI introspection
- `list-open-forms` - List all open forms

**Control Interaction:**
- `set-control-value` - Set values in controls
- `click-button` - Click buttons
- `select-combo-item` - Select ComboBox items
- `select-tab` - Switch tabs
- `close-form` - Close forms
- `set-focus` - Set control focus

**Discovery & Execution:**
- `list-tools` - List all available MCP tools
- `get-application-state` - Get current app state

**State Management:**
- `get-execution-state` - Check execution status (busy/idle)

### Application-Specific Tools (Dynamically Added)

Your application can register additional custom tools. These tools will be automatically discovered by the bridge when your application is running.

**Example Custom Tools:**
- `get-customer-data` - Retrieve customer information
- `process-order` - Process an order
- `generate-report` - Generate custom reports
- etc.

**To see all available tools:**
Use the `list-tools` tool to get the complete, current list of all registered tools from your running application.

## Example Autonomous Workflows

### 1. Inspect Form and Take Screenshot

```
Claude: Use get-form-info with form="active"
Claude: Use take-screenshot with target="active", output="C:\Temp\form.png"
```

### 2. Control Form and Interact with UI

```
Claude: Use list-open-forms
Claude: Use set-control-value with form="MainForm", control="EditCustomerName", value="John Doe"
Claude: Use click-button with form="MainForm", button="btnSave"
Claude: Use take-screenshot with target="active"
```

### 3. Discover Available Tools

```
Claude: Use list-tools
  → Returns all tools with descriptions and categories
  → Shows which tools your application has registered
  → Provides complete tool inventory
```

### 4. Application-Specific Operations

```
Claude: Use your-custom-tool (if registered by your application)
Claude: Use get-application-state
Claude: Use get-execution-state
```

## Troubleshooting

### "Cannot connect to target application" Error

**Causes:**
1. Target application is not running
2. Target application does not have MCP server embedded/enabled
3. Named pipe not accessible

**Solutions:**
- Ensure your Delphi application is running
- Verify your application has the MCP server embedded and enabled
- Check application debug output for MCP server startup messages

### "Connection refused" from Claude Code

**Causes:**
1. DelphiMCPserver.exe is not running
2. Wrong IP address in configuration
3. Firewall blocking port 3001

**Solutions:**
- Verify DelphiMCPserver.exe is running and shows "Server started successfully!"
- Double-check WSL IP address: `ip route | grep default | awk '{print $3}'`
- Check Windows Firewall settings for port 3001

### Tools Not Appearing in Claude Code

**Causes:**
1. MCP server configuration incorrect
2. Claude Code not restarted after config change

**Solutions:**
- Verify `mcp_servers.json` syntax
- Restart Claude Code
- Check Claude Code logs for connection errors

## Advanced Usage

### Custom Application Commands

Your application may implement custom commands or operations. These are application-specific and should be documented by your application's implementation.

**Example command patterns:**
- Menu navigation commands
- Filter and query commands
- Export/import operations
- Business logic operations
- Form control commands

Refer to your application's documentation for available commands and their syntax.

### Screenshot Targets

The `take-screenshot` tool supports multiple capture modes:

- `screen` or `full` - Full desktop
- `active` or `focus` - Active form window
- `FormName` - Specific form by name
- `wincontrol` - Focused control (exact bounds)
- `wincontrol+20` - Focused control with 20px margin
- `wincontrol.parent` - Parent of focused control
- `wincontrol.parent.parent+40` - Grandparent with margin

## Architecture Details

### Named Pipe Communication

- **Pipe Name**: `\\.\pipe\YourApp_MCP_Request` (configurable)
- **Protocol**: JSON-RPC 2.0
- **Timeout**: 5 seconds (configurable)
- **Thread Safety**: All VCL access via `TThread.Synchronize`

### Non-Blocking Execution

- Operations can be queued for asynchronous execution
- Forms can execute during `Application.OnIdle` (application-dependent)
- Modal dialogs don't block MCP server
- Use `get-execution-state` to check status

### Dynamic Tool Discovery

- Bridge queries target application's `list-tools` on startup
- All registered tools are automatically exposed via HTTP MCP
- Application tools appear automatically when registered
- No bridge code changes needed when adding new tools to your application

### Error Handling

All tools return structured responses:
- Success: Operation result with data
- Failure: Error message from target application or connection issues

## Related Documentation

### DelphiMCP Framework Documentation
- **README.md** - Quick start and overview
- **ARCHITECTURE.md** - Complete architecture details
- **DYNAMIC-PROXY.md** - Dynamic tool discovery system (important!)
- **DEBUG-CAPTURE.md** - Debug capture system
- **Packages/README.md** - Package installation
- **Examples/DelphiMCPserver/README.md** - Example bridge server

### Production Examples
For a real-world production implementation, see the **CyberMAX ERP** system which uses this framework:
- 28 core tools dynamically discovered
- 413 operations via tool registry
- Full VCL form introspection and control
- Complete autonomous workflow capabilities

The CyberMAX implementation demonstrates how to embed the MCP server in a large-scale Delphi application and register custom tools for domain-specific operations.

---

**Version**: 2.1
**Last Updated**: 2025-10-11
**Status**: Production Ready
