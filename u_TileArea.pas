unit u_TileArea;

interface

uses
  Windows,
  Types,
  SysUtils,
  i_ZoomList,
  u_ZoomList;

type
  TTileAreaInfo = packed record
    Rect: TRect;
    Zoom: Byte;
    Flag: Byte; // для проверки что все поля залетели (битовая маска)
  end;

  ITileArea = interface(IZoomList)
    ['{F0247423-8584-4DA1-AD52-A2CC11442AC7}']
    function TileInArea(
      const AZoom: Byte;
      const AXYPtr: PPoint
    ): Boolean;
  end;

  TTileArea = class(TZoomList, ITileArea)
  private
    // исходная информация о тайловой прямоугольной области
    FTileAreaInfo: TTileAreaInfo;
    // диапазоны для зумов больше исходного
    FGreaterZooms: array of TRect;
    // и меньше исходного
    FSmallerZooms: array of TRect;
  private
    procedure CalcGreaterZoom(AZoom: Byte; const ARect: PRect);
    procedure CalcSmallerZoom(AZoom: Byte; const ARect: PRect);
    function ParseTileAreaItem(const ATileAreaItemSrc: String): Boolean;
    function CheckTileInRect(
      const AXYPtr: PPoint;
      const ARect: PRect
    ): Boolean;
  protected
    procedure EnableZoomInZoomBits(const AZoom: Byte); override;
  private
    { ITileArea }
    function TileInArea(
      const AZoom: Byte;
      const AXYPtr: PPoint
    ): Boolean;
  public
    constructor Create(const ATileAreaSrc, AZoomAreaSrc: String);
  end;

implementation

{ TTileArea }

procedure TTileArea.CalcGreaterZoom(AZoom: Byte; const ARect: PRect);
begin
  ARect^ := FTileAreaInfo.Rect;
  while (AZoom > FTileAreaInfo.Zoom) do begin
    with ARect^ do begin
      Left   := Left   * 2;
      Top    := Top    * 2;
      Right  := Right  * 2;
      Bottom := Bottom * 2;
    end;
    Dec(AZoom);
  end;
end;

procedure TTileArea.CalcSmallerZoom(AZoom: Byte; const ARect: PRect);
begin
  // z12\x1353\y591\x1361\y593
  // z11\x676\y295\x681\y297
  // z10\x338\y147\x341\y149
  // z9\x169\y73\x171\y75
  // z8\x84\y36\x86\y38
  // z7\x42\y18\x43\y19
  // z6\x21\y9\x22\y10
  // z5\x10\y4\x11\y5
  // z4\x5\y2\x6\y3
  // z3\x2\y1\x3\y2
  // z2\x1\y0\x2\y1
  // z1\x0\y0\x1\y1

  // xymin = xymin div 2
  // xymax = (xymax-1) div 2 + 1

  ARect^ := FTileAreaInfo.Rect;
  while (AZoom < FTileAreaInfo.Zoom) do begin
    with ARect^ do begin
      Left   := (Left div 2);
      Top    := (Top  div 2);
      Right  := (Right-1) div 2 + 1;
      Bottom := (Bottom-1) div 2 + 1;
    end;
    Inc(AZoom);
  end;
end;

function TTileArea.CheckTileInRect(
  const AXYPtr: PPoint;
  const ARect: PRect
): Boolean;
begin
  with AXYPtr^, ARect^ do begin
    Result := (X >= Left) and (X < Right) and (Y >= Top) and (Y < Bottom);
  end;
end;

constructor TTileArea.Create(const ATileAreaSrc, AZoomAreaSrc: String);
var
  VTileAreaOK: Boolean;
begin
  FGreaterZooms := nil;
  FSmallerZooms := nil;
  
  FillChar(FTileAreaInfo, SizeOf(FTileAreaInfo), 0);
  VTileAreaOK := ForeachStringPart(ATileAreaSrc, TRUE, ParseTileAreaItem);
  if (not VTileAreaOK) or (FTileAreaInfo.Flag <> 31) then begin
    // обломились
    FillChar(FTileAreaInfo, SizeOf(FTileAreaInfo), 0);
  end;
    
  inherited Create(AZoomAreaSrc);

  FAvailable := FAvailable and VTileAreaOK;
end;

procedure TTileArea.EnableZoomInZoomBits(const AZoom: Byte);
begin
  inherited;

  // если исходный зум равен нулю - ничего не делаем
  // это означает что исходный зум и область не определены
  if (0=FTileAreaInfo.Zoom) or (AZoom=FTileAreaInfo.Zoom) then
    Exit;
    
  // при включении зума надо рассчитать для него диапазон
  
  // бОльшие зумы
  if (AZoom > FTileAreaInfo.Zoom) then begin
    // если AZoom = Zoom+X+1 - то индекс зума в массиве равен X = AZoom - Zoom - 1, а длина массива AZoom - Zoom
    if Length(FGreaterZooms) < (AZoom - FTileAreaInfo.Zoom) then
      SetLength(FGreaterZooms, (AZoom - FTileAreaInfo.Zoom));
    CalcGreaterZoom(AZoom, @(FGreaterZooms[AZoom - FTileAreaInfo.Zoom - 1]));
  end else begin
    // меньшие зумы
    // если AZoom = Zoom-X-1 - то индекс зума в массиве равен X = Zoom - AZoom - 1, а длина массива Zoom - AZoom
    if Length(FSmallerZooms) < (FTileAreaInfo.Zoom - AZoom) then
      SetLength(FSmallerZooms, (FTileAreaInfo.Zoom - AZoom));
    CalcSmallerZoom(AZoom, @(FGreaterZooms[FTileAreaInfo.Zoom - AZoom - 1]));
  end;
end;

function TTileArea.ParseTileAreaItem(const ATileAreaItemSrc: String): Boolean;
var
  VIntPtr: PLongInt;
  VValue: Integer;
  VFlag: Byte;
begin
  // здесь на вход прилетает любой кусочек из строк типа
  // Z8,L84,T36,R85,B37
  Result := (0<Length(ATileAreaItemSrc));
  if Result then begin
    Result := TryStrToInt(System.Copy(ATileAreaItemSrc, 2, Length(ATileAreaItemSrc)), VValue);
    if Result then begin
      // смотрим первый символ
      VIntPtr := nil;
      VFlag := 0;
      case ATileAreaItemSrc[1] of
        'z','Z': begin
          // zoom
          Result := IsSupportedZoom(VValue);
          if Result then begin
            FTileAreaInfo.Zoom := LoByte(VValue);
            FTileAreaInfo.Flag := FTileAreaInfo.Flag or 16;
            Exit;
          end;
        end;
        'l','L': begin
          VIntPtr := @(FTileAreaInfo.Rect.Left);
          VFlag := 1;
        end;
        't','T': begin
          VIntPtr := @(FTileAreaInfo.Rect.Top);
          VFlag := 2;
        end;
        'r','R': begin
          VIntPtr := @(FTileAreaInfo.Rect.Right);
          VFlag := 4;
        end;
        'b','B': begin
          VIntPtr := @(FTileAreaInfo.Rect.Bottom);
          VFlag := 8;
        end;
        else begin
          Result := FALSE;
          Exit;
        end;
      end;

      if (VIntPtr <> nil) then begin
        VIntPtr^ := VValue;
        FTileAreaInfo.Flag := FTileAreaInfo.Flag or VFlag;
        Result := TRUE;
      end;
    end;
  end;
end;

function TTileArea.TileInArea(
  const AZoom: Byte;
  const AXYPtr: PPoint
): Boolean;
begin
  Result := ZoomInList(AZoom);
  if (not Result) then
    Exit;
  
  if (AZoom = FTileAreaInfo.Zoom) then begin
    // исходный зум
    Result := CheckTileInRect(AXYPtr, @(FTileAreaInfo.Rect));
  end else if (AZoom > FTileAreaInfo.Zoom) then begin
    // бОльшие зумы
    Result := CheckTileInRect(AXYPtr, @(FGreaterZooms[AZoom - FTileAreaInfo.Zoom - 1]));
  end else begin
    // меньшие зумы
    Result := CheckTileInRect(AXYPtr, @(FSmallerZooms[FTileAreaInfo.Zoom - AZoom - 1]));
  end;
end;

end.