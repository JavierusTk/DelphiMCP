object fmMain: TfmMain
  Left = 0
  Top = 0
  Caption = 'Simple VCL App - MCP Integration Example'
  ClientHeight = 500
  ClientWidth = 700
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 700
    Height = 80
    Align = alTop
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 16
      Width = 346
      Height = 21
      Caption = 'Simple VCL Application with MCP Integration'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnShowCustomer: TButton
      Left = 16
      Top = 43
      Width = 120
      Height = 25
      Caption = 'Show Customer'
      TabOrder = 0
      OnClick = btnShowCustomerClick
    end
    object btnClearLog: TButton
      Left = 568
      Top = 43
      Width = 120
      Height = 25
      Caption = 'Clear Log'
      TabOrder = 1
      OnClick = btnClearLogClick
    end
  end
  object memoLog: TMemo
    Left = 0
    Top = 240
    Width = 700
    Height = 235
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 475
    Width = 700
    Height = 25
    Align = alBottom
    TabOrder = 2
    object lblStatus: TLabel
      Left = 16
      Top = 5
      Width = 31
      Height = 15
      Caption = 'Ready'
    end
  end
  object pnlCustomer: TPanel
    Left = 0
    Top = 80
    Width = 700
    Height = 160
    Align = alTop
    TabOrder = 3
    object lblCustomerName: TLabel
      Left = 16
      Top = 16
      Width = 91
      Height = 15
      Caption = 'Customer Name:'
    end
    object lblCustomerEmail: TLabel
      Left = 16
      Top = 72
      Width = 88
      Height = 15
      Caption = 'Customer Email:'
    end
    object edtCustomerName: TEdit
      Left = 16
      Top = 37
      Width = 300
      Height = 23
      TabOrder = 0
      Text = 'John Doe'
    end
    object edtCustomerEmail: TEdit
      Left = 16
      Top = 93
      Width = 300
      Height = 23
      TabOrder = 1
      Text = 'john.doe@example.com'
    end
    object btnSaveCustomer: TButton
      Left = 16
      Top = 122
      Width = 120
      Height = 25
      Caption = 'Save Customer'
      TabOrder = 2
      OnClick = btnSaveCustomerClick
    end
  end
end
