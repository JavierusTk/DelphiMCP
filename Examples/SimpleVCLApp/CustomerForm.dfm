object fmCustomer: TfmCustomer
  Left = 0
  Top = 0
  Caption = 'Customer Management'
  ClientHeight = 450
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  Position = poScreenCenter
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 90
    Align = alTop
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 16
      Width = 148
      Height = 21
      Caption = 'Customer Database'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSearch: TLabel
      Left = 16
      Top = 48
      Width = 38
      Height = 15
      Caption = 'Search:'
    end
    object edtSearch: TEdit
      Left = 60
      Top = 45
      Width = 200
      Height = 23
      TabOrder = 0
    end
    object btnSearch: TButton
      Left = 266
      Top = 44
      Width = 75
      Height = 25
      Caption = 'Search'
      TabOrder = 1
      OnClick = btnSearchClick
    end
    object btnRefresh: TButton
      Left = 347
      Top = 44
      Width = 75
      Height = 25
      Caption = 'Refresh'
      TabOrder = 2
      OnClick = btnRefreshClick
    end
  end
  object gridCustomers: TStringGrid
    Left = 0
    Top = 90
    Width = 600
    Height = 319
    Align = alClient
    TabOrder = 1
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 409
    Width = 600
    Height = 41
    Align = alBottom
    TabOrder = 2
    object btnClose: TButton
      Left = 505
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Close'
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
end
