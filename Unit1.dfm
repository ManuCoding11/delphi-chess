object Form1: TForm1
  Left = 0
  Top = 0
  Width = 1920
  Height = 1200
  Caption = 'Form1'
  Color = clBtnFace
  Constraints.MinHeight = 720
  Constraints.MinWidth = 1280
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  WindowState = wsMaximized
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object Board: TPaintBox
    Left = 0
    Top = 0
    Width = 200
    Height = 200
    OnMouseDown = BoardMouseDown
  end
  object ButtonEnd: TButton
    Left = 16
    Top = 1032
    Width = 400
    Height = 100
    Caption = 'Beenden'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -53
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 0
    OnClick = ButtonEndClick
  end
  object ButtonNewGameComputer0: TButton
    Left = 16
    Top = 328
    Width = 400
    Height = 100
    Caption = 'Einfach'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -48
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    OnClick = ButtonNewGameComputer0Click
  end
  object ButtonNewGameTwoPlayer: TButton
    Left = 16
    Top = 72
    Width = 400
    Height = 100
    Caption = '2-Spieler'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -53
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 2
    OnClick = ButtonNewGameTwoPlayerClick
  end
  object ButtonNewGameComputer10: TButton
    Left = 16
    Top = 448
    Width = 400
    Height = 100
    Caption = 'Mittel'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -48
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 3
    OnClick = ButtonNewGameComputer10Click
  end
  object ButtonNewGameComputer20: TButton
    Left = 16
    Top = 568
    Width = 400
    Height = 100
    Caption = 'Schwer'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -48
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 4
    OnClick = ButtonNewGameComputer20Click
  end
end
