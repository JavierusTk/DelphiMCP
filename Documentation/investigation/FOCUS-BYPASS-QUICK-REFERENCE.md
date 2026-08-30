# Windows 11 Focus Bypass - Quick Reference

**For:** DelphiMCP Automation Framework
**Date:** 2025-10-23
**Status:** Ready for Implementation

---

## TL;DR - What Actually Works

| Technique | Windows 11 Status | Complexity | Recommended |
|-----------|-------------------|------------|-------------|
| **Registry Hack (ForegroundLockTimeout)** | ❌ BROKEN | Low | NO - Don't waste time |
| **Alt Key Simulation** | ✅ WORKS | Low | YES - Implement first |
| **Run as Administrator** | ✅ RELIABLE | Low | YES - Best for testing |
| **Code Signing + uiAccess** | ✅ PRODUCTION | High | YES - Long-term solution |
| **Thread Attachment Alone** | ⚠️ PARTIAL | Medium | NO - Combine with Alt key |
| **Kernel Driver** | ✅ Works but... | Very High | NO - Too dangerous |
| **AllocConsole Trick** | ❓ UNKNOWN | Low | MAYBE - Test first |

---

## Implementation for DelphiMCP

### Option 1: Alt Key Simulation (IMPLEMENT THIS FIRST)

**File:** `AutomationTools/Source/AutomationCoreTools.pas`

```delphi
uses
  Winapi.Windows, Winapi.Messages;

function ForceWindowToForeground(AWindowHandle: HWND): Boolean;
var
  ForegroundThread, CurrentThread: DWORD;
  KeyInputs: array[0..1] of TInput;
  Attached: Boolean;
begin
  Result := False;

  // Already foreground?
  if GetForegroundWindow = AWindowHandle then
    Exit(True);

  // Restore if minimized
  if IsIconic(AWindowHandle) then
    ShowWindow(AWindowHandle, SW_RESTORE);

  // Get thread IDs
  ForegroundThread := GetWindowThreadProcessId(GetForegroundWindow, nil);
  CurrentThread := GetCurrentThreadId;

  // Attach threads
  Attached := False;
  if ForegroundThread <> CurrentThread then
    Attached := AttachThreadInput(CurrentThread, ForegroundThread, True);

  try
    // Simulate Alt key press
    ZeroMemory(@KeyInputs, SizeOf(KeyInputs));

    // Press Alt
    KeyInputs[0].Itype := INPUT_KEYBOARD;
    KeyInputs[0].ki.wVk := VK_MENU;
    KeyInputs[0].ki.dwFlags := KEYEVENTF_EXTENDEDKEY;

    SendInput(1, @KeyInputs[0], SizeOf(TInput));

    // Activate window
    BringWindowToTop(AWindowHandle);
    SetForegroundWindow(AWindowHandle);

    // Release Alt
    KeyInputs[1].Itype := INPUT_KEYBOARD;
    KeyInputs[1].ki.wVk := VK_MENU;
    KeyInputs[1].ki.dwFlags := KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP;

    SendInput(1, @KeyInputs[1], SizeOf(TInput));

    Sleep(50); // Allow activation to complete
    Result := (GetForegroundWindow = AWindowHandle);

  finally
    // Detach threads
    if Attached then
      AttachThreadInput(CurrentThread, ForegroundThread, False);
  end;
end;

// Usage in ui_send_keys tool:
procedure TUIAutomationTools.SendKeys(const AKeys: string);
var
  TargetWindow: HWND;
begin
  TargetWindow := GetTargetWindow; // Your existing logic

  // NEW: Force foreground before sending keys
  if not ForceWindowToForeground(TargetWindow) then
  begin
    // Fallback: Log warning and try anyway
    LogWarning('Could not bring window to foreground - keys may not be sent');
  end;

  // Existing SendInput logic...
end;
```

**Testing:**
```bash
# Test with DelphiMCP Bridge
./DelphiMCPserver.exe

# From Claude Code, call:
ui_send_keys --keys "Hello World" --target "YourAppTitle"

# Should work even if app is not focused (most of the time)
```

---

### Option 2: Run Bridge as Administrator (EASIEST TESTING)

**Approach 1: Manual**
```bash
# Right-click DelphiMCPserver.exe > Run as Administrator
```

**Approach 2: Manifest (Recommended)**

**File:** `Examples/DelphiMCPserver/DelphiMCPserver.manifest`

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity
    name="DelphiMCPserver"
    version="1.0.0.0"
    type="win32"
    processorArchitecture="*"/>

  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <!-- Request admin elevation (will show UAC prompt) -->
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>

  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 11 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <!-- Windows 10 -->
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</assembly>
```

**Add to .dproj:**
```xml
<PropertyGroup>
  <Manifest_File>DelphiMCPserver.manifest</Manifest_File>
</PropertyGroup>
```

**Result:**
- UAC prompt on startup
- `SetForegroundWindow` works reliably
- No code changes needed

---

### Option 3: Task Scheduler (FOR SERVICES)

**Use Case:** Bridge server runs as Windows service or scheduled task

**PowerShell Setup:**
```powershell
# Create scheduled task that runs on logon with highest privileges
$Action = New-ScheduledTaskAction -Execute "C:\Path\To\DelphiMCPserver.exe"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName "DelphiMCP Bridge" `
                       -Action $Action `
                       -Trigger $Trigger `
                       -Principal $Principal `
                       -Description "DelphiMCP automation bridge server"

# Start the task
Start-ScheduledTask -TaskName "DelphiMCP Bridge"
```

**Benefits:**
- No UAC prompt on startup
- Runs with elevated privileges
- Auto-starts on user logon

---

### Option 4: Code Signing + uiAccess (PRODUCTION)

**Requirements:**
1. Purchase Authenticode code signing certificate (~$300-$500/year)
   - Providers: DigiCert, Sectigo, GlobalSign
   - Requires EV (Extended Validation) for Windows 11
2. Install certificate to signing machine
3. Update manifest

**Manifest Update:**
```xml
<requestedExecutionLevel level="asInvoker" uiAccess="true"/>
<!-- Note: uiAccess="true" requires code signing -->
```

**Sign Executable:**
```bash
# Using SignTool from Windows SDK
signtool sign /f "YourCertificate.pfx" /p "password" /tr http://timestamp.digicert.com /td sha256 DelphiMCPserver.exe
```

**Installation:**
- Must install to `Program Files` or `Windows\System32` (trusted locations)
- Installer must also be signed

**Benefits:**
- No UAC prompt
- Reliable focus activation
- Professional deployment
- Used by Microsoft's own tools (PowerToys)

**Drawbacks:**
- Cost (~$300+/year for certificate)
- Annual renewal required
- Must maintain signing infrastructure

---

## What NOT to Implement

### ❌ Registry Hack (ForegroundLockTimeout)

```delphi
// DO NOT USE - BROKEN IN WINDOWS 11
// This code will NOT work:
RegWriteString(HKEY_CURRENT_USER, 'Control Panel\Desktop', 'ForegroundLockTimeout', '200000');
// Windows 11 ignores this registry value
```

**Why:** Windows 11 hardcodes timeout to `2147483647` (max int32), ignoring registry

---

### ❌ Kernel Driver

**Reason:** Overkill, dangerous, unmaintainable

**Complexity:**
- Requires Windows Driver Kit (WDK)
- Requires EV code signing certificate
- Risk of BSOD
- Blocked by HVCI/Secure Boot
- Maintenance nightmare

**Verdict:** Not worth the effort

---

### ❌ SwitchToThisWindow

```delphi
// DO NOT USE - DEPRECATED
SwitchToThisWindow(Handle, True); // Officially deprecated, unreliable
```

**Why:** Microsoft deprecated it, behavior undefined in Windows 11

---

## Testing Strategy

### Phase 1: Verify Current Behavior

```bash
# Test without any fixes
1. Start target Delphi application (CyberMAX, SimpleVCLApp, etc.)
2. Click on another window (Chrome, VS Code) to steal focus
3. Run: ui_send_keys --keys "Test" --target "AppName"
4. Observe: Keys likely sent to wrong window (current focus)
```

### Phase 2: Test Alt Key Fix

```bash
# After implementing ForceWindowToForeground()
1. Rebuild AutomationTools package
2. Restart target application (picks up new code)
3. Repeat Phase 1 test
4. Expected: Keys sent to correct window (even without focus)
5. Success rate: ~80-90% (depends on Windows 11 version)
```

### Phase 3: Test Elevated Mode

```bash
# Run bridge as Administrator
1. Right-click DelphiMCPserver.exe > Run as Administrator
2. Repeat Phase 1 test
3. Expected: 100% success rate
```

### Phase 4: Compare Results

| Test Scenario | No Fix | Alt Key Fix | Elevated | uiAccess |
|---------------|--------|-------------|----------|----------|
| App has focus | ✅ Works | ✅ Works | ✅ Works | ✅ Works |
| App in background (Chrome focused) | ❌ Fails | ⚠️ 80-90% | ✅ Works | ✅ Works |
| App minimized | ❌ Fails | ⚠️ 60-70% | ✅ Works | ✅ Works |
| App on different virtual desktop | ❌ Fails | ❌ Fails | ⚠️ Maybe | ⚠️ Maybe |

---

## Documentation Updates

### Update: CONTROL-PATHS-AND-MODALS.md

Add new section:

```markdown
## SendInput Focus Requirements (Updated 2025-10-23)

### Windows 11 Focus Restrictions

**Problem:** Windows 11 enforces strict focus-stealing protection. `SetForegroundWindow` fails when:
- App is in background
- User is interacting with another app
- Specific timeout windows haven't expired

### Solutions Implemented

**Tier 1: Alt Key Simulation (Automatic)**
- `ForceWindowToForeground()` automatically simulates Alt key press
- Success rate: 80-90% in Windows 11
- No user action required (most of the time)

**Tier 2: User Focus (Fallback)**
- If Tier 1 fails, user must click on app once
- Tool logs warning: "Could not activate window - please click on application"

**Tier 3: Elevated Mode (Optional)**
- Run DelphiMCP bridge as Administrator
- 100% success rate
- Requires UAC prompt on startup

### Usage

Normal operation (no user action):
```bash
# Will automatically attempt to activate window
ui_send_keys --keys "Hello" --target "MyApp"
```

If automation fails:
1. Check log output for warnings
2. Manually click on target application window
3. Retry operation

For guaranteed success:
```bash
# Run bridge as Administrator
Right-click DelphiMCPserver.exe > Run as Administrator
```
```

### Update: README.md

Add troubleshooting section:

```markdown
## Troubleshooting

### Keys Not Being Sent to Target Application

**Symptom:** `ui_send_keys` sends keys to wrong window (currently focused app)

**Cause:** Windows 11 focus-stealing restrictions

**Solutions:**

1. **Automatic (Recommended):** Update to latest version (includes Alt key simulation)
   ```bash
   git pull
   cd Source/AutomationTools
   delphi compile AutomationTools.dproj
   ```

2. **Manual:** Click on target application window before running command

3. **Elevated Mode:** Run bridge as Administrator
   ```bash
   # Right-click DelphiMCPserver.exe > Run as Administrator
   ```

4. **Verify:** Check DelphiMCP logs for activation warnings
```

---

## Implementation Checklist

### Immediate (Phase 1)
- [ ] Add `ForceWindowToForeground()` function to `AutomationCoreTools.pas`
- [ ] Update `ui_send_keys` tool to call `ForceWindowToForeground()` before sending keys
- [ ] Add logging for activation failures
- [ ] Test on Windows 11 22H2, 23H2, 24H2
- [ ] Update documentation (CONTROL-PATHS-AND-MODALS.md, README.md)

### Short-term (Phase 2)
- [ ] Create `DelphiMCPserver.manifest` with `requireAdministrator`
- [ ] Test elevated mode across all Windows 11 versions
- [ ] Document UAC prompt behavior
- [ ] Add Task Scheduler setup guide

### Long-term (Phase 3 - Optional)
- [ ] Evaluate cost/benefit of code signing certificate
- [ ] If proceeding: Purchase certificate (DigiCert, Sectigo)
- [ ] Create signing pipeline
- [ ] Update manifest to `uiAccess="true"`
- [ ] Create installer (must be signed)
- [ ] Deploy to Program Files

---

## Quick Delphi Code Snippet

**Copy-paste ready implementation:**

```delphi
// Add to AutomationCoreTools.pas

function SimulateAltKeyPress: Boolean;
var
  Input: TInput;
begin
  ZeroMemory(@Input, SizeOf(Input));
  Input.Itype := INPUT_KEYBOARD;
  Input.ki.wVk := VK_MENU;
  Input.ki.dwFlags := KEYEVENTF_EXTENDEDKEY;

  Result := SendInput(1, @Input, SizeOf(TInput)) > 0;

  // Release
  Input.ki.dwFlags := KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP;
  SendInput(1, @Input, SizeOf(TInput));
end;

function ActivateWindow(AHandle: HWND): Boolean;
begin
  // 1. Restore if minimized
  if IsIconic(AHandle) then
    ShowWindow(AHandle, SW_RESTORE);

  // 2. Standard activation
  SetForegroundWindow(AHandle);

  // 3. If failed, use Alt trick
  if GetForegroundWindow <> AHandle then
  begin
    SimulateAltKeyPress;
    SetForegroundWindow(AHandle);
  end;

  Sleep(50);
  Result := (GetForegroundWindow = AHandle);
end;

// Usage in ui_send_keys:
if not ActivateWindow(TargetWindowHandle) then
  LogWarning('Failed to activate window - keys may not be delivered');
```

---

## Expected Success Rates

Based on research and community reports:

| Approach | Windows 11 22H2 | Windows 11 23H2 | Windows 11 24H2 |
|----------|----------------|----------------|----------------|
| **No fix (baseline)** | 10-20% | 10-20% | 5-15% |
| **Alt key simulation** | 80-90% | 80-90% | 75-85% |
| **Elevated (Admin)** | 95-100% | 95-100% | 95-100% |
| **uiAccess signed** | 95-100% | 95-100% | 95-100% |

**Note:** Success rates decrease when:
- Target app is minimized
- User is actively typing in another app
- Multiple monitors with different DPI scaling
- Virtual desktops in use

---

## Summary

**For DelphiMCP Project:**

1. **Implement Alt key simulation** (2-3 hours work)
   - 80-90% success rate
   - No UAC prompts
   - Works with standard user accounts

2. **Document elevated mode** (1 hour)
   - 95-100% success rate
   - Requires UAC prompt
   - Good for testing/development

3. **Consider code signing** (long-term)
   - Production-ready solution
   - ~$300-500/year cost
   - Used by Microsoft PowerToys

**Do NOT waste time on:**
- Registry hacks (broken in Win11)
- Kernel drivers (too risky)
- Undocumented APIs (none found)

**Reality Check:**
- No perfect solution exists
- Windows 11 intentionally restricts focus changes
- Best we can do: 80-90% success rate (Alt key) or 100% with elevation
- Document limitations clearly for users

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**See Also:** WINDOWS-11-FOCUS-BYPASS-RESEARCH.md (comprehensive research)
