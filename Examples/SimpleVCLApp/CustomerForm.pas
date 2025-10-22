unit CustomerForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Grids;

type
  TfmCustomer = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    gridCustomers: TStringGrid;
    pnlBottom: TPanel;
    btnClose: TButton;
    btnRefresh: TButton;
    edtSearch: TEdit;
    lblSearch: TLabel;
    btnSearch: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
  private
    procedure LoadCustomerData;
    procedure FilterCustomers(const SearchText: string);
  public
    { Public declarations }
  end;

var
  fmCustomer: TfmCustomer;

implementation

{$R *.dfm}

procedure TfmCustomer.FormCreate(Sender: TObject);
begin
  // Setup grid
  gridCustomers.ColCount := 4;
  gridCustomers.RowCount := 2;  // Must be > FixedRows (at least 1 header + 1 data row)
  gridCustomers.FixedRows := 1;
  gridCustomers.ColWidths[0] := 50;
  gridCustomers.ColWidths[1] := 150;
  gridCustomers.ColWidths[2] := 200;
  gridCustomers.ColWidths[3] := 100;

  gridCustomers.Cells[0, 0] := 'ID';
  gridCustomers.Cells[1, 0] := 'Name';
  gridCustomers.Cells[2, 0] := 'Email';
  gridCustomers.Cells[3, 0] := 'Status';

  LoadCustomerData;
end;

procedure TfmCustomer.LoadCustomerData;
begin
  // Sample data - in real app this would come from database
  gridCustomers.RowCount := 6;

  gridCustomers.Cells[0, 1] := '1';
  gridCustomers.Cells[1, 1] := 'John Doe';
  gridCustomers.Cells[2, 1] := 'john.doe@example.com';
  gridCustomers.Cells[3, 1] := 'Active';

  gridCustomers.Cells[0, 2] := '2';
  gridCustomers.Cells[1, 2] := 'Jane Smith';
  gridCustomers.Cells[2, 2] := 'jane.smith@example.com';
  gridCustomers.Cells[3, 2] := 'Active';

  gridCustomers.Cells[0, 3] := '3';
  gridCustomers.Cells[1, 3] := 'Bob Johnson';
  gridCustomers.Cells[2, 3] := 'bob.j@example.com';
  gridCustomers.Cells[3, 3] := 'Inactive';

  gridCustomers.Cells[0, 4] := '4';
  gridCustomers.Cells[1, 4] := 'Alice Williams';
  gridCustomers.Cells[2, 4] := 'alice.w@example.com';
  gridCustomers.Cells[3, 4] := 'Active';

  gridCustomers.Cells[0, 5] := '5';
  gridCustomers.Cells[1, 5] := 'Charlie Brown';
  gridCustomers.Cells[2, 5] := 'charlie.b@example.com';
  gridCustomers.Cells[3, 5] := 'Active';
end;

procedure TfmCustomer.FilterCustomers(const SearchText: string);
var
  I: Integer;
  Found: Boolean;
begin
  if Trim(SearchText) = '' then
  begin
    LoadCustomerData;
    Exit;
  end;

  // Simple filter implementation
  for I := 1 to gridCustomers.RowCount - 1 do
  begin
    Found := (Pos(LowerCase(SearchText), LowerCase(gridCustomers.Cells[1, I])) > 0) or
             (Pos(LowerCase(SearchText), LowerCase(gridCustomers.Cells[2, I])) > 0);

    if Found then
      gridCustomers.RowHeights[I] := gridCustomers.DefaultRowHeight
    else
      gridCustomers.RowHeights[I] := 0;
  end;
end;

procedure TfmCustomer.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfmCustomer.btnRefreshClick(Sender: TObject);
begin
  LoadCustomerData;
  edtSearch.Clear;
  ShowMessage('Customer data refreshed');
end;

procedure TfmCustomer.btnSearchClick(Sender: TObject);
begin
  FilterCustomers(edtSearch.Text);
end;

end.
