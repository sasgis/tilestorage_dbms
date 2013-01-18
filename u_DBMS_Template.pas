unit u_DBMS_Template;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Classes,
  t_types,
  t_SQL_types,
  u_SQLScriptParser,
  t_ETS_Tiles,
  t_ODBC_Connection,
  t_DBMS_Template,
  u_DBMS_Connect;

type
  TSQLScriptParser_SQL = class(TSQLScriptParser)
  private
    FConnection: IDBMS_Connection;
    FBaseFileName: String;
    FAppendDivider: String;
    FInsertIntoTableForTemplate: String;
  private
    procedure LoadScript_Internal(const AList: TStrings; const AExt: String);
    procedure LoadScript_SQL; inline;
    procedure LoadScript_XQL(const AXQL: TStrings); inline;

    // исполняет текст SQL или
    // сохраняем текст XQL в таблицу Z_ALL_SQL
    procedure ParserFoundProc_SQL(
      const ASender: TObject;
      const ACommandIndex: Integer;
      const ACommandText, AErrors: TStrings
    );

    // выкусывает нужный кусок для таблицы и отдаёт его парсеру
    procedure ParseXQL(
      const AXQLSrc, AErrors: TStrings;
      const ATemplateTableName: String
    );

    class function LineIsEmptyOrComment(const ASQLLine: String): Boolean;

  public
    constructor Create(const AConnection: IDBMS_Connection);
    destructor Destroy; override;

    // выполнение всех имеющихся команд SQL из скрипта .SQL
    // сохранение всех имеющихся команд SQL из скрипта .XQL в таблицу Z_ALL_SQL
    function ExecuteAllSQLs: Byte;
  end;

implementation

uses
  t_DBMS_Connect,
  u_DBMS_Utils;

{ TSQLScriptParser_SQL }

constructor TSQLScriptParser_SQL.Create(const AConnection: IDBMS_Connection);
begin
  inherited Create;

  FConnection := AConnection;

  FBaseFileName := c_SQL_Engine_Name[AConnection.GetCheckedEngineType];
  if (0<Length(FBaseFileName)) then begin
    FBaseFileName := GetModuleFileNameWithoutExt(TRUE, FALSE, '', FBaseFileName);
  end;

  FAppendDivider := AConnection.GetInternalParameter(ETS_INTERNAL_SCRIPT_APPENDER);
end;

destructor TSQLScriptParser_SQL.Destroy;
begin
  FConnection := nil;
  inherited;
end;

function TSQLScriptParser_SQL.ExecuteAllSQLs: Byte;
var
  VXQL, VErrors: TStringList;
begin
  // если пусто - значит неизвестный тип СУБД, и ловить тут нечего
  if (0=Length(FBaseFileName)) then begin
    Result := ETS_RESULT_UNKNOWN_DBMS;
    Exit;
  end;

  VXQL := nil;
  VErrors := TStringList.Create;
  try
    // загрузим текст .SQL
    LoadScript_SQL;

    if (0=Self.Count) then begin
      // нет скрипта
      Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
      Exit;
    end;

    // первая часть - простые таблицы и прочее
    FInsertIntoTableForTemplate := '';
    ParseSQL(ParserFoundProc_SQL, VErrors);
  
    // вторая часть - шаблонные таблицы
    VXQL:=TStringList.Create;

    LoadScript_XQL(VXQL);

    if (0=VXQL.Count) then begin
      // нет скрипта
      Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
      Exit;
    end;

    ParseXQL(VXQL, VErrors, c_Templated_Versions);
    ParseXQL(VXQL, VErrors, c_Templated_CommonTiles);
    ParseXQL(VXQL, VErrors, c_Templated_RealTiles);

    Result := ETS_RESULT_OK;
  finally
    FreeAndNil(VXQL);
    if (VErrors<>nil) then begin
      if VErrors.Count>0 then
      try
        VErrors.SaveToFile(FBaseFileName+c_SQL_Ext_Out);
      except
      end;
      VErrors.Free;
    end;
  end;
end;

class function TSQLScriptParser_SQL.LineIsEmptyOrComment(const ASQLLine: String): Boolean;
var L: Integer;
begin
  L := Length(ASQLLine);
  if (0=L) then begin
    // empty line
    Result := TRUE
  end else if (L<4) then begin
    // some info
    Result := FALSE;
  end else begin
    // check begin and end
    Result := (ASQLLine[1]='/') and (ASQLLine[2]='*') and (ASQLLine[L-1]='*') and (ASQLLine[L]='/');
  end;
end;

procedure TSQLScriptParser_SQL.LoadScript_Internal(const AList: TStrings; const AExt: String);
var
  VFileName: String;
begin
  // грузим файл .SQL или .XQL
  VFileName := FBaseFileName + AExt;
  if FileExists(VFileName) then
    AList.LoadFromFile(VFileName)
  else
    AList.Clear;
end;

procedure TSQLScriptParser_SQL.LoadScript_SQL;
begin
  // грузим файл .SQL
  LoadScript_Internal(Self, c_SQL_Ext_Base)
end;

procedure TSQLScriptParser_SQL.LoadScript_XQL(const AXQL: TStrings);
begin
  // грузим файл .XQL
  LoadScript_Internal(AXQL, c_SQL_Ext_Tmpl)
end;

procedure TSQLScriptParser_SQL.ParserFoundProc_SQL(
  const ASender: TObject;
  const ACommandIndex: Integer;
  const ACommandText, AErrors: TStrings
);
begin
  if (ACommandText.Count>0) then
  try
    if (0=Length(FInsertIntoTableForTemplate)) then begin
      // просто исполняем текст
      FConnection.ExecuteDirectSQL(Trim(ACommandText.Text)+FAppendDivider, FALSE);
    end else begin
      // вставляем в таблицу Z_ALL_SQL
      FConnection.ExecuteDirectSQL(
            'INSERT INTO ' + FConnection.ForcedSchemaPrefix + Z_ALL_SQL+ ' (object_name,object_oper,index_sql,object_sql)'+
           ' VALUES ('+DBMSStrToDB(FInsertIntoTableForTemplate)+',''C'','+IntToStr(ACommandIndex)+','+DBMSStrToDB(ACommandText.Text)+')',
            FALSE
          );
    end;
  except on E: Exception do
    AddExceptionToErrors(AErrors, E);
  end;
end;

procedure TSQLScriptParser_SQL.ParseXQL(
  const AXQLSrc, AErrors: TStrings;
  const ATemplateTableName: String
);
var
  VUppercased: String;
  VLine: String;
  VNextCreateTable: Integer;
begin
  // будем выкусывать кусок SQL в себя
  Self.Clear;

  VUppercased := UpperCase(ATemplateTableName);

  // get all aux SQL text
  Self.Assign(AXQLSrc);

  // remove lines before first line with requested name
  while (Self.Count>0) do begin
    VLine := Trim(Self[0]);
    // check line
    if LineIsEmptyOrComment(VLine) then begin
      // skip line
      Self.Delete(0);
    end else if (System.Pos(VUppercased, UpperCase(VLine)) > 0) then begin
      // found!
      break;
    end else begin
      // skip before table
      Self.Delete(0);
    end;
  end;

  // if no lines
  if (0=Self.Count) then
    Exit;

  // find next line with 'create table'
  VNextCreateTable := 1;

  while (VNextCreateTable<Self.Count) do begin
    VLine := Trim(Self[VNextCreateTable]);
    // check line
    if SameText(c_Template_CreateTable_Prefix, System.Copy(VLine, 1, Length(c_Template_CreateTable_Prefix))) then begin
      // next 'create table' found
      while (Self.Count>VNextCreateTable) do
        Self.Delete(Self.Count-1);
      break;
    end;
    // next line
    Inc(VNextCreateTable);
  end;

  // VLine has all SQL text for specified templated table
  if (0=Self.Count) then
    Exit;

  // insert all SQLs into special table
  FInsertIntoTableForTemplate := ATemplateTableName;
  ParseSQL(ParserFoundProc_SQL, AErrors);
end;

end.
