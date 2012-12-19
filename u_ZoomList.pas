unit u_ZoomList;

interface

uses
  Windows,
  SysUtils;

const
  c_Max_Supported_Zoom = 24; // зумы с 1 по этот включительно

type
  TZoomBits = LongWord;

  TForeachStringPartFunc = function(const AZoomListSrc: String): Boolean of object;

  IZoomList = interface
    ['{64025C2A-34E4-42D2-AA80-EAF6D28FD5E2}']
    function Available: Boolean;
    function ZoomInList(const AZoom: Byte): Boolean;
  end;

  TZoomList = class(TInterfacedObject, IZoomList)
  protected
    FAvailable: Boolean;
    FZoomBits: TZoomBits;
  protected
    procedure EnableZoomInZoomBits(const AZoom: Byte); virtual;
    class function ForeachStringPart(
      const ASource: String;
      const ATrueOnAllParts: Boolean;
      const APartFunc: TForeachStringPartFunc
    ): Boolean;
  private
    function ZoomListToZoomBitsSub(const AZoomListSrc: String): Boolean;
  protected
    { IZoomList }
    function Available: Boolean;
    function ZoomInList(const AZoom: Byte): Boolean;
  public
    constructor Create(const AZoomListSrc: String);
  end;

function IsSupportedZoom(const AIntZoom: Integer): Boolean; inline;
  
implementation

uses
  StrUtils;

function IsSupportedZoom(const AIntZoom: Integer): Boolean; inline;
begin
  Result := ((AIntZoom > 0) and (AIntZoom <= c_Max_Supported_Zoom))
end;

{ TZoomList }

function TZoomList.Available: Boolean;
begin
  Result := FAvailable;
end;

constructor TZoomList.Create(const AZoomListSrc: String);
begin
  inherited Create;
  FZoomBits := 0;
  FAvailable := ForeachStringPart(AZoomListSrc, FALSE, ZoomListToZoomBitsSub);
end;

procedure TZoomList.EnableZoomInZoomBits(const AZoom: Byte);
var
  VWorkBit: TZoomBits;
begin
  VWorkBit := 1;
  VWorkBit := VWorkBit shl (AZoom-1);
  FZoomBits := (FZoomBits or VWorkBit);
end;

class function TZoomList.ForeachStringPart(
  const ASource: String;
  const ATrueOnAllParts: Boolean;
  const APartFunc: TForeachStringPartFunc
): Boolean;
var
  VStart, VNext: Integer;
  VResult: Boolean;
begin
  // разбираем строку типа 1-12,14-16,18,19
  // ищем куски между запятыми и запускаем повторный разбор
  Result := (0<Length(ASource));
  if (not Result) then
    Exit;
  
  VStart := 1;
  repeat
    VNext := PosEx(',', ASource, VStart);
    if (VNext>0) then begin
      // есть кусок до запятой
      VResult := APartFunc(System.Copy(ASource, VStart, VNext-VStart));
    end else begin
      // (больше) нет запятой
      VResult := APartFunc(System.Copy(ASource, VStart, Length(ASource)));
    end;

    // общий результат (если первая итерация - присваиваем результат, иначе стыкуем логически)
    if ATrueOnAllParts then begin
      // должны все вернуть TRUE
      if (1=VStart) then
        Result := VResult
      else
        Result := Result and VResult;
      if (not Result) then
        Exit;
    end else begin
      // хоть один должен вернуть TRUE
      if (1=VStart) then
        Result := VResult
      else
        Result := Result or VResult;
    end;

    // выход
    if (VNext=0) then
      Exit;

    // идём за следующим
    VStart := VNext + 1;
  until FALSE;
end;

function TZoomList.ZoomInList(const AZoom: Byte): Boolean;
var
  VWorkBit: TZoomBits;
begin
  // AZoom from 1 to 32
  // make 0...010...000 value and check ZoomBits
  VWorkBit := 1;
  VWorkBit := VWorkBit shl (AZoom-1);
  Result := ((VWorkBit and FZoomBits) <> 0);
end;

function TZoomList.ZoomListToZoomBitsSub(const AZoomListSrc: String): Boolean;
var
  VPos, VMin, VMax: Integer;
  VZoom: Byte;
begin
  // тут на входе кусок между запятыми типа 18 или 1-12
  VPos := System.Pos('-', AZoomListSrc);
  if (VPos>0) then begin
    // есть дефис
    Result := TryStrToInt(System.Copy(AZoomListSrc, 1, (VPos-1)), VMin) and
              TryStrToInt(System.Copy(AZoomListSrc, (VPos+1), Length(AZoomListSrc)), VMax);
    if Result then begin
      Result := IsSupportedZoom(VMin) and IsSupportedZoom(VMax) and (VMin<=VMax);
      if Result then begin
        for VZoom := LoByte(VMin) to LoByte(VMax) do
          EnableZoomInZoomBits(VZoom);
      end;
    end;
  end else begin
    // нет дефиса - пробуем весь текст как число
    Result := TryStrToInt(AZoomListSrc, VPos);
    if Result then begin
      Result := IsSupportedZoom(VPos);
      if Result then begin
        // включаем бит
        EnableZoomInZoomBits(LoByte(VPos));
      end;
    end;
  end;
end;

end.
