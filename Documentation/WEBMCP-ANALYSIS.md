# WebMCP Adapted to Delphi ERP: Codebase Analysis and Feasibility Assessment

**Date**: 2026-02-20
**Reviewer**: Claude Code (AI Agent)
**Context**: Analysis of WebMCP architecture proposals against the actual DelphiMCP repository
**Scope**: DelphiMCP repository + referenced (but not present) AutomationTools framework

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Architecture Assessment](#2-current-architecture-assessment)
3. [Gap Analysis: What Exists vs What's Proposed](#3-gap-analysis-what-exists-vs-whats-proposed)
4. [Evaluation of Proposal 1 (FormMCP)](#4-evaluation-of-proposal-1-formmcp)
5. [Evaluation of Proposal 2 (Layered Architecture)](#5-evaluation-of-proposal-2-layered-architecture)
6. [Evaluation of Proposal 3 (Hybrid Workflow Engine)](#6-evaluation-of-proposal-3-hybrid-workflow-engine)
7. [Answers to Codebase Questions](#7-answers-to-codebase-questions)
8. [Implementation Recommendations](#8-implementation-recommendations)
9. [Proposed Architecture: Incremental Workflow Layer](#9-proposed-architecture-incremental-workflow-layer)
10. [Risk Assessment](#10-risk-assessment)

---

## 1. Executive Summary

After thorough analysis of the DelphiMCP repository (all source files, documentation, examples, and architecture documents), here is the assessment:

**The Hybrid Workflow Engine (Proposal 3) is the correct architectural direction**, but the document underestimates both what already exists and what needs to change. The current codebase provides a solid foundation that Proposal 3 can build on incrementally, without requiring a rewrite.

### Key Findings

1. **The existing architecture already implements ~60% of Proposal 2's "Layered Architecture"** — the named pipe infrastructure, dynamic tool discovery, thread-safe execution via `TThread.Synchronize`, and the bridge server are all production-quality code.

2. **Proposal 1 (FormMCP) should be discarded** — the document's critique is correct. The coupling, closure lifetime, and scaling problems are real. The codebase has no `IFormToolProvider` or equivalent, and adding one would be counterproductive.

3. **Proposal 2's generic layer already partially exists** — the 41 automation tools (screenshot, click-button, set-control-value, etc.) ARE the "UI Actuation" layer. What's missing is the "UI Awareness" enrichment and the semantic domain layer.

4. **Proposal 3's Workflow Engine is the right next step**, but should be implemented as an **additional layer on top of the existing infrastructure**, not as a replacement. The existing 41 tools remain valuable for ad-hoc debugging and exploration. The workflow layer adds domain-level operations on top.

5. **The biggest unsolved technical problem is modal window blocking** — documented extensively in `IMPLEMENTATION_RESULTS.md` as still unresolved. The `PostMessage`-based broker approach was implemented but proved unreliable. This affects all three proposals equally.

6. **The AutomationTools source code is not in this repository** — it lives at a Windows-mapped path (`/mnt/w/Public/DelphiMCP/Source/AutomationTools/`). The analysis relies on documentation, the SimpleVCLApp example, and references in other files.

---

## 2. Current Architecture Assessment

### What the Repository Contains

```
DelphiMCP/
├── Source/
│   ├── MCPbridge/Core/                          # Bridge infrastructure
│   │   ├── MCPServer.Application.DynamicProxy.pas  # Dynamic tool discovery (312 lines)
│   │   ├── MCPServer.Application.PipeClient.pas    # Named pipe JSON-RPC (147 lines)
│   │   ├── MCPServer.DebugCapture.Core.pas         # Debug capture engine (689 lines)
│   │   ├── MCPServer.DebugCapture.Types.pas        # Debug types (335 lines)
│   │   └── MCP.Tool.Adapter.Indy.pas              # Tool adapter layer (182 lines)
│   ├── MCPserver/
│   │   ├── DelphiMCPserver.dpr                     # Bridge server program (336 lines)
│   │   ├── Backend/MCP.Backend.Intf.pas            # Backend interface (34 lines)
│   │   └── settings.ini                            # Configuration
│   └── [AutomationTools/ - NOT IN REPO]            # Referenced externally
├── Examples/SimpleVCLApp/                          # Integration example
├── Documentation/                                  # 8 markdown documents
└── CLAUDE.md                                      # Comprehensive project guide
```

### Architectural Strengths

1. **Dynamic Proxy Pattern** (`DynamicProxy.pas`): The factory-with-closure pattern at lines 261-276 is well-designed. Each tool call creates a fresh `TApplicationDynamicTool` instance with its own schema clone, avoiding shared state issues.

2. **Clean Separation of Concerns**: Bridge (HTTP/SSE) ↔ Pipe Client (IPC) ↔ Target App (VCL) — each layer has clear responsibilities.

3. **Backend-Agnostic Tool Design** (`MCP.Tool.Adapter.Indy.pas`): The `TMCPToolIndyAdapter` wraps `IMCPToolGeneric` so tools can work with different HTTP backends. This is forward-looking design.

4. **Thread Safety in Debug Capture**: `TCaptureSession` uses `TCriticalSection` correctly throughout. The capture thread properly handles `DBWIN_BUFFER` shared memory with mutex synchronization.

5. **Configuration Flexibility**: The bridge server supports command-line overrides > settings.ini > defaults, with smart pipe name expansion (e.g., "CyberMAX" → `\\.\pipe\CyberMAX_MCP_Request`).

### Architectural Weaknesses

1. **Modal Window Blocking** (documented in `IMPLEMENTATION_RESULTS.md`): The `TThread.Synchronize` approach blocks when VCL modal dialogs are open. The `PostMessage`-based broker was implemented but proved unreliable. This is the most serious technical limitation.

2. **Single-Connection Named Pipe**: Only one bridge server can connect at a time. No multi-client support.

3. **Static Tool Discovery**: Tools are discovered once at bridge startup. Adding/removing tools requires a bridge restart.

4. **No UI Context Awareness**: The bridge forwards calls blindly — it has no knowledge of which form is open, what mode it's in, or what the user is looking at.

5. **External Dependencies Not Vendored**: The `Delphi-MCP-Server` framework lives at `W:\Delphi-MCP-Server\` and shared tools at `..\..\..\DelphiMCPbridge\Source\SharedTools\` — both referenced by relative/absolute paths, not included in the repository.

---

## 3. Gap Analysis: What Exists vs What's Proposed

### Proposal 3 Requirements vs Current State

| Requirement | Current State | Gap |
|---|---|---|
| Domain-level MCP tools (invoice_create, etc.) | Generic UI tools (click-button, set-value) | **Large gap** — no domain tools exist |
| UI Awareness (get_ui_context) | Partial — `list-open-forms`, `get-form-info` exist | **Small gap** — needs enrichment with TAction introspection |
| Workflow Engine with dual-channel execution | Not present | **Large gap** — core of Proposal 3 |
| TStepResult / NeedsInput protocol | Not present | **Medium gap** — needs design and implementation |
| TEvent-based thread synchronization | Uses TThread.Synchronize (blocking on modals) | **Medium gap** — broker approach was attempted but unreliable |
| Backend execution channel | Not present in DelphiMCP (may exist in CyberMAX MCP server) | **Unknown** — depends on CyberMAX codebase |
| UI execution channel | 41 automation tools provide primitives | **Small gap** — tools exist, need orchestration layer |
| Channel selection heuristic | Not present | **Medium gap** — straightforward to implement |
| Named pipe communication | Fully implemented and production-quality | **No gap** |
| Dynamic tool discovery | Fully implemented | **No gap** — but needs extension for workflow tools |
| HTTP/SSE MCP server | Fully implemented | **No gap** |

### What Can Be Reused Directly

1. **Named pipe infrastructure** — PipeClient, DynamicProxy, JSON-RPC 2.0 protocol
2. **HTTP/SSE bridge server** — TMCPIdHTTPServer, settings, CORS, shutdown handling
3. **Tool registration system** — TMCPRegistry.RegisterTool with factory pattern
4. **Debug capture system** — Entire debug infrastructure
5. **Configuration system** — settings.ini, command-line parsing
6. **Adapter pattern** — TMCPToolIndyAdapter for wrapping domain tools

### What Needs to Be Built

1. **Workflow Engine** — TWorkflowEngine, TWorkflowStep, TWorkflowContext
2. **Domain Steps** — TStepCreateInvoice, TStepSelectCustomer, etc.
3. **UI Awareness enrichment** — TAction introspection, dataset state, semantic form context
4. **NeedsInput protocol** — Ambiguity resolution in tool results
5. **Channel routing** — ecUI vs ecBackend decision logic
6. **Backend execution channel** — Direct business layer calls (requires CyberMAX internals)

---

## 4. Evaluation of Proposal 1 (FormMCP)

**Verdict: Reject**

The document's critique (Section 4) is accurate and well-argued. Additional evidence from the codebase:

1. **No IFormToolProvider exists** — The codebase uses a registry-based pattern (`TAutomationToolRegistry.Instance.RegisterTool`) with procedure callbacks, not interface implementations on forms. Switching to `IFormToolProvider` would be a paradigm shift.

2. **SimpleVCLApp confirms the simple integration pattern** — `MCPServerIntegration.pas` shows the 2-line pattern: `RegisterCoreAutomationTools; StartAutomationServer;`. This is incompatible with per-form tool providers.

3. **Closure lifetime IS dangerous** — `MCPServerIntegration.pas:39-50` shows tools registered with anonymous procedures that capture nothing dangerous (just creating TJSONObject). FormMCP closures would capture `Self` (the form), creating the lifetime issue the critique describes.

4. **No TAction introspection infrastructure** — The SimpleVCLApp example doesn't use TActionList. CyberMAX likely does (ERP apps typically use extensive TAction systems), but there's no code in this repo to introspect them.

---

## 5. Evaluation of Proposal 2 (Layered Architecture)

**Verdict: Partially implemented, but insufficient as the final architecture**

### What Already Exists (Layer 2 + Layer 3)

The 41 automation tools are essentially Proposal 2's Layer 3 ("UI Actuation"):

- `get-form-info` ≈ `get_ui_context` (forms and controls)
- `click-button` ≈ `execute_ui_action` (but more specific)
- `set-control-value` ≈ `set_ui_value`
- `list-open-forms` ≈ UI awareness
- `take-screenshot` = visual feedback

### What's Missing

1. **TAction introspection** — The most valuable piece of Layer 2. CyberMAX forms presumably have TActionList with actions like `actNuevo`, `actGuardar`, `actBuscarCliente`. These SHOULD be exposed to the agent because they ARE the semantic operations of the form. Currently, the automation tools only see controls (buttons, edits, combos), not actions.

2. **Semantic enrichment** — Generic introspection produces noise (Section 6.1 of the proposal document is correct). The fix isn't to abandon introspection but to add domain metadata. This could be:
   - External metadata files (JSON) mapping TAction names to descriptions
   - RTTI attributes on action handlers (if CyberMAX supports Delphi 12 attributes)
   - A convention-based system where action names follow a pattern (e.g., `actBuscarCliente` → "Search Customer")

3. **The 12-call problem** — Section 6.3 is the strongest argument against Proposal 2 as the final architecture. Making an invoice requires too many round-trips with generic tools. This is the core motivation for Proposal 3's workflow layer.

### Valid Counterargument

Proposal 2 works well for **exploratory/debugging** scenarios where the agent needs to understand an unfamiliar form. The existing 41 tools are excellent for:
- "What forms are open?"
- "What controls does this form have?"
- "Take a screenshot so I can see the current state"
- "Click this button to see what happens"

These are coding/debugging use cases, not business workflow automation. Both layers should coexist.

---

## 6. Evaluation of Proposal 3 (Hybrid Workflow Engine)

**Verdict: Correct architectural direction with important caveats**

### Strengths of the Proposal

1. **The workflow abstraction is right** — "Create invoice for Grupo Anton" IS the right level of abstraction for an AI agent. The document correctly identifies that the problem is workflow-level, not tool-level.

2. **Dual-channel execution is elegant** — The `CanExecuteViaUI` / `CanExecuteViaBackend` pattern allows graceful degradation. If the invoice form is open, the user sees the agent working. If not, it works silently in the backend.

3. **NeedsInput solves ambiguity** — The `TStepResult.NeedsInput` with choices is a clean way to handle multiple matches. This maps well to how LLMs handle disambiguation.

4. **3 calls instead of 12** — The token and latency savings are substantial. For repetitive business operations, this matters.

5. **TEvent-based synchronization** — Using `TEvent` instead of polling with `Sleep(10)` is the correct approach. The code in the proposal document is nearly production-ready.

### Weaknesses and Risks

1. **Backend channel requires deep CyberMAX integration** — `TStepSelectCustomer.ExecuteViaBackend` calls `DMMain.BuscarCliente(Query)`. This requires access to data modules, business logic classes, and database connections that live inside CyberMAX. The workflow engine must live INSIDE the target application, not in the bridge server.

2. **UI channel has the modal blocking problem** — `ExecuteOnMainThread` uses `TThread.Queue` + `TEvent.WaitFor(10000)`. This is the same fundamental approach as the broker in `IMPLEMENTATION_RESULTS.md`, which proved unreliable. The timeout message "main thread may be blocked by modal dialog" acknowledges this.

3. **Step authoring cost is underestimated** — Each `TWorkflowStep` subclass needs:
   - Knowledge of the specific form class (`TFrmFactura`)
   - Knowledge of internal methods (`SeleccionarClientePorBusqueda`)
   - Knowledge of the data model (`Frm.edtCodCliente.Text`)
   - Dual implementation (UI + backend)
   - Error handling for both channels

   The document estimates "10-15 step classes cover 80% of usage." For a mature ERP with hundreds of operations, the real number is likely 50-100+ to cover the long tail.

4. **Channel heuristic is too simplistic** — `Screen.ActiveForm <> nil` is always true in a desktop app. The real heuristic should be `Screen.ActiveForm is TFrmFactura` (checking if the RELEVANT form is active), which the `TStepSelectCustomer.CanExecuteViaUI` example does correctly, but the `DetermineChannel` method does not.

5. **Cross-form workflow steps are complex** — `invoice_from_delivery_note` involves:
   - Opening the delivery note list
   - Selecting delivery notes
   - Creating an invoice
   - Copying lines with recalculation
   - This may require multiple forms open simultaneously, which complicates both channels.

### Critical Design Decision: Where Does the Workflow Engine Live?

The proposal shows the workflow engine as part of the "Unified MCP Server" layer (the bridge). But the engine calls:
- `TFrmFactura(Screen.ActiveForm).SeleccionarClientePorBusqueda(Query)` — UI channel
- `DMMain.BuscarCliente(Query)` — Backend channel

Both of these are INSIDE the target application's process. The bridge (separate .exe) cannot call them.

**The workflow engine must be embedded in the target application**, alongside the existing AutomationTools framework. The bridge server continues to forward calls via named pipe, but the workflow orchestration happens in-process.

```
Bridge Server (HTTP → Pipe)  →  Target App (Pipe → WorkflowEngine → VCL/DataModules)
```

This is consistent with the existing pattern: the 41 automation tools run INSIDE the target app via `TThread.Synchronize`, not in the bridge.

---

## 7. Answers to Codebase Questions

Based on what's visible in this repository and documentation:

### Architecture Questions

**Q1: How are forms organized?**
From the SimpleVCLApp example: simple inheritance from TForm. No custom base form class visible in the repo. CyberMAX likely has base classes (ERP apps typically do), but this would require examining the CyberMAX codebase. The `CLAUDE.md` references "runtime-loaded packages" suggesting a modular package architecture.

**Q2: What does the existing MCP server expose?**
41 automation tools (30 core + custom) via named pipe JSON-RPC 2.0. Tools are registered via `TAutomationToolRegistry.Instance.RegisterTool()`. The bridge adds 9 more (debug capture + utilities). Transport: Named pipe → Bridge → HTTP/SSE on port 3001.

**Q3: Package structure?**
Two-package architecture visible from CLAUDE.md:
- `AutomationBridge.dpk` (14 infrastructure units)
- `AutomationTools.dpk` (1 unit with 30+ tools, depends on Bridge)
CyberMAX uses runtime-loaded packages (referenced in docs). The WorkflowEngine should live in a NEW package (e.g., `WorkflowEngine.dpk`) that depends on AutomationBridge but NOT on AutomationTools.

**Q4: Data module structure?**
Not visible in this repo. The proposal references `DMMain.BuscarCliente(Query)` suggesting a central data module pattern. This must be investigated in the CyberMAX codebase.

**Q5: TAction usage?**
SimpleVCLApp does NOT use TActionList (the example uses button OnClick handlers directly). CyberMAX almost certainly does (standard for Delphi ERP apps). The CLAUDE.md mentions "413 operations via `execute-internal` tool" and "100+ commands via command processor" — these suggest structured action/command systems exist in CyberMAX.

**Q6: Form state management?**
Not visible in repo. The proposal references `FMode in [fmEditing, fmInserting]` and `DataSet.State in [dsEdit, dsInsert]` — standard Delphi DB-aware form patterns.

**Q7: Lookup mechanisms?**
Not visible in repo. The proposal describes `SeleccionarClientePorBusqueda(Query)` as an internal method that bypasses modal lookup dialogs. These internal methods must be identified in CyberMAX.

**Q8: Event cascades?**
Not visible in repo. The proposal describes customer selection triggering cascading fills (tax ID, address, payment terms, pricing tier). These would fire in the main thread via VCL event handlers, making them safe to call from `TThread.Queue`.

**Q9: VeriFactu integration?**
Not visible in repo. Mentioned in the proposal as part of invoice save validation.

**Q10: Error handling patterns?**
Not fully visible. `IMPLEMENTATION_RESULTS.md` documents ShowMessage as the primary error display mechanism. The automation framework captures errors via JSON-RPC error objects.

**Q11: Thread safety of internal methods?**
The existing automation tools use `TThread.Synchronize` to execute on the main VCL thread. This is safe for any VCL code. The modal blocking issue occurs because `Synchronize` blocks when a modal message loop is running.

**Q12: Test infrastructure?**
No test framework visible in the repository. The SimpleVCLApp serves as manual integration test. No unit tests, no CI/CD.

**Q13: Most valuable operations?**
Based on the CLAUDE.md reference to CyberMAX: invoice creation, customer management, stock queries, delivery note processing. The 413 `execute-internal` operations and 100+ command processor commands suggest these are already exposed at some level.

---

## 8. Implementation Recommendations

### Strategy: Incremental Layering, Not Replacement

Do NOT replace the existing 41 automation tools with workflow steps. Instead, add the workflow layer ON TOP:

```
┌─────────────────────────────────────────────────┐
│                 AGENT (LLM)                     │
├─────────────────────────────────────────────────┤
│            Unified MCP Server (Bridge)          │
├───────────┬──────────────┬──────────────────────┤
│  Bridge   │  Automation  │    Workflow           │
│  Tools    │  Tools       │    Tools              │
│  (9)      │  (41)        │    (NEW)              │
│           │              │                       │
│ mcp_hello │ screenshot   │ invoice_create        │
│ mcp_echo  │ click_button │ invoice_add_line      │
│ debug_*   │ set_value    │ customer_search       │
│           │ list_forms   │ stock_check           │
│           │ send_keys    │ get_erp_context       │
│           │ ...          │ ...                   │
└───────────┴──────────────┴──────────────────────┘
```

The automation tools remain for:
- Debugging and exploration
- Ad-hoc operations not covered by workflows
- Screen verification (screenshots)
- Emergency fallback (when workflow steps fail)

The workflow tools provide:
- Domain-level operations (3 calls instead of 12)
- Dual-channel execution
- NeedsInput disambiguation
- Business logic preservation

### Phase 0: Prerequisites (CyberMAX Codebase Analysis)

Before implementing any workflow steps, investigate the CyberMAX codebase to answer:

1. **Identify internal methods** that can be called programmatically:
   - Customer search without modal dialog
   - Invoice creation without UI
   - Product lookup without popup
   - Save with validation but without confirmation dialog

2. **Identify data module access points**:
   - Central data module(s)
   - Database connection management
   - Transaction handling

3. **Identify form base classes**:
   - Common base form class (if any)
   - Standard patterns for edit/insert/browse modes
   - TAction naming conventions

4. **Identify the `execute-internal` system**:
   - What are the 413 operations?
   - How are they registered?
   - Can they be called from the workflow engine?
   - Do they provide the "backend channel" already?

5. **Resolve the modal blocking problem**:
   - The `PostMessage`-based broker was unreliable
   - Consider: `Application.ProcessMessages` in a loop with TEvent check
   - Consider: Using `SendMessage(WM_APP_*)` instead of `PostMessage`
   - Consider: Running the named pipe server in a Windows message loop (not `TThread.Synchronize`)
   - This must be solved before any UI-channel workflow steps work reliably

### Phase 1: Foundation (In Target Application)

**New package: `WorkflowEngine.dpk`**

Core types (as proposed in the document, with modifications):

```pascal
unit WorkflowEngine.Core;

interface

uses
  System.SysUtils, System.JSON, System.Classes, System.SyncObjs;

type
  TExecutionChannel = (ecAuto, ecUI, ecBackend);
  TStepStatus = (ssSuccess, ssFailure, ssNeedsInput, ssSkipped);

  TStepResult = record
    Status: TStepStatus;
    Data: TJSONObject;        // Caller takes ownership
    Message: string;
    Channel: TExecutionChannel; // Which channel was actually used
    class function OK(const AMsg: string; AData: TJSONObject = nil): TStepResult; static;
    class function Fail(const AMsg: string): TStepResult; static;
    class function NeedsInput(const AMsg: string; AChoices: TJSONArray = nil): TStepResult; static;
  end;

  TWorkflowStep = class abstract
  public
    function CanExecuteViaUI: Boolean; virtual; abstract;
    function CanExecuteViaBackend: Boolean; virtual; abstract;
    function ExecuteViaUI(const AParams: TJSONObject): TStepResult; virtual;
    function ExecuteViaBackend(const AParams: TJSONObject): TStepResult; virtual;
  end;
```

**Integration with existing tool registry:**

```pascal
// Register workflow tool alongside existing automation tools
TAutomationToolRegistry.Instance.RegisterTool(
  'invoice_create',
  procedure(const Params: TJSONObject; out Result: TJSONObject)
  var
    Step: TStepCreateInvoice;
    Context: TWorkflowContext;
    StepResult: TStepResult;
  begin
    Step := TStepCreateInvoice.Create;
    Context := TWorkflowContext.Create;
    try
      StepResult := WorkflowEngine.Execute(Step, Params, Context);
      Result := StepResultToJSON(StepResult);
    finally
      Step.Free;
      Context.Free;
    end;
  end,
  'Creates a new sales invoice. If the invoice form is open, fills it visually. Otherwise creates in backend.',
  'Workflow',
  'CyberMAX',
  // Schema:
  CreateInvoiceSchema  // JSON schema with customer, serie, date parameters
);
```

This approach means:
- Workflow tools register in the SAME registry as automation tools
- The bridge discovers them via the SAME `list-tools` mechanism
- No changes to the bridge server needed
- The agent sees both automation tools AND workflow tools

### Phase 2: First Workflow Steps

Start with the highest-value operations (as the document suggests):

1. `erp_context` — Enhanced UI context with form mode, dataset state, TAction list
2. `customer_search` — Search customers with NeedsInput for disambiguation
3. `invoice_create` — Create new invoice (dual channel)
4. `invoice_add_line` — Add line to current invoice
5. `invoice_save` — Save with validation

### Phase 3: Enrichment

6. NeedsInput protocol integration with agent
7. Backend-to-UI notification
8. Cross-form operations (invoice from delivery note)
9. Compound operations (batch invoice creation)

### Phase 4: Generalization

10. Base classes for common patterns (CRUD, lookup, master-detail)
11. Metadata-driven step generation (from DataModule inspection)
12. Performance measurement and optimization

---

## 9. Proposed Architecture: Incremental Workflow Layer

### Where Components Live

```
┌─────────────────────────────────────────────────────────────┐
│                   Claude Code (MCP Client)                  │
│                    (HTTP/SSE on port 3001)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP/SSE
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              DelphiMCPserver.exe (Bridge)                    │
│                                                             │
│  UNCHANGED — forwards all tool calls via named pipe         │
│  Dynamic proxy discovers workflow tools alongside           │
│  automation tools automatically via list-tools              │
│                                                             │
│  Bridge-local tools remain: debug capture, utilities        │
└──────────────────────────┬──────────────────────────────────┘
                           │ Named Pipe
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            CyberMAX.exe (Target Application)                │
│                                                             │
│  ┌──────────────────────────────────────────────────┐       │
│  │ AutomationToolRegistry (EXISTING - UNCHANGED)    │       │
│  │                                                  │       │
│  │ 41 automation tools (take-screenshot, click, ...) │       │
│  │ execute-internal (413 operations)                │       │
│  │ command processor (100+ commands)                │       │
│  │                                                  │       │
│  │ NEW: Workflow tools registered here too           │       │
│  │   invoice_create, customer_search, etc.          │       │
│  └──────────────────────────────────────────────────┘       │
│                                                             │
│  ┌──────────────────────────────────────────────────┐       │
│  │ WorkflowEngine (NEW PACKAGE)                     │       │
│  │                                                  │       │
│  │ TWorkflowEngine.Execute()                        │       │
│  │   → DetermineChannel()                           │       │
│  │   → ExecuteOnMainThread() or ExecuteViaBackend() │       │
│  │                                                  │       │
│  │ Steps:                                           │       │
│  │   TStepCreateInvoice                             │       │
│  │   TStepSelectCustomer                            │       │
│  │   TStepAddInvoiceLine                            │       │
│  │   TStepSearchProduct                             │       │
│  │   TStepSaveInvoice                               │       │
│  │   ...                                            │       │
│  └──────────────────────────────────────────────────┘       │
│                                                             │
│  ┌──────────────────────────────────────────────────┐       │
│  │ CyberMAX Business Logic (EXISTING - UNCHANGED)   │       │
│  │                                                  │       │
│  │ Forms: TFrmFactura, TFrmCliente, TFrmAlmacen... │       │
│  │ DataModules: DMMain, DMFacturacion...            │       │
│  │ Business: VeriFactu, Pricing, Promotions...      │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Key Insight: Reuse `execute-internal`

The CLAUDE.md mentions 413 operations accessible via `execute-internal`. This existing system may ALREADY provide the backend channel for many operations. If `execute-internal("GESTION.FACTURAS.NUEVA")` creates a new invoice internally, then:

```pascal
function TStepCreateInvoice.ExecuteViaBackend(const AParams: TJSONObject): TStepResult;
begin
  // Reuse existing execute-internal infrastructure!
  ExecuteInternalCommand('GESTION.FACTURAS.NUEVA', AParams);
end;
```

This dramatically reduces the implementation cost of workflow steps.

### Schema Registration for Workflow Tools

Each workflow tool should provide a proper JSON schema so the LLM knows what parameters to send:

```json
{
  "type": "object",
  "properties": {
    "customer": {
      "type": "string",
      "description": "Customer code, name, or tax ID"
    },
    "serie": {
      "type": "string",
      "description": "Invoice series (default: standard)"
    },
    "date": {
      "type": "string",
      "description": "Invoice date YYYY-MM-DD (default: today)"
    }
  },
  "required": ["customer"]
}
```

The existing dynamic proxy already handles schema forwarding (`DynamicProxy.pas:246-256` extracts and clones schemas from target app responses).

---

## 10. Risk Assessment

### High Risk

| Risk | Impact | Mitigation |
|---|---|---|
| Modal blocking unsolved | UI-channel steps timeout when modal dialogs appear | Solve broker issue first; provide backend-only fallback for all steps |
| CyberMAX internal methods not accessible | Workflow steps can't call form methods | Use `execute-internal` as intermediate layer; add new internal operations as needed |
| Step implementation cost | 50+ steps needed for full ERP coverage | Start with 5-10 highest-value steps; use base classes for common patterns |

### Medium Risk

| Risk | Impact | Mitigation |
|---|---|---|
| Thread safety of form internal methods | Crashes when calling form methods from non-UI thread | ALL UI-channel calls go through `ExecuteOnMainThread`; test thoroughly |
| Channel selection heuristic incorrect | Agent modifies wrong invoice or creates duplicate | Check specific form type AND record ID, not just "is form open" |
| LLM misunderstands NeedsInput responses | Agent picks wrong customer from disambiguation list | Include rich context in choices (code + name + tax ID); test with real conversations |

### Low Risk

| Risk | Impact | Mitigation |
|---|---|---|
| Bridge changes needed | Breaking existing automation tools | No bridge changes needed — workflow tools use same registry |
| Performance degradation | Workflow steps slower than direct tool calls | Workflow steps do MORE per call, reducing total round-trips |
| Schema compatibility | MCP clients can't parse workflow results | Use standard MCP result format with text content |

---

## Appendix A: Existing Tool Inventory (from Documentation)

### Automation Tools (41 total, in target app)

**Visual Inspection (10):** take-screenshot, get-form-info, list-open-forms, list-controls, find-control, get-control, ui.get_tree_diff, ui.focus.get, ui.focus.get_path, ui.value.get

**Control Interaction (16):** set-control-value, ui.set_text_verified, click-button, select-combo-item, select-tab, close-form, set-focus, set-form-bounds, ui.send_keys, ui.mouse_move, ui.mouse_click, ui.mouse_dblclick, ui.mouse_wheel, close-nonvcl-modal, + 2 more

**Synchronization (4):** wait_idle, wait_focus, wait_text, wait_when

**Utility & Debug (6+):** echo, list-tools, debug-list-all-windows, + debug capture tools

### Bridge Tools (9, in bridge server)

**Utility (3):** mcp_hello, mcp_echo, mcp_time

**Debug Capture (6):** start_debug_capture, stop_debug_capture, get_debug_messages, get_capture_status, get_process_summary, pause_resume_capture

---

## Appendix B: Proposed Workflow Tool Definitions

The first 5 workflow tools to implement:

```
erp_context
  Description: "Returns current ERP state: active form, mode (browse/edit/insert),
    current record summary, available workflow operations."
  Parameters: none
  Returns: form name, class, mode, record summary, available operations

customer_search
  Description: "Searches customers by name, tax ID, code, or any combination.
    Returns matches with disambiguation if multiple found."
  Parameters: query (string, required)
  Returns: customer data OR NeedsInput with choices

invoice_create
  Description: "Creates a new sales invoice. If the invoice form is open,
    fills it visually (user sees the action). Otherwise creates in backend."
  Parameters: customer (string, required), serie (string), date (string)
  Returns: invoice number, customer details, tariff applied

invoice_add_line
  Description: "Adds a line to the current invoice. Applies customer tariff
    and any active promotions automatically."
  Parameters: product (string, required), quantity (number, required),
    price (number), discount (number)
  Returns: line details with calculated price

invoice_save
  Description: "Validates and saves the current invoice. Runs all fiscal
    validations including VeriFactu hash chain."
  Parameters: none
  Returns: final totals, VeriFactu status
```

---

**Document Version**: 1.0
**Created**: 2026-02-20
**Status**: Analysis Complete — Ready for Implementation Planning
