# Windows 11 Focus-Stealing Bypass Research

**Research Date:** 2025-10-23
**Target OS:** Windows 11 (build 22000+)
**Status:** Comprehensive investigation of documented and undocumented techniques

---

## Executive Summary

This document comprehensively investigates techniques to bypass Windows 11 focus-stealing restrictions (`SetForegroundWindow` limitations). The research covers registry hacks, undocumented APIs, input simulation, elevation strategies, and kernel-mode approaches.

### Key Findings

1. **Windows 11 has TIGHTENED restrictions** compared to Windows 10
2. **Registry approach (ForegroundLockTimeout) NO LONGER WORKS** in Windows 11
3. **Most viable approaches:** Input simulation (Alt key), elevated processes, thread attachment
4. **No magic solution exists** - all approaches have trade-offs
5. **Microsoft is moving toward official APIs** (Windows 11 25H2+)

---

## 1. Registry Hacks and Group Policy

### 1.1 ForegroundLockTimeout Registry Key

**Registry Location:**
```
HKEY_CURRENT_USER\Control Panel\Desktop\ForegroundLockTimeout
```

**Traditional Approach (Windows 7-10):**
```
Value: 200000 (decimal) = 200 seconds
Effect: Prevents ALL applications from stealing focus
```

#### Windows 11 Behavior (BROKEN)

**Critical Finding:** Registry value is **IGNORED** in Windows 11

- **Test Results:** On Windows 11 version 21H2 (build 22000.856), `SPI_GETFOREGROUNDLOCKTIMEOUT` always returns `2147483647` (max int32) regardless of registry value
- **Reason:** Windows 11 no longer respects the registry-based setting
- **Effective Default:** Windows 11 defaults to maximum timeout (effectively disabling programmatic activation)

**Source:** Stack Overflow testing on Windows 11 build 22000

```cpp
// What happens on Windows 11:
DWORD timeout;
SystemParametersInfo(SPI_GETFOREGROUNDLOCKTIMEOUT, 0, &timeout, 0);
// Returns: 2147483647 (always, ignoring registry)
```

#### Workaround: Non-Persistent SystemParametersInfo

```cpp
// Can temporarily change during runtime (NOT persistent across sessions)
DWORD zero = 0;
SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, &zero, SPIF_SENDCHANGE);
SetForegroundWindow(hwnd);
// Restore
SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, &originalTimeout, SPIF_SENDCHANGE);
```

**Limitations:**
- Must be called at EVERY user logon
- Affects global system setting (not per-app)
- Windows 11 silently ignores persistent updates (SPIF_UPDATEINIFILE flag)

**Viability:** ⚠️ **LOW** - Requires re-application every session, no persistent fix

---

### 1.2 Group Policy

**Finding:** No native Group Policy exists for `SetForegroundWindow` behavior

**Alternative:** Can manage "Do Not Disturb" (Focus Assist) via PowerShell/Registry:
```powershell
# Enable/Disable Do Not Disturb (not the same as SetForegroundWindow)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours" -Name "Enabled" -Value 1
```

**Viability:** ❌ **NOT APPLICABLE** - Focus Assist ≠ SetForegroundWindow restrictions

---

## 2. Input Simulation Techniques

### 2.1 Alt Key Press Workaround

**Principle:** Windows automatically enables `SetForegroundWindow` if the user presses ALT key

**Implementation (Modern - SendInput):**
```cpp
// Check if Alt already pressed
BYTE keyState[256];
GetKeyboardState(keyState);

if (!(keyState[VK_MENU] & 0x80))
{
    // Simulate Alt press
    INPUT input[2] = {0};

    // Press Alt
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = VK_MENU;
    input[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;

    SendInput(1, &input[0], sizeof(INPUT));

    // Now call SetForegroundWindow
    SetForegroundWindow(hwnd);

    // Release Alt
    input[1].type = INPUT_KEYBOARD;
    input[1].ki.wVk = VK_MENU;
    input[1].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;

    SendInput(1, &input[1], sizeof(INPUT));
}
```

**Legacy Implementation (keybd_event - DEPRECATED):**
```cpp
// Microsoft recommends using SendInput instead
keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY, 0);       // Press Alt
SetForegroundWindow(hwnd);
keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0); // Release Alt
```

**Requirements:**
- ⚠️ **Target application MUST have focus** for `SendInput` to work
- Simulates user input (may trigger anti-cheat/security systems)
- Can cause visible side effects (Alt key state changes)

**Windows 11 Status:** ✅ **WORKS** (as of 2024)

**Viability:** ⭐⭐⭐ **MODERATE** - Effective but requires focus first (chicken-and-egg problem)

---

### 2.2 Hotkey Registration Trick

**Principle:** Registering a hotkey gives temporary foreground privileges

**Implementation:**
```cpp
// Register a hotkey (e.g., Ctrl+Shift+X)
RegisterHotKey(hwnd, 1, MOD_CONTROL | MOD_SHIFT, 'X');

// When WM_HOTKEY message received, call SetForegroundWindow
// (Will succeed because hotkey processing grants foreground permission)

// Later unregister
UnregisterHotKey(hwnd, 1);
```

**Limitations:**
- Requires user to press hotkey
- Not fully automated
- Hotkey must not conflict with other applications

**Viability:** ⭐⭐ **LOW** - Requires user interaction

---

## 3. Thread Attachment Method

### 3.1 AttachThreadInput Technique

**Principle:** Attach calling thread to foreground window's thread, making Windows treat them as "related"

**Classic Implementation:**
```cpp
HWND hCurrentForeground = GetForegroundWindow();
DWORD dwForegroundThreadID = GetWindowThreadProcessId(hCurrentForeground, NULL);
DWORD dwCurrentThreadID = GetWindowThreadProcessId(hwnd, NULL);

// Attach threads
if (AttachThreadInput(dwCurrentThreadID, dwForegroundThreadID, TRUE))
{
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);

    // Detach threads
    AttachThreadInput(dwCurrentThreadID, dwForegroundThreadID, FALSE);
}
```

**PowerToys Implementation (SendInput Hybrid):**
```cpp
// From PowerToys (GitHub microsoft/PowerToys #1282)
// Combines thread attachment with SendInput hack

// 1. Attach threads
AttachThreadInput(thisThreadID, foregroundThreadID, TRUE);

// 2. Simulate Alt press via SendInput
INPUT input = {0};
input.type = INPUT_KEYBOARD;
input.ki.wVk = VK_MENU;
SendInput(1, &input, sizeof(INPUT));

// 3. Call SetForegroundWindow
SetForegroundWindow(hwnd);

// 4. Release Alt
input.ki.dwFlags = KEYEVENTF_KEYUP;
SendInput(1, &input, sizeof(INPUT));

// 5. Detach threads
AttachThreadInput(thisThreadID, foregroundThreadID, FALSE);
```

**Windows 11 Changes:**

**Critical:** As of Windows 10+, `AttachThreadInput` NO LONGER grants foreground activation permission from non-foreground processes (previously documented method)

**Workaround:** Still works if combined with:
- Input simulation (Alt key)
- Elevated privileges
- Target window is from same process

**Risks:**
- Thread deadlock if target app hangs
- Can cause input queue corruption
- Behavior varies by Windows version

**Windows 11 Status:** ⚠️ **PARTIALLY WORKS** (requires hybrid approach)

**Viability:** ⭐⭐⭐ **MODERATE** - Effective when combined with other techniques

---

## 4. Process Elevation and Task Scheduler

### 4.1 Running as Administrator

**Principle:** Elevated processes have more freedom with `SetForegroundWindow`

**Key Finding:** `SetForegroundWindow` bypasses UIPI (User Interface Privilege Isolation) integrity level checks

**Implementation:**
```cpp
// Application must be running with elevated privileges
// Launch via:
// 1. Right-click > Run as Administrator
// 2. Task Scheduler with "Run with highest privileges"
// 3. Manifest with requireAdministrator

// Then SetForegroundWindow works more reliably
SetForegroundWindow(hwnd);
```

**Task Scheduler Approach:**
```xml
<!-- Task Scheduler XML -->
<Principals>
    <Principal>
        <RunLevel>HighestAvailable</RunLevel>
    </Principal>
</Principals>
```

**UAC Manifest:**
```xml
<requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
```

**Advantages:**
- Bypasses most UIPI restrictions
- Reliable across Windows versions
- No registry hacks needed

**Disadvantages:**
- Requires UAC prompt (or Task Scheduler workaround)
- Not suitable for standard user applications
- Security implications (running with admin rights)

**Windows 11 Status:** ✅ **WORKS RELIABLY**

**Viability:** ⭐⭐⭐⭐ **HIGH** - Most reliable approach if elevation is acceptable

---

### 4.2 UIAccess Approach

**Principle:** Applications with `uiAccess="true"` can bypass UIPI without full admin rights

**Requirements:**
1. Application signed with trusted certificate
2. Installed in secure location (`Program Files` or `Windows\System32`)
3. Manifest with `uiAccess="true"`

**Manifest:**
```xml
<requestedExecutionLevel level="asInvoker" uiAccess="true" />
```

**Use Cases:**
- Screen readers
- Accessibility tools
- UI automation frameworks

**Advantages:**
- No UAC prompt
- Bypass UIPI restrictions
- Used by Microsoft's own tools (PowerToys, Narrator)

**Disadvantages:**
- Requires code signing certificate (~$300+/year)
- Must be installed in secure location
- Certificate validation overhead

**Windows 11 Status:** ✅ **WORKS** (used by PowerToys FancyZones)

**Viability:** ⭐⭐⭐⭐ **HIGH** - Best for commercial/enterprise tools

---

## 5. Alternative APIs

### 5.1 AllowSetForegroundWindow

**Principle:** Foreground process can grant permission to another process

**Implementation:**
```cpp
// Called by FOREGROUND process (Process A)
DWORD targetProcessID = GetProcessIdFromWindow(targetHwnd);
AllowSetForegroundWindow(targetProcessID);

// Now target process (Process B) can call:
SetForegroundWindow(targetHwnd); // Will succeed
```

**Limitations:**
- Requires cooperation from current foreground process
- Target process must call `SetForegroundWindow` within timeout window
- Only works if caller IS the foreground process

**Viability:** ⭐⭐ **LOW** - Requires foreground process cooperation

---

### 5.2 SwitchToThisWindow (DEPRECATED)

**API:**
```cpp
// Undocumented/deprecated API
SwitchToThisWindow(hwnd, TRUE);
```

**Status:** ❌ **NOT RECOMMENDED**
- Officially deprecated by Microsoft
- Can push current foreground window to bottom of z-order
- Unreliable behavior in Windows 11

---

### 5.3 BringWindowToTop

**API:**
```cpp
BringWindowToTop(hwnd); // Changes z-order, NOT keyboard focus
```

**Important:** `BringWindowToTop` only changes Z-ORDER, does NOT grant keyboard focus

**Common Mistake:** Developers confuse z-order with keyboard focus

**Viability:** ❌ **INSUFFICIENT ALONE** - Must combine with `SetForegroundWindow`

---

## 6. Console Allocation Trick

### 6.1 AllocConsole/FreeConsole Workaround

**Principle:** Allocating/freeing console window satisfies Windows' foreground conditions

**Implementation:**
```cpp
// Allocate console
AllocConsole();
HWND hConsole = GetConsoleWindow();

// Position console window (optional)
SetWindowPos(hConsole, HWND_BOTTOM, 0, 0, 0, 0,
             SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

// Free console
FreeConsole();

// Now SetForegroundWindow should work
SetForegroundWindow(targetHwnd);
```

**GitHub Reference:** https://github.com/amarmer/SetForegroundWindow

**Windows 11 Status:** ⚠️ **UNKNOWN** - No recent confirmations (2024)

**Risk Assessment:**
- May have been patched by Microsoft
- Creates/destroys console window (potential visual artifact)
- Side effects on console-based applications

**Viability:** ⭐⭐ **LOW/UNKNOWN** - Needs testing on Windows 11

---

## 7. UI Automation (UIA)

### 7.1 Microsoft UI Automation Framework

**Principle:** Use Windows UI Automation to set focus via accessibility APIs

**Implementation:**
```cpp
#include <UIAutomation.h>

IUIAutomation* pAutomation;
CoCreateInstance(__uuidof(CUIAutomation), NULL, CLSCTX_INPROC_SERVER,
                 __uuidof(IUIAutomation), (void**)&pAutomation);

IUIAutomationElement* pElement;
pAutomation->ElementFromHandle(hwnd, &pElement);

pElement->SetFocus(); // Uses accessibility framework
```

**Advantages:**
- Designed for automation scenarios
- Bypasses some SetForegroundWindow restrictions
- Used by screen readers and testing tools

**Disadvantages:**
- Requires UIAccess="true" for elevated windows
- More complex API
- May not work for all window types

**Windows 11 Compatibility Issues:**
- Some UIA methods throw "Not Implemented" exceptions in Windows 11
- `GetCurrentPropertyValue` has known issues when upgrading from Win10 to Win11

**Viability:** ⭐⭐⭐ **MODERATE** - Good for automation tools, but has Win11 bugs

---

## 8. Kernel-Mode Approaches (Last Resort)

### 8.1 Kernel Driver for Input Injection

**Principle:** Inject input at kernel level, bypassing user-mode restrictions

**Approach:**
1. Write kernel-mode filter driver
2. Intercept input stack (keyboard/mouse)
3. Inject input directly into target window's input queue

**Requirements:**
- Windows Driver Kit (WDK)
- Driver signing certificate (EV certificate ~$300+/year)
- Enable test signing mode OR disable driver signature enforcement
- Deep Windows kernel knowledge

**Windows 11 Challenges:**
- Kernel-mode code signing enforcement (Windows 11 S mode, Secure Boot)
- HVCI (Hypervisor-Protected Code Integrity) blocks unsigned drivers
- Microsoft Defender flags kernel drivers aggressively

**Risks:**
- System instability (BSOD potential)
- Security vulnerabilities
- Extremely high development complexity
- Maintenance nightmare (kernel ABI changes)

**Viability:** ❌ **NOT RECOMMENDED** - Overkill, high risk, minimal benefit

---

### 8.2 Undocumented Kernel APIs

**Research Area:** `NtUserSetForegroundWindow` (undocumented ntdll function)

**Finding:** No public documentation for Windows 11-specific undocumented focus APIs

**Status:** ❌ **DEAD END** - No viable undocumented APIs discovered

---

## 9. Third-Party Tool Analysis

### 9.1 AutoHotkey

**WinActivate Implementation:**
- Uses standard `SetForegroundWindow` with retry logic
- Attempts activation 6 times over 60ms
- Acknowledges OS restrictions: "OS prevents focus change functions from working under hard to predict circumstances"

**Workarounds used by AHK community:**
1. Activate taskbar first: `WinActivate("ahk_class Shell_TrayWnd")`
2. Use window handle (HWND) instead of title
3. Minimize visual artifacts: `SetWinDelay -1` + `#WinActivateForce`

**Windows 11 Status:** Same limitations as direct API calls

---

### 9.2 PowerToys (FancyZones)

**Approach:**
- Uses `uiAccess="true"` in manifest
- Code-signed by Microsoft
- Installed in `Program Files`

**Key Techniques:**
- Event hooking: `SetWinEventHook` for window events
- `BringWindowToTop` + `SetForegroundWindow` combination
- Thread input attachment for stubborn windows

**Source Code:** `microsoft/PowerToys` GitHub
- Path: `src/modules/fancyzones/FancyZonesLib/`
- Files: `WindowMoveHandler.cpp`, `FancyZones.cpp`

**Why it works:** UIAccess privilege from Microsoft signing

---

### 9.3 StayFocused (Focus Theft Prevention)

**GitHub:** `bladeSk/StayFocused`

**Approach (DEFENSIVE, not offensive):**
- Injects DLL into applications
- Hooks `SetForegroundWindow` calls
- BLOCKS focus stealing (opposite of our goal)

**Relevance:** Shows that DLL injection can intercept focus calls

---

## 10. Windows 11 Specific Features

### 10.1 Focus Sessions API

**Feature:** Windows 11 productivity tool (Clock app integration)

**Finding:** ❌ **NOT AVAILABLE** - Microsoft has NOT opened Focus Sessions API to third-party developers

**Recommendation:** Use PowerShell/registry to control underlying "Do Not Disturb" instead

---

### 10.2 Snap Layouts API

**Feature:** Windows 11 window snapping (Win+Z)

**Finding:** Uses internal Shell APIs, not publicly documented for focus manipulation

**Viability:** ❌ **NOT ACCESSIBLE** for third-party developers

---

### 10.3 Virtual Desktops API

**Feature:** Multiple desktop workspaces

**Finding:** Virtual desktop switching does NOT bypass SetForegroundWindow restrictions

---

## 11. PowerShell and Scripting

### 11.1 PowerShell with Admin Rights

**Can PowerShell bypass restrictions?** ⚠️ PARTIALLY

**Example:**
```powershell
# Running as Administrator
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$hwnd = [IntPtr]0x000A0B0C # Window handle
[Win32]::SetForegroundWindow($hwnd)
```

**Result:** Admin PowerShell has SLIGHTLY better success rate, but still subject to OS restrictions

**Viability:** ⭐⭐ **LOW** - Minor improvement, not a silver bullet

---

## 12. Comprehensive Workaround Strategy

### 12.1 Recommended Multi-Layered Approach

**Best Practice:** Combine multiple techniques for maximum reliability

```cpp
bool ForceSetForegroundWindow(HWND hwnd)
{
    // Layer 1: Check if already foreground
    if (GetForegroundWindow() == hwnd)
        return true;

    // Layer 2: Restore if minimized
    if (IsIconic(hwnd))
        ShowWindow(hwnd, SW_RESTORE);

    // Layer 3: Thread attachment + Alt key simulation
    HWND hCurrentForeground = GetForegroundWindow();
    DWORD dwForegroundThreadID = GetWindowThreadProcessId(hCurrentForeground, NULL);
    DWORD dwCurrentThreadID = GetCurrentThreadId();

    bool attached = false;
    if (dwForegroundThreadID != dwCurrentThreadID)
    {
        attached = AttachThreadInput(dwCurrentThreadID, dwForegroundThreadID, TRUE);
    }

    // Simulate Alt key press
    INPUT inputs[2] = {0};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_MENU;
    inputs[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY;

    SendInput(1, &inputs[0], sizeof(INPUT));

    // Layer 4: Multiple activation attempts
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    SetFocus(hwnd);
    SetActiveWindow(hwnd);
    EnableWindow(hwnd, TRUE);

    // Release Alt
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = VK_MENU;
    inputs[1].ki.dwFlags = KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP;
    SendInput(1, &inputs[1], sizeof(INPUT));

    // Detach threads
    if (attached)
        AttachThreadInput(dwCurrentThreadID, dwForegroundThreadID, FALSE);

    // Layer 5: Verify success
    Sleep(50);
    return (GetForegroundWindow() == hwnd);
}
```

---

## 13. Risk Assessment Matrix

| Technique | Viability | Complexity | Risk | Windows 11 Status | Recommendation |
|-----------|-----------|------------|------|-------------------|----------------|
| **Registry (ForegroundLockTimeout)** | ❌ Low | Low | Low | BROKEN | DO NOT USE |
| **Alt Key Simulation** | ⭐⭐⭐ Moderate | Low | Low | WORKS | USE (with focus first) |
| **Thread Attachment** | ⭐⭐⭐ Moderate | Medium | Medium | PARTIAL | USE (hybrid approach) |
| **Run as Administrator** | ⭐⭐⭐⭐ High | Low | Medium | WORKS | RECOMMENDED (if acceptable) |
| **UIAccess (code-signed)** | ⭐⭐⭐⭐ High | High | Low | WORKS | BEST (for commercial) |
| **AllocConsole Trick** | ⭐⭐ Low | Low | Low | UNKNOWN | TEST FIRST |
| **UI Automation** | ⭐⭐⭐ Moderate | High | Low | BUGGY | USE WITH CAUTION |
| **Kernel Driver** | ❌ Very Low | Very High | Very High | WORKS (too risky) | AVOID |
| **AllowSetForegroundWindow** | ⭐⭐ Low | Low | Low | WORKS | Limited use case |
| **Task Scheduler (elevated)** | ⭐⭐⭐⭐ High | Medium | Medium | WORKS | GOOD FOR SERVICES |

---

## 14. Long-Term Viability Analysis

### Will Microsoft Patch These?

**Historical Trend:**
- Windows Vista → Windows 10: Gradual tightening of restrictions
- Windows 11: **Significant lockdown** (registry hack disabled)
- Future trend: **More restrictions, not fewer**

**What's Safe Long-Term?**

✅ **Safe approaches (Microsoft-approved):**
1. UIAccess with code signing
2. Administrator elevation
3. UI Automation framework
4. Official APIs when released (Windows 11 25H2+)

⚠️ **Gray area (may be patched):**
1. AllocConsole trick
2. Thread attachment + Alt key hybrid
3. Undocumented APIs

❌ **Likely to be blocked:**
1. Registry hacks (already broken in Win11)
2. Kernel mode injection
3. DLL hijacking

---

## 15. Delphi-Specific Implementation

### 15.1 SendInput for Alt Key (Delphi)

```delphi
uses
  Winapi.Windows, Winapi.Messages;

function ForceForegroundWindow(Handle: HWND): Boolean;
var
  Inputs: array[0..1] of TInput;
  ForegroundThreadID, CurrentThreadID: DWORD;
begin
  Result := False;

  // Check if already foreground
  if GetForegroundWindow = Handle then
    Exit(True);

  // Restore if minimized
  if IsIconic(Handle) then
    ShowWindow(Handle, SW_RESTORE);

  // Thread attachment
  ForegroundThreadID := GetWindowThreadProcessId(GetForegroundWindow, nil);
  CurrentThreadID := GetCurrentThreadId;

  if ForegroundThreadID <> CurrentThreadID then
    AttachThreadInput(CurrentThreadID, ForegroundThreadID, True);

  // Simulate Alt key press
  ZeroMemory(@Inputs, SizeOf(Inputs));

  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_MENU;
  Inputs[0].ki.dwFlags := KEYEVENTF_EXTENDEDKEY;

  SendInput(1, @Inputs[0], SizeOf(TInput));

  // Set foreground
  BringWindowToTop(Handle);
  SetForegroundWindow(Handle);

  // Release Alt key
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := VK_MENU;
  Inputs[1].ki.dwFlags := KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP;

  SendInput(1, @Inputs[1], SizeOf(TInput));

  // Detach threads
  if ForegroundThreadID <> CurrentThreadID then
    AttachThreadInput(CurrentThreadID, ForegroundThreadID, False);

  Sleep(50);
  Result := (GetForegroundWindow = Handle);
end;
```

---

## 16. Recommendations for DelphiMCP Project

### Current Situation

**Problem:** `ui_send_keys` tool requires target application to have focus

**DelphiMCP Context:**
- MCP server runs in target Delphi application
- Claude Code sends automation commands via HTTP/SSE
- Need to activate Delphi app window programmatically

### Recommended Solution (Tiered)

#### Tier 1: Minimal Approach (Implement First)
```delphi
// Add to AutomationTools package
function EnsureForegroundWindow(Handle: HWND): Boolean;
begin
  // 1. Restore if minimized
  if IsIconic(Handle) then
    ShowWindow(Handle, SW_RESTORE);

  // 2. Try standard SetForegroundWindow
  Result := SetForegroundWindow(Handle);

  // 3. If failed, use Alt key trick
  if not Result or (GetForegroundWindow <> Handle) then
    Result := ForceForegroundWindow(Handle); // Use implementation above
end;
```

#### Tier 2: Enhanced Approach (If Tier 1 Insufficient)
```delphi
// Add manifest to DelphiMCP Bridge Server:
// <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
// <assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
//   <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
//     <security>
//       <requestedPrivileges>
//         <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
//       </requestedPrivileges>
//     </security>
//   </trustInfo>
// </assembly>

// User runs bridge as Administrator (via Task Scheduler or Run as Admin)
```

#### Tier 3: Enterprise Approach (For Production)
```delphi
// 1. Code-sign DelphiMCP bridge server with Authenticode certificate
// 2. Update manifest:
//    <requestedExecutionLevel level="asInvoker" uiAccess="true"/>
// 3. Install to Program Files
// 4. Benefits: No UAC prompt, reliable focus, professional deployment
```

### Implementation Priority

1. **Phase 1 (Immediate):** Implement Alt key simulation (Tier 1)
2. **Phase 2 (Testing):** Test with elevated bridge server (Tier 2)
3. **Phase 3 (Production):** Acquire code signing certificate (Tier 3)

### Documentation Updates

**Add to CONTROL-PATHS-AND-MODALS.md:**
```markdown
## Known Limitations

### SendInput Focus Requirement

**Current Behavior:**
- `ui_send_keys` requires target application to have focus
- Windows 11 enforces strict focus-stealing restrictions

**Workarounds:**
1. **User Action (Simplest):** User clicks on target app once before automation begins
2. **Alt Key Simulation:** Bridge server can simulate Alt press before sending keys
3. **Elevated Mode:** Run bridge server as Administrator (most reliable)
4. **UIAccess Mode:** Code-signed bridge with uiAccess="true" (production)

**Recommendation:** Document requirement for user to give initial focus, implement Alt key simulation for improved UX.
```

---

## 17. Code Examples Repository

### 17.1 Complete C++ Example (All Techniques)

See GitHub Gist: https://gist.github.com/EBNull/1419093

**Key functions:**
- `forceFocus()` - Combines SystemParametersInfo + thread attachment
- Includes timeout manipulation
- Python implementation (portable to Delphi via ctypes → DllImport)

### 17.2 PowerToys Reference

**Repository:** https://github.com/microsoft/PowerToys
**Relevant Files:**
- `src/modules/fancyzones/FancyZonesLib/WindowMoveHandler.cpp`
- `src/modules/fancyzones/FancyZonesLib/FancyZones.cpp`

**Note:** GitHub raw URLs returned 404 during research (files may have moved)

---

## 18. Testing Checklist

Before deploying any solution, test on:

- [ ] Windows 11 22H2 (build 22621+)
- [ ] Windows 11 23H2 (build 22631+)
- [ ] Windows 11 24H2 (build 26100+)
- [ ] Windows 11 25H2 (when available)
- [ ] With standard user account
- [ ] With administrator account
- [ ] With UAC at different levels (Low, Default, High)
- [ ] With Secure Boot enabled
- [ ] With HVCI (Memory Integrity) enabled
- [ ] Across multiple desktop sessions
- [ ] With different foreground applications (Chrome, VS Code, Explorer)

---

## 19. References

### Official Microsoft Documentation
- SetForegroundWindow: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow
- AllowSetForegroundWindow: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-allowsetforegroundwindow
- SendInput: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput
- UI Automation: https://learn.microsoft.com/en-us/windows/win32/winauto/entry-uiauto-win32

### Community Resources
- Stack Overflow: SetForegroundWindow tag
- AutoHotkey Community: WinActivate discussions
- PowerToys GitHub: Issues and Pull Requests

### Security Research
- Akamai: "Teaching an Old Framework New Tricks: The Dangers of Windows UI Automation"
- Windows Kernel Explorer: https://github.com/AxtMueller/Windows-Kernel-Explorer

---

## 20. Conclusion

### Summary

**No magic bullet exists for Windows 11 focus-stealing bypass.**

**Most Reliable Approaches (in order):**
1. ⭐⭐⭐⭐⭐ **Code-signed application with uiAccess="true"** (best for production)
2. ⭐⭐⭐⭐ **Running as Administrator** (best for enterprise/internal tools)
3. ⭐⭐⭐⭐ **Task Scheduler with highest privileges** (best for services)
4. ⭐⭐⭐ **Alt key simulation + thread attachment** (best effort for standard apps)

**Do NOT waste time on:**
- Registry hacks (broken in Windows 11)
- Kernel drivers (overkill and dangerous)
- Undocumented APIs (none found for Windows 11)

**For DelphiMCP Project:**
- **Short-term:** Implement Alt key simulation, document user focus requirement
- **Medium-term:** Test elevated bridge server
- **Long-term:** Consider code signing for production deployments

### Final Recommendation

**Accept Windows 11's security model** and work within its constraints. The most maintainable approach is:
1. Document that user must give initial focus (one-time click)
2. Implement Alt key simulation as fallback
3. For commercial deployment, invest in code signing + uiAccess

This research confirms there are **no undiscovered secret techniques** - the limitations are by design, and Microsoft is unlikely to relax them in future versions.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Next Review:** When Windows 11 25H2 releases (check for new official APIs)
