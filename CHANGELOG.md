# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2025-10-12

### Initial Public Release

**DelphiMCP** - Work-in-Progress Generic VCL Automation Framework for Delphi applications.

⚠️ **Important**: This release is NOT production-ready due to modal window limitations (see Known Issues below).

### Features

**Automation Framework (30 tools)**:
- **Visual Inspection (9 tools)**: take-screenshot, get-form-info, list-open-forms, list-controls, find-control, get-control, ui_get_tree_diff, ui_focus_get, ui_value_get
- **Control Interaction (7 tools)**: set-control-value, ui_set_text_verified, click-button, select-combo-item, select-tab, close-form, set-focus
- **Keyboard/Mouse (5 tools)**: ui_send_keys, ui_mouse_move, ui_mouse_click, ui_mouse_dblclick, ui_mouse_wheel
- **Synchronization (4 tools)**: wait_idle, wait_focus, wait_text, wait_when
- **Development (2 tools)**: analyze-form-taborder, list-focusable-forms
- **Utility (2 tools)**: echo, list-tools

**Bridge Tools (9 tools)**:
- **Debug Capture (5 tools)**: start_debug_capture, get_debug_messages, stop_debug_capture, get_capture_status, pause_resume_capture
- **Utility (4 tools)**: mcp_hello, mcp_echo, mcp_time, get_process_summary

**Architecture**:
- 2-package structure: AutomationBridge (13 infrastructure units) + AutomationTools (30 tools)
- Clean dependency chain: Tools → Bridge → RTL/VCL
- Named pipe server with JSON-RPC 2.0
- HTTP/SSE bridge server (port 3001)
- Dynamic tool discovery (zero maintenance)

**Key Capabilities**:
- Thread-safe VCL interaction (TThread.Synchronize)
- Self-contained (~6,000 lines, no external dependencies)
- Configurable without recompilation (settings.ini)
- Works with ANY Delphi VCL application (non-modal forms)
- Being developed alongside CyberMAX ERP

### Technical Details

- **AutomationBridge.dpk**: 13 infrastructure units (Config, Logger, Registry, Server, ServerThread, Describable, Screenshot, FormIntrospection, ControlInteraction, InputSimulation, Synchronization, Tabulator, TabOrderAnalyzer)
- **AutomationTools.dpk**: 1 unit (AutomationCoreTools.pas) with 30 tool implementations
- **Compilation**: All projects compile with 0 errors, 0 warnings, 0 hints
- **Build times**: AutomationBridge (0.17s, 156KB), AutomationTools (clean), SimpleVCLApp (0.44s), DelphiMCPserver (0.25s)

### Requirements

- Delphi 12 (RAD Studio 12 Athens) or later
- Windows platform (named pipes are Windows-specific)
- Delphi-MCP-Server framework (HTTP/SSE server infrastructure)

### Integration

Minimal integration (2 lines):
```pascal
uses AutomationServer, AutomationCoreTools;
begin
  RegisterCoreAutomationTools;  // Register 30 tools
  StartAutomationServer;        // Start server
  Application.Run;
end;
```

### Known Issues

**Critical:**
- **⚠️ Modal Windows Not Supported**: Framework blocks when modal forms are displayed via ShowModal()
  - Affects: Message boxes (ShowMessage, MessageDlg), modal dialogs, blocking UI operations
  - Impact: Prevents production use in applications with modal dialogs
  - Status: Actively being worked on - primary development focus

**Minor:**
- Bridge server requires manual restart when target application restarts
- Single connection per named pipe (no multi-connection support yet)
- Windows-only (named pipes are Windows-specific)

### What Works

- ✅ Non-modal form automation (Show, not ShowModal)
- ✅ Visual inspection and screenshots
- ✅ Control interaction and keyboard/mouse simulation
- ✅ Synchronization and waiting
- ✅ Debug capture and logging

### Roadmap

**Next Priority**: Resolve modal window blocking issue to enable production use

---

For detailed documentation, see:
- [README.md](README.md) - Overview and quick start
- [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) - Architecture details
- [SETUP-GUIDE.md](Documentation/SETUP-GUIDE.md) - Complete setup instructions
