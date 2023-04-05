program delphi_chess;

uses
  Forms,
  Unit1 in '..\delphi-chess\Unit1.pas' {Form1},
  Board in '..\delphi-chess\Board.pas',
  Bitmap in '..\delphi-chess\Bitmap.pas',
  Engine in '..\delphi-chess\Engine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
