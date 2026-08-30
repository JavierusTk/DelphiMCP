# Elevated Helper Application Research (Windows 11)

**Research Date:** 2025-10-23
**Context:** Investigating solutions for Windows 11 focus-stealing restrictions affecting `ui_send_keys` automation
**Current Issue:** `SendInput` requires target application to have focus (user must click app window first)

---

## Executive Summary

**Question:** Can an elevated (administrator) helper application bypass Windows 11 focus-stealing restrictions for automation purposes?

**Answer:** **Partially - with significant tradeoffs**

### Key Findings

1. **Administrator Privilege Alone:** ❌ **Does NOT bypass SetForegroundWindow restrictions on Windows 11**
   - Windows 11 has stricter restrictions than Windows 10
   - Running as admin helps in some scenarios but is NOT a reliable solution
   - Foreground lock timeout (SPI_GETFOREGROUNDLOCKTIMEOUT) is set to max value (2,147,483,647ms) on Windows 11

2. **UIAccess Flag:** ✅ **CAN bypass UIPI restrictions** (but has strict requirements)
   - Requires code signing with trusted certificate ($216-$520/year + $90-$140 for HSM token)
   - Must be installed in secure location (Program Files or Windows\System32)
   - Specifically designed for accessibility tools (screen readers, automation)
   - **Successfully used by NVDA screen reader and TestComplete automation tool**

3. **Security Implications:** ⚠️ **High risk if not implemented carefully**
   - Recent malware (Coyote trojan) abuses UIAccess/UI Automation for credential theft
   - EDR tools cannot detect UIAccess abuse
   - Code signing required (prevents casual malware, but not targeted attacks)

4. **User Experience Impact:** ⚠️ **Moderate to High**
   - First-time UAC prompt for admin privilege (if using admin approach)
   - Code signing certificate cost and renewal overhead
   - Installation to Program Files requirement (no portable deployment)
   - Task Scheduler workaround can avoid UAC prompts (see section below)

### Recommendation

**For DelphiMCP:** ❌ **Do NOT pursue elevated helper approach**

**Better Alternative:** ✅ **Implement AttachThreadInput + SetForegroundWindow** (already documented in NEXT-STEPS.md)
- No elevated privileges needed
- No code signing cost
- No security concerns
- No UAC prompts
- Well-documented Windows API pattern
- Solves 90% of focus issues

**Only consider UIAccess if:**
- You need to automate elevated applications (admin privilege dialogs)
- You have budget for code signing certificate ($216-$520/year)
- You can install to Program Files (no portable mode)
- You're willing to maintain certificate renewal process

---

## Detailed Analysis

### 1. Administrator Privilege and SetForegroundWindow

#### Does Admin Privilege Help on Windows 11?

**Short Answer:** Sometimes, but unreliable.

**Evidence from Research:**

1. **Stack Overflow Report (2022):**
   > "Running the program as administrator can enable SetForegroundWindow to work in Windows 11, though this was not necessary in Windows 10."

   - Suggests Windows 11 is stricter than Windows 10
   - Admin privilege helps in some cases but is not guaranteed

2. **Windows 11 Foreground Lock Timeout:**
   > "SPI_GETFOREGROUNDLOCKTIMEOUT always reports 2147483647 (the max. value of a signed 32-bit integer) on logon in Windows 11, even though the ForegroundLockTimeout registry default value is 200000."

   - Windows 11 effectively blocks cross-process activation by default
   - This explains why admin privilege alone is insufficient

3. **SetForegroundWindow Restrictions (Microsoft Documentation):**

   A process can call SetForegroundWindow only if one of these conditions is true:
   - The calling process is the foreground process
   - The calling process was started by the foreground process
   - There is currently no foreground window
   - The foreground process called AllowSetForegroundWindow
   - The calling process received the last input event
   - Either the foreground or calling process is being debugged

   **Note:** "Running as administrator" is NOT in this list.

#### Conclusion on Admin Privilege

❌ **Administrator privilege alone does NOT reliably bypass Windows 11 focus restrictions.**

Running the helper as admin might help in edge cases, but is not a robust solution. You would still need additional techniques (AttachThreadInput, AllowSetForegroundWindow, or UIAccess).

---

### 2. UIAccess Flag (Trusted Applications)

#### What is UIAccess?

UIAccess is a Windows security feature that allows applications to bypass **User Interface Privilege Isolation (UIPI)** restrictions. It was designed for accessibility tools like screen readers.

**What UIAccess Enables:**
- Bypass UIPI restrictions (send messages to elevated windows)
- Call SetForegroundWindow more reliably
- Use SendInput to send keyboard/mouse input to higher-privilege applications
- Read UI elements from elevated applications

**Official Use Case:**
> "UIAccess integrity allows an application to bypass User Interface Privilege Isolation (UIPI) restrictions when an application is elevated in privilege from a standard user to an administrator. This ability is required to support accessibility features such as screen readers."

#### Requirements for UIAccess

UIAccess applications have **three strict requirements:**

##### 1. Code Signing with Trusted Certificate

**Requirement:**
> "The application must have a digital signature that can be verified using a digital certificate associated with the Trusted Root Certification Authorities store on the local device."

**What This Means:**
- Must purchase a code signing certificate from a trusted CA
- Certificate must chain to a root CA in Windows trust store
- Cannot use self-signed certificates (except for local testing)

**Certificate Costs (2025):**
| Provider | Type | Annual Cost | Notes |
|----------|------|-------------|-------|
| DigiCert | Standard | $474-$519 | Industry standard |
| Sectigo | Standard | $215-$260 | Budget option |
| GlobalSign | Standard | $250-$300 | Mid-range |
| Apple | macOS only | $100 | Not for Windows |

**Additional Costs:**
- Hardware Security Module (HSM) token: $90 (US) / $130 (International)
- Expedited shipping: $140
- **Total first year:** ~$305-$660

**Important:** As of June 1, 2023, code signing keys must be stored on FIPS 140-2 Level 2+ HSM (hardware token). You cannot store the private key on disk.

##### 2. Secure Installation Location

**Requirement:**
> "The application must be installed in a local folder that is writeable only by administrators."

**Allowed Locations:**
- `C:\Program Files\` (and subdirectories)
- `C:\Program Files (x86)\` (and subdirectories)
- `C:\Windows\System32\` (and subdirectories)

**Forbidden Locations:**
- User home directories (`C:\Users\<username>\`)
- Temp directories
- Current working directory
- Network shares
- Removable media

**Impact:**
- ❌ Cannot run as portable application
- ❌ Cannot xcopy deploy to user directories
- ✅ Must use proper installer (MSI or InnoSetup with admin elevation)

**Group Policy Override:**
> "This can be bypassed using a signed application with a manifest file containing requestedExecutionLevel.uiAccess set to true."

However, this requires changing domain/local security policy - not viable for general deployment.

##### 3. UIAccess Manifest Flag

**Requirement:**
Application manifest must include:

```xml
<trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
  <security>
    <requestedPrivileges>
      <requestedExecutionLevel
        level="asInvoker"
        uiAccess="true" />
    </requestedPrivileges>
  </security>
</trustInfo>
```

**Important Notes:**
- Must use `level="asInvoker"` or `level="highestAvailable"`
- Using `level="requireAdministrator"` defeats the purpose (would need UAC prompt)
- Debugging UIAccess apps is difficult (Windows blocks debugging unsigned UIAccess apps)

**Delphi Implementation:**
- Delphi Berlin and later have built-in UIAccess manifest option
- Set via Project Options → Application → Runtime Themes → Enable runtime themes
- Or manually edit .dproj file: `<UiAccess>true</UiAccess>`

**Development Workflow:**
> "Debugging is best done with a manifest that does not include 'uiAccess'. As of Windows 10.1903.18362.295 a Sandbox VM allowed debug testing without code signing."

#### Real-World Examples

**NVDA Screen Reader:**
- Open source project: https://github.com/nvaccess/nvda
- Uses UIAccess to interact with elevated applications
- Purchases code signing certificate from trusted CA
- Installs to Program Files
- Documented challenges:
  - Portable copies cannot have UIAccess
  - Installer must use ShellExecute to start with elevation
  - Service mode requires CreateProcessAsUser with UIAccess token
  - 64-bit helper loader required special token handling

**TestComplete (SmartBear):**
- Commercial test automation tool
- Uses UIAccess for automating elevated applications
- Documented setup: https://support.smartbear.com/testcomplete/docs/working-with/automating/via-com/configuring-manifests.html

**Windows Built-in Tools:**
- Narrator (screen reader)
- On-Screen Keyboard
- Magnifier

#### Does UIAccess Work on Windows 11?

✅ **Yes, UIAccess still works on Windows 11** (as of 2025)

The requirements are the same as Windows 10. Microsoft has not deprecated this feature, and accessibility tools continue to rely on it.

**However:**
- Windows 11 has NOT closed these loopholes
- The strictness comes from code signing and installation location requirements
- Windows 11 Defender SmartScreen is more aggressive about unsigned executables

---

### 3. Helper Application Architecture

#### Proposed Architecture (if pursuing UIAccess)

```
┌─────────────────────────────────────────────────┐
│         DelphiMCP Main Application              │
│         (Standard user privileges)              │
│                                                 │
│  - Automation framework                         │
│  - Named pipe server                            │
│  - MCP tool registry                            │
└────────────────────┬────────────────────────────┘
                     │
                     │ IPC (Named Pipe or Mailslot)
                     │
┌────────────────────▼────────────────────────────┐
│     DelphiMCPHelper.exe                         │
│     (UIAccess=true, code signed, Program Files) │
│                                                 │
│  - SetForegroundWindow(HWND)                    │
│  - SendInput to elevated windows                │
│  - AllowSetForegroundWindow coordination        │
└─────────────────────────────────────────────────┘
```

#### IPC Communication Protocol

**Request Format (JSON-RPC 2.0):**
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "method": "focus-window",
  "params": {
    "hwnd": 12345678
  }
}
```

**Response Format:**
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "result": {
    "success": true,
    "message": "Window focused successfully"
  }
}
```

**Methods:**
- `focus-window` - Call SetForegroundWindow
- `allow-focus` - Call AllowSetForegroundWindow
- `send-input` - Use SendInput with UIAccess privilege
- `ping` - Health check

#### Startup and Lifecycle

**Option A: Task Scheduler Auto-Start** (✅ Recommended for UIAccess)

Create a scheduled task that runs at user logon:

**Task Configuration:**
```xml
<Task>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Actions>
    <Exec>
      <Command>C:\Program Files\DelphiMCP\DelphiMCPHelper.exe</Command>
    </Exec>
  </Actions>
  <Principals>
    <Principal>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
</Task>
```

**Benefits:**
- ✅ No UAC prompt (runs with UIAccess, not admin elevation)
- ✅ Starts automatically with Windows
- ✅ Runs in user session context
- ✅ Can be created programmatically via installer

**Caveats:**
- Requires one-time task creation (installer can do this)
- Task survives even if user uninstalls main app (cleanup needed)

**Option B: Windows Startup Folder** (❌ Not viable for UIAccess)
- UIAccess apps cannot start from startup folder
- Windows requires ShellExecute or Task Scheduler

**Option C: Windows Service** (❌ Overkill and problematic)
- Services run in Session 0 (isolated from user desktop)
- Cannot interact with user session windows
- Requires complex token manipulation (CreateProcessAsUser)

#### Keep-Alive Strategy

**Recommended Approach:**
```pascal
procedure THelperMain.Execute;
begin
  // Minimize to system tray
  Application.ShowMainForm := False;
  TrayIcon.Visible := True;

  // Start named pipe server
  StartPipeServer('\\.\pipe\DelphiMCP_Helper');

  // Run message loop
  Application.Run;
end;
```

**Benefits:**
- Stays running in background
- No visible window (system tray icon only)
- Minimal resource usage when idle
- Clean shutdown via Windows session end

---

### 4. Security Implications

#### Attack Surface Analysis

**Threat Model:**

1. **Malicious Application Requests Helper to Focus Malware**
   - Attacker sends IPC request: `focus-window(hwnd: <malware_window>)`
   - Helper focuses malware, allowing it to steal keyboard input

   **Mitigation:**
   - Validate HWND belongs to known safe process (check PID and executable path)
   - Whitelist only windows from DelphiMCP process
   - Require authentication token in IPC

2. **Malware Impersonates Helper**
   - Attacker creates fake DelphiMCPHelper.exe
   - Main app connects to fake helper

   **Mitigation:**
   - Verify helper process signature before connecting
   - Use secure IPC channel (ACL on named pipe)

3. **UIAccess Abuse for Credential Theft**
   - Real risk: Coyote banking trojan used UI Automation for credential exfiltration
   - Helper could theoretically read passwords from elevated windows

   **Mitigation:**
   - Minimize helper capabilities (only focus and input, no reading)
   - Log all operations for audit trail
   - Open source the helper code for transparency

#### Recent Malware Examples

**Coyote Banking Trojan (2024):**
> "Coyote malware targets Brazilian users to extract login credentials from 75 web addresses linked to banking institutions. The first documented real-world malware exploiting Microsoft's UI Automation framework."

- Used UIAccess to read data from banking apps
- Exfiltrated credentials via UI Automation APIs
- **Undetected by all EDR vendors tested**

**Key Takeaway:**
> "While exploitation of UIA may be more difficult than some other attacks, the fact that EDR cannot detect it makes it a highly attractive attack surface."

**Monitoring Recommendation:**
> "Administrators can monitor UIAutomationCore.dll usage, as its loading into a previously unknown process should raise legitimate concern."

#### Code Signing as Security Measure

**What Code Signing Provides:**
- ✅ Proves code integrity (hasn't been tampered with)
- ✅ Proves author identity (certificate holder)
- ✅ Enables Windows SmartScreen trust
- ✅ Prevents casual malware (cost barrier)

**What Code Signing Does NOT Provide:**
- ❌ Does NOT prevent determined attacker with stolen certificate
- ❌ Does NOT prevent legitimate developer from writing malicious code
- ❌ Does NOT prevent malware from using signed helper for nefarious purposes

**Real-World Precedent:**
- Stuxnet used stolen certificates
- Flame malware used forged Microsoft certificates
- Many legitimate certificates have been stolen and used for malware

**Conclusion:**
Code signing is a **necessary but not sufficient** security measure for UIAccess applications.

---

### 5. Implementation Cost-Benefit Analysis

#### Development Costs

| Item | Estimated Time | Notes |
|------|----------------|-------|
| Helper application development | 8-16 hours | IPC server, focus management, error handling |
| Code signing integration | 2-4 hours | SignTool post-build, certificate management |
| Installer creation | 4-8 hours | Program Files installation, Task Scheduler setup |
| Testing on Windows 11 | 4-8 hours | Various privilege scenarios, UAC levels |
| Documentation | 2-4 hours | User setup guide, troubleshooting |
| **Total** | **20-40 hours** | ~1 week of development |

#### Ongoing Costs

| Item | Annual Cost | Notes |
|------|-------------|-------|
| Code signing certificate | $216-$520 | Renewal required annually |
| HSM token replacement | $90 | If token fails or lost |
| Certificate management | 2-4 hours/year | Renewal, updating builds |
| User support | Variable | UAC issues, installation problems |

#### Comparison with AttachThreadInput Alternative

**AttachThreadInput Approach (from NEXT-STEPS.md):**

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

**Costs:**
- Development time: 2-3 hours
- Ongoing costs: $0
- Deployment: No special requirements
- Security: No elevated privileges needed

**Limitations:**
- May still fail if Windows security policy is extremely strict
- Does not work for automating elevated applications (UAC dialogs, etc.)

**Success Rate:**
- Estimated 90%+ of scenarios (based on Windows API documentation and Stack Overflow reports)

#### Decision Matrix

| Factor | UIAccess Helper | AttachThreadInput |
|--------|----------------|-------------------|
| Development Time | 1 week | 2-3 hours |
| Annual Cost | $216-$520 | $0 |
| Deployment Complexity | High (installer, Program Files) | Low (xcopy) |
| Security Risk | Medium-High (abuse potential) | Low |
| UAC Prompts | None (Task Scheduler) | None |
| Automate Elevated Apps | ✅ Yes | ❌ No |
| Success Rate | ~95% | ~90% |
| Maintenance | High (cert renewal) | Low |

**Recommendation:**
✅ **Start with AttachThreadInput** - covers 90% of use cases with 10% of the effort

Only pursue UIAccess if:
- AttachThreadInput proves insufficient in practice
- You specifically need to automate elevated applications
- You have budget for code signing certificate

---

### 6. Task Scheduler UAC Bypass (Legitimate)

#### How It Works

Windows Task Scheduler allows creating tasks that run with elevated privileges **without UAC prompts** for standard operations.

**Key Concept:**
> "Create a Task Scheduler task set to run the program with elevated privileges, then create a shortcut to this task. This method bypasses UAC for that program only."

#### Implementation Steps

**1. Create the Scheduled Task:**

```bash
schtasks /create /tn "DelphiMCPHelper" /tr "C:\Program Files\DelphiMCP\DelphiMCPHelper.exe" /sc ONLOGON /rl HIGHEST /f
```

**Parameters:**
- `/tn` - Task name
- `/tr` - Program path
- `/sc ONLOGON` - Trigger on user logon
- `/rl HIGHEST` - Run with highest privileges
- `/f` - Force (overwrite if exists)

**2. Create Shortcut to Task:**

```bash
# In shortcut "Target" field:
schtasks.exe /run /tn "DelphiMCPHelper"
```

**3. Verify Task is Running:**

```bash
schtasks /query /tn "DelphiMCPHelper"
```

#### Security Implications

**Legitimate Uses:**
- Admin tools that need elevation frequently
- System maintenance utilities
- Backup/sync applications

**Security Concerns:**
> "Please make sure you are certain the program you want to disable UAC for is safe. It could damage your system if you willingly allow an unsafe program to bypass UAC."

**Audit Trail:**
- Task creation is logged in Event Viewer (Security log)
- Task execution is logged (Task Scheduler operational log)
- Administrators can query all scheduled tasks

**Mitigation:**
- Only administrators can create scheduled tasks with elevation
- Task path is fixed (cannot be modified without admin rights)
- Code signing prevents tampering with executable

#### When This Helps DelphiMCP

**Scenario A: Helper Needs Admin Rights**
- If using admin privilege (not UIAccess) for focus management
- Avoids UAC prompt every time app starts
- User sees UAC prompt only during initial setup (installer creates task)

**Scenario B: Helper Needs UIAccess**
- UIAccess apps don't need admin elevation
- But Task Scheduler ensures auto-start at logon
- More reliable than Startup folder for signed apps

**Current Recommendation:**
If pursuing helper approach, use Task Scheduler for auto-start (regardless of admin vs UIAccess).

---

### 7. Alternative Approaches (Non-Elevated)

Before committing to elevated helper, consider these alternatives:

#### Option 1: AttachThreadInput (✅ Recommended)

**Already documented in NEXT-STEPS.md - Section 6**

**Pros:**
- ✅ No elevated privileges
- ✅ Well-documented Windows API pattern
- ✅ Works for 90% of scenarios
- ✅ No code signing cost
- ✅ No deployment restrictions

**Cons:**
- ❌ May fail if Windows policy extremely strict
- ❌ Cannot automate elevated applications

**Implementation:** See NEXT-STEPS.md line 258-276

#### Option 2: AllowSetForegroundWindow Pattern

**Concept:**
Main application (if in foreground) calls `AllowSetForegroundWindow(ASFW_ANY)` before launching target, allowing target to steal focus.

**Code:**
```pascal
// In DelphiMCP (when it has focus)
AllowSetForegroundWindow(ASFW_ANY); // Allow any process to steal focus
ExecuteInternal('GESTION.CLIENTES'); // Launch form

// Form can now call SetForegroundWindow successfully
```

**Pros:**
- ✅ Simple
- ✅ No elevated privileges
- ✅ No helper process needed

**Cons:**
- ❌ Requires DelphiMCP to be foreground at time of call
- ❌ Only works if DelphiMCP controls the form launch
- ❌ Not applicable if form already exists

**Use Case:**
Good for `execute-internal` workflow, where DelphiMCP launches forms. Not applicable for focusing existing windows.

#### Option 3: SendMessage Instead of SendInput

**Concept:**
Instead of simulating keyboard input via `SendInput`, send `WM_CHAR` / `WM_KEYDOWN` messages directly to target window.

**Code:**
```pascal
procedure SendKeysViaMessage(HWND: THandle; const Keys: string);
var
  I: Integer;
begin
  for I := 1 to Length(Keys) do
  begin
    SendMessage(HWND, WM_CHAR, Ord(Keys[I]), 0);
  end;
end;
```

**Pros:**
- ✅ Bypasses focus requirement entirely
- ✅ No elevated privileges needed
- ✅ Works even if app is background

**Cons:**
- ❌ Some controls ignore WM_CHAR (use OnKeyPress instead)
- ❌ Special keys (Tab, Enter) require different messages
- ❌ Complex key sequences (Ctrl+C) are difficult

**Recommendation:**
Hybrid approach:
1. Try AttachThreadInput + SendInput (most reliable)
2. Fall back to SendMessage for simple text input

#### Option 4: Automation via UI Automation API

**Note:** Already researched and rejected - see UIA-RESEARCH-COMPREHENSIVE.md

**Summary:**
- UI Automation (UIA) was investigated as focus-free alternative
- Research concluded UIA is not appropriate for DelphiMCP
- Reasons: Complexity, performance, limited VCL support, focus issues still exist

**Reference:**
- Documentation/UIA-RESEARCH-COMPREHENSIVE.md
- Documentation/UIA-EXECUTIVE-SUMMARY.md

---

## Conclusion and Recommendations

### For DelphiMCP Project

**Primary Recommendation:** ❌ **Do NOT pursue elevated helper approach**

**Rationale:**
1. **Cost:** $216-$520/year + 1 week development time
2. **Complexity:** Installer, Task Scheduler, IPC, certificate management
3. **Security Risk:** UIAccess abuse potential (Coyote malware precedent)
4. **Deployment:** Cannot run portable (Program Files only)
5. **Alternative Available:** AttachThreadInput solves 90% of cases with 10% of effort

**Recommended Path:**

**Phase 1 (Next Session):** Implement AttachThreadInput
- 2-3 hours development time
- $0 cost
- Covers 90% of focus scenarios
- Already documented in NEXT-STEPS.md

**Phase 2 (If Phase 1 Insufficient):** Hybrid approach
- AttachThreadInput + SendMessage fallback
- Still no elevated privileges
- Handles edge cases

**Phase 3 (Only if Critical):** UIAccess helper
- Requires business case justification
- Budget for code signing certificate
- Accept deployment restrictions
- Thorough security review

### When UIAccess Makes Sense

UIAccess is appropriate for:
- ✅ Commercial products (certificate cost amortized)
- ✅ Enterprise deployments (centralized certificate management)
- ✅ Accessibility tools (primary use case)
- ✅ Test automation products (TestComplete, etc.)
- ✅ Automating elevated applications (UAC dialogs, admin tools)

UIAccess is NOT appropriate for:
- ❌ Open source projects (certificate renewal burden)
- ❌ Portable applications (Program Files requirement)
- ❌ Quick prototypes (development overhead)
- ❌ When alternatives exist (AttachThreadInput)

### Implementation Checklist (If Pursuing UIAccess)

**Pre-Implementation:**
- [ ] Verify AttachThreadInput is truly insufficient
- [ ] Confirm budget for code signing certificate ($305-$660 first year)
- [ ] Accept Program Files installation requirement
- [ ] Plan certificate renewal process

**Development:**
- [ ] Create helper application with IPC server
- [ ] Implement focus management (SetForegroundWindow)
- [ ] Add security validation (HWND verification)
- [ ] Create installer for Program Files
- [ ] Configure Task Scheduler auto-start

**Code Signing:**
- [ ] Purchase code signing certificate from trusted CA
- [ ] Receive HSM token (FIPS 140-2 Level 2+)
- [ ] Configure SignTool in build process
- [ ] Test signed executable on clean Windows 11

**Testing:**
- [ ] Test on Windows 11 (latest updates)
- [ ] Test with various UAC levels
- [ ] Test focus stealing from different privilege levels
- [ ] Test Task Scheduler auto-start
- [ ] Test uninstall and cleanup

**Documentation:**
- [ ] User setup guide
- [ ] Troubleshooting common issues
- [ ] Certificate renewal procedure
- [ ] Security considerations

**Ongoing:**
- [ ] Renew certificate annually
- [ ] Update builds with new certificate
- [ ] Monitor for Windows security policy changes

---

## References

### Microsoft Documentation
- [SetForegroundWindow function](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)
- [Security Considerations for Assistive Technologies](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-securityoverview)
- [UIAccess in Manifest Files](https://learn.microsoft.com/en-us/archive/msdn-technet-forums/4d2e1358-af95-4f4f-b239-68ec7e2525a9)
- [User Account Control: Only elevate UIAccess applications](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/jj852244(v=ws.11))
- [AllowSetForegroundWindow function](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-allowsetforegroundwindow)

### Real-World Implementations
- [NVDA Screen Reader - GitHub](https://github.com/nvaccess/nvda)
- [NVDA UIAccess Issue #397](https://github.com/nvaccess/nvda/issues/397)
- [TestComplete - Configuring Manifests](https://support.smartbear.com/testcomplete/docs/working-with/automating/via-com/configuring-manifests.html)
- [OptiKey UIAccess Documentation](https://github.com/OptiKey/OptiKey/blob/main/docs/UiAccess.md)

### Security Research
- [Coyote Malware - UI Automation Abuse](https://gbhackers.com/coyote-malware-targets-wils/)
- [Windows UI Automation Attack Technique](https://www.akamai.com/blog/security-research/2024-december-windows-ui-automation-attack-technique-evades-edr)
- [The Hacker News - Malware Technique Exploits Windows UI](https://thehackernews.com/2024/12/new-malware-technique-could-exploit.html)

### Stack Overflow Discussions
- [SetForegroundWindow Windows 11 doesn't work](https://stackoverflow.com/questions/72938538/setforegroundwindow-windows-11-doesnt-work)
- [Steal focus as SetForegroundWindow can't do it](https://stackoverflow.com/questions/32032548/steal-focus-as-setforegroundwindow-cant-do-it)
- [SendInput fail because of UIPI](https://stackoverflow.com/questions/17645204/sendinput-fail-because-of-uipi)
- [AllowSetForegroundWindow cross-process](https://stackoverflow.com/questions/23715026/allow-background-application-to-set-foreground-window-of-different-process)

### Code Signing
- [DigiCert Code Signing Certificates](https://www.digicert.com/signing/code-signing-certificates)
- [Code Signing Certificate Cost Comparison](https://codesigncert.com/blog/code-signing-certificate-cost)
- [Cheap SSL Web - Individual Code Signing](https://cheapsslweb.com/individual-code-signing-certificates)

### Delphi-Specific
- [Delphi Code Signing Guide](https://www.developer-experts.net/en/2018/06/15/signing-windows-delphi-applications/)
- [Signing Delphi Executables](https://wiert.me/2014/11/25/signing-your-delphi-executables-with-a-digital-certificate/)
- [Hooks Made Easy - UIAccess Example](https://github.com/fschetterer/Hooks-Made-Easy)

### Task Scheduler UAC Bypass
- [How to bypass UAC using Task Scheduler](https://zanozbot.medium.com/how-to-bypass-uac-using-task-scheduler-7a990dfde363)
- [Use Task Scheduler to run apps without UAC prompts](https://www.digitalcitizen.life/use-task-scheduler-launch-programs-without-uac-prompts/)
- [Create Elevated Shortcut without UAC prompt](https://www.thewindowsclub.com/create-elevated-shortcut-run-programs-bypass-uac)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Research Scope:** Windows 11 focus-stealing restrictions and mitigation strategies
**Recommendation Status:** Do NOT pursue elevated helper - use AttachThreadInput instead
