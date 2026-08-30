# Menu Automation Research - Delphi/VCL

Comprehensive research on automating interaction with popup menus (TPopupMenu) and application menus (TMainMenu) in Delphi VCL applications.

**Date:** 2025-10-23
**Context:** DelphiMCP Automation Framework
**Purpose:** Enable AI-driven automation of menu interactions

---

## Table of Contents

1. [Overview](#overview)
2. [Popup Menus (TPopupMenu)](#popup-menus-tpopupmenu)
3. [Application Menus (TMainMenu)](#application-menus-tmainmenu)
4. [VCL TMenuItem API](#vcl-tmenuitem-api)
5. [Windows API Approaches](#windows-api-approaches)
6. [Implementation Strategies](#implementation-strategies)
7. [Code Examples](#code-examples)
8. [Timing and Reliability Considerations](#timing-and-reliability-considerations)
9. [Recommendations](#recommendations)

---

## Overview

### Menu Types in VCL Applications

Delphi VCL provides two main menu component types:

1. **TPopupMenu** - Context menus (right-click menus)
   - Shown programmatically via `.Popup(X, Y)` method
   - Associated with controls via `Control.PopupMenu` property
   - Can be triggered by right-click or programmatically

2. **TMainMenu** - Application main menu bar
   - Integrated into the form's window frame
   - Accessible via Windows API (GetMenu)
   - Uses WM_COMMAND messages for item selection

Both menu types use **TMenuItem** components as their building blocks.

---

## Popup Menus (TPopupMenu)

### VCL Approach (Recommended)

#### 1. Showing a Popup Menu Programmatically

```pascal
// Method 1: Show at specific screen coordinates
procedure ShowPopupAtPoint(PopupMenu: TPopupMenu; X, Y: Integer);
begin
  PopupMenu.Popup(X, Y);
end;

// Method 2: Show at control's position
procedure ShowPopupAtControl(PopupMenu: TPopupMenu; Control: TControl);
var
  Pt: TPoint;
begin
  Pt := Control.ClientToScreen(Point(0, 0));
  PopupMenu.Popup(Pt.X, Pt.Y);
end;

// Method 3: Show at current mouse position
procedure ShowPopupAtMouse(PopupMenu: TPopupMenu);
var
  Pt: TPoint;
begin
  GetCursorPos(Pt);
  PopupMenu.Popup(Pt.X, Pt.Y);
end;
```

**Key Properties:**
- `PopupComponent: TComponent` - Component that "owns" the popup (set automatically when popup is shown)
- `Alignment: TPopupAlignment` - paLeft, paRight, paCenter
- `AutoPopup: Boolean` - If True, shows automatically on right-click
- `OnPopup: TNotifyEvent` - Triggered before menu is shown (for dynamic menu building)

#### 2. Finding Menu Items

```pascal
// Find by caption
function FindMenuItemByCaption(Menu: TPopupMenu; const Caption: string): TMenuItem;
begin
  Result := Menu.Items.Find(Caption);
end;

// Find recursively (including submenus)
function FindMenuItemRecursive(ParentItem: TMenuItem; const Caption: string): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to ParentItem.Count - 1 do
  begin
    if SameText(ParentItem[i].Caption, Caption) then
    begin
      Result := ParentItem[i];
      Exit;
    end;

    // Search in submenus
    if ParentItem[i].Count > 0 then
    begin
      Result := FindMenuItemRecursive(ParentItem[i], Caption);
      if Result <> nil then
        Exit;
    end;
  end;
end;

// Find by tag
function FindMenuItemByTag(ParentItem: TMenuItem; Tag: Integer): TMenuItem;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to ParentItem.Count - 1 do
  begin
    if ParentItem[i].Tag = Tag then
    begin
      Result := ParentItem[i];
      Exit;
    end;

    if ParentItem[i].Count > 0 then
    begin
      Result := FindMenuItemByTag(ParentItem[i], Tag);
      if Result <> nil then
        Exit;
    end;
  end;
end;

// Find by name (using RTTI or component name)
function FindMenuItemByName(Menu: TPopupMenu; const ItemName: string): TMenuItem;
begin
  Result := Menu.FindComponent(ItemName) as TMenuItem;
end;
```

#### 3. Clicking Menu Items

```pascal
// Direct VCL click (recommended - most reliable)
procedure ClickMenuItem(MenuItem: TMenuItem);
begin
  if Assigned(MenuItem) and MenuItem.Enabled and MenuItem.Visible then
    MenuItem.Click;
end;

// Click by caption
procedure ClickMenuItemByCaption(Menu: TPopupMenu; const Caption: string);
var
  Item: TMenuItem;
begin
  Item := FindMenuItemRecursive(Menu.Items, Caption);
  if Assigned(Item) then
    ClickMenuItem(Item);
end;

// Click by path (e.g., "File|Open|Recent Files")
procedure ClickMenuItemByPath(Menu: TPopupMenu; const Path: string);
var
  Parts: TArray<string>;
  CurrentItem: TMenuItem;
  i, j: Integer;
  Found: Boolean;
begin
  Parts := Path.Split(['|']);
  CurrentItem := Menu.Items;

  for i := 0 to High(Parts) do
  begin
    Found := False;
    for j := 0 to CurrentItem.Count - 1 do
    begin
      if SameText(StripHotkey(CurrentItem[j].Caption), Parts[i]) then
      begin
        if i = High(Parts) then
        begin
          // Last item - click it
          ClickMenuItem(CurrentItem[j]);
          Exit;
        end
        else
        begin
          // Navigate deeper
          CurrentItem := CurrentItem[j];
          Found := True;
          Break;
        end;
      end;
    end;

    if not Found then
      raise Exception.CreateFmt('Menu path not found: %s', [Path]);
  end;
end;

// Helper function to strip hotkey ampersands
function StripHotkey(const Text: string): string;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(Text) do
  begin
    if Text[i] = '&' then
    begin
      Inc(i);
      if (i <= Length(Text)) and (Text[i] = '&') then
        Result := Result + '&';
    end
    else
      Result := Result + Text[i];
    Inc(i);
  end;
end;
```

#### 4. Enumerating Menu Items

```pascal
// Get all menu items (flat list)
procedure EnumerateMenuItems(ParentItem: TMenuItem; List: TList<TMenuItem>);
var
  i: Integer;
begin
  for i := 0 to ParentItem.Count - 1 do
  begin
    List.Add(ParentItem[i]);
    if ParentItem[i].Count > 0 then
      EnumerateMenuItems(ParentItem[i], List);
  end;
end;

// Get menu structure as JSON
function MenuToJSON(ParentItem: TMenuItem): TJSONObject;
var
  i: Integer;
  ItemsArray: TJSONArray;
  ItemObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('caption', StripHotkey(ParentItem.Caption));
    Result.AddPair('enabled', TJSONBool.Create(ParentItem.Enabled));
    Result.AddPair('visible', TJSONBool.Create(ParentItem.Visible));
    Result.AddPair('checked', TJSONBool.Create(ParentItem.Checked));
    Result.AddPair('tag', TJSONNumber.Create(ParentItem.Tag));
    Result.AddPair('name', ParentItem.Name);
    Result.AddPair('is_line', TJSONBool.Create(ParentItem.IsLine));

    if ParentItem.Count > 0 then
    begin
      ItemsArray := TJSONArray.Create;
      for i := 0 to ParentItem.Count - 1 do
      begin
        ItemObj := MenuToJSON(ParentItem[i]);
        ItemsArray.Add(ItemObj);
      end;
      Result.AddPair('items', ItemsArray);
    end;
  except
    Result.Free;
    raise;
  end;
end;
```

#### 5. Detecting When Popup is Visible

```pascal
// Check if any popup menu is currently showing
function IsPopupMenuVisible: Boolean;
var
  Msg: TMsg;
begin
  // Windows maintains popup menu state internally
  // We can check if popup menu tracking is active
  Result := PeekMessage(Msg, 0, WM_ENTERMENULOOP, WM_EXITMENULOOP, PM_NOREMOVE);
end;

// Wait for popup to close
procedure WaitForPopupToClose(TimeoutMs: Integer = 5000);
var
  StartTime: Cardinal;
begin
  StartTime := GetTickCount;
  while IsPopupMenuVisible do
  begin
    Application.ProcessMessages;
    Sleep(10);

    if GetTickCount - StartTime > TimeoutMs then
      raise Exception.Create('Timeout waiting for popup menu to close');
  end;
end;
```

### Windows API Approach (TrackPopupMenu)

VCL's `TPopupMenu.Popup()` internally uses Windows API `TrackPopupMenu`. Direct API usage is rarely needed but documented here for completeness:

```pascal
uses Winapi.Windows, Winapi.Messages;

procedure TrackPopupMenuAPI(MenuHandle: HMENU; X, Y: Integer; OwnerWnd: HWND);
var
  Flags: UINT;
begin
  Flags := TPM_LEFTALIGN or TPM_TOPALIGN or TPM_LEFTBUTTON;

  // TrackPopupMenu is blocking - it doesn't return until menu is dismissed
  TrackPopupMenu(MenuHandle, Flags, X, Y, 0, OwnerWnd, nil);
end;

// Get popup menu handle from TPopupMenu
function GetPopupMenuHandle(PopupMenu: TPopupMenu): HMENU;
begin
  Result := PopupMenu.Handle;
end;
```

**Key API Functions:**
- `TrackPopupMenu()` - Display and track popup menu (blocking call)
- `TrackPopupMenuEx()` - Extended version with return rectangle
- `GetSubMenu()` - Get submenu handle
- `GetMenuItemCount()` - Get item count
- `GetMenuItemInfo()` - Get item information

---

## Application Menus (TMainMenu)

### VCL Approach (Recommended)

#### 1. Accessing Main Menu

```pascal
// Get main menu from form
function GetFormMainMenu(Form: TForm): TMainMenu;
begin
  Result := Form.Menu;
end;

// Find menu item in main menu
function FindMainMenuItem(MainMenu: TMainMenu; const Caption: string): TMenuItem;
begin
  Result := FindMenuItemRecursive(MainMenu.Items, Caption);
end;

// Click main menu item (same as popup menu)
procedure ClickMainMenuItem(MenuItem: TMenuItem);
begin
  if Assigned(MenuItem) and MenuItem.Enabled and MenuItem.Visible then
    MenuItem.Click;
end;
```

#### 2. Enumerating Main Menu Structure

```pascal
// Get all top-level menu items (File, Edit, View, etc.)
function GetTopLevelMenuItems(MainMenu: TMainMenu): TArray<TMenuItem>;
var
  i: Integer;
begin
  SetLength(Result, MainMenu.Items.Count);
  for i := 0 to MainMenu.Items.Count - 1 do
    Result[i] := MainMenu.Items[i];
end;

// Get complete menu structure as JSON
function MainMenuToJSON(MainMenu: TMainMenu): TJSONObject;
var
  i: Integer;
  TopLevelArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  try
    TopLevelArray := TJSONArray.Create;
    for i := 0 to MainMenu.Items.Count - 1 do
      TopLevelArray.Add(MenuToJSON(MainMenu.Items[i]));

    Result.AddPair('menu_items', TopLevelArray);
  except
    Result.Free;
    raise;
  end;
end;
```

### Windows API Approach

#### 1. Getting Menu Handles

```pascal
uses Winapi.Windows;

// Get main menu handle from form window
function GetFormMenuHandle(Form: TForm): HMENU;
begin
  Result := GetMenu(Form.Handle);
end;

// Get submenu by position
function GetSubmenuByPosition(MenuHandle: HMENU; Position: Integer): HMENU;
begin
  Result := GetSubMenu(MenuHandle, Position);
end;

// Get menu item count
function GetMenuItemCountAPI(MenuHandle: HMENU): Integer;
begin
  Result := GetMenuItemCount(MenuHandle);
end;
```

#### 2. Menu Item Information

```pascal
uses Winapi.Windows;

// Get menu item info
function GetMenuItemInfoAPI(MenuHandle: HMENU; ItemID: UINT;
  ByPosition: Boolean): TMenuItemInfo;
begin
  ZeroMemory(@Result, SizeOf(Result));
  Result.cbSize := SizeOf(TMenuItemInfo);
  Result.fMask := MIIM_STATE or MIIM_ID or MIIM_TYPE or MIIM_SUBMENU or MIIM_DATA;

  if not GetMenuItemInfo(MenuHandle, ItemID, ByPosition, Result) then
    RaiseLastOSError;
end;

// Get menu item caption
function GetMenuItemCaptionAPI(MenuHandle: HMENU; Position: Integer): string;
var
  Buffer: array[0..255] of Char;
begin
  if GetMenuString(MenuHandle, Position, Buffer, SizeOf(Buffer), MF_BYPOSITION) > 0 then
    Result := Buffer
  else
    Result := '';
end;

// Check if menu item is enabled
function IsMenuItemEnabledAPI(MenuHandle: HMENU; ItemID: UINT): Boolean;
var
  State: UINT;
begin
  State := GetMenuState(MenuHandle, ItemID, MF_BYCOMMAND);
  Result := (State <> UINT(-1)) and ((State and MF_DISABLED) = 0);
end;
```

#### 3. Invoking Menu Items via WM_COMMAND

```pascal
uses Winapi.Windows, Winapi.Messages;

// Send WM_COMMAND to invoke menu item
procedure InvokeMenuItemByCommand(FormHandle: HWND; CommandID: WORD);
begin
  PostMessage(FormHandle, WM_COMMAND, CommandID, 0);
end;

// Get command ID from menu item
function GetMenuItemCommandID(MenuHandle: HMENU; Position: Integer): WORD;
begin
  Result := GetMenuItemID(MenuHandle, Position);
  if Result = UINT(-1) then
    raise Exception.CreateFmt('Invalid menu item position: %d', [Position]);
end;

// Click menu item by position (Windows API approach)
procedure ClickMenuItemByPositionAPI(Form: TForm; TopLevelPos, ItemPos: Integer);
var
  MenuHandle, SubMenuHandle: HMENU;
  CommandID: WORD;
begin
  MenuHandle := GetMenu(Form.Handle);
  if MenuHandle = 0 then
    raise Exception.Create('Form has no menu');

  SubMenuHandle := GetSubMenu(MenuHandle, TopLevelPos);
  if SubMenuHandle = 0 then
    raise Exception.Create('Invalid top-level menu position');

  CommandID := GetMenuItemID(SubMenuHandle, ItemPos);
  if CommandID = UINT(-1) then
    raise Exception.Create('Invalid menu item position');

  PostMessage(Form.Handle, WM_COMMAND, CommandID, 0);
end;
```

### Accelerator Key Simulation vs Direct Invocation

#### Option 1: Simulate Keyboard Shortcuts (Less Reliable)

```pascal
// Send Alt+F, then O for File > Open
procedure SendMenuAccelerator(FormHandle: HWND; const Keys: string);
begin
  // Use existing SendKeys functionality
  SetForegroundWindow(FormHandle);
  Sleep(100);
  SendKeysSequence(Keys);  // From AutomationInputSimulation
end;

// Example: File > Open (Alt+F, then O)
SendMenuAccelerator(Form.Handle, '%F{DOWN}{ENTER}');  // Alt+F, Down, Enter
```

**Pros:**
- Works like user interaction
- Triggers all intermediate events

**Cons:**
- Unreliable (timing-dependent)
- Requires window to have focus
- Affected by keyboard layout
- Can fail if shortcuts change

#### Option 2: Direct Menu Invocation (Recommended)

```pascal
// VCL approach - most reliable
MenuItem.Click;

// Windows API approach - when VCL access is not available
PostMessage(FormHandle, WM_COMMAND, CommandID, 0);
```

**Pros:**
- Reliable and fast
- No focus requirements
- No timing issues
- No keyboard layout dependencies

**Cons:**
- Bypasses some VCL event handling (but still calls OnClick)

---

## VCL TMenuItem API

### Key Properties

```pascal
TMenuItem = class(TComponent)
  property Caption: string;           // Display text (with & for hotkeys)
  property Checked: Boolean;          // Check mark state
  property Enabled: Boolean;          // Grayed out if False
  property Visible: Boolean;          // Hidden if False
  property RadioItem: Boolean;        // Mutual exclusion in group
  property GroupIndex: Byte;          // Radio group identifier
  property ShortCut: TShortCut;       // Keyboard shortcut
  property ImageIndex: Integer;       // Icon from ImageList
  property Tag: Integer;              // User-defined data
  property Hint: string;              // Tooltip text
  property Default: Boolean;          // Bold text
  property Break: TMenuBreak;         // Column break

  // Hierarchy
  property Count: Integer;            // Number of child items
  property Items[Index: Integer]: TMenuItem;  // Child items
  property Parent: TMenuItem;         // Parent item
  property MenuIndex: Integer;        // Position in parent

  // Events
  property OnClick: TNotifyEvent;     // Click handler
end;
```

### Key Methods

```pascal
// Programmatic click
procedure TMenuItem.Click;

// Find child by caption
function TMenuItem.Find(const ACaption: string): TMenuItem;

// Add/remove items
procedure TMenuItem.Add(Item: TMenuItem);
procedure TMenuItem.Insert(Index: Integer; Item: TMenuItem);
procedure TMenuItem.Remove(Item: TMenuItem);
procedure TMenuItem.Delete(Index: Integer);
procedure TMenuItem.Clear;

// Check if it's a separator line
function TMenuItem.IsLine: Boolean;
```

---

## Windows API Approaches

### Key API Functions Summary

```pascal
// Menu handle retrieval
GetMenu(Wnd: HWND): HMENU;                      // Get window's menu
GetSubMenu(Menu: HMENU; Pos: Integer): HMENU;   // Get submenu

// Menu item information
GetMenuItemCount(Menu: HMENU): Integer;
GetMenuItemID(Menu: HMENU; Pos: Integer): UINT;
GetMenuState(Menu: HMENU; ID: UINT; Flags: UINT): UINT;
GetMenuString(Menu: HMENU; IDItem: UINT; Buffer: PChar; Count: Integer; Flags: UINT): Integer;
GetMenuItemInfo(Menu: HMENU; Item: UINT; ByPos: BOOL; var Info: TMenuItemInfo): BOOL;

// Menu tracking
TrackPopupMenu(Menu: HMENU; Flags: UINT; X, Y: Integer; Reserved: Integer;
  Wnd: HWND; Rect: PRect): BOOL;

// Menu invocation
PostMessage(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL;
  // Use WM_COMMAND with menu item ID as wParam
```

### WM_COMMAND Message Structure

```pascal
// For menu item clicks:
wParam := MenuItemID;  // Command ID (low word)
lParam := 0;           // Always 0 for menu items

// Example:
PostMessage(FormHandle, WM_COMMAND, MenuItemID, 0);
```

---

## Implementation Strategies

### Strategy 1: Pure VCL Approach (Recommended)

**Best for:** Applications where you have access to VCL component references

```pascal
// 1. Find menu item by path
MenuItem := FindMenuItemByPath(Form.Menu, 'File|Open');

// 2. Click it
if Assigned(MenuItem) then
  MenuItem.Click;
```

**Advantages:**
- ✅ Most reliable
- ✅ Respects VCL event model
- ✅ No timing issues
- ✅ Works with disabled/invisible items (if needed for testing)

**Disadvantages:**
- ❌ Requires component access
- ❌ May bypass some low-level Windows event handling

### Strategy 2: Windows API Approach

**Best for:** External automation tools, when VCL access is not available

```pascal
// 1. Get menu handle
MenuHandle := GetMenu(FormHandle);

// 2. Navigate to submenu
FileMenu := GetSubMenu(MenuHandle, 0);  // File menu (position 0)

// 3. Find item by caption
ItemID := FindMenuItemIDByCaption(FileMenu, 'Open');

// 4. Send WM_COMMAND
PostMessage(FormHandle, WM_COMMAND, ItemID, 0);
```

**Advantages:**
- ✅ Works without VCL access
- ✅ Can automate external applications
- ✅ No component references needed

**Disadvantages:**
- ❌ More complex
- ❌ Requires window handle management
- ❌ Caption matching can be fragile

### Strategy 3: Hybrid Approach

**Best for:** DelphiMCP automation framework (internal automation with component access)

```pascal
// Use VCL for finding, Windows API for edge cases
MenuItem := FindMenuItemByPath(Form.Menu, Path);

if Assigned(MenuItem) then
begin
  // VCL click (preferred)
  MenuItem.Click;
end
else
begin
  // Fallback to Windows API if needed
  ClickMenuItemByPositionAPI(Form, TopLevel, ItemPos);
end;
```

---

## Code Examples

### Complete Popup Menu Automation

```pascal
unit AutomationPopupMenu;

interface

uses
  System.Classes, System.SysUtils, System.JSON, Vcl.Menus;

type
  TPopupMenuAutomation = class
  public
    // Show popup at coordinates
    class procedure ShowAt(PopupMenu: TPopupMenu; X, Y: Integer);

    // Find menu item by path
    class function FindItemByPath(PopupMenu: TPopupMenu;
      const Path: string): TMenuItem;

    // Click menu item by path
    class procedure ClickItemByPath(PopupMenu: TPopupMenu;
      const Path: string);

    // Get menu structure as JSON
    class function GetStructure(PopupMenu: TPopupMenu): TJSONObject;

    // Enumerate all items
    class function GetAllItems(PopupMenu: TPopupMenu): TArray<TMenuItem>;
  end;

implementation

class procedure TPopupMenuAutomation.ShowAt(PopupMenu: TPopupMenu; X, Y: Integer);
begin
  PopupMenu.Popup(X, Y);
end;

class function TPopupMenuAutomation.FindItemByPath(PopupMenu: TPopupMenu;
  const Path: string): TMenuItem;
var
  Parts: TArray<string>;
  Current: TMenuItem;
  i, j: Integer;
  Found: Boolean;
begin
  Parts := Path.Split(['|']);
  Current := PopupMenu.Items;

  for i := 0 to High(Parts) do
  begin
    Found := False;
    for j := 0 to Current.Count - 1 do
    begin
      if SameText(StripHotkey(Current[j].Caption), Parts[i]) then
      begin
        if i = High(Parts) then
          Exit(Current[j])
        else
        begin
          Current := Current[j];
          Found := True;
          Break;
        end;
      end;
    end;

    if not Found then
      raise Exception.CreateFmt('Menu path not found: %s', [Path]);
  end;

  Result := nil;
end;

class procedure TPopupMenuAutomation.ClickItemByPath(PopupMenu: TPopupMenu;
  const Path: string);
var
  Item: TMenuItem;
begin
  Item := FindItemByPath(PopupMenu, Path);
  if Assigned(Item) and Item.Enabled and Item.Visible then
    Item.Click
  else if not Assigned(Item) then
    raise Exception.CreateFmt('Menu item not found: %s', [Path])
  else if not Item.Enabled then
    raise Exception.CreateFmt('Menu item is disabled: %s', [Path])
  else
    raise Exception.CreateFmt('Menu item is not visible: %s', [Path]);
end;

class function TPopupMenuAutomation.GetStructure(PopupMenu: TPopupMenu): TJSONObject;
begin
  Result := MenuToJSON(PopupMenu.Items);
end;

class function TPopupMenuAutomation.GetAllItems(PopupMenu: TPopupMenu): TArray<TMenuItem>;
var
  List: TList<TMenuItem>;
begin
  List := TList<TMenuItem>.Create;
  try
    EnumerateMenuItems(PopupMenu.Items, List);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

end.
```

### Complete Main Menu Automation

```pascal
unit AutomationMainMenu;

interface

uses
  System.Classes, System.SysUtils, System.JSON, Vcl.Forms, Vcl.Menus;

type
  TMainMenuAutomation = class
  public
    // Get main menu from form
    class function GetMenu(Form: TForm): TMainMenu;

    // Find menu item by path
    class function FindItemByPath(Form: TForm; const Path: string): TMenuItem;

    // Click menu item by path
    class procedure ClickItemByPath(Form: TForm; const Path: string);

    // Get menu structure as JSON
    class function GetStructure(Form: TForm): TJSONObject;

    // Get all menu items
    class function GetAllItems(Form: TForm): TArray<TMenuItem>;
  end;

implementation

class function TMainMenuAutomation.GetMenu(Form: TForm): TMainMenu;
begin
  Result := Form.Menu;
  if not Assigned(Result) then
    raise Exception.Create('Form has no main menu');
end;

class function TMainMenuAutomation.FindItemByPath(Form: TForm;
  const Path: string): TMenuItem;
var
  MainMenu: TMainMenu;
begin
  MainMenu := GetMenu(Form);
  Result := TPopupMenuAutomation.FindItemByPath(MainMenu, Path);
end;

class procedure TMainMenuAutomation.ClickItemByPath(Form: TForm;
  const Path: string);
var
  MainMenu: TMainMenu;
begin
  MainMenu := GetMenu(Form);
  TPopupMenuAutomation.ClickItemByPath(MainMenu, Path);
end;

class function TMainMenuAutomation.GetStructure(Form: TForm): TJSONObject;
var
  MainMenu: TMainMenu;
begin
  MainMenu := GetMenu(Form);
  Result := TPopupMenuAutomation.GetStructure(MainMenu);
end;

class function TMainMenuAutomation.GetAllItems(Form: TForm): TArray<TMenuItem>;
var
  MainMenu: TMainMenu;
begin
  MainMenu := GetMenu(Form);
  Result := TPopupMenuAutomation.GetAllItems(MainMenu);
end;

end.
```

---

## Timing and Reliability Considerations

### 1. Menu Item Visibility Changes

Some applications dynamically enable/disable or show/hide menu items in the `OnPopup` event:

```pascal
// Wait for OnPopup to complete before clicking
procedure ShowAndWaitForPopup(PopupMenu: TPopupMenu; X, Y: Integer);
begin
  PopupMenu.Popup(X, Y);

  // Give OnPopup handlers time to execute
  Application.ProcessMessages;
  Sleep(50);  // Small delay
end;
```

### 2. Submenu Navigation

When navigating through multiple levels:

```pascal
// Navigate through submenus with processing between levels
procedure ClickMenuItemWithNavigation(const Path: string);
var
  Parts: TArray<string>;
  Current: TMenuItem;
  i: Integer;
begin
  Parts := Path.Split(['|']);
  Current := Menu.Items;

  for i := 0 to High(Parts) - 1 do
  begin
    Current := FindChildByCaption(Current, Parts[i]);

    // Allow OnClick/OnPopup to execute
    Application.ProcessMessages;
    Sleep(10);
  end;

  // Click final item
  Current := FindChildByCaption(Current, Parts[High(Parts)]);
  Current.Click;
end;
```

### 3. Modal Menu Tracking

`TrackPopupMenu` is blocking - it doesn't return until the menu is dismissed:

```pascal
// Don't call TrackPopupMenu directly in automation
// Use VCL's non-blocking TPopupMenu.Popup() instead
```

### 4. Thread Safety

All menu operations must occur in the main VCL thread:

```pascal
// Use TThread.Synchronize if calling from background thread
TThread.Synchronize(nil, procedure
begin
  MenuItem.Click;
end);
```

---

## Recommendations

### For DelphiMCP Automation Framework

Based on the research, here are recommendations for implementing menu automation:

#### Phase 1: VCL-Based Menu Tools (Recommended Start)

Implement four MCP tools:

1. **`ui.menu.get_structure`** - Get menu hierarchy as JSON
   ```json
   {
     "form_name": "fmMain",
     "menu_type": "main" | "popup",
     "items": [...]
   }
   ```

2. **`ui.menu.find_item`** - Find menu item by path
   ```json
   {
     "form_name": "fmMain",
     "path": "File|Open|Recent",
     "separator": "|"
   }
   ```

3. **`ui.menu.click_item`** - Click menu item
   ```json
   {
     "form_name": "fmMain",
     "path": "File|Save As",
     "wait_ms": 100
   }
   ```

4. **`ui.popup.show`** - Show popup menu at coordinates
   ```json
   {
     "popup_menu_name": "popContextMenu",
     "x": 100,
     "y": 200
   }
   ```

#### Phase 2: Right-Click Context Menu Automation

Add convenience tool:

5. **`ui.control.popup_menu`** - Right-click control to show popup
   ```json
   {
     "form_name": "fmMain",
     "control_path": "grdData",
     "then_click": "Copy|Copy Cell"
   }
   ```

#### Implementation Priority

1. ✅ **Start with VCL approach** (most reliable, already have component access)
2. ✅ **Path-based navigation** (more robust than position-based)
3. ✅ **JSON structure export** (enables Claude Code to "see" available menus)
4. ⚠️ **Windows API fallback** (only if VCL approach fails)
5. ❌ **Avoid keyboard simulation** (unreliable, timing-dependent)

#### Error Handling

```pascal
try
  // Attempt VCL click
  MenuItem.Click;
except
  on E: Exception do
  begin
    // Log error
    OutputDebugString(PChar('Menu click failed: ' + E.Message));

    // Return error in JSON
    Result.AddPair('success', TJSONBool.Create(False));
    Result.AddPair('error', E.Message);
  end;
end;
```

#### Integration with Existing Framework

Menu tools fit naturally into existing automation structure:

- **AutomationMenuTools.pas** - New unit with menu-specific tools
- **AutomationCoreTools.pas** - Register menu tools alongside existing tools
- **AutomationFormIntrospection.pas** - Extend to include menu structure

---

## Appendix: VCL Menu Component Hierarchy

```
TMenu (abstract base)
├── TMainMenu
│   ├── Items: TMenuItem (root)
│   ├── Handle: HMENU
│   └── WindowHandle: HWND
│
└── TPopupMenu
    ├── Items: TMenuItem (root)
    ├── Popup(X, Y: Integer)
    ├── PopupComponent: TComponent
    └── Handle: HMENU

TMenuItem
├── Caption: string
├── Items[]: TMenuItem (children)
├── Count: Integer
├── Click() method
└── Find(Caption): TMenuItem
```

---

## References

1. **Delphi VCL Documentation**
   - `Vcl.Menus.pas` - VCL menu implementation
   - TMenuItem class reference
   - TPopupMenu class reference
   - TMainMenu class reference

2. **Windows API Documentation**
   - `GetMenu`, `GetSubMenu`, `GetMenuItemInfo`
   - `TrackPopupMenu`, `TrackPopupMenuEx`
   - `WM_COMMAND`, `WM_MENUSELECT`
   - Menu flags and constants

3. **Existing Implementations**
   - `/mnt/w/VCL/VTreeView/Source/VTHeaderPopup.pas` - Popup menu implementation
   - `/mnt/w/CyberMAX/meus/MenuUsuario.pas` - Custom menu wrapper
   - `/mnt/w/VCL/Forms/Menubar.pas` - Toolbar menu integration
   - `/mnt/w/cnvcl/Source/NonVisual/CnMenuHook.pas` - Menu hooking framework

4. **DelphiMCP Framework**
   - `AutomationInputSimulation.pas` - Keyboard/mouse simulation
   - `AutomationControlInteraction.pas` - Control interaction patterns
   - `AutomationFormIntrospection.pas` - Form structure inspection

---

**Last Updated:** 2025-10-23
**Status:** Research Complete - Ready for Implementation
**Next Step:** Create `AutomationMenuTools.pas` implementing Phase 1 tools
