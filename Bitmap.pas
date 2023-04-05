unit Bitmap;

interface

uses
  Classes, Graphics;

type
  TBitmapUtil = class
    class function ImportPiece(location: string): TBitmap; static;
    class function ShrinkBitmap(Bitmap: TBitmap; NewSize: integer): TBitmap; static;
  end;

implementation

class function TBitmapUtil.ImportPiece(location: string): TBitmap;
begin
  result := TBitmap.Create;
  result.Transparent := true;
  result.LoadFromFile(location);
end;

class function TBitmapUtil.ShrinkBitmap(Bitmap: TBitmap; NewSize: integer): TBitmap;
begin
  Result := TBitmap.Create;
  Result.Width := NewSize;
  Result.Height := NewSize;
  Result.Transparent := true;
  Result.Canvas.StretchDraw(
    Rect(0, 0, NewSize, NewSize),
    Bitmap);
end;

end.