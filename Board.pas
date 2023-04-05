unit Board;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Math, ExtCtrls, StdCtrls, Menus, Bitmap;

type
  EPieces = (empty, pawn, knight, bishop, rook, queen, king);
  EColor = (none, white, black);

  InvalidMoveException = class(Exception)

  end;

  { Koordinate einer Figur }
  TBoardCoord = class
  public
    r, f: integer;

    constructor Create(x, y: integer);
    procedure setPos(x, y: integer);
    procedure setTo(c: TBoardCoord);
    function toString: string;
    class function null: TBoardCoord; static;
  end;

  TCoordList = array of TBoardCoord;

  { Liste aller bisherigen Züge }
  TMoveSequence = class
  public
    function getMove(index: cardinal): string;
    function getLastMove: string;
    procedure setMove(move: string);

    function engineFormat: string;

  private
    moves: array of string;
  end;

  { eine einzelne Spielfigur }
  TPiece = class
  public
    constructor Create(pType: EPieces; col: EColor); overload;
    procedure Update(pType: EPieces; col: EColor);

  public
    pieceType: EPieces;
    color: EColor;
  end;

  { Typalias für eine Reihe und ein 8x8-Feld aus Spielfiguren }
  TPieceRow = array [1..8] of TPiece;
  TPieceMap = array [1..8] of TPieceRow;

  { Managerklasse des Spiels }
  TBoard = class
  public
    constructor Create(s: integer);

    procedure setBoardSize(s: integer);
    procedure moveString(instruction: string);
    procedure move(fromPos, toPos: TBoardCoord);
    procedure render(target: TBitmap; asWhite: boolean);
    procedure renderSingle(target: TBitmap; pos: TBoardCoord);
    procedure reset;

    function currentPos: TPieceMap;
    function legalMove(fromPos, toPos: TBoardCoord): boolean;

    class function STARTPOS: TPieceMap;

  public
    moveSeq: TMoveSequence;
    promotionTarget: EPieces;

  private
    size: integer;
    position: TPieceMap;
    enPTarget: TBoardCoord;
    cW, cWL, cB, cBL: Boolean;
    imageStack: array[EPieces, EColor] of TBitmap;
  end;

  BoardHelper = class
    class function IsInBounds(c: TBoardCoord): boolean; static;
    class function FileToNumber(f: char): integer; static;
    class function FileToChar(f: integer): char; static;
    class function EmptyRow: TPieceRow; static;
    class function MapToFEN(map: TPieceMap): string; static;
    class function DecodeStrMove(move: string): TCoordList; static;

    class function PieceMoves(position: TBoardCoord; piece: TPiece): TCoordList; static;
    class function FilterPossible(from: TBoardCoord; board: TPieceMap; enPTarget: TBoardCoord): TCoordList; static;
    class function LineOfSight(fromPos, toPos: TBoardCoord; board: TPieceMap): TCoordList; static;
    class function IsInLineOfSight(fromPos, toPos: TBoardCoord; board: TPieceMap): boolean; static;
    //class function AnalyseThreats(board: TCoordList): TCoordList; static;
  end;



implementation

constructor TBoardCoord.Create(x, y: integer);
begin
  f := x;
  r := y;
end;

procedure TBoardCoord.setPos(x, y: integer);
begin
  f := x;
  r := y;
end;

procedure TBoardCoord.setTo(c: TBoardCoord);
begin
  if c <> nil
  then begin
    f := c.f;
    r := c.r;
  end;
end;

function TBoardCoord.toString: string;
begin
  result := BoardHelper.FileToChar(f) + IntToStr(r);
end;

class function TBoardCoord.null: TBoardCoord;
begin
  result := TBoardCoord.Create(0, 0);
end;

function TMoveSequence.getMove(index: cardinal): string;
begin
  if high(moves) >= index
  then result := moves[index]
  else result := '';
end;

function TMoveSequence.getLastMove: string;
begin
  if length(moves) > 0
  then result := moves[high(moves)]
  else result := '';
end;

procedure TMoveSequence.setMove(move: string);
begin
  setLength(moves, length(moves) + 1);
  if length(moves) > 0
  then moves[length(moves) - 1] := move;
end;

function TMoveSequence.engineFormat: string;
var
  i: cardinal;
begin
  result := 'startpos moves';

  for i := low(moves) to high(moves) do
    result := result + ' ' + moves[i];
end;

constructor TPiece.Create(pType: EPieces; col: EColor);
begin
  pieceType := pType;
  color := col;
end;

procedure TPiece.Update(pType: EPieces; col: EColor);
begin
  pieceType := pType;
  color := col;
end;


class function BoardHelper.IsInBounds(c: TBoardCoord): boolean;
begin
  result := (c <> nil) and (c.f >= 1) and (c.f <= 8) and (c.r >= 1) and (c.r <= 8);
end;

class function BoardHelper.FileToNumber(f: char): integer;
begin
  result := max(min(ord(f), 104), 97) - 96;
end;

class function BoardHelper.FileToChar(f: integer): char;
begin
  result := char(max(min(f + 96, 104), 97));
end;

class function BoardHelper.EmptyRow: TPieceRow;
var
  i: cardinal;
  row: TPieceRow;
begin
  fillChar(row, sizeof(row), 0);

  for i := 1 to 8 do
    row[i] := TPiece.Create(empty, none);

  result := row;
end;

{ String-Manipulation für Erzeugung eines FEN-Strings
  - fügt dem Zielstring einen anderen String an
  - wenn das ganzzahlige Argument > 0 ist, wird dieses als String zwischen Zielstring und anderem String eingefügt
  - wenn das ganzzahlige Argument >= 8 ist, entfällt der andere String }
procedure concatIfInRange(var target: string; count: integer; str: string);
begin
  if count >= 8
  then target := target + IntToStr(count)
  else if count > 0
  then target := target + IntToStr(count) + str
  else target := target + str;
end;

{ Erzeugt eine Repräsentation der Positionen aller Spielfiguren im FEN-Format }
class function BoardHelper.MapToFEN(map: TPieceMap): string;
var
  x, y, emptyCount: integer;
  tempPiece: TPiece;
begin
  result := '';
  
  for y := 1 to 8 do
  begin
    emptyCount := 0;

    for x := 1 to 8 do
    begin
      tempPiece := map[9 - y][x];

      if (tempPiece.color = white) and (tempPiece.pieceType <> empty)
      then begin
        case tempPiece.pieceType of
          pawn: concatIfInRange(result, emptyCount, 'P');
          knight: concatIfInRange(result, emptyCount, 'N');
          bishop: concatIfInRange(result, emptyCount, 'B');
          rook: concatIfInRange(result, emptyCount, 'R');
          queen: concatIfInRange(result, emptyCount, 'Q');
          king: concatIfInRange(result, emptyCount, 'K');
        end;

        emptyCount := 0;
      end
      else if (tempPiece.color = black) and (tempPiece.pieceType <> empty)
      then begin
        case tempPiece.pieceType of
          pawn: concatIfInRange(result, emptyCount, 'p');
          knight: concatIfInRange(result, emptyCount, 'n');
          bishop: concatIfInRange(result, emptyCount, 'b');
          rook: concatIfInRange(result, emptyCount, 'r');
          queen: concatIfInRange(result, emptyCount, 'q');
          king: concatIfInRange(result, emptyCount, 'k');
        end;

        emptyCount := 0;
      end
      else emptyCount := emptyCount + 1;
    end;

    concatIfInRange(result, emptyCount, '');

    if y < 8
    then concatIfInRange(result, 0, '/');
  end;
end;

{ Gibt die Anfangsposition eines normalen Spiels als TPieceMap zurück; statische Funktion mit konstantem Rückgabewert }
class function TBoard.STARTPOS: TPieceMap;
begin
  result[1][1] := TPiece.Create(rook, white);
  result[1][2] := TPiece.Create(knight, white);
  result[1][3] := TPiece.Create(bishop, white);
  result[1][4] := TPiece.Create(queen, white);
  result[1][5] := TPiece.Create(king, white);
  result[1][6] := TPiece.Create(bishop, white);
  result[1][7] := TPiece.Create(knight, white);
  result[1][8] := TPiece.Create(rook, white);

  result[2][1] := TPiece.Create(pawn, white);
  result[2][2] := TPiece.Create(pawn, white);
  result[2][3] := TPiece.Create(pawn, white);
  result[2][4] := TPiece.Create(pawn, white);
  result[2][5] := TPiece.Create(pawn, white);
  result[2][6] := TPiece.Create(pawn, white);
  result[2][7] := TPiece.Create(pawn, white);
  result[2][8] := TPiece.Create(pawn, white);
  
  result[3] := BoardHelper.EmptyRow;
  result[4] := BoardHelper.EmptyRow;
  result[5] := BoardHelper.EmptyRow;
  result[6] := BoardHelper.EmptyRow;

  result[7][1] := TPiece.Create(pawn, black);
  result[7][2] := TPiece.Create(pawn, black);
  result[7][3] := TPiece.Create(pawn, black); 
  result[7][4] := TPiece.Create(pawn, black);
  result[7][5] := TPiece.Create(pawn, black);
  result[7][6] := TPiece.Create(pawn, black);
  result[7][7] := TPiece.Create(pawn, black);
  result[7][8] := TPiece.Create(pawn, black);

  result[8][1] := TPiece.Create(rook, black);
  result[8][2] := TPiece.Create(knight, black);
  result[8][3] := TPiece.Create(bishop, black);
  result[8][4] := TPiece.Create(queen, black);
  result[8][5] := TPiece.Create(king, black);
  result[8][6] := TPiece.Create(bishop, black);
  result[8][7] := TPiece.Create(knight, black);
  result[8][8] := TPiece.Create(rook, black);
end;


constructor TBoard.Create(s: integer);
begin
  size := s;

  position := TBoard.STARTPOS;

  moveSeq := TMoveSequence.Create;

  enPTarget := TBoardCoord.null;

  promotionTarget := queen;

  cB := true;
  cBL := true;
  cW := true;
  cWL := true;

  imageStack[pawn, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wp.bmp'), size div 8);
  imageStack[knight, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wn.bmp'), size div 8);
  imageStack[bishop, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wb.bmp'), size div 8);
  imageStack[rook, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wr.bmp'), size div 8);
  imageStack[queen, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wq.bmp'), size div 8);
  imageStack[king, white] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/wk.bmp'), size div 8);

  imageStack[pawn, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/bp.bmp'), size div 8);
  imageStack[knight, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/bn.bmp'), size div 8);
  imageStack[bishop, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/bb.bmp'), size div 8);
  imageStack[rook, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/br.bmp'), size div 8);
  imageStack[queen, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/bq.bmp'), size div 8);
  imageStack[king, black] := TBitmapUtil.ShrinkBitmap(TBitmapUtil.ImportPiece('src/pieces/bk.bmp'), size div 8);
end;

procedure TBoard.setBoardSize(s: integer);
begin
  size := s;
end;

procedure TBoard.reset;
begin
  position := TBoard.STARTPOS;

  cB := true;
  cBL := true;
  cW := true;
  cWL := true;

  moveSeq.Free;
  moveSeq := TMoveSequence.Create;
end;

procedure TBoard.render(target: TBitmap; asWhite: boolean);
var
  f, r: integer;
begin
  target.Transparent := true;

  for r := 1 to 8 do
    for f := 1 to 8 do
    begin
      if (position[r][f].pieceType <> empty) and (position[r][f].color <> none)
      then if asWhite
        then target.Canvas.Draw((f - 1) * (size div 8), (8 - r) * (size div 8),
          imageStack[
            position[r][f].pieceType,
            position[r][f].color
          ]
        )
        else target.Canvas.Draw((8 - f) * (size div 8), (r - 1) * (size div 8),
          imageStack[
            position[r][f].pieceType,
            position[r][f].color
          ]
        );
    end;
end;

procedure TBoard.renderSingle(target: TBitmap; pos: TBoardCoord);
begin
  target.Transparent := true;

  if (position[pos.r][pos.f].pieceType <> empty) and (position[pos.r][pos.f].color <> none)
  then target.Canvas.Draw(0, 0,
    imageStack[
      position[pos.r][pos.f].pieceType,
      position[pos.r][pos.f].color
    ]
  );
end;

function TBoard.currentPos: TPieceMap;
begin
  result := position;
end;

{ Diese Prozedur dekodiert einen move-string und führt anschließend TBoard.move() aus }
procedure TBoard.moveString(instruction: string);
var
  moveList: TCoordList;
begin
  moveList := BoardHelper.DecodeStrMove(instruction);

  if length(moveList) <> 2
  then exit;

  if length(instruction) = 5
  then case instruction[4] of
    'q': promotionTarget := queen;
    'r': promotionTarget := rook;
    'n': promotionTarget := knight;
    'b': promotionTarget := bishop;
  end;

  move(moveList[0], moveList[1]);

  promotionTarget := queen;
end;

{ Diese Prozedur registriert einen Zug und updated den internen Status der Instanz, wenn der Zug legal ist }
procedure TBoard.move(fromPos, toPos: TBoardCoord);
var
  movestring: string;
  pawnIsQueening: boolean;
  movingPiece: TPiece;
begin
  if (fromPos = nil) or (toPos = nil) or not legalMove(fromPos, toPos)
  then raise InvalidMoveException.Create('Illegal move played.');

  movingPiece := position[fromPos.r][fromPos.f];

  // Wenn die sich bewegende Figur ein Bauer ist und dieser sich in die (für ihn gesehen) letzte Reihe bewegt, wird dieser Wert True
  pawnIsQueening := (movingPiece.pieceType = pawn) and (((fromPos.r = 7) and (toPos.r = 8) and (movingPiece.color = white)) or ((fromPos.r = 2) and (toPos.r = 1) and (movingPiece.color = black)));

  // Wenn ein Bauer sich in die letzte Reihe bewegt, wird an der Zielposition statt dem Bauern die Zielfigur platziert.
  // Ansonsten wird die Figur einfach von der Start- zur Zielposition kopiert.
  // Das Startfeld des Zuges wird anschließend mit einem leeren Feld überschrieben.
  if pawnIsQueening
  then begin
    position[toPos.r][toPos.f].update(promotionTarget, movingPiece.color);
  end
  else begin
    position[toPos.r][toPos.f].update(movingPiece.pieceType, movingPiece.color);
  end;

  if BoardHelper.IsInBounds(enPTarget)
  then if (movingPiece.pieceType = pawn) and (position[enPTarget.r][enPTarget.f].pieceType = pawn) and (enPTarget.r = fromPos.r) and (enPTarget.f = toPos.f) and not (movingPiece.color = position[enPTarget.r][enPTarget.f].color)
    then position[enPTarget.r][enPTarget.f].update(empty, none);

  // Wenn ein Bauer sich 2 Felder bewegt, wird er zum Ziel für en passent des nächsten Zuges
  if (movingPiece.pieceType = pawn) and (abs(fromPos.r - toPos.r) = 2)
  then enPTarget.setTo(toPos)
  else enPTarget.setTo(TBoardCoord.null);

  // Rochadebedingungen
  if movingPiece.pieceType = king
  then if movingPiece.color = white
    then begin
      cW := false;
      cWL := false;
    end
    else begin
      cB := false;
      cBL := false;
   end;

  if movingPiece.pieceType = rook
  then if (movingPiece.color = white) and (fromPos.f = 1)
    then cWL := false
    else if (movingPiece.color = white) and (fromPos.f = 8)
    then cW := false
    else if (movingPiece.color = black) and (fromPos.f = 1)
    then cBL := false
    else if (movingPiece.color = black) and (fromPos.f = 8)
    then cB := false;
  
  // Rochade
  if (movingPiece.pieceType = king) and (fromPos.f = 5) and (abs(fromPos.f - toPos.f) = 2)
  then begin
    if toPos.f = 3
    then begin
      position[fromPos.r][1].update(empty, none);

      position[fromPos.r][4].update(rook, movingPiece.color);
    end
    else begin
      position[fromPos.r][8].update(empty, none);

      position[fromPos.r][6].update(rook, movingPiece.color);
    end;
  end;

  position[fromPos.r][fromPos.f].update(empty, none);

  movestring := BoardHelper.FileToChar(fromPos.f) + IntToStr(fromPos.r) + BoardHelper.FileToChar(toPos.f) + IntToStr(toPos.r);

  if pawnIsQueening
  then movestring := movestring + 'q';

  moveSeq.setMove(movestring);
end;

{ Überprüft, ob die angegebene CoordList die Koordinate c enthält }
function isInCoordList(c: TBoardCoord; list: TCoordList): boolean;
var
  i: TBoardCoord;
begin
  result := false;

  if length(list) <= 0
  then exit;

  for i in list do
    if (c.f = i.f) and (c.r = i.r)
    then result := true;
end;

function TBoard.legalMove(fromPos, toPos: TBoardCoord): boolean;
var
  i: cardinal;
  possibleMoves: TCoordList;
  piece: TPiece;
begin
  result := true;

  // ist die Koordinate innerhalb des Spielfelds
  if not (
    BoardHelper.IsInBounds(fromPos) and
    BoardHelper.IsInBounds(toPos) and
    not (position[fromPos.r][fromPos.f].pieceType = empty)
  )
  then begin
    result := false;
    exit;
  end;

  piece := position[fromPos.r][fromPos.f];

  //possibleMoves := BoardHelper.FilterPossible(fromPos, position, enPTarget);
  possibleMoves := BoardHelper.PieceMoves(fromPos, piece);

  // ist die Zielkoordinate in der Liste möglicher Züge der Figur enthalten
  if not isInCoordList(toPos, possibleMoves)
  then begin
    result := false;
    exit;
  end;

  if position[toPos.r][toPos.f].color = piece.color
  then begin
    result := false;
    exit;
  end;

  // Ist die Figur ein König und sein nächster Zug eine Rochade
  if (piece.pieceType = king) and (fromPos.f = 5) and (abs(fromPos.f - toPos.f) = 2)
  then begin
    if not
    ((
      (piece.color = white) and
      (fromPos.r = 1) and
      (toPos.r = 1) and
      (
        (
          (toPos.f = 3) and
          cWL and
          (position[1][1].pieceType = rook) and
          (position[1][1].color = white) and
          (position[1][2].pieceType = empty) and
          (position[1][4].pieceType = empty)
        ) or (
          (toPos.f = 7) and
          cW and
          (position[1][8].pieceType = rook) and
          (position[1][8].color = white) and
          (position[1][6].pieceType = empty)
        )
      )
    ) or (
      (piece.color = black) and
      (fromPos.r = 8) and
      (toPos.r = 8) and
      (
        (
          (toPos.f = 3) and
          cBL and
          (position[8][1].pieceType = rook) and
          (position[8][1].color = black) and
          (position[8][2].pieceType = empty) and
          (position[8][4].pieceType = empty)
        ) or (
          (toPos.f = 7) and
          cB and
          (position[8][8].pieceType = rook) and
          (position[8][8].color = black) and
          (position[8][6].pieceType = empty)
        )
      )
    ))
    then begin
      result := false;
      exit;
    end;
  end;
end;

{ Hängt eine gegebene Brettposition an eine Liste aus Positionen an, wenn sie innerhalb des Spielfeldes liegt }
procedure tryAppendCoord(var arr: TCoordList; el: TBoardCoord);
var
  prevLength: smallint;
begin
  if BoardHelper.IsInBounds(el)
  then begin
    prevLength := length(arr);
    setLength(arr, prevLength + 1);
    if (length(arr) > prevLength)
    then arr[prevLength] := el;
  end;
end;

class function BoardHelper.DecodeStrMove(move: string): TCoordList;
begin
  SetLength(result, 0);

  if length(move) < 4
  then exit;

  tryAppendCoord(result, TBoardCoord.Create(Ord(move[1]) - 96, StrToInt(move[2])));
  tryAppendCoord(result, TBoardCoord.Create(Ord(move[3]) - 96, StrToInt(move[4])));
end;

{ Gibt alle möglichen Positionen zurück, die eine Spielfigur im nächsten Zug erreichen könnte }
class function BoardHelper.PieceMoves(position: TBoardCoord; piece: TPiece): TCoordList;
var
  x, y: integer;
begin
  setLength(result, 0);

  with piece do
  begin
    if (not BoardHelper.IsInBounds(position)) or (piece = nil) or (color = none)
    then exit;

    case pieceType of
      empty: exit;

      // König
      king:
      begin
        for y := max(position.r - 1, 1) to min(position.r + 1, 8) do
          for x := max(position.f - 1, 1) to min(position.f + 1, 8) do
            if not ((x = position.f) and (y = position.r))
            then tryAppendCoord(result, TBoardCoord.Create(x, y));
        
        if (color = white) and (position.f = 5) and (position.r = 1)
        then begin
          tryAppendCoord(result, TBoardCoord.Create(3, 1));
          tryAppendCoord(result, TBoardCoord.Create(7, 1));
        end
        else if (color = black) and (position.f = 5) and (position.r = 8)
        then begin
          tryAppendCoord(result, TBoardCoord.Create(3, 8));
          tryAppendCoord(result, TBoardCoord.Create(7, 8));
        end;
      end;

      // Bauer
      pawn:
      begin
        if (color = white) and (position.r < 8)
        then begin
          tryAppendCoord(result, TBoardCoord.Create(position.f, position.r + 1));
          tryAppendCoord(result, TBoardCoord.Create(position.f + 1, position.r + 1));
          tryAppendCoord(result, TBoardCoord.Create(position.f - 1, position.r + 1));

          if position.r = 2
          then tryAppendCoord(result, TBoardCoord.Create(position.f, position.r + 2));
        end
        else if (color = black) and (position.r > 1)
        then begin
          tryAppendCoord(result, TBoardCoord.Create(position.f, position.r - 1));
          tryAppendCoord(result, TBoardCoord.Create(position.f + 1, position.r - 1));
          tryAppendCoord(result, TBoardCoord.Create(position.f - 1, position.r - 1));

          if position.r = 7
          then tryAppendCoord(result, TBoardCoord.Create(position.f, position.r - 2));
        end;
      end;

      // Springer
      knight:
      begin
        tryAppendCoord(result, TBoardCoord.Create(position.f - 2, position.r - 1));
        tryAppendCoord(result, TBoardCoord.Create(position.f - 2, position.r + 1));
        tryAppendCoord(result, TBoardCoord.Create(position.f + 2, position.r - 1));
        tryAppendCoord(result, TBoardCoord.Create(position.f + 2, position.r + 1));
        
        tryAppendCoord(result, TBoardCoord.Create(position.f - 1, position.r - 2));
        tryAppendCoord(result, TBoardCoord.Create(position.f - 1, position.r + 2));
        tryAppendCoord(result, TBoardCoord.Create(position.f + 1, position.r - 2));
        tryAppendCoord(result, TBoardCoord.Create(position.f + 1, position.r + 2));
      end;

      // Läufer
      bishop:
      begin
        for x := 1 to 8 do
        begin
          if x <> position.f
          then begin
            tryAppendCoord(result, TBoardCoord.Create(x, position.r + (position.f - x)));
            tryAppendCoord(result, TBoardCoord.Create(x, position.r - (position.f - x)));
          end;
        end;
      end;

      // Turm
      rook:
      begin
        for x := 1 to 8 do
          if x <> position.f
          then tryAppendCoord(result, TBoardCoord.Create(x, position.r));

        for y := 1 to 8 do
          if y <> position.r
          then tryAppendCoord(result, TBoardCoord.Create(position.f, y));
      end;

      // Dame
      queen:
      begin
        for x := 1 to 8 do
        begin
          if x <> position.f
          then begin
            tryAppendCoord(result, TBoardCoord.Create(x, position.r + (position.f - x)));
            tryAppendCoord(result, TBoardCoord.Create(x, position.r - (position.f - x)));
          end;
        end;

        for x := 1 to 8 do
          if x <> position.f
          then tryAppendCoord(result, TBoardCoord.Create(x, position.r));

        for y := 1 to 8 do
          if y <> position.r
          then tryAppendCoord(result, TBoardCoord.Create(position.f, y));
      end;
    end;

  end;
end;

class function BoardHelper.FilterPossible(from: TBoardCoord; board: TPieceMap; enPTarget: TBoardCoord): TCoordList;
var
  moves: TCoordList;
  temp: TBoardCoord;
  i: cardinal;

begin
  moves := BoardHelper.PieceMoves(from, board[from.r][from.f]);

  // Wenn die Figur keine Züge hat, die überprüft werden könnten oder es ein Springer ist, dann gib das Array der PieceMoves-Funktion zurück
  if (length(moves) <= 0) or (board[from.r][from.f].pieceType = knight) or (board[from.r][from.f].pieceType = empty) or (board[from.r][from.f].color = none)
  then begin
    result := moves;
    exit
  end
  // Wenn die Figur ein Bauer ist, gelten spezielle Bedingungen
  else if board[from.r][from.f].pieceType = pawn
  then begin
    for i := 0 to high(moves) do
    begin
      if board[moves[i].r][moves[i].f].pieceType = empty
      then
        if moves[i].f = from.f
        then tryAppendCoord(result, moves[i])
        else if IsInBounds(enPTarget) and (enPTarget.r = from.r) and (enPTarget.f = moves[i].f)
        then tryAppendCoord(result, moves[i])
        else begin end
      else
        if moves[i].f <> from.f
        then tryAppendCoord(result, moves[i]);
    end;
  end
  else if (board[from.r][from.f].pieceType = bishop) or
    (board[from.r][from.f].pieceType = rook) or
    (board[from.r][from.f].pieceType = queen)
  then for temp in moves do
  begin
    if isInLineOfSight(from, temp, board)
    then tryAppendCoord(result, temp);
  end
  else if (board[from.r][from.f].pieceType = king)
  then result := moves;
end;

class function BoardHelper.LineOfSight(fromPos, toPos: TBoardCoord; board: TPieceMap): TCoordList;
var
  f, r: integer;
  hasEncountered: boolean;
begin
  SetLength(result, 0);

  hasEncountered := false;

  if (abs(fromPos.f - toPos.f) = abs(fromPos.r - toPos.r))
  then for r := fromPos.r to toPos.r do
      for f := fromPos.f to toPos.f do
        if (abs(fromPos.f - f) = abs(fromPos.r - r))
        then begin
          if not hasEncountered and (board[r][f].pieceType = empty)
          then tryAppendCoord(result, TBoardCoord.Create(f, r))
          else if not hasEncountered and (board[r][f].color <> board[fromPos.r][fromPos.f].color)
          then begin
            tryAppendCoord(result, TBoardCoord.Create(f, r));
            hasEncountered := true;
          end
          else hasEncountered := true;
        end
        else begin end
  else if fromPos.f - toPos.f = 0
  then
    for r := fromPos.r to toPos.r do
    begin
      if not hasEncountered and (board[r][fromPos.f].pieceType = empty)
      then tryAppendCoord(result, TBoardCoord.Create(fromPos.f, r))
      else if not hasEncountered and (board[r][fromPos.f].color <> board[fromPos.r][fromPos.f].color)
      then begin
        tryAppendCoord(result, TBoardCoord.Create(fromPos.f, r));
        hasEncountered := true;
      end
      else hasEncountered := true;
    end
  else if fromPos.r - toPos.r = 0
  then for f := fromPos.f to toPos.f do
    begin
      if not hasEncountered and (board[fromPos.r][f].pieceType = empty)
      then tryAppendCoord(result, TBoardCoord.Create(f, fromPos.r))
      else if not hasEncountered and (board[fromPos.r][f].color <> board[fromPos.r][fromPos.f].color)
      then begin
        tryAppendCoord(result, TBoardCoord.Create(f, fromPos.r));
        hasEncountered := true;
      end
      else hasEncountered := true;
    end
  else exit;
end;

class function BoardHelper.IsInLineOfSight(fromPos, toPos: TBoardCoord; board: TPieceMap): boolean;
var
  f, r: integer;
  hasEncountered: boolean;
begin
  result := true;

  hasEncountered := false;

  if ((fromPos.f - toPos.f) = (fromPos.r - toPos.r))
  then
    for f := fromPos.f to toPos.f do
      begin
        r := f - fromPos.f + (fromPos.r * ((toPos.f - toPos.r) div abs(toPos.f - toPos.r)));

        if not ((fromPos.f = f) and (fromPos.r = r)) and IsInBounds(TBoardCoord.Create(f, r))
        then begin
          if hasEncountered
          then begin
            result := false;
            exit;
          end
          else if not hasEncountered
              and not (board[r][f].color = board[fromPos.r][fromPos.f].color)
              and not (board[r][f].pieceType = empty)
          then begin
            hasEncountered := true;
          end
          else if board[r][f].color = board[fromPos.r][fromPos.f].color
          then begin
            hasEncountered := true;
            result := false;
            exit;
          end;
        end
      end
  else if fromPos.f - toPos.f = 0
  then
    for r := fromPos.r to toPos.r do
    begin
      if hasEncountered
      then result := false
      else if not hasEncountered
        and not (board[r][fromPos.f].color = board[fromPos.r][fromPos.f].color)
        and not (board[r][fromPos.f].pieceType = empty)
      then begin
        hasEncountered := true;
      end
      else if board[r][fromPos.f].color = board[fromPos.r][fromPos.f].color
      then begin
        hasEncountered := true;
        result := false;
      end;
    end
  else if fromPos.r - toPos.r = 0
  then
    for f := fromPos.f to toPos.f do
    begin
      if hasEncountered
      then result := false
      else if not hasEncountered
        and not (board[fromPos.r][f].color = board[fromPos.r][fromPos.f].color)
        and not (board[fromPos.r][f].pieceType = empty)
      then begin
        hasEncountered := true;
      end
      else if board[fromPos.r][f].color = board[fromPos.r][fromPos.f].color
      then begin
        hasEncountered := true;
        result := false;
      end;
    end
  else begin
    result := false;
    exit;
  end;
end;


end.
