unit AutomationControlResolver;

{
  Control Path Resolution - Navigate control hierarchies using paths

  PURPOSE:
  - Resolve controls using path notation (named + indexed)
  - Support unnamed controls via index notation
  - Generate paths from control references

  PATH SYNTAX:
  - Named controls: "edtFichero"
  - Indexed children: "#0", "#1", etc. (0-based)
  - Nested paths: "edtFichero.#0.#1"
  - Form-relative: "#3.#5" starts from form.Controls[]

  EXAMPLES:
  - "edtFichero" → Find control by name
  - "edtFichero.#0" → First child of edtFichero
  - "#3" → form.Controls[3]
  - "pnlMain.#2.btnSave" → pnlMain → 3rd child → btnSave child

  USAGE:
    var Ctrl: TControl;
    Ctrl := ResolveControlPath(Form, 'edtFichero.#0');

    var Path: string;
    Path := GetControlPath(Form, Control);
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls;

/// <summary>
/// Resolve a control path to a TControl reference
/// </summary>
/// <param name="Form">The form containing the control hierarchy</param>
/// <param name="Path">Control path (e.g., "edtFichero.#0")</param>
/// <returns>TControl reference, or nil if not found</returns>
function ResolveControlPath(Form: TForm; const Path: string): TControl;

/// <summary>
/// Get the path to a control from the form root
/// </summary>
/// <param name="Form">The form containing the control</param>
/// <param name="Control">The control to get the path for</param>
/// <returns>Control path string</returns>
function GetControlPath(Form: TForm; Control: TControl): string;

implementation

uses
  System.StrUtils;

function FindControlByName(Parent: TWinControl; const Name: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  if Parent = nil then Exit;

  for I := 0 to Parent.ControlCount - 1 do
  begin
    if SameText(Parent.Controls[I].Name, Name) then
    begin
      Result := Parent.Controls[I];
      Exit;
    end;
  end;
end;

function GetIndexedChild(Parent: TWinControl; Index: Integer): TControl;
begin
  Result := nil;
  if (Parent = nil) or (Index < 0) or (Index >= Parent.ControlCount) then
    Exit;

  Result := Parent.Controls[Index];
end;

function ResolveControlPath(Form: TForm; const Path: string): TControl;
var
  Parts: TArray<string>;
  I: Integer;
  Current: TControl;
  Part: string;
  Index: Integer;
begin
  Result := nil;
  if (Form = nil) or (Path = '') then Exit;

  // Split path by dots
  Parts := SplitString(Path, '.');
  if Length(Parts) = 0 then Exit;

  // Start from form
  Current := Form;

  for I := 0 to High(Parts) do
  begin
    Part := Trim(Parts[I]);
    if Part = '' then Continue;

    // Check if this is an indexed reference (#N)
    if (Length(Part) > 1) and (Part[1] = '#') then
    begin
      // Extract index
      if not TryStrToInt(Copy(Part, 2, Length(Part) - 1), Index) then
      begin
        // Invalid index format
        Result := nil;
        Exit;
      end;

      // Get indexed child
      if not (Current is TWinControl) then
      begin
        Result := nil;
        Exit;
      end;

      Current := GetIndexedChild(TWinControl(Current), Index);
      if Current = nil then Exit;
    end
    else
    begin
      // Named control
      if not (Current is TWinControl) then
      begin
        Result := nil;
        Exit;
      end;

      Current := FindControlByName(TWinControl(Current), Part);
      if Current = nil then Exit;
    end;
  end;

  Result := Current;
end;

function GetControlPath(Form: TForm; Control: TControl): string;
var
  Parts: TArray<string>;
  Current: TControl;
  Parent: TWinControl;
  Index: Integer;
  I: Integer;
begin
  Result := '';
  if (Form = nil) or (Control = nil) then Exit;

  SetLength(Parts, 0);
  Current := Control;

  // Walk up the parent chain
  while (Current <> nil) and (Current <> Form) do
  begin
    Parent := Current.Parent;
    if Parent = nil then Break;

    // If control has a name, use it; otherwise use index
    if Current.Name <> '' then
    begin
      SetLength(Parts, Length(Parts) + 1);
      Parts[High(Parts)] := Current.Name;
    end
    else
    begin
      // Find index in parent's Controls array
      Index := -1;
      for I := 0 to Parent.ControlCount - 1 do
      begin
        if Parent.Controls[I] = Current then
        begin
          Index := I;
          Break;
        end;
      end;

      if Index >= 0 then
      begin
        SetLength(Parts, Length(Parts) + 1);
        Parts[High(Parts)] := '#' + IntToStr(Index);
      end
      else
      begin
        // Control not found in parent? Should not happen
        Result := '';
        Exit;
      end;
    end;

    Current := Parent;
  end;

  // Reverse parts (we built from child to parent, need parent to child)
  for I := High(Parts) downto 0 do
  begin
    if Result <> '' then
      Result := Result + '.';
    Result := Result + Parts[I];
  end;
end;

end.
