object OptionsForm: TOptionsForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'DiskLED Options'
  ClientHeight = 497
  ClientWidth = 460
  Color = 15921906
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Padding.Left = 8
  Padding.Top = 8
  Padding.Right = 8
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PageControl1: TPageControl
    Left = 8
    Top = 8
    Width = 444
    Height = 441
    ActivePage = TsGeneral
    Align = alClient
    TabOrder = 0
    object TsGeneral: TTabSheet
      Caption = 'General'
      object CardWindow: TPanel
        Left = 16
        Top = 16
        Width = 400
        Height = 305
        BevelOuter = bvNone
        Color = clWhite
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
        object LblLanguage: TLabel
          Left = 20
          Top = 150
          Width = 52
          Height = 15
          Caption = 'Language'
        end
        object LblLanguageHint: TLabel
          Left = 234
          Top = 150
          Width = 146
          Height = 15
          AutoSize = False
          Caption = 'Applied after restart'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object LblStartupBlocked: TLabel
          Left = 38
          Top = 106
          Width = 344
          Height = 30
          AutoSize = False
          Caption = 'Enable this in Windows Startup Apps settings.'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          Visible = False
          WordWrap = True
        end
        object LblSecWindowMode: TLabel
          Left = 20
          Top = 200
          Width = 85
          Height = 17
          Caption = 'Display mode'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object CbLanguage: TComboBox
          Left = 90
          Top = 146
          Width = 136
          Height = 23
          Style = csDropDownList
          TabOrder = 3
          Items.Strings = (
            'Auto'
            #26085#26412#35486
            'English')
        end
        object ChkStayOnTop: TCheckBox
          Left = 20
          Top = 48
          Width = 360
          Height = 21
          Caption = 'Always on top'
          TabOrder = 0
        end
        object ChkStartup: TCheckBox
          Left = 20
          Top = 82
          Width = 360
          Height = 21
          Caption = 'Run at Windows startup'
          TabOrder = 1
        end
        object ChkUpdateCheck: TCheckBox
          Left = 20
          Top = 119
          Width = 360
          Height = 21
          Caption = 'Check for a new version at startup'
          TabOrder = 2
        end
        object RbWinOnly: TRadioButton
          Left = 20
          Top = 226
          Width = 360
          Height = 21
          Caption = 'Window Only'
          TabOrder = 4
        end
        object RbWinTrayLed: TRadioButton
          Left = 20
          Top = 250
          Width = 360
          Height = 21
          Caption = 'Window + Tray LED'
          TabOrder = 5
        end
        object RbTrayOnly: TRadioButton
          Left = 20
          Top = 274
          Width = 360
          Height = 21
          Caption = 'Tray LED Only'
          TabOrder = 6
        end
      end
    end
    object TsDisplay: TTabSheet
      Caption = 'Display'
      object CardFps: TPanel
        Left = 16
        Top = 16
        Width = 400
        Height = 128
        BevelOuter = bvNone
        Color = clWhite
        TabOrder = 2
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
          Top = 87
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
          Top = 35
          Width = 72
          Height = 21
          Caption = '10'
          TabOrder = 0
        end
        object RbFps15: TRadioButton
          Left = 108
          Top = 35
          Width = 72
          Height = 21
          Caption = '15'
          Checked = True
          TabOrder = 1
          TabStop = True
        end
        object RbFps20: TRadioButton
          Left = 196
          Top = 35
          Width = 72
          Height = 21
          Caption = '20'
          TabOrder = 2
        end
        object PnlGraphRates: TPanel
          Left = 12
          Top = 106
          Width = 376
          Height = 32
          BevelOuter = bvNone
          Color = clWhite
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
        Left = 16
        Top = 160
        Width = 400
        Height = 96
        BevelOuter = bvNone
        Color = clWhite
        TabOrder = 0
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
      object CardDisplayScale: TPanel
        Left = 16
        Top = 268
        Width = 400
        Height = 96
        BevelOuter = bvNone
        Color = clWhite
        TabOrder = 1
        object LblSecDisplayScale: TLabel
          Left = 20
          Top = 12
          Width = 81
          Height = 17
          Caption = 'Display Scale'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object RbScaleAuto: TRadioButton
          Left = 20
          Top = 40
          Width = 80
          Height = 21
          Caption = 'Auto'
          Checked = True
          TabOrder = 0
          TabStop = True
        end
        object RbScale100: TRadioButton
          Left = 110
          Top = 40
          Width = 80
          Height = 21
          Caption = '100%'
          TabOrder = 1
        end
        object RbScale150: TRadioButton
          Left = 200
          Top = 40
          Width = 80
          Height = 21
          Caption = '150%'
          TabOrder = 2
        end
        object RbScale200: TRadioButton
          Left = 290
          Top = 40
          Width = 80
          Height = 21
          Caption = '200%'
          TabOrder = 3
        end
      end
    end
    object TsTrayLed: TTabSheet
      Caption = 'Tray LED'
      object CardTrayLed: TPanel
        Left = 16
        Top = 16
        Width = 400
        Height = 400
        BevelOuter = bvNone
        Color = clWhite
        TabOrder = 0
        object LblSecTrayLedColor: TLabel
          Left = 20
          Top = 78
          Width = 91
          Height = 17
          Caption = 'Tray LED Color'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object LblSecTrayLedInfo: TLabel
          Left = 20
          Top = 12
          Width = 83
          Height = 17
          Caption = 'Tray LED Info'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object ImgLedGreen: TImage
          Left = 112
          Top = 101
          Width = 16
          Height = 16
          Center = True
          Proportional = True
          Stretch = True
          Transparent = True
        end
        object ImgLedBlue: TImage
          Left = 184
          Top = 101
          Width = 16
          Height = 16
          Center = True
          Proportional = True
          Stretch = True
          Transparent = True
        end
        object ImgLedRed: TImage
          Left = 256
          Top = 101
          Width = 16
          Height = 16
          Center = True
          Proportional = True
          Stretch = True
          Transparent = True
        end
        object ImgLedYellow: TImage
          Left = 328
          Top = 101
          Width = 16
          Height = 16
          Center = True
          Proportional = True
          Stretch = True
          Transparent = True
        end
        object LblLedGreen: TLabel
          Left = 90
          Top = 119
          Width = 60
          Height = 15
          Alignment = taCenter
          AutoSize = False
          Caption = 'Green'
        end
        object LblLedBlue: TLabel
          Left = 162
          Top = 119
          Width = 60
          Height = 15
          Alignment = taCenter
          AutoSize = False
          Caption = 'Blue'
        end
        object LblLedRed: TLabel
          Left = 234
          Top = 119
          Width = 60
          Height = 15
          Alignment = taCenter
          AutoSize = False
          Caption = 'Red'
        end
        object LblLedYellow: TLabel
          Left = 306
          Top = 119
          Width = 60
          Height = 15
          Alignment = taCenter
          AutoSize = False
          Caption = 'Yellow'
        end
        object LblSecTrayDrives: TLabel
          Left = 20
          Top = 212
          Width = 89
          Height = 17
          Caption = 'Per-drive LEDs'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object PnlLedDisk: TPanel
          Left = 0
          Top = 140
          Width = 400
          Height = 24
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 2
          object LblLedDisk: TLabel
            Left = 20
            Top = 4
            Width = 80
            Height = 15
            AutoSize = False
            Caption = 'Disk'
          end
          object RbLedDiskGreen: TRadioButton
            Left = 112
            Top = 3
            Width = 17
            Height = 17
            Checked = True
            TabOrder = 0
            TabStop = True
          end
          object RbLedDiskBlue: TRadioButton
            Left = 184
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 1
          end
          object RbLedDiskRed: TRadioButton
            Left = 256
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 2
          end
          object RbLedDiskYellow: TRadioButton
            Left = 328
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 3
          end
        end
        object PnlLedNet: TPanel
          Left = 0
          Top = 166
          Width = 400
          Height = 24
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 3
          object LblLedNet: TLabel
            Left = 20
            Top = 4
            Width = 80
            Height = 15
            AutoSize = False
            Caption = 'Network'
          end
          object RbLedNetGreen: TRadioButton
            Left = 112
            Top = 3
            Width = 17
            Height = 17
            Checked = True
            TabOrder = 0
            TabStop = True
          end
          object RbLedNetBlue: TRadioButton
            Left = 184
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 1
          end
          object RbLedNetRed: TRadioButton
            Left = 256
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 2
          end
          object RbLedNetYellow: TRadioButton
            Left = 328
            Top = 3
            Width = 17
            Height = 17
            TabOrder = 3
          end
        end
        object ChkLedDisk: TCheckBox
          Left = 20
          Top = 36
          Width = 120
          Height = 21
          Caption = 'Disk'
          Checked = True
          State = cbChecked
          TabOrder = 0
          OnClick = ChkLedDiskClick
        end
        object ChkLedNet: TCheckBox
          Left = 136
          Top = 36
          Width = 120
          Height = 21
          Caption = 'Network'
          TabOrder = 1
          OnClick = ChkLedNetClick
        end
        object ChkLedTotal: TCheckBox
          Left = 20
          Top = 364
          Width = 360
          Height = 21
          Caption = 'Also show the total LED'
          TabOrder = 5
        end
        object LstDrives: TCheckListBox
          Left = 20
          Top = 238
          Width = 360
          Height = 120
          ItemHeight = 17
          TabOrder = 4
        end
      end
    end
    object TsPing: TTabSheet
      Caption = 'Ping && Network'
      object CardPing: TPanel
        Left = 16
        Top = 16
        Width = 400
        Height = 345
        BevelOuter = bvNone
        Color = clWhite
        TabOrder = 0
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
          Left = 12
          Top = 216
          Width = 381
          Height = 121
          BevelOuter = bvNone
          Color = 15921906
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
  end
  object PnlButtons: TPanel
    Left = 8
    Top = 449
    Width = 444
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    TabOrder = 1
    object ShpButtonTop: TShape
      Left = 0
      Top = 0
      Width = 444
      Height = 1
      Align = alTop
      Pen.Color = 14211288
      ExplicitWidth = 460
    end
    object BtnOk: TButton
      Left = 240
      Top = 7
      Width = 96
      Height = 32
      Caption = 'Apply'
      Default = True
      TabOrder = 0
      OnClick = BtnOkClick
    end
    object BtnCancel: TButton
      Left = 350
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
