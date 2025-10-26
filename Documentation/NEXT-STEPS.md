# Next Steps for DelphiMCP Development

**Last Updated:** 2025-10-25 (Post v3.3.0)
**Current Version:** v3.3.0 (Enhanced focus detection + {SPACE} key support)

## ✅ Completed in v3.3.0 (2025-10-25)

**What Was Done:**
1. **Added {SPACE} special key support** - SPACE must be sent as VK_SPACE (virtual key), not Unicode, to activate buttons in Windows dialogs
2. **Enhanced ui_focus_get tool** - Now returns:
   - `type` field: `"vcl"` or `"windows"` (explicit discriminator)
   - For Windows controls: `class` (via GetClassName) and `caption` (via GetWindowText)
   - Enables detection of which button has focus in non-VCL dialogs

**Key Finding:**
- Modal dialog automation works perfectly: `{TAB}{SPACE}` successfully activates buttons
- Unicode SPACE (` `) doesn't work - must use `{SPACE}` (VK_SPACE) virtual key
- Focus management (3-tier) validated and working
- Modal detection: 100% accuracy

**Impact:** Non-VCL modal dialogs (MessageDlg, TOpenDialog) are now fully automatable.

---

## Ongoing Priorities

This document outlines recommended priorities for future development based on the current state of the framework.

---

## 🔴 High Priority - Fix Incomplete Features

### 1. Debug Control Path Resolution ⚙️

**Status:** 🟡 Implemented but not working

**Issue:**
- Control path resolution code is complete and compiles
- `click-button(control: "edtFichero.#0")` fails with "Control path not found"
- The resolver (`AutomationControlResolver.pas`) is integrated but untested
- `ui.focus.get_path` tool created but never validated in practice

**Root Cause (Suspected):**
- Path resolution might need VCL thread synchronization
- Form lookup via `FindForm()` might be failing in the tool context
- Index-based traversal might have off-by-one error

**Action Plan:**
1. Add debug logging to `ResolveControlPath()` function
2. Test with simplest case first: `#0` (form.Controls[0])
3. Progress to named control: `"edtFichero"`
4. Then test combined path: `"edtFichero.#0"`
5. Verify `FindForm()` returns valid form reference
6. Check if Controls array matches what `get-control` shows

**Code Locations:**
- `Source/AutomationTools/AutomationControlResolver.pas` - Core resolver logic
- `Source/AutomationTools/AutomationCoreTools.pas:424-475` - Enhanced click-button implementation
- `Source/AutomationTools/AutomationCoreTools.pas:875-944` - ui.focus.get_path implementation

**Expected Outcome:**
- `click-button(form: "fmTest", control: "edtFichero.#0")` successfully clicks unnamed button
- `ui.focus.get_path` returns accurate paths when control is focused

**Time Estimate:** 30-60 minutes

**Priority Rationale:** Feature is 90% complete - just needs debugging session to make it production-ready.

---

### 2. Test ui.focus.get_path Tool 🧪

**Status:** 🟡 Created but never tested

**Issue:**
- Tool was added to registry and compiles
- Never called during testing session
- Path generation logic (`GetControlPath()`) unvalidated

**Action Plan:**
1. Start test application (e.g., Gestion2000.exe)
2. Open a form with nested controls (e.g., fmImportarPaseExterno)
3. Click on a control manually (e.g., the browse button in edtFichero)
4. Call `ui.focus.get_path` via MCP
5. Verify returned path is correct
6. Test path by using it in `click-button`

**Test Cases:**
```javascript
// Test 1: Named control
User clicks: edtFichero text field
Expected: { "path": "edtFichero", ... }

// Test 2: Unnamed control
User clicks: Browse button in edtFichero
Expected: { "path": "edtFichero.#0", ... }

// Test 3: Deeply nested unnamed
User clicks: Some deeply nested control
Expected: { "path": "panel1.#2.#0", ... }
```

**Code Location:**
- `Source/AutomationTools/AutomationCoreTools.pas:875-944` - Tool implementation
- `Source/AutomationTools/AutomationControlResolver.pas:141-210` - GetControlPath function

**Expected Outcome:**
- Tool returns valid paths that work in click-button
- Validates the path generation algorithm

**Time Estimate:** 15-30 minutes

**Priority Rationale:** Quick validation test - should "just work" if the resolver logic is correct.

---

## 🟡 Medium Priority - Known Issues

### 3. Identify Modal Blocking Edge Case 🔍

**Status:** 🔴 Unresolved issue

**Issue:**
During testing, after clicking OK in "Importar Pases Externos" form, the MCP server stopped responding. The server only recovered after manually closing modal error dialogs.

**What We Know:**
- ✅ VCL modal forms work (tested: fmImportarPaseExterno, fmInfoSistema, TMessageFormMax)
- ✅ Non-VCL modals work (tested: TOpenDialog)
- ❌ Some specific scenario caused complete server blocking
- Manual intervention (closing dialogs) restored connectivity

**Theories:**
1. **Nested modals during error processing** - Error dialog shown while parent form was transitioning
2. **Exception before modal display** - Error thrown in a way that blocks message queue before TMessageFormMax appears
3. **Multiple simultaneous modals** - Several error windows opened at once
4. **Specific message box type** - Different ShowModal pattern (e.g., Application.MessageBox vs TMessageFormMax)
5. **Modal shown in wrong thread** - Error dialog created outside VCL thread

**Action Plan:**
1. Create reproducible test case with "Importar Pases Externos"
2. Add logging to `AutomationServerThread.pas` to track modal detection
3. Test deliberately creating nested modals (ShowModal within ShowModal)
4. Test Application.MessageBox vs TMessageFormMax
5. Add timeout recovery mechanism if blocking detected
6. Monitor Windows message queue state during blocking

**Code Locations:**
- `Source/AutomationTools/AutomationServerThread.pas` - Message loop and pipe handling
- Test application: Gestion2000.exe → CONTABILIDAD.EJERCICIO.PASESEXTERNOS.IMPORTAR

**Expected Outcome:**
- Identify exact scenario that causes blocking
- Implement workaround or fix
- Document any unavoidable limitations

**Time Estimate:** 1-2 hours

**Priority Rationale:** Potential production blocker if error dialogs are common in real usage.

---

### 4. Add ListBox Reading Support 📋

**Status:** 🔴 Not implemented

**Issue:**
- `ui_value_get` tool doesn't support TListBox or TListBoxMax
- During testing, couldn't extract error messages from message list window
- Other list-based controls likely unsupported too

**Current Support:**
- ✅ TEdit, TMemo
- ✅ TCheckBox, TRadioButton
- ✅ TComboBox
- ❌ TListBox, TListBoxMax
- ❌ TStringGrid, TDBGrid
- ❌ TTreeView, TListView

**Action Plan:**
1. Study TListBox API (Items.Text, Items.Count, ItemIndex)
2. Add ListBox case to `AutomationControlInteraction.pas`
3. Extend `ui_value_get` schema to support list mode
4. Decide on return format:
   ```json
   // Option A: All items as string
   { "value": "Item1\r\nItem2\r\nItem3" }

   // Option B: Items array
   { "items": ["Item1", "Item2", "Item3"], "selected_index": 1 }
   ```
5. Test with TListBox and TListBoxMax
6. Document in tool schema

**Code Locations:**
- `Source/AutomationTools/AutomationControlInteraction.pas:99-180` - SetControlValue (add GetControlValue)
- `Source/AutomationTools/AutomationCoreTools.pas` - ui_value_get tool

**Expected Outcome:**
- Can read ListBox items and selection
- Completes the original test scenario (reading error messages)

**Time Estimate:** 30-45 minutes

**Priority Rationale:** Common control type, needed for reading error messages and selections.

---

## 🟢 Low Priority - Enhancements

### 5. Extend Path Support to Other Tools

**Status:** 🟡 Partial implementation

**Current State:**
- ✅ `click-button` supports paths
- ❌ `set-focus` - named controls only
- ❌ `set-control-value` - named controls only
- ❌ `select-combo-item` - named controls only
- ❌ `select-tab` - named controls only
- ❌ `ui_value_get` - named controls only
- ❌ `get-control` - named controls only

**Action Plan:**
Apply the same pattern used in `click-button` to all control interaction tools:
1. Detect if control parameter contains `.` or `#`
2. If yes, resolve path via `AutomationControlResolver`
3. If no, use traditional name lookup

**Template Code:**
```pascal
// Check if control path
if (Pos('.', ControlName) > 0) or (Pos('#', ControlName) > 0) then
begin
  TargetForm := AutomationFormIntrospection.FindForm(FormName);
  ResolvedControl := AutomationControlResolver.ResolveControlPath(TargetForm, ControlName);
  // ... use ResolvedControl
end
else
begin
  // Traditional name lookup
end;
```

**Tools to Update:**
- `set-focus` (line ~500)
- `set-control-value` (line ~99)
- `select-combo-item` (line ~265)
- `select-tab` (line ~332)
- `ui_value_get` (custom tool)

**Expected Outcome:**
- All control interaction tools accept paths
- Consistent UX across entire framework

**Time Estimate:** 1-2 hours

**Priority Rationale:** Nice-to-have for consistency, but click-button covers most use cases.

---

### 6. Improve Focus Management

**Status:** 🔴 Not implemented

**Issue:**
`ui_send_keys` requires the target application to have focus. User must manually click on the application window before automation begins.

**Current Workaround:**
1. User starts target application
2. User clicks on application window (one-time)
3. Application retains focus
4. All subsequent `ui_send_keys` work correctly

**Research Notes:**
- **UI Automation (UIA):** Investigated as a potential solution (no focus requirement). Research concluded that **UIA is not appropriate for DelphiMCP** - see [UIA-RESEARCH-COMPREHENSIVE.md](UIA-RESEARCH-COMPREHENSIVE.md) and [UIA-EXECUTIVE-SUMMARY.md](UIA-EXECUTIVE-SUMMARY.md) for full analysis.
- **Elevated Helper Application:** Investigated using UIAccess/admin privileges for focus management. Research concluded this approach is **not recommended** due to cost ($216-$520/year code signing), deployment restrictions (Program Files only), and security concerns. See [ELEVATED-HELPER-RESEARCH.md](ELEVATED-HELPER-RESEARCH.md) for comprehensive analysis.
- **Windows Service Approach:** Investigated using a Windows service with SYSTEM privileges to grant focus permission via IPC. Research concluded this is **NOT recommended** due to excessive complexity (3-process architecture), deployment friction (service installation), and security concerns. See [WINDOWS-SERVICE-FOCUS-RESEARCH.md](WINDOWS-SERVICE-FOCUS-RESEARCH.md) and [FOCUS-SOLUTIONS-COMPARISON.md](FOCUS-SOLUTIONS-COMPARISON.md) for complete analysis.
- **Recommendation:** The focus issue can be solved with traditional Windows API approaches (AttachThreadInput) at zero cost. For production deployments, UIAccess manifest with code signing is the industry-standard solution. See [FOCUS-CONTROL-QUICK-REFERENCE.md](FOCUS-CONTROL-QUICK-REFERENCE.md) for one-page summary.

**Proposed Solutions:**

**Option A: AttachThreadInput + SetFocus** ✅ **Recommended**
```pascal
function SetFocusToWindow(TargetHWND: HWND): Boolean;
var
  ForegroundThread, TargetThread: DWORD;
begin
  ForegroundThread := GetWindowThreadProcessId(GetForegroundWindow, nil);
  TargetThread := GetWindowThreadProcessId(TargetHWND, nil);

  AttachThreadInput(ForegroundThread, TargetThread, True);
  try
    SetForegroundWindow(TargetHWND);
    SetFocus(TargetHWND);
    Result := True;
  finally
    AttachThreadInput(ForegroundThread, TargetThread, False);
  end;
end;
```

**Option B: SendMessage Instead of SendInput**
Send keyboard events via WM_KEYDOWN/WM_CHAR directly to window:
```pascal
SendMessage(TargetHWND, WM_CHAR, Ord('A'), 0);
```

**Option C: BringWindowToTop + SetForegroundWindow**
More aggressive focus stealing (may still fail on some Windows versions)

**Tradeoffs:**
- **AttachThreadInput**: Most reliable, well-documented pattern, eliminates UIA's only advantage over VCL
- **SendMessage**: Bypasses focus entirely, but some controls don't respond to messages
- **BringWindowToTop**: Simplest, but Windows security may still block

**Action Plan:**
1. Implement AttachThreadInput approach (proven Windows API pattern)
2. Test with target application focused in background
3. Test with target application minimized
4. Fall back to current behavior if AttachThreadInput fails
5. Document Windows security restrictions (if any)

**Expected Outcome:**
- `ui_send_keys` works without user needing to click application first
- Fully autonomous automation possible
- **Eliminates the only advantage UI Automation has over current approach**

**Time Estimate:** 2-3 hours

**Priority Rationale:** Nice enhancement for UX, and proves VCL-based approach can match UIA capabilities without complexity overhead.

---

### 7. Add Control Path Schema and Validation

**Status:** 🔴 Not implemented

**Issue:**
- No schema documentation for path syntax in tool definitions
- No validation of path format before attempting resolution
- Error messages are generic

**Action Plan:**

**1. Add Schema to click-button:**
```pascal
function CreateSchema_ClickButton: TJSONObject;
var
  Props, Form, Control: TJSONObject;
begin
  // ...
  Control := TJSONObject.Create;
  Control.AddPair('type', 'string');
  Control.AddPair('description',
    'Control name OR control path.' + sLineBreak +
    'Path syntax: "name.#index.#index"' + sLineBreak +
    '  - Named: "edtFichero"' + sLineBreak +
    '  - Indexed: "#0" (first child)' + sLineBreak +
    '  - Nested: "edtFichero.#0.#1"' + sLineBreak +
    'Examples: "btnSave", "panel1.#2", "edtFile.#0"');
  Props.AddPair('control', Control);
  // ...
end;
```

**2. Add Path Validation:**
```pascal
function ValidateControlPath(const Path: string): Boolean;
var
  Parts: TArray<string>;
  I, Index: Integer;
begin
  Result := False;
  if Path = '' then Exit;

  Parts := SplitString(Path, '.');
  for I := 0 to High(Parts) do
  begin
    if Parts[I] = '' then Exit; // Empty segment
    if Parts[I][1] = '#' then
    begin
      // Validate index format
      if not TryStrToInt(Copy(Parts[I], 2, MaxInt), Index) then
        Exit; // Invalid index
      if Index < 0 then Exit; // Negative index
    end;
    // Named segment is always valid
  end;
  Result := True;
end;
```

**3. Better Error Messages:**
```pascal
if not AutomationControlResolver.ValidateControlPath(ControlName) then
begin
  Result.AddPair('error', Format(
    'Invalid control path: "%s". ' +
    'Path syntax: "name.#index.#index". ' +
    'Examples: "btnSave", "panel1.#2", "edtFile.#0"',
    [ControlName]));
  Exit;
end;
```

**Expected Outcome:**
- AI agents see path syntax in tool schemas
- Invalid paths rejected early with helpful error messages
- Better developer experience

**Time Estimate:** 1 hour

**Priority Rationale:** Quality-of-life improvement, not critical for functionality.

---

## 🔵 Future Enhancements (v2.3+)

### 8. Recording Mode

**Concept:** Record user interactions and generate automation scripts

**Features:**
- Hook into VCL events (OnClick, OnChange, etc.)
- Capture control paths automatically
- Generate Python/JavaScript automation scripts
- Replay recorded actions

**Use Cases:**
- Create test scripts by example
- Document user workflows
- Train AI agents on application patterns

**Time Estimate:** 1-2 weeks

---

### 9. Async/Non-Blocking Automation

**Concept:** Allow automation to continue while forms are processing

**Current Limitation:**
- Some operations block until completion (e.g., clicking OK waits for processing)
- Cannot parallelize operations

**Proposed Solution:**
- Return correlation IDs for async operations
- Poll for completion status
- Event-driven notifications via SSE

**Time Estimate:** 1 week

---

### 10. More Control Types Support

**Controls to Add:**
- TStringGrid, TDBGrid (read/write cells)
- TTreeView (navigate nodes, expand/collapse)
- TListView (read items, change view mode)
- TDateTimePicker (set dates)
- TTrackBar, TProgressBar (read values)
- TRichEdit (formatted text)

**Time Estimate:** 2-3 hours per control type

---

### 11. Visual Regression Testing

**Concept:** Compare screenshots over time to detect UI changes

**Features:**
- Baseline screenshot storage
- Pixel-diff comparison
- Highlight changed regions
- Integration with test frameworks

**Time Estimate:** 1 week

---

### 12. Performance Optimization

**Areas to Optimize:**
- Form introspection caching (70% token reduction achieved, can go further)
- Control lookup indexing (O(n) → O(1) for named controls)
- Reduce JSON serialization overhead
- Batch multiple tool calls

**Expected Gains:**
- 50% faster form introspection
- 90% faster control lookup
- 30% reduced network traffic

**Time Estimate:** 1 week

---

## Recommended Roadmap

### Immediate Next Session (v2.2.1)
**Goal:** Complete v2.2 features
**Duration:** 2-3 hours

1. ✅ Debug control path resolution (60 min)
2. ✅ Test ui.focus.get_path (15 min)
3. ✅ Add ListBox support (45 min)
4. ✅ Document findings

**Deliverable:** Fully working control path system

---

### Short-term (v2.3)
**Goal:** Polish and extend
**Duration:** 1-2 sessions

1. Extend path support to all tools (2 hours)
2. Identify modal blocking edge case (2 hours)
3. Add control path validation and schemas (1 hour)
4. Add 2-3 more control types (TreeView, Grid, etc.)

**Deliverable:** Production-hardened framework

---

### Medium-term (v2.4)
**Goal:** Major features
**Duration:** 1-2 weeks

1. Improve focus management (AttachThreadInput approach)
2. Recording mode prototype
3. Performance optimization pass

**Deliverable:** Advanced automation capabilities

---

### Long-term (v3.0)
**Goal:** Enterprise features
**Duration:** 1-2 months

1. Async/non-blocking automation
2. Visual regression testing
3. Test framework integration
4. Multi-application coordination

**Deliverable:** Enterprise-grade test automation framework

---

## How to Contribute

### Reporting Issues
Create issues in the repository with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

### Submitting Fixes
1. Create a branch from `main`
2. Implement fix with tests
3. Update documentation
4. Submit pull request

### Adding Features
1. Check this roadmap first
2. Discuss approach in an issue
3. Implement with documentation
4. Add to NEXT-STEPS.md

---

## Decision Log

**Why prioritize control path debugging over modal edge case?**
- Control paths are 90% done, just need debugging
- Modal edge case may be non-reproducible or rare
- Quick win to get paths working boosts morale

**Why not implement focus management improvements yet?**
- Current workaround (user click once) is acceptable
- Windows security restrictions make this complex
- Better to validate other features first

**Why add ListBox before extending paths to all tools?**
- ListBox needed to complete original test scenario
- Proves value of reading control values
- Lower complexity than full path rollout

---

**Last Updated:** 2025-10-22
**Next Review:** After v2.2.1 release
