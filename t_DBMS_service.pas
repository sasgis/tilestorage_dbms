unit t_DBMS_service;

{$include i_DBMS.inc}

interface

type
  TDBMS_Service_Info = packed record
    id_service: SmallInt;
    id_contenttype: SmallInt; // default contenttype
    id_ver_comp: AnsiChar; // Z_VER_COMP identifier ('0' by default)
    id_div_mode: AnsiChar; // Z_DIV_MODE identifier
    work_mode: AnsiChar; // in ['0','S','R'] ('0' by default)
    use_common_tiles: AnsiChar; // boolean ('0' by default)
  public
    function XYMaskWidth: Byte; inline;
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
