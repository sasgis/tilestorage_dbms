unit t_DBMS_service;

{$include i_DBMS.inc}

interface

uses
  Types;

type
  PDBMS_Service_Info = ^TDBMS_Service_Info;
  TDBMS_Service_Info = packed record
    id_service: SmallInt;
    id_contenttype: SmallInt; // default contenttype
    id_ver_comp: Char; // Z_VER_COMP identifier ('0' by default)
    id_div_mode: Char; // Z_DIV_MODE identifier
    work_mode: Char; // in ['0','S','R'] ('0' by default)
    use_common_tiles: Char; // boolean ('0' by default)
    // поля, появившиеся во второй версии модели
    // у всех значение по умолчанию в БД равно 0
    tile_load_mode: SmallInt;    // ETS_TLM_*
    tile_save_mode: SmallInt;    // ETS_TSM_*
    tile_hash_mode: SmallInt;    // ETS_THM_*
    new_ver_by_tile: SmallInt;   // ETS_VTM_*
  public
    function XYMaskWidth: Byte; //inline;
    function CalcBackToTilePos(
      XInTable, YInTable: Integer;
      const AXYUpperToTable: TPoint;
      AXYResult: PPoint
    ): Boolean;
  end;

  (*
  TDBMS_Service = record
    service_code: AnsiString; // use in DB only
    service_name: AnsiString; // use in host only
    service_info: TDBMS_Service_Info;
  end;
  PDBMS_Service = ^TDBMS_Service;
  *)

  (*
  TDBMS_Global_Info = packed record
    max_sysname_len: SmallInt;
    max_service_code_len: SmallInt;
    max_service_name_len: SmallInt;
    max_version_len: SmallInt;
    max_contenttype_len: SmallInt;
  end;
  *)

function UseSingleTable(const AXYMaskWidth, AZoom: Byte): Boolean; inline;

implementation

uses
  t_ETS_Tiles;

function UseSingleTable(const AXYMaskWidth, AZoom: Byte): Boolean; inline;
begin
  Result := (0=AXYMaskWidth) or (AZoom <= (AXYMaskWidth+1));
end;

{ TDBMS_Service_Info }

function TDBMS_Service_Info.CalcBackToTilePos(
  XInTable, YInTable: Integer;
  const AXYUpperToTable: TPoint;
  AXYResult: PPoint
): Boolean;
var
  VXYMaskWidth: Byte;
begin
  // рассчитываем обратным расчётом тайловые координаты
  // исходя из параметров деления по таблицам и координат (идентификатора) внутри таблицы
  VXYMaskWidth := XYMaskWidth;

  // общая часть
  AXYResult^.X := XInTable;
  AXYResult^.Y := YInTable;

  // если делились по таблицам - добавим "верхнюю" часть
  if (0<VXYMaskWidth) then begin
    AXYResult^.X := AXYResult^.X or (AXYUpperToTable.X shl VXYMaskWidth);
    AXYResult^.Y := AXYResult^.Y or (AXYUpperToTable.Y shl VXYMaskWidth);
  end;

  Result := TRUE;
end;

function TDBMS_Service_Info.XYMaskWidth: Byte;
begin
  // определяем маску зума
  case id_div_mode of
    TILE_DIV_1024..TILE_DIV_32768: begin
      // делимся по таблицам
      Result := 10 + Ord(id_div_mode) - Ord(TILE_DIV_1024);
    end;
    else {TILE_DIV_NONE} begin
      // не делимся по таблицам
      Result := 0;
    end;
  end;
end;

end.
