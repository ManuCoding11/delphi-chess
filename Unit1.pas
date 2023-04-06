unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Math, ExtCtrls, StdCtrls, Menus, Engine, Board, MMSystem;

type
  TForm1 = class(TForm)
    Board: TPaintBox;
    ButtonEnd: TButton;
    ButtonNewGameComputer0: TButton;
    ButtonNewGameTwoPlayer: TButton;
    ButtonNewGameComputer10: TButton;
    ButtonNewGameComputer20: TButton;
    procedure ButtonNewGameComputer10Click(Sender: TObject);
    procedure ButtonNewGameComputer20Click(Sender: TObject);
    procedure ButtonNewGameComputer0Click(Sender: TObject);
    procedure ButtonNewGameTwoPlayerClick(Sender: TObject);
    procedure BoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ButtonEndClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure ResizeUI(FormWidth, FormHeight: Integer; GameIsRunning: boolean);
  private
  public
    { Public-Deklarationen }
  end;

  TGameData = record
    AsWhite, whitesTurn, twoPlMode: Boolean;
    Board: TBoard;
  end;

const
  // relative Größe des Rands um das Spielbrett 
  BoardMargin: Double = 0.05;

var
  Form1: TForm1;
  BoardBg, BoardBgMax, blackTile, whiteTile, rbTile, rwTile, gbTile, gwTile, bbTile, bwTile: TBitmap;
  GameData: TGameData;
  GlobalScale: Integer;
  EngineData: TEngineData;
  EngineThread: TEngineThread;
  SelectedPiece: TBoardCoord;
  LastMove: TCoordList;

implementation

{$R *.dfm}

{ Initialisiert Bitmaps für einzelne Felder }
procedure InitTiles (Size: Integer);
type
  TARGB = packed record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Alpha: Byte;
  end;
  TARGBArray = packed array[0..MaxInt div System.SizeOf(TARGB) - 1] of TARGB;
  PARGBArray = ^TARGBArray;
  
var
  x, y: Integer;
  Pixel: TARGB;

begin
  if whiteTile <> nil
  then whiteTile.FreeImage
  else whiteTile := TBitmap.Create;

  whiteTile.PixelFormat := pf32bit;
  whiteTile.Width := Size;
  whiteTile.Height := Size;

  if blackTile <> nil
  then blackTile.FreeImage
  else blackTile := TBitmap.Create;

  blackTile.PixelFormat := pf32bit;
  blackTile.Width := Size;
  blackTile.Height := Size;


  if rwTile <> nil
  then rwTile.FreeImage
  else rwTile := TBitmap.Create;

  rwTile.PixelFormat := pf32bit;
  rwTile.Width := Size;
  rwTile.Height := Size;

  if rbTile <> nil
  then rbTile.FreeImage
  else rbTile := TBitmap.Create;

  rbTile.PixelFormat := pf32bit;
  rbTile.Width := Size;
  rbTile.Height := Size;


  if gwTile <> nil
  then gwTile.FreeImage
  else gwTile := TBitmap.Create;

  gwTile.PixelFormat := pf32bit;
  gwTile.Width := Size;
  gwTile.Height := Size;

  if gbTile <> nil
  then gbTile.FreeImage
  else gbTile := TBitmap.Create;

  gbTile.PixelFormat := pf32bit;
  gbTile.Width := Size;
  gbTile.Height := Size;


  if bwTile <> nil
  then bwTile.FreeImage
  else bwTile := TBitmap.Create;

  bwTile.PixelFormat := pf32bit;
  bwTile.Width := Size;
  bwTile.Height := Size;

  if bbTile <> nil
  then bbTile.FreeImage
  else bbTile := TBitmap.Create;

  bbTile.PixelFormat := pf32bit;
  bbTile.Width := Size;
  bbTile.Height := Size;


  for y := 0 to Size - 1 do
  begin
    for x := 0 to Size - 1 do
    begin
      Pixel.Alpha := byte(255);
      Pixel.Red := byte(237);
      Pixel.Green := byte(237);
      Pixel.Blue := byte(237);
      PARGBArray(whiteTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(171);
      Pixel.Green := byte(171);
      Pixel.Blue := byte(171);
      PARGBArray(blackTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(228);
      Pixel.Green := byte(134);
      Pixel.Blue := byte(134);
      PARGBArray(rwTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(163);
      Pixel.Green := byte(90);
      Pixel.Blue := byte(90);
      PARGBArray(rbTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(184);
      Pixel.Green := byte(223);
      Pixel.Blue := byte(146);
      PARGBArray(gwTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(118);
      Pixel.Green := byte(150);
      Pixel.Blue := byte(86);
      PARGBArray(gbTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(161);
      Pixel.Green := byte(240);
      Pixel.Blue := byte(232);
      PARGBArray(bwTile.ScanLine[y])^[x] := Pixel;

      Pixel.Alpha := byte(255);
      Pixel.Red := byte(80);
      Pixel.Green := byte(145);
      Pixel.Blue := byte(138);
      PARGBArray(bbTile.ScanLine[y])^[x] := Pixel;
    end;
  end;
end;

{ erzeugt eine an die Größe des Spielbretts angepasste Bitmap }
procedure RedrawBoard (Size: Integer);
// Funktionsbedingte Typen zum Abrufen und Verändern einzelner Pixel
type
  TARGB = packed record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
    Alpha: Byte;
  end;
  TARGBArray = packed array[0..MaxInt div System.SizeOf(TARGB) - 1] of TARGB;
  PARGBArray = ^TARGBArray;
  
var
  x, y, n: Integer;
  Pixel: TARGB;
  
begin
  // ganzzahliges Teilen durch 8 (da ein Schachbrett 8x8 Felder besitzt),
  // um die nötige Anzahl an Pixeln für ein Feld zu bestimmen.
  n := Size div 8;

  // Wenn die Bitmap des Spielbretts schon einmal beschrieben wurde,
  // dann wird das alte Bild gelöscht,
  // ansonsten wird eine neue Instanz erstellt.
  if BoardBg <> nil
  then BoardBg.FreeImage
  else BoardBg := TBitmap.Create;

  BoardBg.PixelFormat := pf32bit;

  BoardBg.Width := Size - (Size mod 8);
  BoardBg.Height := BoardBg.Width;

  for y := 0 to BoardBg.Height - 1 do
  begin
    for x := 0 to BoardBg.Width - 1 do
    begin
      // Die verketteten xor-Operatoren dienen als Schalter, um zu bestimmen,
      // ob ein Pixel schwarz oder weiß eingefärbt wird.
      // Bedingungen:
      // * wenn (x-Koordinate / Pixelanzahl) durch 2 keinen Rest hat
      // * wenn (y-Koordinate / Pixelanzahl) durch 2 keinen Rest hat
      if not ((((x div n) mod 2) = 0) xor (((y div n) mod 2) = 0))
      then begin
        Pixel.Alpha := byte(255);
        Pixel.Red := byte(237);
        Pixel.Green := byte(237);
        Pixel.Blue := byte(237);
      end
      else begin
        Pixel.Alpha := byte(255);
        Pixel.Red := byte(171);
        Pixel.Green := byte(171);
        Pixel.Blue := byte(171);
      end;

      PARGBArray(BoardBg.ScanLine[y])^[x] := Pixel;
    end;
  end;

  InitTiles(Size div 8);

  // Initialisiert Bitmaps für einzelne Felder
  Form1.Board.Canvas.Draw(0, 0, BoardBg);
end;

{ passt das Spielbrett relativ zur Fenstergröße an }
procedure ResizeBoard (FormWidth, FormHeight: Integer);
begin
  Form1.Board.Width := floor(min(FormWidth, FormHeight) * (1 - BoardMargin));
  Form1.Board.Height := Form1.Board.Width;

  Form1.Board.Width := Form1.Board.Width - Form1.Board.Width mod 8;
  Form1.Board.Height := Form1.Board.Height - Form1.Board.Height mod 8;

  Form1.Board.Left := floor((FormWidth - Form1.Board.Width) / 2);
  Form1.Board.Top := floor((FormHeight - Form1.Board.Height) / 2);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Form1.BorderStyle := bsNone;

  ResizeBoard(ClientWidth, ClientHeight);
  RedrawBoard(Board.Width);

  BoardBgMax := TBitmap.Create;
  BoardBgMax.Assign(BoardBg);

  randomize;
  GameData.whitesTurn := True;
  GameData.AsWhite := floor(Random * 2) = 1;
  GameData.Board := TBoard.Create(Board.Width);

  SelectedPiece := TBoardCoord.null;

  EngineData := TEngineData.Create;

  //PlaySound('src/sfx/background.wav', 0, SND_NOSTOP or SND_NODEFAULT or SND_ASYNC or SND_FILENAME or SND_LOOP);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Wenn die Schach-Engine bereits läuft, dann beende sie.
  TerminateProcess(EngineData.info.hProcess, 0);
  CloseHandle(EngineData.in_read);
  CloseHandle(EngineData.in_write);
  CloseHandle(EngineData.out_read);
  CloseHandle(EngineData.out_write);
end;

procedure TForm1.ButtonEndClick(Sender: TObject);
begin
  if Application.MessageBox('Willst du das Spiel wirklich beenden?', 'Beenden?', 4 + 32) = 6
  then
  begin
    Close;
  end;
end;

procedure TForm1.ResizeUI(FormWidth, FormHeight: Integer; GameIsRunning: boolean);
begin
  ButtonNewGameTwoPlayer.Width := FormWidth div 6;
  ButtonNewGameTwoPlayer.Height := FormHeight div 15;
  ButtonNewGameTwoPlayer.Font.Size := FormHeight div 40;

  ButtonNewGameComputer0.Width := FormWidth div 6;
  ButtonNewGameComputer0.Height := FormHeight div 15;
  ButtonNewGameComputer0.Font.Size := FormHeight div 40;
  ButtonNewGameComputer10.Width := FormWidth div 6;
  ButtonNewGameComputer10.Height := FormHeight div 15;
  ButtonNewGameComputer10.Font.Size := FormHeight div 40;
  ButtonNewGameComputer20.Width := FormWidth div 6;
  ButtonNewGameComputer20.Height := FormHeight div 15;
  ButtonNewGameComputer20.Font.Size := FormHeight div 40;

  ButtonEnd.Width := FormWidth div 6;
  ButtonEnd.Height := FormHeight div 15;
  ButtonEnd.Font.Size := FormHeight div 40;

  if GameIsRunning
  then begin
    ButtonNewGameTwoPlayer.Left := FormWidth div 32;
    ButtonNewGameTwoPlayer.Top := FormHeight div 32 * 6;

    ButtonNewGameComputer0.Left := FormWidth div 32;
    ButtonNewGameComputer0.Top := FormHeight div 32 * 12;
    ButtonNewGameComputer10.Left := FormWidth div 32;
    ButtonNewGameComputer10.Top := FormHeight div 32 * 15;
    ButtonNewGameComputer20.Left := FormWidth div 32;
    ButtonNewGameComputer20.Top := FormHeight div 32 * 18;

    ButtonEnd.Left := FormWidth div 32;
    ButtonEnd.Top := FormHeight div 32 * 26;
  end
  else begin
    ButtonNewGameTwoPlayer.Left := FormWidth div 2 - ButtonNewGameTwoPlayer.Width div 2;
    ButtonNewGameTwoPlayer.Top := FormHeight div 32 * 6;

    ButtonNewGameComputer0.Left := FormWidth div 2 - ButtonNewGameComputer0.Width div 2;
    ButtonNewGameComputer0.Top := FormHeight div 32 * 12;
    ButtonNewGameComputer10.Left := FormWidth div 2 - ButtonNewGameComputer10.Width div 2;
    ButtonNewGameComputer10.Top := FormHeight div 32 * 15;
    ButtonNewGameComputer20.Left := FormWidth div 2 - ButtonNewGameComputer20.Width div 2;
    ButtonNewGameComputer20.Top := FormHeight div 32 * 18;
                                            
    ButtonEnd.Left := FormWidth div 2 - ButtonEnd.Width div 2;
    ButtonEnd.Top := FormHeight div 32 * 26;
  end;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  ResizeBoard(ClientWidth, ClientHeight);
  ResizeUI(ClientWidth, ClientHeight, false);
end;

{ rendert die gesamte Stellung }
procedure renderPosition;
var
  buffer: TBitmap;
begin
  buffer := TBitmap.Create;
  buffer.Width := Form1.Board.Width;
  buffer.Height := Form1.Board.Height;

  if BoardBgMax <> nil
  then buffer.Canvas.Draw(0, 0, BoardBgMax)
  else buffer.Canvas.Draw(0, 0, BoardBg);

  GameData.Board.render(buffer, GameData.AsWhite);

  Form1.Board.Canvas.Draw(0, 0, buffer);
end;

{ rendert nur das Feld auf Koordinate pos; extrem ressourcenschonend }
procedure renderUpdated(pos: TBoardCoord);
var
  buffer: TBitmap;
begin
  buffer := TBitmap.Create;

  if ((pos.f  mod 2) = 0) xor ((pos.r mod 2) = 0)
  then buffer.Assign(whiteTile)
  else buffer.Assign(blackTile);

  GameData.Board.renderSingle(buffer, pos);

  if GameData.AsWhite
  then Form1.Board.Canvas.Draw
    (
      (pos.f - 1) * (Form1.Board.Width div 8),
      (8 - pos.r) * (Form1.Board.Height div 8),
      buffer
    )
  else Form1.Board.Canvas.Draw
    (
      (8 - pos.f) * (Form1.Board.Width div 8),
      (pos.r - 1) * (Form1.Board.Height div 8),
      buffer
    );
end;

{ rendert nur das Feld auf Koordinate pos in Selektionsfarbe }
procedure renderSelected(pos: TBoardCoord);
var
  buffer: TBitmap;
begin
  buffer := TBitmap.Create;

  if (GameData.whitesTurn and (GameData.Board.currentPos[pos.r][pos.f].color = white))
    or (not GameData.whitesTurn and (GameData.Board.currentPos[pos.r][pos.f].color = black))
  then if ((pos.f  mod 2) = 0) xor ((pos.r mod 2) = 0)
    then buffer.Assign(rwTile)
    else buffer.Assign(rbTile)
  else if ((pos.f  mod 2) = 0) xor ((pos.r mod 2) = 0)
    then buffer.Assign(gwTile)
    else buffer.Assign(gbTile);

  GameData.Board.renderSingle(buffer, pos);

  if GameData.AsWhite
  then Form1.Board.Canvas.Draw
    (
      (pos.f - 1) * (Form1.Board.Width div 8),
      (8 - pos.r) * (Form1.Board.Height div 8),
      buffer
    )
  else Form1.Board.Canvas.Draw
    (
      (8 - pos.f) * (Form1.Board.Width div 8),
      (pos.r - 1) * (Form1.Board.Height div 8),
      buffer
    );
end;

procedure renderSelectedBlue(pos: TBoardCoord);
var
  buffer: TBitmap;
begin
  buffer := TBitmap.Create;

  if ((pos.f  mod 2) = 0) xor ((pos.r mod 2) = 0)
    then buffer.Assign(bwTile)
    else buffer.Assign(bbTile);

  GameData.Board.renderSingle(buffer, pos);

  if GameData.AsWhite
  then Form1.Board.Canvas.Draw
    (
      (pos.f - 1) * (Form1.Board.Width div 8),
      (8 - pos.r) * (Form1.Board.Height div 8),
      buffer
    )
  else Form1.Board.Canvas.Draw
    (
      (8 - pos.f) * (Form1.Board.Width div 8),
      (pos.r - 1) * (Form1.Board.Height div 8),
      buffer
    );
end;

{ rendert die Felder aller legalen Züge einer Figur in Selektionsfarbe }
procedure renderPieceMoves(pos: TBoardCoord);
var
  r, f: integer;
begin
  for r := 1 to 8 do
    for f := 1 to 8 do
    begin
      if GameData.Board.legalMove(SelectedPiece, TBoardCoord.Create(f, r))
      then renderSelected(TBoardCoord.Create(f, r));
    end;
end;

{ rendert die Felder aller legalen Züge einer Figur; löscht somit die Selektion }
procedure clearPieceMoves(pos: TBoardCoord);
var
  r, f: integer;
begin
  for r := 1 to 8 do
    for f := 1 to 8 do
    begin
      if GameData.Board.legalMove(SelectedPiece, TBoardCoord.Create(f, r))
      then renderUpdated(TBoardCoord.Create(f, r));
    end;
end;



procedure TForm1.BoardMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  transposed, enPTarget: TBoardCoord;
  soundfile: PChar;
begin
  transposed := TBoardCoord.null;

  if Button = mbLeft
  then begin
    if GameData.AsWhite
    then transposed.setPos(x div (Board.Width div 8) + 1, 8 - y div (Board.Height div 8))
    else transposed.setPos(8 - x div (Board.Width div 8), y div (Board.Height div 8) + 1);

    if not BoardHelper.IsInBounds(SelectedPiece)
    then begin
      if (GameData.Board.currentPos[transposed.r][transposed.f].pieceType <> empty) and
        (
          (
            (
              (GameData.Board.currentPos[transposed.r][transposed.f].color <> white) xor
              GameData.whitesTurn
            ) and
            GameData.twoPlMode
          ) or (
            (
              (
                (GameData.Board.currentPos[transposed.r][transposed.f].color = white) and
                GameData.whitesTurn and
                GameData.AsWhite
              ) or (
                (GameData.Board.currentPos[transposed.r][transposed.f].color = black) and
                not GameData.whitesTurn and
                not GameData.AsWhite
              )
            ) and not
            GameData.twoPlMode
          )
        )
      then begin
        SelectedPiece.setTo(transposed);

        if length(LastMove) >= 2
        then begin
          renderSelectedBlue(LastMove[0]);
          renderSelectedBlue(LastMove[1]);
        end;

        renderSelected(SelectedPiece);
        
        renderPieceMoves(SelectedPiece);
      end;
    end
    else if GameData.Board.legalMove(SelectedPiece, transposed)
    then begin
      clearPieceMoves(SelectedPiece);

      if GameData.Board.currentPos[transposed.r][transposed.f].pieceType <> empty
      then soundfile := PChar('src/sfx/capture.wav')
      else soundfile := PChar('src/sfx/move-self.wav');

      enPTarget := TBoardCoord.null;
      enPTarget.setTo(GameData.Board.getEnPTarget);

      GameData.Board.move(SelectedPiece, transposed);
      renderPosition;

      if BoardHelper.IsInBounds(enPTarget)
      then if GameData.Board.currentPos[enPTarget.r][enPTarget.f].pieceType = empty
        then soundfile := PChar('src/sfx/capture.wav'); 

      if 
      (
        (GameData.Board.currentPos[transposed.r][transposed.f].pieceType = king) and
        (abs(SelectedPiece.f - transposed.f) = 2)
      )
      then begin
        renderUpdated(TBoardCoord.Create(1, 1));
        renderUpdated(TBoardCoord.Create(4, 1));

        renderUpdated(TBoardCoord.Create(6, 1));
        renderUpdated(TBoardCoord.Create(8, 1));

        renderUpdated(TBoardCoord.Create(1, 8));
        renderUpdated(TBoardCoord.Create(4, 8));

        renderUpdated(TBoardCoord.Create(6, 8));
        renderUpdated(TBoardCoord.Create(8, 8));
      end;

      if length(LastMove) < 2
      then begin
        SetLength(LastMove, 2);
        LastMove[0] := TBoardCoord.null;
        LastMove[1] := TBoardCoord.null;
      end;
      
      LastMove[0].setTo(transposed);
      LastMove[1].setTo(SelectedPiece);

      renderSelectedBlue(LastMove[0]);
      renderSelectedBlue(LastMove[1]);

      PlaySound(soundfile, 0, SND_NODEFAULT or SND_ASYNC or SND_FILENAME or SND_NOSTOP);

      SelectedPiece.setTo(TBoardCoord.null);

      GameData.whitesTurn := not GameData.whitesTurn;

      if not GameData.twoPlMode
      then begin
        EngineThread := TEngineThread.Create(EngineData, GameData.Board.moveSeq.engineFormat);

        if EngineThread.WaitFor <> 0
        then begin
          EngineData.is_started := false;
        end;

        EngineThread.Terminate;

        try
          LastMove := BoardHelper.DecodeStrMove(EngineThread.engineMove);

          if (GameData.Board.currentPos[LastMove[1].r][LastMove[1].f].pieceType <> empty)
          then soundfile := PChar('src/sfx/capture.wav')
          else soundfile := PChar('src/sfx/move-self.wav');

          if GameData.Board.currentPos[transposed.r][transposed.f].color = GameData.Board.currentPos[LastMove[0].r][LastMove[0].f].color
          then raise InvalidMoveException.Create('Engine has played an illegal move.');

          enPTarget := TBoardCoord.null;
          enPTarget.setTo(GameData.board.getEnPTarget);

          GameData.Board.moveString(EngineThread.engineMove);

          if BoardHelper.IsInBounds(enPTarget)
          then if GameData.Board.currentPos[enPTarget.r][enPTarget.f].pieceType = empty
            then soundfile := PChar('src/sfx/capture.wav');

          sleep(200);
          renderPosition;

          renderSelectedBlue(LastMove[0]);
          renderSelectedBlue(LastMove[1]);

          PlaySound(soundfile, 0, SND_NODEFAULT or SND_ASYNC or SND_FILENAME or SND_NOSTOP);

          GameData.whitesTurn := not GameData.whitesTurn;
        except
          on InvalidMoveException do begin
            EngineData.is_started := false;
            ShowMessage('Der Engine ist ein Fehler unterlaufen.' + #10 + 'Computermodus temporär nicht verfügbar.');
          end;
        end;

        EngineThread := nil;
      end
    end
    else if (GameData.Board.currentPos[transposed.r][transposed.f].pieceType <> empty) and
      (
        (GameData.Board.currentPos[transposed.r][transposed.f].color <> white) xor
        GameData.whitesTurn
      )
    then begin
      renderUpdated(SelectedPiece);
      clearPieceMoves(SelectedPiece);

      SelectedPiece.setTo(transposed);

      if length(LastMove) >= 2
      then begin
        renderSelectedBlue(LastMove[0]);
        renderSelectedBlue(LastMove[1]);
      end;

      renderSelected(SelectedPiece);
      renderPieceMoves(SelectedPiece);
    end
    else begin
      renderUpdated(SelectedPiece);
      clearPieceMoves(SelectedPiece);

      SelectedPiece.setTo(TBoardCoord.null);

      if length(LastMove) >= 2
      then begin
        renderSelectedBlue(LastMove[0]);
        renderSelectedBlue(LastMove[1]);
      end;
    end;
  end;

  transposed.free;
end;

procedure NewGameComputer(difficulty: Integer);
var
  buffer: array[0..255] of AnsiChar;
  bytesWritten: cardinal;
  option, move: string;
  soundfile: PChar;
begin
  // Wenn die Engine nicht fehlerfrei läuft, dann wird kein Spiel gestartet
  if not EngineData.is_started
  then begin
    ShowMessage('Nicht verfügbar.');
    exit;
  end;

  SetLength(LastMove, 0);

  // Ändert die Position der UI-Elemente, damit das Brett platz hat
  Form1.ResizeUI(Form1.ClientWidth, Form1.ClientHeight, true);

  // Sendet eine Nachricht mit der Angabe der Schwierigkeit an die Engine
  option := 'setoption name skill level value ' + IntToStr(max(min(difficulty, 20), 0)) + #10;
  fillChar(buffer, sizeof(buffer), #0);
  StrLCopy(buffer, PAnsiChar(option), sizeof(buffer) - 1);
  WriteFile(EngineData.in_write, buffer, length(option), bytesWritten, nil);

  // Schreiben der Nachricht in die Log-Datei
  option := option + #10;
  f.Write(option[1], length(option) * sizeof(AnsiChar));


  // Setzt den 2-Spieler-Modus außer Kraft
  GameData.twoPlMode := false;

  // Bestimmt (mit etwa 50% Chance), welche Farbe der Spieler bekommt
  GameData.AsWhite := floor(Random * 2) = 1;

  // Setzt das Spielbrett in die Ausgangsposition zurück
  GameData.Board.reset;

  // Setzt die Auswahl der angeklickten Spielfigur zurück
  SelectedPiece := TBoardCoord.null;

  // Sagt dem Spiel, das Weiß am Zug ist
  GameData.whitesTurn := true;

  renderPosition;
  
  // Wenn der Spieler Schwarz bekommen hat,
  // dann mache den ersten Zug
  if not GameData.AsWhite
  then begin
    // Zufällige Auswahl eines Zuges aus vier Eröffnungszügen
    case Random(4) of
      0: move := 'e2e4';
      1: move := 'd2d4';
      2: move := 'g2g3';
      3: move := 'b1a3';
    end;

    // Setzen des aktuellen Zuges als LastMove,
    // um das Highlighting zu aktivieren
    LastMove := BoardHelper.DecodeStrMove(move);

    // Auswahl des Zuggeräuschs, das abgespielt werden soll
    if GameData.Board.currentPos[LastMove[1].r][LastMove[1].f].pieceType <> empty
    then soundfile := PChar('src/sfx/capture.wav')
    else soundfile := PChar('src/sfx/move-self.wav');

    GameData.Board.moveString(move);

    PlaySound(soundfile, 0, SND_NODEFAULT or SND_ASYNC or SND_FILENAME or SND_NOSTOP);

    EngineThread := nil;
    renderPosition;

    // Highlighting des letzten Zuges
    renderSelectedBlue(LastMove[0]);
    renderSelectedBlue(LastMove[1]);

    GameData.whitesTurn := false;
  end;
end;

procedure TForm1.ButtonNewGameTwoPlayerClick(Sender: TObject);
begin
  // Ändert die Position der UI-Elemente, damit das Brett platz hat
  Form1.ResizeUI(Form1.ClientWidth, Form1.ClientHeight, true);

  SetLength(LastMove, 0);

  GameData.twoPlMode := true;
  GameData.AsWhite := true;
  GameData.Board.reset;
  SelectedPiece := TBoardCoord.null;
  renderPosition;
  GameData.whitesTurn := true;
end;

procedure TForm1.ButtonNewGameComputer0Click(Sender: TObject);
begin
  NewGameComputer(0);
end;

procedure TForm1.ButtonNewGameComputer20Click(Sender: TObject);
begin
  NewGameComputer(20);
end;

procedure TForm1.ButtonNewGameComputer10Click(Sender: TObject);
begin
  NewGameComputer(10);
end;

end.
