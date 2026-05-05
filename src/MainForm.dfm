object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Delphi LLMs Client'
  ClientHeight = 720
  ClientWidth = 1120
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 17
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1120
    Height = 140
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      1120
      140)
    object lblProvider: TLabel
      Left = 12
      Top = 12
      Width = 47
      Height = 17
      Caption = 'Provider'
    end
    object lblModel: TLabel
      Left = 190
      Top = 12
      Width = 43
      Height = 17
      Caption = 'Modelo'
    end
    object lblBaseUrl: TLabel
      Left = 455
      Top = 12
      Width = 52
      Height = 17
      Caption = 'Base URL'
    end
    object lblSecret: TLabel
      Left = 805
      Top = 12
      Width = 41
      Height = 17
      Caption = 'API key'
    end
    object lblSessionKey: TLabel
      Left = 12
      Top = 78
      Width = 120
      Height = 17
      Caption = 'SessionKey OpenClaw'
    end
    object cbProvider: TComboBox
      Left = 12
      Top = 34
      Width = 160
      Height = 25
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbProviderChange
    end
    object edtModel: TEdit
      Left = 190
      Top = 34
      Width = 245
      Height = 25
      TabOrder = 1
    end
    object edtBaseUrl: TEdit
      Left = 455
      Top = 34
      Width = 330
      Height = 25
      TabOrder = 2
    end
    object edtSecret: TEdit
      Left = 805
      Top = 34
      Width = 295
      Height = 25
      PasswordChar = '*'
      TabOrder = 3
    end
    object edtSessionKey: TEdit
      Left = 12
      Top = 100
      Width = 260
      Height = 25
      TabOrder = 4
    end
    object chkKeepContext: TCheckBox
      Left = 295
      Top = 101
      Width = 360
      Height = 24
      Caption = 'Manter contexto local'
      Checked = True
      State = cbChecked
      TabOrder = 5
    end
    object btnSave: TButton
      Left = 680
      Top = 96
      Width = 110
      Height = 32
      Caption = 'Guardar'
      TabOrder = 6
      OnClick = btnSaveClick
    end
    object btnClear: TButton
      Left = 800
      Top = 96
      Width = 140
      Height = 32
      Caption = 'Limpar conversa'
      TabOrder = 7
      OnClick = btnClearClick
    end
  end
  object memChat: TMemo
    Left = 0
    Top = 140
    Width = 1120
    Height = 420
    Align = alClient
    Lines.Strings = (
      '')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    WordWrap = True
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 560
    Width = 1120
    Height = 160
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Top = 8
    Padding.Right = 10
    Padding.Bottom = 10
    TabOrder = 2
    object pnlActions: TPanel
      Left = 965
      Top = 8
      Width = 145
      Height = 142
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 0
      object btnSend: TButton
        Left = 0
        Top = 0
        Width = 145
        Height = 42
        Align = alTop
        Caption = 'Enviar'
        Default = True
        TabOrder = 0
        OnClick = btnSendClick
      end
    end
    object memPrompt: TMemo
      Left = 10
      Top = 8
      Width = 955
      Height = 142
      Align = alClient
      ScrollBars = ssVertical
      TabOrder = 1
      WordWrap = True
      OnKeyDown = memPromptKeyDown
    end
  end
end
