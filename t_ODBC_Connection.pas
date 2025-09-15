unit t_ODBC_Connection;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  Classes,
  odbcsql,
  i_StatementHandleCache,
  t_ODBC_Buffer,
  t_ODBC_Exception;

const
  c_RTL_ODBC_Paramname = '?';
  c_BlobDataType_Default = SQL_LONGVARBINARY;

type
  TOdbcEnvironment = packed record
    HENV: SQLHENV;
  public
    procedure Init;
    procedure Close;
    function Load: Boolean;
    function FindDSN(const ASystemDSN: String; out ADescription: String): Boolean;
  end;

{$if defined(CONNECTION_AS_CLASS)}
  IODBCConnection = interface
    ['{6CDDBC7E-3DFF-484C-8769-38C5FB85231D}']

    function ExecuteDirectSQL(
      const ASQLText: AnsiString;
      const ASilentOnError: Boolean
    ): Boolean;

    function ExecuteDirectWithBlob(
      const ASQLText, AFullParamName: AnsiString;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean
    ): Boolean;

    function OpenDirectSQLFetchCols(
      const ASQLText: AnsiString;
      const ABufPtr: POdbcFetchCols
    ): Boolean;

    function TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean;
    
    function CheckDirectSQLSingleNotNull(const ASQLText: AnsiString): Boolean;
  end;
{$else}
  IODBCConnection = ^TODBCConnection;
{$ifend}

  TODBCConnection =
{$if defined(CONNECTION_AS_RECORD)}
  record
{$else}
  class(TInterfacedObject, IODBCConnection)
{$ifend}
  private
    FBlobDataType: SQLSMALLINT; // SQL_LONGVARBINARY или SQL_VARBINARY
    Fhdbc: SQLHDBC;
    FParams: TStrings;
    FStatementCache: IStatementHandleCache;
  private
    function GetDSN: String;
    function GetPWD: String;
    function GetUID: String;
    procedure SetDSN(const Value: String);
    procedure SetPWD(const Value: String);
    procedure SetUID(const Value: String);
  private
    function GetHENV: SQLHENV; // SQLHANDLE;

    procedure ODBCDriverInfo(
      InfoType: SQLUSMALLINT;
      InfoValuePtr: SQLPOINTER;
      BufferLength: SQLSMALLINT;
      StringLengthPtr: PSQLSMALLINT;
      const AAllowWithInfo: Boolean = FALSE
    );

    procedure CheckSQLResult(const ASqlRes: SQLRETURN);
  public
    ConnectWithParams: Boolean;
    ConnectWithInfoMessages: String;
    SQL_IDENTIFIER_QUOTE_CHAR_VALUE: String;
    SYNC_SQL_MODE: Integer;

{$if defined(CONNECTION_AS_CLASS)}
  private
{$ifend}
    procedure Init;
    procedure Uninit;
  public
{$if defined(CONNECTION_AS_CLASS)}
    constructor Create;
    destructor Destroy; override;
{$ifend}

    procedure DisConnect;
    procedure Connect;

    function Connected: Boolean; inline;

    function ExecuteDirectSQL(
      const ASQLText: String;
      const ASilentOnError: Boolean
    ): Boolean;

    function ExecuteDirectWithBlob(
      const ASQLText: String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean
    ): Boolean;

    function OpenDirectSQLFetchCols(
      const ASQLText: String;
      const ABufPtr: POdbcFetchCols
    ): Boolean;

    function TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;

    function CheckDirectSQLSingleNotNull(const ASQLText: String): Boolean;

    (*
    function GetTablesWithTiles(
      const ATileServiceName: AnsiString;
      AListOfTables: TStrings
    ): Boolean;
    *)

    procedure CheckByteaAsLoOff(const ANeedCheck: Boolean);

    property UID: String read GetUID write SetUID;
    property PWD: String read GetPWD write SetPWD;
    property DSN: String read GetDSN write SetDSN;

    property Params: TStrings read FParams;

    property StatementCache: IStatementHandleCache read FStatementCache;
  end;

function Load_DSN_Params_from_ODBC(const ASystemDSN: String; out ADescription: String): Boolean;

implementation

uses
  u_StatementHandleCache;

var
  gEnv: TOdbcEnvironment;

function Load_DSN_Params_from_ODBC(const ASystemDSN: String; out ADescription: String): Boolean;
begin
  Result := gEnv.FindDSN(ASystemDSN, ADescription);
end;

{ TODBCConnection }

procedure TODBCConnection.CheckByteaAsLoOff(const ANeedCheck: Boolean);
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
  VSQLText: String;
  VDescribeColData: TDescribeColData;
begin
  if ANeedCheck then begin
    // проверяем как есть - прямым запросом
    VSQLText := 'select null::bytea';
    // только тут от греха всё ловим и при ошибке включаем признак
    try
      CheckSQLResult(FStatementCache.GetStatementHandle(h));
      try
        VRes := SQLExecDirect(h, PChar(VSQLText), Length(VSQLText));
        CheckStatementResult(h, VRes, EODBCDirectExecError);
        // имя поля тут не интересует
        VRes := SQLDescribeCol(
          h,
          1,
          nil,
          0,
          VDescribeColData.NameLen,
          VDescribeColData.DataType,
          VDescribeColData.ColumnSize,
          VDescribeColData.DecimalDigits,
          VDescribeColData.Nullable
        );
        // проверяем результат
        CheckStatementResult(h, VRes, EODBCDescribeColError);
        // здесь уже всё что надо получено
        SQLCloseCursor(h);
        // итоговое значение
        FBlobDataType := VDescribeColData.DataType;
      finally
        FStatementCache.FreeStatement(h);
      end;
    except
      FBlobDataType := SQL_VARBINARY;
    end;
  end else begin
    // по умолчанию
    FBlobDataType := c_BlobDataType_Default;
  end;
end;

function TODBCConnection.CheckDirectSQLSingleNotNull(const ASQLText: String): Boolean;
var
  VOdbcFetchCols: TOdbcFetchCols;
begin
  VOdbcFetchCols.Init;
  try
    Result := OpenDirectSQLFetchCols(ASQLText, @VOdbcFetchCols)
              AND
              VOdbcFetchCols.FetchRecord
              AND
              (not VOdbcFetchCols.IsNull(1));
  finally
    VOdbcFetchCols.Close;
  end;
end;

procedure TODBCConnection.CheckSQLResult(const ASqlRes: SQLRETURN);
begin
  if not SQL_SUCCEEDED(ASqlRes) then
    raise EODBCConnectionError.CreateWithDiag(ASqlRes, SQL_HANDLE_DBC, Fhdbc);
end;

procedure TODBCConnection.Connect;
var
  i, VConnectResult: SQLRETURN;
  SServer: array [0..1025] of Char;
  cbout:   SQLSMALLINT;
  ConnectionString, VUID, VPWD: String;
  dc:      SQLUSMALLINT;
begin
  if Connected then
    Exit;

  // сбросим признак
  FBlobDataType := c_BlobDataType_Default;

  CheckSQLResult(SQLAllocHandle(SQL_HANDLE_DBC, GetHENV, Fhdbc));

  // TStatementHandleNonCached
  // TStatementHandleCache
  // TStatementFetchableCache
  FStatementCache := TStatementFetchableCache.Create(@Fhdbc);

  ConnectWithInfoMessages := '';
  //VConnectResult := SQL_NO_DATA;

  (*
  case DriverCompletion of
    sdPrompt:      dc := SQL_DRIVER_PROMPT;
    sdComplete:    dc := SQL_DRIVER_COMPLETE;
    sdCompleteReq: dc := SQL_DRIVER_COMPLETE_REQUIRED;
    sdNoPrompt:    dc := SQL_DRIVER_NOPROMPT;
    else           dc := SQL_DRIVER_COMPLETE_REQUIRED;
  end;
  *)

  try
    if ConnectWithParams then begin
      dc := SQL_DRIVER_COMPLETE_REQUIRED;

      ConnectionString := '';
      for i := 0 to FParams.Count-1 do
      begin
        if Length(ConnectionString) > 0 then
          ConnectionString := ConnectionString + ';';
        ConnectionString := ConnectionString+FParams[i];
      end;

      // via connectionstring
      VConnectResult := SQLDriverConnect(
        Fhdbc,
        0, //Application.handle,
        PChar(ConnectionString),
        SQL_NTS,
        SServer,
        1024,
        cbout,
        dc
      );
    end else begin
      // simple without params
      ConnectionString := DSN;
      VUID := UID;
      VPWD := PWD;
      VConnectResult := SQLConnect(
        fhdbc,
        PChar(ConnectionString),
        Length(ConnectionString),
        PChar(VUID),
        Length(VUID),
        PChar(VPWD),
        Length(VPWD)
      );
    end;

    // подключение удалось, но драйвер выдал информацию к размышлению
    if (SQL_SUCCESS_WITH_INFO=VConnectResult) then begin
      ConnectWithInfoMessages := MakeODBCInfoMessage(VConnectResult, SQL_HANDLE_DBC, Fhdbc);
    end else begin
      // остальное проверяем
      CheckSQLResult(VConnectResult);
    end;
  except on E: Exception do begin
      ConnectWithInfoMessages := E.Message;
      SQLFreeHandle(SQL_HANDLE_DBC, Fhdbc);
      Fhdbc := SQL_NULL_HANDLE;
      raise;
    end;
  end;

  // успешно подключились
  
  // get quotation options
  SQL_IDENTIFIER_QUOTE_CHAR_VALUE := '';
  SetLength(SQL_IDENTIFIER_QUOTE_CHAR_VALUE, 4);
  ODBCDriverInfo(
    SQL_IDENTIFIER_QUOTE_CHAR,
    SQLPOINTER(@SQL_IDENTIFIER_QUOTE_CHAR_VALUE[1]),
    Length(SQL_IDENTIFIER_QUOTE_CHAR_VALUE),
    @cbout,
    TRUE
  );
  SetLength(SQL_IDENTIFIER_QUOTE_CHAR_VALUE, cbout);

  // ещё бы надо прочитать:
  // SQL_DATA_SOURCE_READ_ONLY
  // SQL_DBMS_NAME
  // SQL_DBMS_VER
  // SQL_MAX_CONCURRENT_ACTIVITIES aka SQL_ACTIVE_STATEMENTS
  // SQL_SPECIAL_CHARACTERS
end;

function TODBCConnection.Connected: Boolean;
begin
  Result := (Fhdbc <> SQL_NULL_HANDLE)
end;

{$if defined(CONNECTION_AS_CLASS)}
constructor TODBCConnection.Create;
begin
  Init;
  inherited Create;
end;
{$ifend}

{$if defined(CONNECTION_AS_CLASS)}
destructor TODBCConnection.Destroy;
begin
  Uninit;
  inherited Destroy;
end;
{$ifend}

procedure TODBCConnection.DisConnect;
begin
  if Connected then begin
    FStatementCache := nil;
    SQLDisConnect(Fhdbc);
    SQLFreeHandle(SQL_HANDLE_DBC, Fhdbc);
    Fhdbc := SQL_NULL_HANDLE;
  end;
end;

function TODBCConnection.ExecuteDirectSQL(
  const ASQLText: String;
  const ASilentOnError: Boolean
): Boolean;
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
begin
  CheckSQLResult(FStatementCache.GetStatementHandle(h));
  try
    VRes := SQLExecDirect(h, PChar(ASQLText), Length(ASQLText));
    Result := SQL_SUCCEEDED(VRes);
    if (not Result) and (not ASilentOnError) then
      CheckStatementResult(h, VRes, EODBCDirectExecError);
  finally
    FStatementCache.FreeStatement(h);
  end;
end;

function TODBCConnection.ExecuteDirectWithBlob(
  const ASQLText: String;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  const ASilentOnError: Boolean
): Boolean;
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
  VBufferAddr: Pointer;
  VColumnSize: SQLULEN;
  VStrLen_or_IndPtr: SQLLEN;
begin
  h := SQL_NULL_HANDLE;
  try
    // allocate statement
    CheckSQLResult(FStatementCache.GetStatementHandle(h));

    if (ABufferAddr<>nil) and (ABufferSize>0) then begin
      // has data
      VBufferAddr := ABufferAddr;
      VStrLen_or_IndPtr := ABufferSize;
      VColumnSize := ABufferSize;
    end else begin
      // is null
      VBufferAddr := nil;
      VStrLen_or_IndPtr := SQL_NULL_DATA;
      VColumnSize := 0;
    end;

    // bind single blob
    VRes := SQLBindParameter(
      h,
      1,
      SQL_PARAM_INPUT,
      SQL_C_BINARY,
      FBlobDataType,
      VColumnSize,
      0,
      VBufferAddr,
      VStrLen_or_IndPtr,
      VStrLen_or_IndPtr
    );

    CheckStatementResult(h, VRes, EODBCDirectExecBlobError);

    // execute
    VRes := SQLExecDirect(
      h,
      PChar(ASQLText),
      Length(ASQLText)
    );

    Result := SQL_SUCCEEDED(VRes);

    if (not Result) and (not ASilentOnError) then
      CheckStatementResult(h, VRes, EODBCDirectExecBlobError);
  finally
    FStatementCache.FreeStatement(h);
  end;
end;

function TODBCConnection.GetDSN: String;
begin
  Result := FParams.Values['DSN'];
end;

function TODBCConnection.GetHENV: SQLHENV;
begin
  Result := gEnv.HENV;
end;

function TODBCConnection.GetPWD: String;
begin
  Result := FParams.Values['PWD'];
end;

(*
function TODBCConnection.GetTablesWithTiles(
  const ATileServiceName: AnsiString;
  AListOfTables: TStrings
): Boolean;
const
  c_SQL_NAME_LEN = 63; // если больше длина - таблица не наша
var
  VStmtHandle: SQLHSTMT;
  VStrLen_or_Ind_TableName, VStrLen_or_Ind_TableType: SQLLEN;
  VTableName: array [0..SQL_NAME_LEN + 1] of AnsiChar;
  VTableType: array [0..SQL_NAME_LEN + 1] of AnsiChar;
  VTableFilterStr: AnsiString;
  VTableFilterPtr: PAnsiChar;
  VFoundTable: AnsiString;
  VUnderPos: Integer;
begin
  VTableFilterPtr := nil;
  VTableFilterStr := ATileServiceName;

  Result := SQL_SUCCEEDED(GetStatementHandle(VStmtHandle));
  if Result then
  try
    if (0 < Length(VTableFilterStr)) then begin
      // есть шаблон
      Result := SQL_SUCCEEDED(SQLSetStmtAttr(VStmtHandle, SQL_ATTR_METADATA_ID, Pointer(SQL_FALSE), 0));
      if Result then begin
        VTableFilterStr := '%___' + VTableFilterStr;
        VTableFilterPtr := @VTableFilterPtr[1];
      end;
    end;

    if Result then
    if SQL_SUCCEEDED(SQLTablesA(VStmtHandle, nil, 0, nil, 0, VTableFilterPtr, Length(VTableFilterStr), nil, 0)) then begin
      // привяжем 2 нужных поля
      SQLBindCol(VStmtHandle, 3, SQL_CHAR, @VTableName, c_SQL_NAME_LEN, @VStrLen_or_Ind_TableName);
      SQLBindCol(VStmtHandle, 4, SQL_CHAR, @VTableType, c_SQL_NAME_LEN, @VStrLen_or_Ind_TableType);
      // вытащим список
      while SQL_SUCCEEDED(SQLFetch(VStmtHandle)) do begin
        // "TABLE"             - надо
        // "VIEW"              - надо
        // "SYSTEM TABLE"      - не надо
        // "GLOBAL TEMPORARY"  - не надо
        // "LOCAL TEMPORARY"   - не надо
        // "ALIAS"             - ?
        // "SYNONYM"           - надо
        // or a data source–specific type name:
        // "BASE TABLE"        - надо (PostgreSQL)
        if (VStrLen_or_Ind_TableName > Length(ATileServiceName)+2) then
        if (VStrLen_or_Ind_TableType <= 10) then begin
          VFoundTable := StrPas(VTableName);
          VUnderPos := System.Pos('_', VFoundTable);
          // есть символ подчёркивания, и он не ранее чем на третьей позиции
          if (VUnderPos > 2) then
          // начинается не с символов xyz
          if (not (VFoundTable[1] in ['X','x','Y','y','Z','z'])) then
          // после подчёркивания идёт суффикс
          if (0=StrIComp(@VFoundTable[VUnderPos+1], @ATileServiceName[1])) then begin
            // можно добавлять
            AListOfTables.Add(VFoundTable);
          end;
        end;
      end;
    end;
  finally
    FreeStatementHandle(VStmtHandle);
  end;
end;
*)

function TODBCConnection.GetUID: String;
begin
  Result := FParams.Values['UID'];
end;

procedure TODBCConnection.Init;
begin
  gEnv.Load;
  Fhdbc := SQL_NULL_HANDLE;
  FStatementCache := nil;
  FBlobDataType := c_BlobDataType_Default;
  ConnectWithParams := FALSE;
  FParams := TStringList.Create;
  SQL_IDENTIFIER_QUOTE_CHAR_VALUE := '"'; // default value
end;

procedure TODBCConnection.ODBCDriverInfo(InfoType: SQLUSMALLINT;
  InfoValuePtr: SQLPOINTER; BufferLength: SQLSMALLINT;
  StringLengthPtr: PSQLSMALLINT; const AAllowWithInfo: Boolean);
var
  sqlres: SQLRETURN;
begin
  sqlres := SQLGetInfo(Fhdbc, InfoType, InfoValuePtr, BufferLength, StringLengthPtr);
  case sqlres of
    SQL_SUCCESS:;
    SQL_SUCCESS_WITH_INFO: if not AAllowWithInfo then raise EODBCDriverInfoErrorWithInfo.CreateWithDiag(sqlres, SQL_HANDLE_DBC, Fhdbc);
    SQL_NEED_DATA:         raise EODBCDriverInfoNeedDataError.CreateWithDiag(sqlres, SQL_HANDLE_DBC, Fhdbc);
    SQL_STILL_EXECUTING:   raise EODBCDriverInfoStillExecuting.Create('SQL_STILL_EXECUTING');
    SQL_ERROR:             raise EODBCDriverInfoError.CreateWithDiag(sqlres, SQL_HANDLE_DBC, Fhdbc);
    SQL_NO_DATA:           raise EODBCDriverInfoNoData.CreateWithDiag(sqlres, SQL_HANDLE_DBC, Fhdbc);
    SQL_INVALID_HANDLE:    raise EODBCDriverInfoInvalidHandle.Create('SQL_INVALID_HANDLE');
    else                   raise EODBCDriverInfoUnknown.Create('Unknown SQL result');
  end;
end;

function TODBCConnection.OpenDirectSQLFetchCols(
  const ASQLText: String;
  const ABufPtr: POdbcFetchCols
): Boolean;
var
  VRes: SQLRETURN;
begin
  Assert(ABufPtr<>nil);
  Assert(SQL_NULL_HANDLE=ABufPtr^.Stmt);

  ABufPtr^.StatementHandleCache := FStatementCache;
  CheckSQLResult(FStatementCache.GetStatementHandle(ABufPtr^.Stmt));

  VRes := SQLExecDirect(ABufPtr^.Stmt, PChar(ASQLText), Length(ASQLText));
  CheckStatementResult(ABufPtr^.Stmt, VRes, EODBCOpenFetchError);

  Result := ABufPtr^.DescribeAndBind;
end;

procedure TODBCConnection.SetDSN(const Value: String);
begin
  FParams.Values['DSN'] := Value;
end;

procedure TODBCConnection.SetPWD(const Value: String);
begin
  FParams.Values['PWD'] := Value;
end;

procedure TODBCConnection.SetUID(const Value: String);
begin
  FParams.Values['UID'] := Value;
end;

function TODBCConnection.TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
var
  VFullSQL: String;
begin
  VFullSQL := 'SELECT 1 as a' +
               ' FROM ' + AFullyQualifiedQuotedTableName +
              ' WHERE 0=1';
  Result := ExecuteDirectSQL(VFullSQL, TRUE);
end;

procedure TODBCConnection.Uninit;
begin
  DisConnect;
  FreeAndNil(FParams);
end;

{ TOdbcEnvironment }

procedure TOdbcEnvironment.Close;
begin
  if (HENV <> SQL_NULL_HANDLE) then begin
    SQLFreeHandle(SQL_HANDLE_ENV, HENV);
    HENV := SQL_NULL_HANDLE;
  end;
end;

function TOdbcEnvironment.FindDSN(const ASystemDSN: String; out ADescription: String): Boolean;
var
  VResult: SQLRETURN;
  VDirection: SQLUSMALLINT;
  VServerName: array [0..SQL_MAX_DSN_LENGTH] of Char;
  VDescription: array [0..SQL_MAX_OPTION_STRING_LENGTH] of Char;
  VSize1, VSize2: SQLSmallint;
  VServerNameStr: String;
begin
  Load;
  
  Result := FALSE;
  ADescription := '';

  if (0=Length(ASystemDSN)) then
    Exit;

  VDirection := SQL_FETCH_FIRST_SYSTEM; // SQL_FETCH_FIRST;
  repeat
    // перечисляем
    VResult := SQLDataSources(HENV,
      VDirection,
      VServerName,
      SQL_MAX_DSN_LENGTH,
      VSize1,
      VDescription,
      SQL_MAX_OPTION_STRING_LENGTH,
      VSize2
    );

    if SQL_SUCCEEDED(VResult) then begin
      // ok
      if (VSize1 = Length(ASystemDSN)) then begin
        SetString(VServerNameStr, PChar(@(VServerName[0])), VSize1);

        // check servername
        if SameText(VServerNameStr, ASystemDSN) then begin
          // found
          SetString(ADescription, PChar(@(VDescription[0])), VSize2);
          // get all params
          // SQLGetPrivateProfileStringW
          // done
          Result := TRUE;
          break;
        end;
      end;
    end else begin
      // error or SQL_NO_DATA
      break;
    end;

    VDirection := SQL_FETCH_NEXT;
  until FALSE;
end;

procedure TOdbcEnvironment.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
end;

function TOdbcEnvironment.Load: Boolean;
var VRes: SQLRETURN;
begin
  if (HENV <> SQL_NULL_HANDLE) then begin
    // уже загружено
    Result := TRUE;
    Exit;
  end;

  try
    // берём окружение
    VRes := SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, HENV);

    if not SQL_SUCCEEDED(VRes) then
      raise EODBCAllocateEnvironment.Create(IntToStr(VRes));

    // натянем версию
    VRes := SQLSetEnvAttr(
      HENV,
      SQL_ATTR_ODBC_VERSION,
{$if defined(ODBCVER380)}
      SQLPOINTER(SQL_OV_ODBC3_80),
{$elseif defined(ODBCVER351)}
      SQLPOINTER(SQL_OV_ODBC3_51),
{$elseif defined(ODBCVER350)}
      SQLPOINTER(SQL_OV_ODBC3_50),
{$else}
      SQLPOINTER(SQL_OV_ODBC3),
{$ifend}
      0
    );

    if not SQL_SUCCEEDED(VRes) then
      raise EODBCEnvironmentError.CreateWithDiag(VRes, SQL_HANDLE_ENV, HENV);

    Result := TRUE;
  except
    Close;
    Result := FALSE;
  end;
end;

initialization
  gEnv.Init;
finalization
  gEnv.Close;
end.
