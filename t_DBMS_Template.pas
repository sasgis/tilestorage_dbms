unit t_DBMS_Template;

interface

uses
  Types,
  SysUtils;

const
  c_Template_Tablename = 't_all_sql';

  c_Template_CreateTable_Prefix = 'create table';

  c_Templated_Versions    = 'v_%SERVICE%';
  c_Templated_CommonTiles = 'u_%SERVICE%';
  c_Templated_RealTiles   = '%DIV%%ZOOM%%HEAD%_%SERVICE%';

  c_VersionDateTileToDBFormat = 'yyyymmdd hh:nn:ss.zzz';
  c_UTCLoadDateTimeToDBFormat = 'yyyymmdd hh:nn:ss.zzz';

type
  TSQLParts = record
    RequestedVersionFound: Boolean;
    SelectSQL, FromSQL, WhereSQL, OrderBySQL: WideString;
  end;
  PSQLParts = ^TSQLParts;

  TSQLTile = record
    Zoom: Byte;
    XYMaskWidth: Byte;
    TileTableName: WideString;
    XYUpperToTable: TPoint;
    XYLowerToID: TPoint;
  public
    // convert zoom value to single char (to use in tablename)
    function ZoomToTableNameChar: Char;
    // get upper part of XY (for tablename)
    function GetXYUpperInfix: String;
  end;
  PSQLTile = ^TSQLTile;


(*

create table v_%SERVICE% (
   id_ver               smallint                       not null,
   ver_value            varchar(50)                    not null,
   ver_date             datetime                       not null,
   ver_number           int                            default 0 not null,
   ver_comment          varchar(255)                   null,
   constraint PK_V_%SERVICE% primary key (id_ver)
)

create table %DIV%%ZOOM%%HEAD%_%SERVICE% (
   x                    numeric                        not null,
   y                    numeric                        not null,
   id_ver               smallint                       not null,
   tile_size            int                            default 0 not null,
   id_contenttype       smallint                       not null,
   load_date            datetime                       default getdate() not null,
   tile_body            image                          null,
   constraint PK_%DIV%%ZOOM%%HEAD%_%SERVICE% primary key (x, y, id_ver)
)

create table u_%SERVICE% (
   id_common_tile       smallint                       not null,
   id_common_type       smallint                       not null,
   common_size          int                            not null,
   common_body          image                          null,
   constraint PK_U_%SERVICE% primary key (id_common_tile)
)

create table t_service (
   id_service           smallint                       not null,
   service_code         varchar(20)                    not null,
   service_name         varchar(50)                    not null,
   id_contenttype       smallint                       not null,
   id_ver_comp          char(1)                        default '0' not null,
   id_div_mode          char(1)                        default 'F' not null,
   work_mode            char(1)                        default '0' not null
         constraint CKC_WORK_MODE_T_SERVICE check (work_mode in ('0','S','R')),
   use_common_tiles     char(1)                        default '0' not null,
   constraint PK_T_SERVICE primary key (id_service)
)

*)
  
implementation

{ TSQLTile }

function TSQLTile.GetXYUpperInfix: String;
var
  VExceed: Byte;
  VUpperL: LongInt;
begin
  // if single table
  if (0=XYMaskWidth) or (Zoom <= (XYMaskWidth+1)) then begin
    // single table - use 0
    Result + '0';
    Exit;
  end;

  VExceed := (Zoom - (XYMaskWidth+1));

  // count of tables = 4^VExceed
  // both X and Y are from 0 to 2^VExceed-1
  VUpperL := XYUpperToTable.X;
  VUpperL := VUpperL shl VExceed;
  VUpperL := VUpperL + XYUpperToTable.Y;

  // to string
  Result := IntToHex(VUpperL, 8);
  while (Length(Result)>1) and (Result[1]='0') do begin
    System.Delete(Result, 1, 1);
  end;
end;

function TSQLTile.ZoomToTableNameChar: Char;
begin
  if (Zoom=0) then begin
    Result := '0';
  end else if (Zoom<10) then begin
    // 1='1'
    // 9='9'
    Result := Chr(Ord('1')+Zoom-1);
  end else begin
    // 10='A'
    // 16='G'
    // 18='I'
    // 24='O'
    // 32='W'
    Result := Chr(Ord('A')+Zoom-10);
  end;
end;

end.
