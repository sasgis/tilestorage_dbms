unit t_DBMS_Template;

interface

uses
  Types,
  SysUtils;

const
  // подпапка дл€ скриптов и настроек
  c_SQL_SubFolder = 'DBMS\';
  // расширени€ дл€ файлов скриптов (базовое и дл€ шаблонов)
  c_SQL_Ext_Base = '.sql';
  c_SQL_Ext_Tmpl = '.xql';
  // расширение дл€ файла результата
  c_SQL_Ext_Out  = '.out';

  // таблица с шаблонами запросов
  c_Tablename_With_Templates = 't_all_sql';

  // префикс дл€ разбора скрипта и выполнени€ потаблично
  c_Template_CreateTable_Prefix = 'create table';

  // шаблон имени дл€ таблицы с верси€ми дл€ сервиса %SERVICE%
  c_Templated_Versions    = 'v_%SERVICE%';
  // шаблон имени дл€ таблицы с часто используемыми тайлами дл€ сервиса %SERVICE%
  c_Templated_CommonTiles = 'u_%SERVICE%';
  // шаблон имени дл€ таблицы с тайлами дл€ сервиса %SERVICE%
  // %DIV%  - способ делени€ тайлов на таблицы (кодируетс€ одной буквой)
  // %ZOOM% - зум (от 1 до 24 - кодируетс€ одной буквой)
  // %HEAD% - "верхн€€" часть идентификатора тайла, "ушедша€" в им€ таблицы
  c_Templated_RealTiles   = '%DIV%%ZOOM%%HEAD%_%SERVICE%';

  c_Date_Separator = '-';
  c_Time_Separator = ':';

  // формат дл€ вставки даты-времени в Ѕƒ
  c_DateTimeToDBFormat = 'YYYY' + c_Date_Separator + 'MM' + c_Date_Separator + 'DD HH' + c_Time_Separator + 'NN' + c_Time_Separator + 'SS';

type
  TSQLParts = record
    RequestedVersionFound: Boolean;
    SelectSQL, FromSQL, WhereSQL, OrderBySQL: WideString;
  end;
  PSQLParts = ^TSQLParts;

  TSQLTile = record
    // зум (от 1 до 24)
    Zoom: Byte;
    // значение маски зума, если меньше - нет делени€ на таблицы по зумам
    XYMaskWidth: Byte;
    // им€ таблицы дл€ тайлов - здесь без возможного префикса схемы
    TileTableName: WideString;
    // "верхн€€" часть идентификатора тайла - в им€ таблицы
    XYUpperToTable: TPoint;
    // "нижн€€" часть идентификатора тайла - в идентификатор (в поле таблицы)
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
