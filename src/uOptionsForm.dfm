object OptionsForm: TOptionsForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'DiskLED Options'
  ClientHeight = 466
  ClientWidth = 859
  Color = 15921906
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PnlContent: TPanel
    Left = 0
    Top = 0
    Width = 859
    Height = 410
    Align = alClient
    BevelOuter = bvNone
    Color = 15921906
    ParentBackground = False
    TabOrder = 0
    ExplicitWidth = 440
    ExplicitHeight = 746
    object CardWindow: TPanel
      Left = 20
      Top = 16
      Width = 400
      Height = 126
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object LblSecWindow: TLabel
        Left = 20
        Top = 12
        Width = 51
        Height = 17
        Caption = 'Window'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object ChkStayOnTop: TCheckBox
        Left = 20
        Top = 40
        Width = 360
        Height = 21
        Caption = 'Always on top'
        TabOrder = 0
      end
      object ChkStartup: TCheckBox
        Left = 20
        Top = 66
        Width = 360
        Height = 21
        Caption = 'Run at Windows startup'
        TabOrder = 1
      end
      object ChkUpdateCheck: TCheckBox
        Left = 20
        Top = 92
        Width = 360
        Height = 21
        Caption = 'Check for a new version at startup'
        TabOrder = 2
      end
    end
    object CardFps: TPanel
      Left = 20
      Top = 154
      Width = 400
      Height = 128
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object LblSecFps: TLabel
        Left = 20
        Top = 12
        Width = 107
        Height = 17
        Caption = 'Refresh rate (fps)'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LblSecGraph: TLabel
        Left = 20
        Top = 72
        Width = 114
        Height = 17
        Caption = 'Graph update (Hz)'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object RbFps10: TRadioButton
        Left = 20
        Top = 40
        Width = 72
        Height = 21
        Caption = '10'
        TabOrder = 0
      end
      object RbFps15: TRadioButton
        Left = 108
        Top = 40
        Width = 72
        Height = 21
        Caption = '15'
        Checked = True
        TabOrder = 1
        TabStop = True
      end
      object RbFps20: TRadioButton
        Left = 196
        Top = 40
        Width = 72
        Height = 21
        Caption = '20'
        TabOrder = 2
      end
      object PnlGraphRates: TPanel
        Left = 12
        Top = 90
        Width = 376
        Height = 32
        BevelOuter = bvNone
        Color = clWhite
        ParentBackground = False
        TabOrder = 3
        object RbGraph2: TRadioButton
          Left = 8
          Top = 4
          Width = 72
          Height = 21
          Caption = '2'
          TabOrder = 0
        end
        object RbGraph1: TRadioButton
          Left = 96
          Top = 4
          Width = 72
          Height = 21
          Caption = '1'
          Checked = True
          TabOrder = 1
          TabStop = True
        end
        object RbGraph05: TRadioButton
          Left = 184
          Top = 4
          Width = 72
          Height = 21
          Caption = '0.5'
          TabOrder = 2
        end
      end
    end
    object CardScale: TPanel
      Left = 20
      Top = 294
      Width = 400
      Height = 96
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 2
      object LblSecScale: TLabel
        Left = 20
        Top = 12
        Width = 151
        Height = 17
        Caption = 'Network speed response'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object RbScaleLinear: TRadioButton
        Left = 20
        Top = 40
        Width = 360
        Height = 21
        Caption = 'Linear (link speed = 100%)'
        Checked = True
        TabOrder = 0
        TabStop = True
      end
      object RbScaleLog: TRadioButton
        Left = 20
        Top = 64
        Width = 360
        Height = 21
        Caption = 'Logarithmic (small traffic more visible)'
        TabOrder = 1
      end
    end
    object CardPing: TPanel
      Left = 436
      Top = 16
      Width = 400
      Height = 328
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 3
      object LblSecPing: TLabel
        Left = 20
        Top = 12
        Width = 28
        Height = 17
        Caption = 'Ping'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LblHost: TLabel
        Left = 20
        Top = 96
        Width = 50
        Height = 15
        Caption = 'Ping host'
      end
      object LblInterval: TLabel
        Left = 20
        Top = 146
        Width = 115
        Height = 15
        Caption = 'Interval (sec, min 300)'
      end
      object ChkPingEnabled: TCheckBox
        Left = 20
        Top = 40
        Width = 360
        Height = 21
        Caption = 'Enable Ping'
        TabOrder = 0
        OnClick = ChkPingEnabledClick
      end
      object ChkAutoGw: TCheckBox
        Left = 20
        Top = 66
        Width = 360
        Height = 21
        Caption = 'Use default gateway'
        TabOrder = 1
        OnClick = ChkAutoGwClick
      end
      object EdHost: TEdit
        Left = 20
        Top = 114
        Width = 360
        Height = 23
        TabOrder = 2
      end
      object EdInterval: TEdit
        Left = 20
        Top = 164
        Width = 120
        Height = 23
        TabOrder = 3
      end
      object CardThresholds: TPanel
        Left = 16
        Top = 200
        Width = 368
        Height = 112
        BevelOuter = bvNone
        Color = 15921906
        ParentBackground = False
        TabOrder = 4
        object LblSecThresholds: TLabel
          Left = 12
          Top = 10
          Width = 115
          Height = 15
          Caption = 'Ping level thresholds'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object LblFair: TLabel
          Left = 12
          Top = 36
          Width = 46
          Height = 15
          Caption = 'Fair (ms)'
        end
        object LblSlow: TLabel
          Left = 100
          Top = 36
          Width = 52
          Height = 15
          Caption = 'Slow (ms)'
        end
        object LblTimeout: TLabel
          Left = 188
          Top = 36
          Width = 45
          Height = 15
          Caption = 'Timeout'
        end
        object EdFair: TEdit
          Left = 12
          Top = 54
          Width = 72
          Height = 23
          TabOrder = 0
        end
        object EdSlow: TEdit
          Left = 100
          Top = 54
          Width = 72
          Height = 23
          TabOrder = 1
        end
        object EdTimeout: TEdit
          Left = 188
          Top = 54
          Width = 72
          Height = 23
          TabOrder = 2
        end
        object BtnResetThresholds: TButton
          Left = 12
          Top = 86
          Width = 344
          Height = 26
          Caption = 'Reset thresholds to defaults'
          TabOrder = 3
          OnClick = BtnResetThresholdsClick
        end
      end
    end
  end
  object PnlButtons: TPanel
    Left = 0
    Top = 410
    Width = 859
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 746
    ExplicitWidth = 440
    object ShpButtonTop: TShape
      Left = 0
      Top = 0
      Width = 859
      Height = 1
      Align = alTop
      Pen.Color = 14211288
      ExplicitWidth = 440
    end
    object BtnOk: TButton
      Left = 632
      Top = 7
      Width = 96
      Height = 32
      Caption = 'Apply'
      Default = True
      TabOrder = 0
      OnClick = BtnOkClick
    end
    object BtnCancel: TButton
      Left = 748
      Top = 7
      Width = 88
      Height = 32
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
