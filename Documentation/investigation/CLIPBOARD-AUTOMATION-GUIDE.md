# Clipboard Automation Guide

**Status:** Research Complete
**Last Updated:** 2025-10-23
**Audience:** DelphiMCP framework developers and automation tool implementers

This comprehensive guide covers programmatic clipboard operations for automation in Delphi/VCL applications, focusing on the DelphiMCP automation framework context.

---

## Table of Contents

1. [Overview](#overview)
2. [Two Approaches to Clipboard Automation](#two-approaches-to-clipboard-automation)
3. [Direct Clipboard API](#direct-clipboard-api)
4. [Keyboard Simulation (Ctrl+C/Ctrl+V)](#keyboard-simulation-ctrlcctrlv)
5. [When to Use Each Approach](#when-to-use-each-approach)
6. [VCL TClipboard Object](#vcl-tclipboard-object)
7. [Windows Clipboard API](#windows-clipboard-api)
8. [Clipboard Formats](#clipboard-formats)
9. [Thread Safety and Timing](#thread-safety-and-timing)
10. [Clipboard Monitoring](#clipboard-monitoring)
11. [Code Examples](#code-examples)
12. [Best Practices](#best-practices)
13. [Common Pitfalls](#common-pitfalls)
14. [Security Considerations](#security-considerations)
15. [DelphiMCP Integration](#delphimcp-integration)

---

## Overview

Clipboard operations in Windows automation can be performed via two fundamentally different approaches:

1. **Direct API Access** - Programmatic read/write via Windows clipboard API or VCL `TClipboard`
2. **Keyboard Simulation** - Simulating Ctrl+C and Ctrl+V keystrokes via SendInput

Each approach has distinct characteristics, use cases, and trade-offs.

---

## Two Approaches to Clipboard Automation

### Approach 1: Direct Clipboard API

**Mechanism:** Direct interaction with Windows clipboard via API calls

**Characteristics:**
- Immediate, synchronous operation
- No user interaction required
- No focus/foreground window requirements
- Full control over clipboard formats
- Can read/write any data type
- Clipboard ownership is managed

**Typical Uses:**
- Copying data between applications programmatically
- Reading clipboard contents without user action
- Setting clipboard data for user to paste manually
- Multi-format clipboard operations (text + bitmap + custom)
- Background clipboard operations

### Approach 2: Keyboard Simulation

**Mechanism:** Simulating Ctrl+C and Ctrl+V via SendInput

**Characteristics:**
- Asynchronous (depends on target application processing)
- Requires target window to have focus
- Triggers application's native clipboard handlers
- Respects application's clipboard format preferences
- May trigger additional application behavior (events, validation)
- Timing-dependent (need delays for processing)

**Typical Uses:**
- Automating user workflows in target applications
- Triggering application-specific copy/paste logic
- Working with applications that have custom clipboard handling
- Mimicking actual user behavior for testing
- Cases where direct API access might be blocked or monitored

---

## Direct Clipboard API

### VCL TClipboard Class

Delphi provides the `Vcl.Clipbrd.TClipboard` class, which wraps the Windows clipboard API with a high-level, easy-to-use interface.

**Key Features:**
- Global singleton instance: `Clipboard`
- Automatic clipboard opening/closing
- Built-in format detection
- Component streaming support
- Thread-safe (with caveats - see Thread Safety section)

**Basic Interface:**
```pascal
uses
  Vcl.Clipbrd;

// Simple text operations
Clipboard.AsText := 'Hello World';              // Set text
var Text := Clipboard.AsText;                    // Get text

// Format checking
if Clipboard.HasFormat(CF_TEXT) then             // Check if text available
  ShowMessage(Clipboard.AsText);

// Multiple formats
Clipboard.Clear;                                  // Clear all formats
Clipboard.AsText := 'Text';
Clipboard.Assign(MyBitmap);                       // Add bitmap format
```

**Key Methods:**

| Method | Description |
|--------|-------------|
| `AsText: string` | Get/Set clipboard text (Unicode) |
| `HasFormat(Format: Word): Boolean` | Check if format is available |
| `Clear` | Clear all clipboard data |
| `Open`, `Close` | Manual clipboard session control |
| `Assign(Source: TPersistent)` | Copy object to clipboard |
| `GetAsHandle(Format: Word): THandle` | Get data handle for format |
| `SetAsHandle(Format: Word; Value: THandle)` | Set data handle |
| `GetTextBuf(Buffer: PChar; BufSize: Integer): Integer` | Get text into buffer |
| `SetTextBuf(Buffer: PChar)` | Set text from buffer |
| `GetComponent(Owner, Parent: TComponent): TComponent` | Retrieve component |
| `SetComponent(Component: TComponent)` | Store component |

---

## Keyboard Simulation (Ctrl+C/Ctrl+V)

### Using DelphiMCP SendInput Framework

DelphiMCP already provides comprehensive keyboard simulation via `AutomationInputSimulation.pas`:

**Existing Tool: `ui_send_keys`**

```pascal
// Copy operation (Ctrl+C)
Tool_SendKeys(ParamsWithKeys('^c'), Result);

// Paste operation (Ctrl+V)
Tool_SendKeys(ParamsWithKeys('^v'), Result);

// Select All + Copy (Ctrl+A, Ctrl+C)
Tool_SendKeys(ParamsWithKeys('^a^c'), Result);
```

**Key Characteristics:**
- Requires target window to have focus
- Uses SendInput API (already implemented in `AutomationInputSimulation.pas`)
- Asynchronous - need delays for application processing
- Respects application's clipboard behavior

**Current SendInput Implementation:**

The framework already has comprehensive keyboard simulation:
- `SendUnicodeText()` - Unicode character sequences
- `KeyDown()`, `KeyUp()`, `Tap()` - Virtual key control
- `SendKeysSequence()` - String-based key sequences with special keys

**Special Key Notation (already implemented):**
```
{ENTER}, {TAB}, {ESC}, {BACKSPACE}, {DELETE}
{UP}, {DOWN}, {LEFT}, {RIGHT}
{HOME}, {END}, {PAGEUP}, {PAGEDOWN}
{F1}-{F12}
```

### Implementing Ctrl+C and Ctrl+V

**Approach A: Using Existing `ui_send_keys` Tool**

From MCP/Claude Code perspective:
```json
// Copy (Ctrl+C)
{
  "tool": "ui_send_keys",
  "params": {
    "keys": "^c"
  }
}

// Paste (Ctrl+V)
{
  "tool": "ui_send_keys",
  "params": {
    "keys": "^v"
  }
}
```

**Approach B: Add Ctrl Modifier to SendKeysSequence**

Enhance `SendKeysSequence()` to support modifier keys:
```pascal
// Enhanced syntax (PROPOSED - not yet implemented):
"^c"        → Ctrl+C
"^v"        → Ctrl+V
"+{TAB}"    → Shift+Tab
"^+s"       → Ctrl+Shift+S
```

**Approach C: Low-Level SendInput for Ctrl+C/Ctrl+V**

Direct implementation (cleanest for automation):
```pascal
procedure SendCtrlC;
var
  Inputs: array[0..3] of TInput;
begin
  ZeroMemory(@Inputs, SizeOf(Inputs));

  // Ctrl down
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_CONTROL;

  // C down
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := Ord('C');

  // C up
  Inputs[2].Itype := INPUT_KEYBOARD;
  Inputs[2].ki.wVk := Ord('C');
  Inputs[2].ki.dwFlags := KEYEVENTF_KEYUP;

  // Ctrl up
  Inputs[3].Itype := INPUT_KEYBOARD;
  Inputs[3].ki.wVk := VK_CONTROL;
  Inputs[3].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(4, @Inputs[0], SizeOf(TInput));
end;

procedure SendCtrlV;
var
  Inputs: array[0..3] of TInput;
begin
  ZeroMemory(@Inputs, SizeOf(Inputs));

  // Ctrl down
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_CONTROL;

  // V down
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := Ord('V');

  // V up
  Inputs[2].Itype := INPUT_KEYBOARD;
  Inputs[2].ki.wVk := Ord('V');
  Inputs[2].ki.dwFlags := KEYEVENTF_KEYUP;

  // Ctrl up
  Inputs[3].Itype := INPUT_KEYBOARD;
  Inputs[3].ki.wVk := VK_CONTROL;
  Inputs[3].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(4, @Inputs[0], SizeOf(TInput));
end;
```

---

## When to Use Each Approach

### Use Direct Clipboard API When:

✅ **Reading clipboard data programmatically**
- Need to check what user has copied
- Automating data extraction from other applications
- Background clipboard monitoring

✅ **Setting clipboard data for user**
- Preparing data for user to paste manually
- Copying data from automation to user workflow
- Pre-loading clipboard with template/boilerplate

✅ **Multi-format clipboard operations**
- Need to provide text + bitmap + custom format
- Working with component streaming
- Clipboard format negotiation

✅ **Immediate, synchronous operations needed**
- No delays acceptable
- Precise timing requirements
- Transactional clipboard operations

✅ **No focus requirements**
- Target window not in foreground
- Background clipboard operations
- System-wide clipboard manipulation

### Use Keyboard Simulation (Ctrl+C/Ctrl+V) When:

✅ **Automating existing application workflows**
- Triggering application's native copy/paste handlers
- Respecting application's clipboard format preferences
- Mimicking user behavior for testing

✅ **Application has custom clipboard handling**
- Application overrides clipboard operations
- Custom clipboard formats registered by app
- Application-specific validation on paste

✅ **Need to trigger application events**
- OnChange, OnKeyDown, OnKeyUp events needed
- Application performs additional processing on paste
- Copy/paste shortcuts trigger business logic

✅ **Avoiding clipboard ownership issues**
- Application manages its own clipboard state
- Clipboard delayed rendering in use
- Application uses clipboard viewers/listeners

✅ **Testing user interaction flows**
- Reproducing user-reported bugs
- Validating keyboard shortcut behavior
- End-to-end workflow automation

### Hybrid Approach: Both Together

**Common Pattern: Copy Data Between Applications**

```pascal
// 1. Focus source control (TEdit with data)
FocusControl(SourceEdit);

// 2. Select all + Copy via keyboard (triggers app's copy handler)
SendCtrlA;
Sleep(50);  // Let selection complete
SendCtrlC;
Sleep(100); // Let clipboard write complete

// 3. Read clipboard data via API (reliable, synchronous)
var CopiedText := Clipboard.AsText;

// 4. Validate/transform data
CopiedText := ProcessData(CopiedText);

// 5. Write back to clipboard via API
Clipboard.AsText := CopiedText;

// 6. Focus target control
FocusControl(TargetEdit);

// 7. Paste via keyboard (triggers app's paste handler)
Sleep(50);  // Let focus complete
SendCtrlV;
```

**Why Hybrid Works Well:**
- Keyboard simulation respects application behavior
- Direct API provides reliable data access
- Combines strengths of both approaches

---

## VCL TClipboard Object

### Complete API Reference

**Unit:** `Vcl.Clipbrd`

**Global Instance:**
```pascal
function Clipboard: TClipboard;
```
Returns the global clipboard singleton. Thread-safe lazy initialization.

### Properties

#### AsText: string
```pascal
property AsText: string read GetAsText write SetAsText;
```
Get/set clipboard text in Unicode format (CF_UNICODETEXT).

**Getter Behavior:**
- Tries CF_UNICODETEXT first
- Falls back to CF_TEXT (converted to Unicode)
- Returns empty string if no text format available

**Setter Behavior:**
- Opens clipboard
- Clears existing data
- Sets CF_UNICODETEXT format
- Closes clipboard

**Example:**
```pascal
// Copy text to clipboard
Clipboard.AsText := 'Hello, World!';

// Read text from clipboard
if Clipboard.HasFormat(CF_TEXT) then
  ShowMessage(Clipboard.AsText);
```

#### FormatCount: Integer
```pascal
property FormatCount: Integer read GetFormatCount;
```
Returns number of different formats available on clipboard.

#### Formats[Index: Integer]: Word
```pascal
property Formats[Index: Integer]: Word read GetFormat;
```
Returns clipboard format ID at specified index (0-based).

**Example:**
```pascal
for i := 0 to Clipboard.FormatCount - 1 do
  WriteLn(Format('Format %d: %d', [i, Clipboard.Formats[i]]));
```

### Methods

#### Clear
```pascal
procedure Clear;
```
Clears all data from the clipboard.

**Thread Safety:** Opens/closes clipboard automatically.

#### Open
```pascal
procedure Open;
```
Opens the clipboard for multiple operations. Must be matched with `Close`.

**Use Case:** Optimizes multiple clipboard operations:
```pascal
Clipboard.Open;
try
  Clipboard.Clear;
  Clipboard.AsText := 'Text';
  Clipboard.Assign(MyBitmap);
finally
  Clipboard.Close;
end;
```

#### Close
```pascal
procedure Close;
```
Closes the clipboard after `Open`. Always use in try/finally.

#### HasFormat
```pascal
function HasFormat(Format: Word): Boolean;
```
Checks if specified format is available on clipboard.

**Common Formats:**
- `CF_TEXT` - ANSI text
- `CF_UNICODETEXT` - Unicode text
- `CF_BITMAP` - Bitmap image
- `CF_METAFILEPICT` - Metafile
- `CF_DIB` - Device-independent bitmap
- `CF_HDROP` - File drop list
- Custom formats via `RegisterClipboardFormat`

**Example:**
```pascal
if Clipboard.HasFormat(CF_BITMAP) then
  MyImage.Picture.Bitmap.Assign(Clipboard);
```

#### GetAsHandle / SetAsHandle
```pascal
function GetAsHandle(Format: Word): THandle;
procedure SetAsHandle(Format: Word; Value: THandle);
```
Low-level access to clipboard data handles.

**Warning:** You own the returned handle - must call `GlobalFree`.

**Example:**
```pascal
var
  Handle: THandle;
  Ptr: Pointer;
  Size: Cardinal;
begin
  if Clipboard.HasFormat(CF_TEXT) then
  begin
    Handle := Clipboard.GetAsHandle(CF_TEXT);
    try
      Ptr := GlobalLock(Handle);
      try
        Size := GlobalSize(Handle);
        // Use Ptr to access raw data
      finally
        GlobalUnlock(Handle);
      end;
    finally
      GlobalFree(Handle);
    end;
  end;
end;
```

#### GetTextBuf / SetTextBuf
```pascal
function GetTextBuf(Buffer: PChar; BufSize: Integer): Integer;
procedure SetTextBuf(Buffer: PChar);
```
Legacy buffer-based text access. Use `AsText` instead for modern code.

#### Assign
```pascal
procedure Assign(Source: TPersistent);
```
Copies a TPersistent object to the clipboard.

**Supported Types:**
- `TPicture` → CF_BITMAP, CF_METAFILEPICT
- `TBitmap` → CF_BITMAP, CF_DIB
- `TGraphic` descendants

**Example:**
```pascal
// Copy bitmap to clipboard
Clipboard.Assign(MyBitmap);

// Copy picture to clipboard
Clipboard.Assign(Image1.Picture);
```

#### GetComponent / SetComponent
```pascal
function GetComponent(Owner, Parent: TComponent): TComponent;
procedure SetComponent(Component: TComponent);
```
Store/retrieve VCL components via clipboard.

**Use Case:** Copy/paste components in design-time IDE.

---

## Windows Clipboard API

### Low-Level API Functions

For cases where TClipboard is insufficient, use Windows API directly.

**Core API:**
```pascal
uses
  Winapi.Windows;

function OpenClipboard(hWndNewOwner: HWND): BOOL; stdcall;
function CloseClipboard: BOOL; stdcall;
function EmptyClipboard: BOOL; stdcall;
function SetClipboardData(uFormat: UINT; hMem: THandle): THandle; stdcall;
function GetClipboardData(uFormat: UINT): THandle; stdcall;
function IsClipboardFormatAvailable(format: UINT): BOOL; stdcall;
function RegisterClipboardFormat(lpszFormat: LPCWSTR): UINT; stdcall;
function CountClipboardFormats: Integer; stdcall;
function EnumClipboardFormats(format: UINT): UINT; stdcall;
function GetClipboardFormatName(format: UINT; lpszFormatName: LPWSTR; cchMaxCount: Integer): Integer; stdcall;
```

### Setting Clipboard Data (Low-Level)

```pascal
procedure SetClipboardText(const Text: string);
var
  Data: THandle;
  DataPtr: Pointer;
begin
  if not OpenClipboard(0) then
    Exit;
  try
    if not EmptyClipboard then
      Exit;

    // Allocate global memory
    Data := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE,
                        (Length(Text) + 1) * SizeOf(Char));
    try
      DataPtr := GlobalLock(Data);
      try
        Move(PChar(Text)^, DataPtr^, (Length(Text) + 1) * SizeOf(Char));
      finally
        GlobalUnlock(Data);
      end;

      // Transfer ownership to clipboard
      SetClipboardData(CF_UNICODETEXT, Data);
      Data := 0; // Clipboard now owns the handle
    finally
      if Data <> 0 then
        GlobalFree(Data);
    end;
  finally
    CloseClipboard;
  end;
end;
```

**Key Points:**
- `GlobalAlloc` with `GMEM_MOVEABLE` and `GMEM_DDESHARE`
- Clipboard takes ownership of handle (don't free after `SetClipboardData`)
- Must call `EmptyClipboard` before setting data

### Getting Clipboard Data (Low-Level)

```pascal
function GetClipboardText: string;
var
  Data: THandle;
  DataPtr: PWideChar;
begin
  Result := '';

  if not IsClipboardFormatAvailable(CF_UNICODETEXT) then
    Exit;

  if not OpenClipboard(0) then
    Exit;
  try
    Data := GetClipboardData(CF_UNICODETEXT);
    if Data = 0 then
      Exit;

    DataPtr := GlobalLock(Data);
    if DataPtr <> nil then
    try
      Result := DataPtr;
    finally
      GlobalUnlock(Data);
    end;
  finally
    CloseClipboard;
  end;
end;
```

**Key Points:**
- Check format availability first
- Don't free the handle (clipboard owns it)
- GlobalLock can return nil even with valid handle

---

## Clipboard Formats

### Standard Formats

| Constant | Value | Description |
|----------|-------|-------------|
| `CF_TEXT` | 1 | ANSI text |
| `CF_BITMAP` | 2 | Bitmap handle (HBITMAP) |
| `CF_METAFILEPICT` | 3 | Metafile picture |
| `CF_SYLK` | 4 | Microsoft Symbolic Link |
| `CF_DIF` | 5 | Software Arts' Data Interchange Format |
| `CF_TIFF` | 6 | Tagged Image File Format |
| `CF_OEMTEXT` | 7 | OEM text |
| `CF_DIB` | 8 | Device-independent bitmap |
| `CF_PALETTE` | 9 | Color palette |
| `CF_PENDATA` | 10 | Pen data (Windows for Pen Computing) |
| `CF_RIFF` | 11 | Audio data (RIFF format) |
| `CF_WAVE` | 12 | Wave audio data |
| `CF_UNICODETEXT` | 13 | Unicode text |
| `CF_ENHMETAFILE` | 14 | Enhanced metafile |
| `CF_HDROP` | 15 | File drop list (HDROP) |
| `CF_LOCALE` | 16 | Locale identifier |
| `CF_DIBV5` | 17 | DIB v5 bitmap |

### Custom Formats

Register custom clipboard formats:
```pascal
const
  CF_MYAPP_DATA = RegisterClipboardFormat('MyApp.CustomData');
```

**Best Practices for Custom Formats:**
- Use descriptive names with app/company prefix
- Register once at startup (store result in const/var)
- Document the data structure
- Consider versioning in format name

**Example:**
```pascal
const
  CF_CYBERMAX_INVOICE = RegisterClipboardFormat('CyberMAX.Invoice.v1');

type
  TClipboardInvoice = packed record
    Version: Integer;
    InvoiceID: Int64;
    CustomerID: Int64;
    Total: Currency;
  end;

procedure CopyInvoiceToClipboard(const Invoice: TClipboardInvoice);
var
  Data: THandle;
  DataPtr: Pointer;
begin
  Data := GlobalAlloc(GMEM_MOVEABLE, SizeOf(TClipboardInvoice));
  try
    DataPtr := GlobalLock(Data);
    try
      Move(Invoice, DataPtr^, SizeOf(TClipboardInvoice));
    finally
      GlobalUnlock(Data);
    end;

    if not OpenClipboard(0) then Exit;
    try
      EmptyClipboard;
      SetClipboardData(CF_CYBERMAX_INVOICE, Data);
      Data := 0; // Clipboard owns it now
    finally
      CloseClipboard;
    end;
  finally
    if Data <> 0 then
      GlobalFree(Data);
  end;
end;
```

### Multiple Formats

Applications can provide data in multiple formats simultaneously:

```pascal
procedure CopyTextMultiFormat(const Text: string);
begin
  Clipboard.Open;
  try
    Clipboard.Clear;

    // Unicode text (preferred)
    Clipboard.AsText := Text;

    // ANSI text (compatibility)
    var AnsiData := GlobalAlloc(GMEM_MOVEABLE, Length(AnsiString(Text)) + 1);
    var AnsiPtr := GlobalLock(AnsiData);
    try
      Move(PAnsiChar(AnsiString(Text))^, AnsiPtr^, Length(AnsiString(Text)) + 1);
    finally
      GlobalUnlock(AnsiData);
    end;
    SetClipboardData(CF_TEXT, AnsiData);

    // Custom app-specific format
    // ... (your custom format code here)
  finally
    Clipboard.Close;
  end;
end;
```

**Priority Handling:**
- Windows offers formats to paste target in priority order
- First registered format = highest priority
- Target application picks first format it understands

---

## Thread Safety and Timing

### TClipboard Thread Safety

**Design:**
- Global `Clipboard` instance is shared across threads
- Internal synchronization via `ClipboardCriticalSection`
- `Open`/`Close` are NOT thread-safe (by design)

**Safe Operations (from any thread):**
```pascal
// Single-operation methods (internally synchronized)
Clipboard.AsText := 'Text';        // Safe
var Text := Clipboard.AsText;      // Safe
Clipboard.HasFormat(CF_TEXT);      // Safe
Clipboard.Clear;                   // Safe
```

**Unsafe Operations (from non-main thread):**
```pascal
// Manual Open/Close sessions
Clipboard.Open;
try
  // Multiple operations
  Clipboard.AsText := 'Text';
  Clipboard.Assign(Bitmap);
finally
  Clipboard.Close;  // RACE CONDITION if other thread also uses Open/Close
end;
```

**Best Practice for Threads:**
```pascal
// Option 1: Use TThread.Synchronize
TThread.Synchronize(nil,
  procedure
  begin
    Clipboard.AsText := MyData;
  end
);

// Option 2: Use Windows API directly with manual synchronization
var
  ClipboardLock: TCriticalSection;
begin
  ClipboardLock.Enter;
  try
    if OpenClipboard(0) then
    try
      EmptyClipboard;
      // ... set data ...
    finally
      CloseClipboard;
    end;
  finally
    ClipboardLock.Leave;
  end;
end;
```

### Timing Considerations

#### Clipboard Delay Rendering

Windows supports delayed rendering - application provides data only when requested:

```pascal
// Application becomes clipboard owner but doesn't provide data yet
OpenClipboard(Handle);
EmptyClipboard;
SetClipboardData(CF_UNICODETEXT, 0);  // 0 = delayed rendering
CloseClipboard;

// Later, when another app requests data:
// Windows sends WM_RENDERFORMAT message
// Application must then provide actual data
```

**Implication for Automation:**
- Clipboard data may not be immediately available
- Reading clipboard may trigger data generation
- Some applications lazy-load clipboard data

**Solution:**
```pascal
function GetClipboardTextWithRetry(MaxRetries: Integer = 3): string;
var
  Attempt: Integer;
begin
  for Attempt := 1 to MaxRetries do
  begin
    Result := Clipboard.AsText;
    if Result <> '' then
      Exit;
    Sleep(50); // Give delayed rendering time to complete
  end;
end;
```

#### Keyboard Simulation Timing

When using Ctrl+C/Ctrl+V, delays are critical:

```pascal
// Copy operation timing
procedure AutomatedCopy: string;
begin
  FocusControl(SourceEdit);
  Sleep(50);        // Let focus complete

  SendCtrlA;        // Select all
  Sleep(50);        // Let selection complete

  SendCtrlC;        // Copy
  Sleep(100);       // Let clipboard write complete (CRITICAL)

  Result := Clipboard.AsText;  // Now safe to read
end;

// Paste operation timing
procedure AutomatedPaste(const Text: string);
begin
  Clipboard.AsText := Text;

  FocusControl(TargetEdit);
  Sleep(50);        // Let focus complete

  SendCtrlV;        // Paste
  Sleep(100);       // Let paste processing complete

  // Verify paste success
  if TargetEdit.Text <> Text then
    raise Exception.Create('Paste failed or modified');
end;
```

**Timing Guidelines:**
- Focus change: 50-100ms
- Clipboard write after Ctrl+C: 100-200ms
- Clipboard read before Ctrl+V: No delay needed (synchronous)
- Paste processing: 50-100ms
- Complex paste (rich text, images): 200-500ms

**Adaptive Timing:**
```pascal
function WaitForClipboardText(const ExpectedSubstring: string;
                              TimeoutMs: Integer = 1000): Boolean;
var
  StartTime: Cardinal;
begin
  Result := False;
  StartTime := GetTickCount;

  while GetTickCount - StartTime < TimeoutMs do
  begin
    if Pos(ExpectedSubstring, Clipboard.AsText) > 0 then
    begin
      Result := True;
      Exit;
    end;
    Sleep(50);
  end;
end;

// Usage
SendCtrlC;
if WaitForClipboardText('expected data') then
  // Clipboard has data
else
  // Timeout - copy failed
```

---

## Clipboard Monitoring

### Clipboard Change Notification

Windows provides `WM_CLIPBOARDUPDATE` message for clipboard monitoring.

**Implementation:**
```pascal
type
  TClipboardMonitor = class(TComponent)
  private
    FHandle: HWND;
    FOnClipboardChange: TNotifyEvent;
    procedure WndProc(var Msg: TMessage);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartMonitoring;
    procedure StopMonitoring;
    property OnClipboardChange: TNotifyEvent read FOnClipboardChange write FOnClipboardChange;
  end;

constructor TClipboardMonitor.Create(AOwner: TComponent);
begin
  inherited;
  FHandle := AllocateHWnd(WndProc);
end;

destructor TClipboardMonitor.Destroy;
begin
  StopMonitoring;
  DeallocateHWnd(FHandle);
  inherited;
end;

procedure TClipboardMonitor.StartMonitoring;
begin
  AddClipboardFormatListener(FHandle);
end;

procedure TClipboardMonitor.StopMonitoring;
begin
  RemoveClipboardFormatListener(FHandle);
end;

procedure TClipboardMonitor.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_CLIPBOARDUPDATE then
  begin
    if Assigned(FOnClipboardChange) then
      FOnClipboardChange(Self);
  end
  else
    Msg.Result := DefWindowProc(FHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

// Usage
var
  Monitor: TClipboardMonitor;
begin
  Monitor := TClipboardMonitor.Create(nil);
  try
    Monitor.OnClipboardChange :=
      procedure(Sender: TObject)
      begin
        WriteLn('Clipboard changed: ', Clipboard.AsText);
      end;
    Monitor.StartMonitoring;

    // ... do work ...

  finally
    Monitor.Free;
  end;
end;
```

### Polling Alternative

For simpler cases or when monitoring is unavailable:

```pascal
type
  TClipboardPoller = class
  private
    FLastContent: string;
    FTimer: TTimer;
    FOnChange: TNotifyEvent;
    procedure TimerTick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(IntervalMs: Integer = 500);
    procedure Stop;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

procedure TClipboardPoller.TimerTick(Sender: TObject);
var
  Current: string;
begin
  Current := Clipboard.AsText;
  if Current <> FLastContent then
  begin
    FLastContent := Current;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;
```

---

## Code Examples

### Example 1: Simple Text Copy/Paste

```pascal
// Direct API approach
procedure CopyTextDirect(const Text: string);
begin
  Clipboard.AsText := Text;
end;

function PasteTextDirect: string;
begin
  Result := Clipboard.AsText;
end;

// Keyboard simulation approach
procedure CopyTextKeyboard(Edit: TEdit);
begin
  Edit.SetFocus;
  Sleep(50);
  Edit.SelectAll;
  Sleep(50);
  SendCtrlC;
  Sleep(100);
end;

procedure PasteTextKeyboard(Edit: TEdit);
begin
  Edit.SetFocus;
  Sleep(50);
  SendCtrlV;
  Sleep(100);
end;
```

### Example 2: Multi-Format Clipboard

```pascal
procedure CopyRichData;
begin
  Clipboard.Open;
  try
    Clipboard.Clear;

    // Text format (for Notepad, etc.)
    Clipboard.AsText := 'Plain text version';

    // Bitmap format (for Paint, etc.)
    var Bmp := TBitmap.Create;
    try
      Bmp.Width := 100;
      Bmp.Height := 100;
      Bmp.Canvas.Brush.Color := clRed;
      Bmp.Canvas.FillRect(Rect(0, 0, 100, 100));
      Clipboard.Assign(Bmp);
    finally
      Bmp.Free;
    end;

    // Custom format (for my app)
    var CustomData := GlobalAlloc(GMEM_MOVEABLE, 1024);
    var Ptr := GlobalLock(CustomData);
    try
      // Fill custom data
      FillChar(Ptr^, 1024, 0);
    finally
      GlobalUnlock(CustomData);
    end;
    SetClipboardData(CF_MYAPP_DATA, CustomData);

  finally
    Clipboard.Close;
  end;
end;
```

### Example 3: Robust Clipboard Operation with Retry

```pascal
function SetClipboardTextRobust(const Text: string;
                                MaxRetries: Integer = 3): Boolean;
var
  Attempt: Integer;
begin
  Result := False;

  for Attempt := 1 to MaxRetries do
  begin
    try
      Clipboard.Open;
      try
        Clipboard.Clear;
        Clipboard.AsText := Text;
        Result := True;
        Exit;
      finally
        Clipboard.Close;
      end;
    except
      on E: Exception do
      begin
        OutputDebugString(PChar(Format('Clipboard attempt %d failed: %s',
                                      [Attempt, E.Message])));
        if Attempt < MaxRetries then
          Sleep(100 * Attempt); // Exponential backoff
      end;
    end;
  end;
end;
```

### Example 4: Copy Data Between Applications

```pascal
procedure CopyFromEditToEdit(SourceEdit, TargetEdit: TEdit);
var
  OriginalClipboard: string;
begin
  // Save original clipboard (good practice)
  OriginalClipboard := Clipboard.AsText;
  try
    // Copy from source
    SourceEdit.SetFocus;
    Sleep(50);
    SourceEdit.SelectAll;
    Sleep(50);
    SendCtrlC;
    Sleep(100);

    // Verify data in clipboard
    var CopiedText := Clipboard.AsText;
    if CopiedText = '' then
      raise Exception.Create('Copy failed - clipboard empty');

    // Paste to target
    TargetEdit.SetFocus;
    Sleep(50);
    SendCtrlV;
    Sleep(100);

    // Verify paste
    if TargetEdit.Text <> CopiedText then
      raise Exception.Create('Paste failed - text mismatch');

  finally
    // Restore original clipboard
    Clipboard.AsText := OriginalClipboard;
  end;
end;
```

### Example 5: DelphiMCP Tool Integration

```pascal
// Proposed: ui_clipboard_get tool
procedure Tool_ClipboardGet(const Params: TJSONObject; out Result: TJSONObject);
var
  Format: string;
  Text: string;
begin
  Result := TJSONObject.Create;
  try
    // Optional format parameter (default: text)
    if not Params.TryGetValue<string>('format', Format) then
      Format := 'text';

    if SameText(Format, 'text') then
    begin
      if Clipboard.HasFormat(CF_UNICODETEXT) or Clipboard.HasFormat(CF_TEXT) then
      begin
        Text := Clipboard.AsText;
        Result.AddPair('success', TJSONBool.Create(True));
        Result.AddPair('format', 'text');
        Result.AddPair('content', Text);
        Result.AddPair('length', TJSONNumber.Create(Length(Text)));
      end
      else
      begin
        Result.AddPair('success', TJSONBool.Create(False));
        Result.AddPair('error', 'No text format available on clipboard');
      end;
    end
    else
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Unsupported format: ' + Format);
    end;
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

// Proposed: ui_clipboard_set tool
procedure Tool_ClipboardSet(const Params: TJSONObject; out Result: TJSONObject);
var
  Content: string;
  Format: string;
begin
  Result := TJSONObject.Create;
  try
    if not Params.TryGetValue<string>('content', Content) then
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Missing required parameter: content');
      Exit;
    end;

    if not Params.TryGetValue<string>('format', Format) then
      Format := 'text';

    if SameText(Format, 'text') then
    begin
      Clipboard.AsText := Content;
      Result.AddPair('success', TJSONBool.Create(True));
      Result.AddPair('format', 'text');
      Result.AddPair('length', TJSONNumber.Create(Length(Content)));
      OutputDebugString(PChar(Format('MCP.ClipboardSet: Set %d chars', [Length(Content)])));
    end
    else
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', 'Unsupported format: ' + Format);
    end;
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

// Proposed: ui_clipboard_clear tool
procedure Tool_ClipboardClear(const Params: TJSONObject; out Result: TJSONObject);
begin
  Result := TJSONObject.Create;
  try
    Clipboard.Clear;
    Result.AddPair('success', TJSONBool.Create(True));
    OutputDebugString('MCP.ClipboardClear: Clipboard cleared');
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;

// Proposed: ui_clipboard_formats tool
procedure Tool_ClipboardFormats(const Params: TJSONObject; out Result: TJSONObject);
var
  Formats: TJSONArray;
  i: Integer;
  FormatObj: TJSONObject;
  FormatID: Word;
  FormatName: array[0..255] of Char;
begin
  Result := TJSONObject.Create;
  try
    Formats := TJSONArray.Create;

    for i := 0 to Clipboard.FormatCount - 1 do
    begin
      FormatID := Clipboard.Formats[i];
      FormatObj := TJSONObject.Create;
      FormatObj.AddPair('id', TJSONNumber.Create(FormatID));

      // Get format name
      if GetClipboardFormatName(FormatID, FormatName, SizeOf(FormatName)) > 0 then
        FormatObj.AddPair('name', string(FormatName))
      else
      begin
        // Standard format - provide name
        case FormatID of
          CF_TEXT: FormatObj.AddPair('name', 'CF_TEXT');
          CF_UNICODETEXT: FormatObj.AddPair('name', 'CF_UNICODETEXT');
          CF_BITMAP: FormatObj.AddPair('name', 'CF_BITMAP');
          CF_METAFILEPICT: FormatObj.AddPair('name', 'CF_METAFILEPICT');
          CF_DIB: FormatObj.AddPair('name', 'CF_DIB');
          CF_HDROP: FormatObj.AddPair('name', 'CF_HDROP');
          else FormatObj.AddPair('name', Format('Unknown (%d)', [FormatID]));
        end;
      end;

      Formats.Add(FormatObj);
    end;

    Result.AddPair('success', TJSONBool.Create(True));
    Result.AddPair('format_count', TJSONNumber.Create(Clipboard.FormatCount));
    Result.AddPair('formats', Formats);
  except
    on E: Exception do
    begin
      Result.AddPair('success', TJSONBool.Create(False));
      Result.AddPair('error', E.Message);
    end;
  end;
end;
```

---

## Best Practices

### 1. Always Use Try/Finally with Open/Close

```pascal
// GOOD
Clipboard.Open;
try
  // Multiple operations
finally
  Clipboard.Close;
end;

// BAD
Clipboard.Open;
// Operations without try/finally - clipboard stays open if exception
Clipboard.Close;
```

### 2. Preserve Original Clipboard Content

```pascal
procedure DoSomethingWithClipboard;
var
  OriginalText: string;
begin
  // Save
  OriginalText := Clipboard.AsText;
  try
    // Your operations
    Clipboard.AsText := 'Temporary data';
    // ... use clipboard ...
  finally
    // Restore
    Clipboard.AsText := OriginalText;
  end;
end;
```

### 3. Check Format Availability Before Reading

```pascal
// GOOD
if Clipboard.HasFormat(CF_UNICODETEXT) then
  ProcessText(Clipboard.AsText);

// BAD
var Text := Clipboard.AsText; // Returns empty string if no text - may hide errors
```

### 4. Use Delays After Keyboard Simulation

```pascal
// GOOD
SendCtrlC;
Sleep(100);  // Let clipboard write complete
var Text := Clipboard.AsText;

// BAD
SendCtrlC;
var Text := Clipboard.AsText; // May read old clipboard data
```

### 5. Validate Data After Paste

```pascal
procedure SmartPaste(Edit: TEdit; const ExpectedText: string);
begin
  Clipboard.AsText := ExpectedText;
  Edit.SetFocus;
  Sleep(50);
  SendCtrlV;
  Sleep(100);

  if Edit.Text <> ExpectedText then
    raise Exception.Create('Paste validation failed');
end;
```

### 6. Handle Clipboard Busy Errors

```pascal
function TrySetClipboard(const Text: string; Retries: Integer = 3): Boolean;
var
  i: Integer;
begin
  for i := 1 to Retries do
  begin
    try
      Clipboard.AsText := Text;
      Exit(True);
    except
      on E: Exception do
      begin
        if i = Retries then
          Exit(False);
        Sleep(100);
      end;
    end;
  end;
  Result := False;
end;
```

### 7. Prefer Direct API for Non-Interactive Operations

```pascal
// GOOD (for automation)
Clipboard.AsText := DataToExport;
ShowMessage('Data copied - you can now paste into Excel');

// BAD (unnecessary complexity)
FocusHiddenEdit;
HiddenEdit.Text := DataToExport;
SendCtrlC; // Why simulate when direct API works?
```

### 8. Prefer Keyboard Simulation for Interactive Operations

```pascal
// GOOD (respects app behavior)
SourceEdit.SetFocus;
SendCtrlC;
Sleep(100);

// BAD (bypasses app's OnCopy handler)
Clipboard.AsText := SourceEdit.Text; // May miss custom formatting
```

---

## Common Pitfalls

### 1. Forgetting to Close Clipboard

**Problem:** Clipboard stays open, other apps can't access it

```pascal
// WRONG
if SomeCondition then
begin
  Clipboard.Open;
  if AnotherCondition then
    Exit; // CLIPBOARD STAYS OPEN!
  Clipboard.Close;
end;

// RIGHT
Clipboard.Open;
try
  if SomeCondition then
    Exit; // Clipboard will be closed
finally
  Clipboard.Close;
end;
```

### 2. Reading Clipboard Too Soon After Ctrl+C

**Problem:** Reading old clipboard data

```pascal
// WRONG
SendCtrlC;
var Text := Clipboard.AsText; // Likely reads OLD data

// RIGHT
SendCtrlC;
Sleep(100); // Let clipboard write complete
var Text := Clipboard.AsText;
```

### 3. Not Handling Clipboard Formats

**Problem:** Assuming text is always available

```pascal
// WRONG
var Text := Clipboard.AsText; // Empty string if no text format
ProcessText(Text); // May process empty string unexpectedly

// RIGHT
if Clipboard.HasFormat(CF_TEXT) or Clipboard.HasFormat(CF_UNICODETEXT) then
  ProcessText(Clipboard.AsText)
else
  ShowMessage('No text on clipboard');
```

### 4. Thread Safety Issues

**Problem:** Multiple threads accessing clipboard without synchronization

```pascal
// WRONG (from background thread)
Clipboard.AsText := ThreadData; // May corrupt clipboard

// RIGHT
TThread.Synchronize(nil,
  procedure
  begin
    Clipboard.AsText := ThreadData;
  end
);
```

### 5. Ownership Confusion with SetClipboardData

**Problem:** Freeing memory that clipboard owns

```pascal
// WRONG
var Data := GlobalAlloc(...);
FillMemory(Data);
SetClipboardData(CF_UNICODETEXT, Data);
GlobalFree(Data); // ERROR: Clipboard now owns this!

// RIGHT
var Data := GlobalAlloc(...);
FillMemory(Data);
SetClipboardData(CF_UNICODETEXT, Data);
// Don't free - clipboard owns it now
```

### 6. Not Restoring Clipboard

**Problem:** Overwriting user's clipboard data

```pascal
// WRONG
procedure MyAutomation;
begin
  Clipboard.AsText := 'temporary';
  // ... operations ...
  // User's clipboard data is lost!
end;

// RIGHT
procedure MyAutomation;
var
  SavedText: string;
begin
  SavedText := Clipboard.AsText;
  try
    Clipboard.AsText := 'temporary';
    // ... operations ...
  finally
    Clipboard.AsText := SavedText;
  end;
end;
```

### 7. Incorrect Timing Assumptions

**Problem:** Assuming instant clipboard updates

```pascal
// WRONG (race condition)
Edit1.SetFocus;
SendCtrlC;
Edit2.SetFocus; // Too fast!
SendCtrlV;

// RIGHT
Edit1.SetFocus;
Sleep(50);
SendCtrlC;
Sleep(100);
Edit2.SetFocus;
Sleep(50);
SendCtrlV;
```

---

## Security Considerations

### 1. Clipboard Injection Attacks

**Risk:** Malicious clipboard monitoring can inject data

**Mitigation:**
```pascal
// Validate clipboard data before use
function SafeGetClipboardText: string;
begin
  Result := Clipboard.AsText;

  // Validate/sanitize
  if Length(Result) > MAX_EXPECTED_LENGTH then
    raise Exception.Create('Clipboard data too large');

  if ContainsSQLInjection(Result) then
    raise Exception.Create('Suspicious clipboard content');

  // Strip dangerous content
  Result := StripScriptTags(Result);
end;
```

### 2. Sensitive Data in Clipboard

**Risk:** Passwords/secrets left in clipboard

**Mitigation:**
```pascal
procedure CopyPasswordTemporarily(const Password: string);
begin
  Clipboard.AsText := Password;
  try
    // User pastes password
    MessageDlg('Password copied. Paste it now. ' +
               'It will be cleared in 10 seconds.', mtInformation, [mbOK], 0);
    Sleep(10000);
  finally
    // Clear clipboard
    Clipboard.Clear;
  end;
end;
```

### 3. Clipboard Monitoring/Hijacking

**Risk:** Malware monitoring clipboard for credit cards, crypto addresses

**Detection:**
```pascal
type
  TClipboardMonitor = class
  private
    FLastHash: string;
    procedure CheckClipboardIntegrity;
  public
    procedure VerifyClipboardNotModified;
  end;

procedure TClipboardMonitor.CheckClipboardIntegrity;
var
  CurrentHash: string;
begin
  CurrentHash := HashString(Clipboard.AsText);
  if (FLastHash <> '') and (CurrentHash <> FLastHash) then
    LogSecurityEvent('Clipboard modified unexpectedly');
  FLastHash := CurrentHash;
end;
```

### 4. Cross-Process Clipboard Access

**Risk:** Other processes can read clipboard

**Awareness:**
- Clipboard is system-wide
- Any process can read clipboard data
- No encryption or access control
- Don't put secrets in clipboard unnecessarily

**Best Practice:**
```pascal
// AVOID
Clipboard.AsText := APIKey; // Now visible to all processes!

// PREFER
DirectAPICall(APIKey); // Keep secret in memory only
```

---

## DelphiMCP Integration

### Proposed New Tools

#### 1. ui_clipboard_get

**Description:** Read clipboard content

**Parameters:**
- `format` (optional, default: "text") - Format to read ("text", "formats")

**Returns:**
```json
{
  "success": true,
  "format": "text",
  "content": "clipboard text here",
  "length": 1234
}
```

**Use Cases:**
- Read what user copied
- Verify copy operation succeeded
- Extract data from external applications

#### 2. ui_clipboard_set

**Description:** Write content to clipboard

**Parameters:**
- `content` (required) - Text to write
- `format` (optional, default: "text") - Format ("text")

**Returns:**
```json
{
  "success": true,
  "format": "text",
  "length": 1234
}
```

**Use Cases:**
- Prepare data for user to paste
- Transfer data to external applications
- Pre-load clipboard with templates

#### 3. ui_clipboard_clear

**Description:** Clear clipboard contents

**Parameters:** None

**Returns:**
```json
{
  "success": true
}
```

**Use Cases:**
- Security: clear sensitive data
- Reset clipboard state
- Clean up after operations

#### 4. ui_clipboard_formats

**Description:** List available clipboard formats

**Parameters:** None

**Returns:**
```json
{
  "success": true,
  "format_count": 3,
  "formats": [
    {"id": 13, "name": "CF_UNICODETEXT"},
    {"id": 1, "name": "CF_TEXT"},
    {"id": 49156, "name": "MyApp.CustomFormat"}
  ]
}
```

**Use Cases:**
- Debugging clipboard issues
- Format discovery
- Multi-format handling

### Integration Strategy

**Phase 1: Direct API Tools** (Recommended First)
- Implement `ui_clipboard_get`, `ui_clipboard_set`, `ui_clipboard_clear`
- Use VCL `TClipboard` for simplicity
- Synchronous, reliable operations
- No timing issues

**Phase 2: Enhanced Keyboard Simulation** (Optional)
- Add modifier key support to `ui_send_keys`
- Support `^c`, `^v`, `^a`, etc.
- Builds on existing `SendKeysSequence` infrastructure

**Phase 3: Advanced Clipboard Tools** (Future)
- `ui_clipboard_formats` - Format introspection
- Multi-format support (bitmaps, files)
- Clipboard monitoring tools

### Example Usage in Claude Code

```json
// Scenario: Copy data from one form to another

// 1. Focus source control
{"tool": "ui_set_focus", "params": {"control_path": "edtSource"}}

// 2. Copy via keyboard (respects app behavior)
{"tool": "ui_send_keys", "params": {"keys": "^a^c"}}

// 3. Verify clipboard data
{"tool": "ui_clipboard_get", "params": {"format": "text"}}

// 4. Optionally transform data
// (Claude processes clipboard content)

// 5. Write transformed data back
{"tool": "ui_clipboard_set", "params": {"content": "transformed data"}}

// 6. Focus target control
{"tool": "ui_set_focus", "params": {"control_path": "edtTarget"}}

// 7. Paste
{"tool": "ui_send_keys", "params": {"keys": "^v"}}
```

---

## Summary

### Quick Decision Matrix

| Scenario | Recommended Approach | Rationale |
|----------|---------------------|-----------|
| Read clipboard data | Direct API (`Clipboard.AsText`) | Synchronous, reliable, no timing issues |
| Write clipboard data for user | Direct API (`Clipboard.AsText := ...`) | Simple, immediate |
| Copy from VCL control | Keyboard (`Ctrl+C`) | Respects control's copy behavior |
| Paste to VCL control | Keyboard (`Ctrl+V`) | Triggers OnChange events, validation |
| Copy from non-VCL window | Keyboard (`Ctrl+C`) | Only option for external apps |
| Multi-format clipboard | Direct API (Clipboard.Open/Close) | Full control over formats |
| Background operation | Direct API | No focus requirements |
| User workflow automation | Keyboard + Direct API | Hybrid: keyboard for app behavior, API for data access |
| Clipboard monitoring | WM_CLIPBOARDUPDATE | System notification, not polling |

### Key Takeaways

1. **Direct API is preferred for programmatic data access** - simpler, faster, more reliable
2. **Keyboard simulation is preferred for user workflow automation** - respects application behavior
3. **Hybrid approach often optimal** - keyboard for interaction, API for data access
4. **Always handle timing** - delays after keyboard simulation are critical
5. **Preserve clipboard** - restore original content after operations
6. **Check formats** - don't assume text is available
7. **Thread safety** - use TThread.Synchronize or manual synchronization
8. **Security awareness** - clipboard is system-wide, visible to all processes

---

## References

**Delphi Documentation:**
- `Vcl.Clipbrd.TClipboard` - VCL clipboard class
- `Winapi.Windows` - Windows clipboard API functions

**Windows API:**
- `OpenClipboard`, `CloseClipboard`, `EmptyClipboard`
- `SetClipboardData`, `GetClipboardData`
- `RegisterClipboardFormat`, `IsClipboardFormatAvailable`
- `AddClipboardFormatListener`, `WM_CLIPBOARDUPDATE`

**DelphiMCP Framework:**
- `AutomationInputSimulation.pas` - SendInput keyboard/mouse simulation
- `AutomationCoreTools.pas` - MCP tool implementations
- `Documentation/CONTROL-PATHS-AND-MODALS.md` - Modal window support

**Related Topics:**
- [Windows Clipboard Formats](https://docs.microsoft.com/en-us/windows/win32/dataxchg/clipboard-formats)
- [Delayed Rendering](https://docs.microsoft.com/en-us/windows/win32/dataxchg/using-the-clipboard#delayed-rendering)
- [Clipboard Format Names](https://docs.microsoft.com/en-us/windows/win32/dataxchg/clipboard-format-names)

---

**Document Status:** Research Complete - Ready for Implementation
**Next Steps:** Implement Phase 1 tools (ui_clipboard_get, ui_clipboard_set, ui_clipboard_clear)
**Estimated Effort:** 4-6 hours for Phase 1 implementation
