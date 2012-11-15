unit t_DBMS_Template;

interface

uses
  Types,
  SysUtils;

const
  // подпапка для скриптов и настроек
  c_SQL_SubFolder = 'DBMS\';
  // расширения для файлов скриптов (базовое и для шаблонов)
  c_SQL_Ext_Base = '.sql';
  c_SQL_Ext_Tmpl = '.xql';
  // расширение для файла результата
  c_SQL_Ext_Out  = '.out';

  // таблица с шаблонами запросов
  c_Template_Tablename = 't_all_sql';

  // префикс для разбора скрипта и выполнения потаблично
  c_Template_CreateTable_Prefix = 'create table';

  // шаблон имени для таблицы с версиями для сервиса %SERVICE%
  c_Templated_Versions    = 'v_%SERVICE%';
  // шаблон имени для таблицы с часто используемыми тайлами для сервиса %SERVICE%
  c_Templated_CommonTiles = 'u_%SERVICE%';
  // шаблон имени для таблицы с тайлами для сервиса %SERVICE%
  // %DIV%  - способ деления тайлов на таблицы (кодируется одной буквой)
  // %ZOOM% - зум (от 1 до 24 - кодируется одной буквой)
  // %HEAD% - "верхняя" часть идентификатора тайла, "ушедшая" в имя таблицы
  c_Templated_RealTiles   = '%DIV%%ZOOM%%HEAD%_%SERVICE%';

  // формат для вставки даты версии в БД
  c_VersionDateTileToDBFormat = 'yyyymmdd hh:nn:ss.zzz';
  // формат для вставки даты тайла в БД
  c_UTCLoadDateTimeToDBFormat = 'yyyymmdd hh:nn:ss.zzz';

type
  TSQLParts = record
    RequestedVersionFound: Boolean;
    SelectSQL, FromSQL, WhereSQL, OrderBySQL: WideString;
  end;
  PSQLParts = ^TSQLParts;

  TSQLTile = record
    // зум (от 1 до 24)
    Zoom: Byte;
    // значение маски зума, если меньше - нет деления на таблицы по зумам
    XYMaskWidth: Byte;
    TileTableName: WideString;
    // "верхняя" часть идентификатора тайла - в имя таблицы
    XYUpperToTable: TPoint;
    // "нижняя" часть идентификатора тайла - в идентификатор (в поле таблицы)
    XYLowerToID: TPoint;
  public
    // convert zoom value to single char (to use in tablename)
    function ZoomToTableNameChar: Char;
    // get upper part of XY (for tablename)
    function GetXYUpperInfix: String;
  end;
  PSQLTile = ^TSQLTile;


(*

create table t_all_sql (
   object_name          sysname                        not null,
   object_operation     char(1)                        not null
         constraint CKC_OBJECT_OPERATION_T_ALL_SQ check (object_operation in ('C','S','I','U','D')),
   index_sql            smallint                       not null,
   skip_sql             char(1)                        default '0' not null,
   ignore_errors        char(1)                        default '1' not null,
   object_sql           text                           null,
   constraint PK_T_ALL_SQL primary key (object_name, object_operation, index_sql)
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

// table with versions
create table v_%SERVICE% (
   id_ver               smallint                       not null,
   ver_value            varchar(50)                    not null,
   ver_date             datetime                       not null,
   ver_number           int                            default 0 not null,
   ver_comment          varchar(255)                   null,
   constraint PK_V_%SERVICE% primary key (id_ver)
)

// table with real tiles
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

// table with common tiles
create table u_%SERVICE% (
   id_common_tile       smallint                       not null,
   id_common_type       smallint                       not null,
   common_size          int                            not null,
   common_body          image                          null,
   constraint PK_U_%SERVICE% primary key (id_common_tile)
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
