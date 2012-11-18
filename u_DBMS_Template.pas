unit u_DBMS_Template;

interface

uses
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_DBMS_Template,
  u_DBMS_Connect;

type
  TDBMS_SQLTemplates_File = class(TObject)
  private
    FSQL: TStringList;
    FAux: TStringList;
    FUniqueEngineType: String;
    FForcedSchemaPrefix: String;
    FAppendDivider: String;
  private
    function LineIsEmptyOrComment(const ASQLLine: String): Boolean;

    function GetSQLDivider(const ALines: TStrings): String;

    function GetNextDivLineIndex(
      const ASrcLines: TStrings;
      const AStartLine: Integer;
      const ADivider: String;
      const ALines: TStrings
    ): Integer;

    procedure ExecuteAuxSQL(
      const AErrors: TStrings;
      const ADataset: TDBMS_Dataset;
      const ATemplatedTableName: String
    );

    procedure ExecSQLFromStrings(
      const ASrcLines: TStrings;
      const ADataset: TDBMS_Dataset;
      const AErrors: TStrings;
      const AInsertIntoTableForTemplated: String
    );

    procedure AddExceptionToErrors(
      const AErrors: TStrings;
      const E: Exception
    );
  public
    constructor Create(const AUniqueEngineType, AForcedSchemaPrefix, AAppendDivider: String);
    destructor Destroy; override;
    
    // выполнение всех имеющихся команд SQL из скрипта
    function ExecuteAllSQLs(const ADataset: TDBMS_Dataset): Byte;
  end;

implementation

uses
  u_DBMS_Utils;


{ TDBMS_SQLTemplates_File }

procedure TDBMS_SQLTemplates_File.AddExceptionToErrors(
  const AErrors: TStrings;
  const E: Exception
);
begin
  if AErrors.Count>0 then
    AErrors.Add('');
  AErrors.Add(E.ClassName);
  AErrors.Add(E.Message);
end;

constructor TDBMS_SQLTemplates_File.Create(const AUniqueEngineType, AForcedSchemaPrefix, AAppendDivider: String);
var
  VFileName: String;
begin
  inherited Create;
  
  FUniqueEngineType := AUniqueEngineType;
  FForcedSchemaPrefix := AForcedSchemaPrefix;
  FAppendDivider := AAppendDivider;
  
  // templated sql text
  FAux := TStringList.Create;
  VFileName := GetModuleFileNameWithoutExt(TRUE, '', AUniqueEngineType) + c_SQL_Ext_Tmpl;
  if FileExists(VFileName) then
  try
    FAux.LoadFromFile(VFileName);
  except
  end;
  
  // plan sql text
  FSQL := TStringList.Create;
  VFileName := GetModuleFileNameWithoutExt(TRUE, '', AUniqueEngineType) + c_SQL_Ext_Base;
  if FileExists(VFileName) then
  try
    FSQL.LoadFromFile(VFileName);
  except
  end;
end;

destructor TDBMS_SQLTemplates_File.Destroy;
begin
  FreeAndNil(FAux);
  FreeAndNil(FSQL);
  inherited;
end;

procedure TDBMS_SQLTemplates_File.ExecSQLFromStrings(
  const ASrcLines: TStrings;
  const ADataset: TDBMS_Dataset;
  const AErrors: TStrings;
  const AInsertIntoTableForTemplated: String
);
var
  VLines: TStrings;
  VDivider: String;
  VStartLine, VNewDivLine: Integer;
  VSQLInsertIndex: SmallInt;
begin
  // divide by strings 'go' or ';' (defined as first line) and execute every part
  if (0=ASrcLines.Count) then
    Exit;

  // get divider from last nonempty line
  VDivider := GetSQLDivider(ASrcLines);

  VLines := TStringList.Create;
  try
    // first part - PLAIN SQL TEXT
    VSQLInsertIndex := 0;
    VStartLine := 0;
    repeat
      Inc(VSQLInsertIndex);
      // get part of file between dividers
      VNewDivLine := GetNextDivLineIndex(ASrcLines, VStartLine, VDivider, VLines);

      if (VLines.Count>0) then
      try
        if (0=Length(AInsertIntoTableForTemplated)) then begin
          // если не в таблицу - значит просто исполняем команды SQL
          if (0=Length(FAppendDivider)) then begin
            // просто дообавляем строки
            ADataset.SQL.Clear;
            ADataset.SQL.AddStrings(VLines);
          end else begin
            // кроме строк добавляем окончание команды
            ADataset.SQL.Text := Trim(VLines.Text) + FAppendDivider;
          end;
          // исполняем
          ADataset.ExecSQL(FALSE);
        end else begin
          // make insert SQL statement for special table
          ADataset.SQL.Text := 'insert into ' + FForcedSchemaPrefix + Z_ALL_SQL+
                              ' (object_name,object_oper,index_sql,object_sql)'+
                              ' values ('+WideStrToDB(AInsertIntoTableForTemplated)+',''C'','+IntToStr(VSQLInsertIndex)+','+WideStrToDB(VLines.Text)+')';
          ADataset.ExecSQL(TRUE);
        end;
      except
        on E: Exception do begin
          AddExceptionToErrors(AErrors, E);
        end;
      end;

      // check finished
      if (VNewDivLine<0) or (VNewDivLine>=ASrcLines.Count) then
        break;

      VStartLine := VNewDivLine + 1;
    until FALSE;
  finally
    VLines.Free;
  end;
end;

function TDBMS_SQLTemplates_File.ExecuteAllSQLs(const ADataset: TDBMS_Dataset): Byte;
var
  VErrors: TStrings;
begin
  Result := ETS_RESULT_OK;
  
  VErrors := TStringList.Create;
  try
    // первая часть - простые таблицы и прочее
    ExecSQLFromStrings(FSQL, ADataset, VErrors, '');

    // вторая часть - шаблонные таблицы
    ExecuteAuxSQL(VErrors, ADataset, c_Templated_Versions);
    ExecuteAuxSQL(VErrors, ADataset, c_Templated_CommonTiles);
    ExecuteAuxSQL(VErrors, ADataset, c_Templated_RealTiles);
  finally
    if VErrors.Count>0 then
    try
      VErrors.SaveToFile(GetModuleFileNameWithoutExt(TRUE, '', FUniqueEngineType)+c_SQL_Ext_Out);
    except
    end;

    VErrors.Free;
  end;
end;

procedure TDBMS_SQLTemplates_File.ExecuteAuxSQL(
  const AErrors: TStrings;
  const ADataset: TDBMS_Dataset;
  const ATemplatedTableName: String
);
var
  VLine, VDivider, VUppercased: String;
  VLines: TStrings;
  VNextCreateTable: Integer;
begin
  VDivider := GetSQLDivider(FAux);
  VUppercased := UpperCase(ATemplatedTableName);

  VLines := TStringList.Create;
  try
    // get all aux SQL text
    VLines.Assign(FAux);

    // remove ines before first line with requested name
    while (VLines.Count>0) do begin
      VLine := Trim(VLines[0]);
      // check line
      if LineIsEmptyOrComment(VLine) then begin
        // skip line
        VLines.Delete(0);
      end else if (System.Pos(VUppercased, UpperCase(VLine)) > 0) then begin
        // found!
        break;
      end else begin
        // skip before table
        VLines.Delete(0);
      end;
    end;

    // if no lines
    if (0=VLines.Count) then
      Exit;

    // find next line with 'create table'
    VNextCreateTable := 1;

    while (VNextCreateTable<VLines.Count) do begin
      VLine := Trim(VLines[VNextCreateTable]);
      // check line
      if SameText(c_Template_CreateTable_Prefix, System.Copy(VLine, 1, Length(c_Template_CreateTable_Prefix))) then begin
        // next 'create table' found
        while (VLines.Count>VNextCreateTable) do
          VLines.Delete(VLines.Count-1);
        break;
      end;
      // next line
      Inc(VNextCreateTable);
    end;

    // VLine has all SQL text for specified templated table
    if (0=VLines.Count) then
      Exit;

    // insert all SQLs into special table
    ExecSQLFromStrings(VLines, ADataset, AErrors, ATemplatedTableName);
  finally
    VLines.Free;
  end;
end;

function TDBMS_SQLTemplates_File.GetNextDivLineIndex(
  const ASrcLines: TStrings;
  const AStartLine: Integer;
  const ADivider: String;
  const ALines: TStrings
): Integer;
var
  VLine: String;
begin
  // перед циклом чистимся и берём стартовую строку
  ALines.Clear;
  VLine := Trim(ASrcLines[AStartLine]);
  if (not SameText(VLine, ADivider)) then
    ALines.Add(VLine);

  // цикл до разделителя
  Result := AStartLine+1;
  while (Result<ASrcLines.Count) do begin
    VLine := Trim(ASrcLines[Result]);
    if SameText(VLine, ADivider) then
      break
    else
      ALines.Add(VLine);
    Inc(Result);
  end;

  // а теперь с начала и с конца строк удаляем пустышки

  while ALines.Count>0 do begin
    VLine := Trim(ALines[0]);
    if (0=Length(VLine)) then
      ALines.Delete(0)
    else
      break;
  end;

  while ALines.Count>0 do begin
    VLine := Trim(ALines[ALines.Count-1]);
    if (0=Length(VLine)) then
      ALines.Delete(ALines.Count-1)
    else
      break;
  end;

  // вот теперь остаток можно исполнять  
end;

function TDBMS_SQLTemplates_File.GetSQLDivider(const ALines: TStrings): String;
var
  i: Integer;
begin
  i := ALines.Count;

  if (0=i) then begin
    Result := 'go';
    Exit;
  end;

  Dec(i);

  while (i>=0) do begin
    Result := Trim(ALines[i]);
    if (Length(Result)>0) then
    if (Length(Result)<4) then
      Exit;
    Dec(i);
  end;

  Result := 'go';
end;

function TDBMS_SQLTemplates_File.LineIsEmptyOrComment(const ASQLLine: String): Boolean;
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

end.
