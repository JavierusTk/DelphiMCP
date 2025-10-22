# Automation Framework - Generic VCL Automation for Delphi Applications

Work-in-progress framework providing 30 automation tools for AI-driven control of Delphi VCL applications via Model Context Protocol (MCP).

⚠️ **Known Limitation**: Modal windows not yet supported - framework blocks on ShowModal calls

## Overview

The Automation Framework enables AI assistants like Claude Code to autonomously interact with Delphi VCL applications through:
- Visual inspection (screenshots, form structure, control hierarchy)
- Control interaction (set values, click buttons, select items)
- Keyboard/mouse simulation (SendInput API)
- Synchronization primitives (wait for idle, focus, text)
- Development tools (tab order analysis, focusable forms)

**Key Facts:**
- **2-Package Architecture** - AutomationBridge (13 infrastructure units) + AutomationTools (30 tools)
- **30 generic tools** - Works with any Delphi VCL application (non-modal forms)
- **In Development** - Being developed alongside CyberMAX ERP system
- **Self-contained** - No external dependencies beyond Delphi RTL/VCL
- **Thread-safe** - All VCL access via `TThread.Synchronize`
- **Flexible** - Easy to extend with application-specific tools
- ⚠️ **Not Production Ready** - Modal window support under development

## Package Structure

**AutomationBridge.dpk** (Infrastructure - 13 units):
- Core: Config, Logger, Describable, Registry, Server, ServerThread
- Utilities: Screenshot, FormIntrospection, ControlInteraction, InputSimulation, Synchronization, Tabulator, TabOrderAnalyzer
- Dependencies: RTL, VCL, VCLIMG

**AutomationTools.dpk** (Tools - 1 unit with 30 tools):
- AutomationCoreTools.pas - All 30 automation tool implementations
- Dependencies: RTL, VCL, VCLIMG, **AutomationBridge**

## Quick Start

### 1. Add Framework to Your Project

Copy the AutomationFramework directory to your project or add as package reference.

### 2. Compile Packages

**Compilation Order** (required):
```bash
# 1. Compile AutomationBridge first (no dependencies)
/compile Source/AutomationTools/AutomationBridge.dproj

# 2. Compile AutomationTools (depends on Bridge)
/compile Source/AutomationTools/AutomationTools.dproj
```

### 3. Integrate in Your Application

**Simple Integration** (most applications):
```pascal
program MyApp;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas',
  AutomationServer,       // Framework server
  AutomationCoreTools;    // Tool implementations

begin
  Application.Initialize;
  Application.CreateForm(TfmMain, fmMain);

  RegisterCoreAutomationTools;  // Register 30 tools
  StartAutomationServer;        // Start server

  Application.Run;
end.
```

**Advanced Integration** (with custom tools):
```pascal
// Register your custom tools first
procedure RegisterMyTools;
begin
  AutomationToolRegistry.TAutomationToolRegistry.Instance.RegisterTool(
    'my-custom-tool',
    procedure(const Params: TJSONObject; out Result: TJSONObject)
    begin
      // Your tool implementation
    end,
    'My tool description',
    'Custom',
    'MyModule'
  );
end;

// Then start server
begin
  RegisterCoreAutomationTools;  // Register 30 core tools
  RegisterMyTools;              // Register your custom tools
  StartAutomationServer;        // Start server
  Application.Run;
end;
```

### 4. Connect Bridge Server

Run the DelphiMCP bridge server to connect your application to Claude Code:
```bash
cd /mnt/w/Public/DelphiMCP/Binaries
./DelphiMCPserver.exe
```

### 5. Configure Claude Code

Add to `~/.claude/mcp_servers.json`:
```json
{
  "mcpServers": {
    "my-app": {
      "type": "http",
      "url": "http://localhost:3001/mcp"
    }
  }
}
```

## Architecture

```
┌───────────────────────────────────────────────────┐
│   Your Delphi VCL Application                     │
│                                                   │
│   RegisterCoreAutomationTools()                   │
│   RegisterMyTools() ← Optional                    │
│   StartAutomationServer()                         │
│   ↓                                               │
│   [AutomationTools Package]                       │
│   - 30 Generic Tools (AutomationCoreTools.pas)   │
│          ↓ depends on                             │
│   [AutomationBridge Package]                      │
│   - Named Pipe Server                             │
│   - Tool Registry                                 │
│   - Automation Utilities                          │
└───────────────────────────────────────────────────┘
              ↓
    Named Pipe: \\.\pipe\YourApp_MCP_Request
              ↓
┌───────────────────────────────────────────────────┐
│   DelphiMCP Bridge Server                         │
│   (HTTP/SSE on port 3001)                         │
└───────────────────────────────────────────────────┘
              ↓
┌───────────────────────────────────────────────────┐
│   Claude Code (AI Assistant)                      │
└───────────────────────────────────────────────────┘
```

## Available Tools (30)

### Visual Inspection (9 tools)
- `take-screenshot` - Capture screen/form/control screenshots
- `get-form-info` - Get form structure via RTTI introspection
- `list-open-forms` - List all open forms
- `list-controls` - List controls in a form
- `find-control` - Find control by name/caption
- `get-control` - Get detailed control information
- `ui_get_tree_diff` - Compare form control trees
- `ui_focus_get` - Get currently focused control
- `ui_value_get` - Get control value/text

### Control Interaction (7 tools)
- `set-control-value` - Set control value/text
- `ui_set_text_verified` - Set text with verification
- `click-button` - Click a button
- `select-combo-item` - Select ComboBox/ListBox item
- `select-tab` - Switch to a tab page
- `close-form` - Close a form
- `set-focus` - Set focus to a control

### Keyboard/Mouse Simulation (5 tools)
- `ui_send_keys` - Send keyboard input
- `ui_mouse_move` - Move mouse cursor
- `ui_mouse_click` - Click mouse button
- `ui_mouse_dblclick` - Double-click mouse
- `ui_mouse_wheel` - Scroll mouse wheel

### Synchronization (4 tools)
- `wait_idle` - Wait for application idle state
- `wait_focus` - Wait for control to receive focus
- `wait_text` - Wait for text to appear
- `wait_when` - Wait for custom condition

### Development Tools (2 tools)
- `analyze-form-taborder` - Analyze tab order
- `list-focusable-forms` - List forms that can receive focus

### Utility (2 tools)
- `echo` - Echo back a message (connectivity test)
- `list-tools` - List all registered tools

## Configuration

### Default Settings

The framework uses sensible defaults:
```pascal
TAutomationConfig.Default:
  PipeName: '\\.\pipe\YourApp_MCP_Request'
  Timeout: 30000 ms (30 seconds)
  MaxConnections: 1
```

### Custom Configuration

```pascal
var
  Config: TAutomationConfig;
  Server: TAutomationServer;
begin
  Config.PipeName := '\\.\pipe\MyCustomPipe';
  Config.TimeoutMS := 60000;  // 60 seconds

  Server := TAutomationServer.Create;
  try
    RegisterCoreAutomationTools;  // 30 tools
    Server.Start(Config);
  finally
    Server.Free;
  end;
end;
```

## Adding Custom Tools

### Step 1: Create Tool Handler

```pascal
procedure MyCustomTool(const Params: TJSONObject; out Result: TJSONObject);
begin
  Result := TJSONObject.Create;

  // Thread-safe VCL access
  TThread.Synchronize(nil, procedure
  var
    Form: TForm;
  begin
    Form := Screen.ActiveForm;
    if Assigned(Form) then
      Result.AddPair('title', Form.Caption);
  end);
end;
```

### Step 2: Register Tool

```pascal
RegisterAutomationTool(
  'get-active-form-title',  // Tool name
  'Custom',                 // Category
  'Get active form title',  // Description
  @MyCustomTool,            // Handler
  nil                       // JSON schema (optional)
);
```

### Step 3: Start Server

```pascal
// Register custom tools first
RegisterAutomationTool(...);

// Then start server (registers core tools automatically)
StartAutomationServer;
```

## Thread Safety

**Critical**: The automation server runs on a background thread. All VCL access MUST use `TThread.Synchronize`:

```pascal
procedure MyTool(const Params: TJSONObject; out Result: TJSONObject);
begin
  Result := TJSONObject.Create;

  TThread.Synchronize(nil, procedure
  begin
    // Safe VCL access here
    ShowMessage('This is safe');
    Button1.Click;
  end);
end;
```

## Logging

The framework uses `AutomationLogger` which defaults to `OutputDebugString`:

```pascal
uses AutomationLogger;

// Logs appear in debug output
Log(llInfo, 'Server started');
Log(llError, 'Tool execution failed');
```

### Custom Logger

```pascal
AutomationLogHandler := procedure(Level: TLogLevel; const Msg: string)
begin
  WriteLn('[' + LogLevelToStr(Level) + '] ' + Msg);
end;
```

## Examples

See `/mnt/w/Public/DelphiMCP/Examples/SimpleVCLApp/` for complete integration example.

## Production Use

This framework powers the **CyberMAX ERP** system in production:
- 30 generic tools (from framework)
- 6 CyberMAX-specific tools
- Full autonomous form control
- Complete business operation execution
- 70% token optimization

## Dependencies

- **Delphi 12** (RAD Studio 12 Athens) or later
- **RTL** - Delphi Runtime Library
- **VCL** - Visual Component Library
- **vclimg** - VCL Imaging components
- **Windows** - Named pipes are Windows-specific

## Files

**Core Infrastructure** (6 files):
- `AutomationServer.pas` - Lifecycle management
- `AutomationServerThread.pas` - Named pipe listener
- `AutomationToolRegistry.pas` - Tool registration
- `AutomationConfig.pas` - Configuration
- `AutomationLogger.pas` - Logging
- `AutomationDescribable.pas` - Interfaces

**Tool Implementation** (7 files):
- `AutomationCoreTools.pas` - 30 tool registrations
- `AutomationScreenshot.pas` - Screenshot capture
- `AutomationFormIntrospection.pas` - RTTI inspection
- `AutomationControlInteraction.pas` - Control manipulation
- `AutomationInputSimulation.pas` - Keyboard/mouse
- `AutomationSynchronization.pas` - Wait primitives
- `AutomationTabulator.pas` - Tab order analysis

## License

MPL-2.0 (Mozilla Public License 2.0)

## Related Documentation

- **DelphiMCP README**: `../../README.md`
- **Setup Guide**: `../../Documentation/SETUP-GUIDE.md`
- **Architecture**: `../../Documentation/ARCHITECTURE.md`
- **Example App**: `../../Examples/SimpleVCLApp/`

---

**Version**: 3.0.0
**Status**: Production Ready
**Source**: Extracted from CyberMAX ERP system
