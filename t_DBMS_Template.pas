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

  // базовые таблицы

  Z_ALL_SQL     = 'Z_ALL_SQL';
  Z_OPTIONS     = 'Z_OPTIONS';
  Z_CONTENTTYPE = 'Z_CONTENTTYPE';
  Z_DIV_MODE    = 'Z_DIV_MODE';
  Z_VER_COMP    = 'Z_VER_COMP';
  Z_SERVICE     = 'Z_SERVICE';

  // префикс для разбора скрипта и выполнения потаблично
  c_Template_CreateTable_Prefix = 'create table';

  // базовые шаблоны

  // шаблон для имени сервиса
  c_Templated_SVC  = '%SVC%';
  // шаблон для зума (от 1 до 24 - кодируется одной буквой)
  c_Templated_Z    = '%Z%';
  // шаблон для способ деления тайлов на таблицы (кодируется одной буквой вне диапазона 16-ричных символов)
  c_Templated_DIV  = '%DIV%';
  // шаблоны для "верхних" частей идентификатора тайла X и Y, "попадающих" в имя таблицы (16-ричный формат)
  c_Templated_HX   = '%HX%';
  c_Templated_HY   = '%HY%';

  // производные шаблоны (см. скрипты *.xql)

  // шаблон имени для таблицы с версиями для сервиса (например, X_gsat)
  c_Prefix_Versions = 'X_';
  c_Templated_Versions    = c_Prefix_Versions + c_Templated_SVC;

  // шаблон имени для таблицы с часто используемыми тайлами для сервиса (например, Y_yasat)
  c_Prefix_CommonTiles = 'Y_';
  c_Templated_CommonTiles = c_Prefix_CommonTiles + c_Templated_SVC;

  // шаблон имени для таблицы с тайлами для сервиса (например, AZ_nmc_recency)
  c_Templated_RealTiles   = c_Templated_Z + c_Templated_HX + c_Templated_DIV + c_Templated_HY + '_' + c_Templated_SVC;


  c_Date_Separator = '-';
  c_Time_Separator = ':';

  // формат для вставки даты-времени в БД
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
    // значение маски зума, если меньше - нет деления на таблицы по зумам
    XYMaskWidth: Byte;
    // имя таблицы для тайлов - здесь без возможного префикса схемы
    TileTableName: WideString;
    // "верхняя" часть идентификатора тайла - в имя таблицы
    XYUpperToTable: TPoint;
    // "нижняя" часть идентификатора тайла - в идентификатор (в поле таблицы)
    XYLowerToID: TPoint;
  public
    // convert zoom value to single char (to use in tablename)
    function ZoomToTableNameChar: Char;
    // get upper part of X and Y (for tablename)
    function HXToTableNameChar: String;
    function HYToTableNameChar: String;
    // deprecated version (for both XY)
    function GetXYUpperInfix: String; deprecated;
  end;
  PSQLTile = ^TSQLTile;

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

function TSQLTile.HXToTableNameChar: String;
begin
  // если одна таблица - значит не делимся - вернём пустую строку
  if (0=XYMaskWidth) or (Zoom <= (XYMaskWidth+1)) then begin
    Result:='';
    Exit;
  end;

  // конвертируемся
  Result := IntToHex(XYUpperToTable.X, 8);
  
  // оставляем хотя бы один символ
  while (Length(Result)>1) and (Result[1]='0') do begin
    System.Delete(Result, 1, 1);
  end;
end;

function TSQLTile.HYToTableNameChar: String;
begin
  // если одна таблица - значит не делимся - вернём пустую строку
  if (0=XYMaskWidth) or (Zoom <= (XYMaskWidth+1)) then begin
    Result:='';
    Exit;
  end;

  // конвертируемся
  Result := IntToHex(XYUpperToTable.Y, 8);
  
  // оставляем хотя бы один символ
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
