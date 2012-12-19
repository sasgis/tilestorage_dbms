unit t_ODBC_Connection;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  Classes,
  odbcsql,
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
    function FindDSN(const ASystemDSN: AnsiString; out ADescription: AnsiString): Boolean;
  end;

  TODBCConnection = class(TObject)
  private
    FBlobDataType: SQLSMALLINT; // SQL_LONGVARBINARY или SQL_VARBINARY
    Fhdbc: SQLHDBC;
    FParams: TStrings;
    FConnectWithInfoMessages: String;
    FSQL_IDENTIFIER_QUOTE_CHAR_VALUE: AnsiString;
  private
    function GetDSN: String;
    function GetPWD: String;
    function GetUID: String;
    procedure SetDSN(const Value: String);
    procedure SetPWD(const Value: String);
    procedure SetUID(const Value: String);
    procedure SetParams(const Value: TStrings);
    procedure SetConnected(const Value: Boolean);
  private
    function GetHENV: SQLHENV; // SQLHANDLE;

    procedure ODBCDriverInfo(
      InfoType: SQLUSMALLINT;
      InfoValuePtr: SQLPOINTER;
      BufferLength: SQLSMALLINT;
      StringLengthPtr: PSQLSMALLINT;
      const AAllowWithInfo: Boolean = FALSE
    );
    
  public
    ConnectWithParams: Boolean;
    function IsConnected: Boolean; inline;
  public
    constructor Create;
    destructor Destroy; override;

    procedure CheckSQLResult(const ASqlRes: SQLRETURN);

    procedure DisConnect;
    procedure Connect;

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

    function CheckDirectSQLSingleNotNull(const ASQLText: AnsiString): Boolean;

    function TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean;

    procedure CheckByteaAsLoOff(const ANeedCheck: Boolean);

    property UID: String read GetUID write SetUID;
    property PWD: String read GetPWD write SetPWD;
    property DSN: String read GetDSN write SetDSN;

    property Connected: Boolean read IsConnected write SetConnected default FALSE;
    property Params: TStrings read FParams write SetParams;

    property SQL_IDENTIFIER_QUOTE_CHAR_VALUE: AnsiString read FSQL_IDENTIFIER_QUOTE_CHAR_VALUE;
  end;

function Load_DSN_Params_from_ODBC(const ASystemDSN: AnsiString; out ADescription: AnsiString): Boolean;

implementation

var
  gEnv: TOdbcEnvironment;

function Load_DSN_Params_from_ODBC(const ASystemDSN: AnsiString; out ADescription: AnsiString): Boolean;
begin
  Result := gEnv.FindDSN(ASystemDSN, ADescription);
end;

{ TODBCConnection }

procedure TODBCConnection.CheckByteaAsLoOff(const ANeedCheck: Boolean);
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
  VSQLText: AnsiString;
  VDescribeColData: TDescribeColData;
begin
  if ANeedCheck then begin
    // проверяем как есть - прямым запросом
    VSQLText := 'select null::bytea';
    // только тут от греха всё ловим и при ошибке включаем признак
    try
      CheckSQLResult(SQLAllocHandle(SQL_HANDLE_STMT, Fhdbc, h));
      try
        VRes := SQLExecDirectA(h, PAnsiChar(VSQLText), Length(VSQLText));
        CheckStatementResult(h, VRes, EODBCDirectExecError);
        // имя поля тут не интересует
        VRes := SQLDescribeColA(
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
        SQLFreeHandle( SQL_HANDLE_STMT, h);
      end;
    except
      FBlobDataType := SQL_VARBINARY;
    end;
  end else begin
    // по умолчанию
    FBlobDataType := c_BlobDataType_Default;
  end;
end;

function TODBCConnection.CheckDirectSQLSingleNotNull(const ASQLText: AnsiString): Boolean;
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
  SServer: array [0..1025] of AnsiChar;
  cbout:   SQLSMALLINT;
  ConnectionString, VUID, VPWD: AnsiString;
  dc:      SQLUSMALLINT;
begin
  if IsConnected then
    Exit;

  // сбросим признак
  FBlobDataType := c_BlobDataType_Default;

  CheckSQLResult(SQLAllocHandle(SQL_HANDLE_DBC, GetHENV, Fhdbc));

  FConnectWithInfoMessages := '';
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
      VConnectResult := SQLDriverConnectA(
        Fhdbc,
        0, //Application.handle,
        PAnsiChar(ConnectionString),
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
      VConnectResult := SQLConnectA(
        fhdbc,
        PAnsiChar(ConnectionString),
        Length(ConnectionString),
        PAnsiChar(VUID),
        Length(VUID),
        PAnsiChar(VPWD),
        Length(VPWD)
      );
    end;

    // подключение удалось, но драйвер выдал информацию к размышлению
    if (SQL_SUCCESS_WITH_INFO=VConnectResult) then begin
      FConnectWithInfoMessages := MakeODBCInfoMessage(VConnectResult, SQL_HANDLE_DBC, Fhdbc);
    end else begin
      // остальное проверяем
      CheckSQLResult(VConnectResult);
    end;
  except on E: Exception do begin
      FConnectWithInfoMessages := E.Message;
      SQLFreeHandle(SQL_HANDLE_DBC, Fhdbc);
      Fhdbc := SQL_NULL_HANDLE;
      raise;
    end;
  end;

  // успешно подключились
  
  // get quotation options
  FSQL_IDENTIFIER_QUOTE_CHAR_VALUE := '';
  SetLength(FSQL_IDENTIFIER_QUOTE_CHAR_VALUE, 4);
  ODBCDriverInfo( SQL_IDENTIFIER_QUOTE_CHAR,     SQLPOINTER(@FSQL_IDENTIFIER_QUOTE_CHAR_VALUE[1]),  Length(FSQL_IDENTIFIER_QUOTE_CHAR_VALUE), @cbout, TRUE);
  SetLength(FSQL_IDENTIFIER_QUOTE_CHAR_VALUE, cbout);

  // ещё бы надо прочитать:
  // SQL_DATA_SOURCE_READ_ONLY
  // SQL_DBMS_NAME
  // SQL_DBMS_VER
  // SQL_MAX_CONCURRENT_ACTIVITIES aka SQL_ACTIVE_STATEMENTS
  // SQL_SPECIAL_CHARACTERS
end;

constructor TODBCConnection.Create;
begin
  gEnv.Load;
  inherited Create;
  Fhdbc := SQL_NULL_HANDLE;
  FBlobDataType := c_BlobDataType_Default;
  ConnectWithParams := FALSE;
  FParams := TStringList.Create;
  FSQL_IDENTIFIER_QUOTE_CHAR_VALUE := '"'; // default value
end;

destructor TODBCConnection.Destroy;
begin
  DisConnect;
  FreeAndNil(FParams);
  inherited Destroy;
end;

procedure TODBCConnection.DisConnect;
begin
  if Connected then begin
    SQLDisConnect(Fhdbc);
    SQLFreeHandle(SQL_HANDLE_DBC, Fhdbc);
    Fhdbc := SQL_NULL_HANDLE;
  end;
end;

function TODBCConnection.ExecuteDirectSQL(
  const ASQLText: AnsiString;
  const ASilentOnError: Boolean
): Boolean;
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
begin
  CheckSQLResult(SQLAllocHandle(SQL_HANDLE_STMT, Fhdbc, h));
  try
    VRes := SQLExecDirectA(h, PAnsiChar(ASQLText), Length(ASQLText));
    Result := SQL_SUCCEEDED(VRes);
    if (not Result) and (not ASilentOnError) then
      CheckStatementResult(h, VRes, EODBCDirectExecError);
  finally
    SQLFreeHandle(SQL_HANDLE_STMT, h);
  end;
end;

function TODBCConnection.ExecuteDirectWithBlob(
  const ASQLText, AFullParamName: AnsiString;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  const ASilentOnError: Boolean
): Boolean;
var
  h: SQLHANDLE;
  VRes: SQLRETURN;
  VColumnSize: SQLULEN;
  VStrLen_or_IndPtr: SQLLEN;
  VFullSQLText: AnsiString;
begin
  h := SQL_NULL_HANDLE;
  try
    VFullSQLText := StringReplace(ASQLText, AFullParamName, c_RTL_ODBC_Paramname, [rfReplaceAll,rfIgnoreCase]);

    // allocate statement
    CheckSQLResult(SQLAllocHandle(SQL_HANDLE_STMT, Fhdbc, h));

    if (ABufferAddr<>nil) and (ABufferSize>0) then begin
      // has data
      VStrLen_or_IndPtr := ABufferSize;
      VColumnSize := ABufferSize;
    end else begin
      // is null
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
      ABufferAddr,
      VStrLen_or_IndPtr,
      @VStrLen_or_IndPtr
    );

    CheckStatementResult(h, VRes, EODBCDirectExecBlobError);

    // execute
    VRes := SQLExecDirectA(h, PAnsiChar(VFullSQLText), Length(VFullSQLText));

    Result := SQL_SUCCEEDED(VRes);

    if (not Result) and (not ASilentOnError) then
      CheckStatementResult(h, VRes, EODBCDirectExecBlobError);
  finally
    SQLFreeHandle(SQL_HANDLE_STMT, h);
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

function TODBCConnection.GetUID: String;
begin
  Result := FParams.Values['UID'];
end;

function TODBCConnection.IsConnected: Boolean;
begin
  Result := (Fhdbc <> SQL_NULL_HANDLE)
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
  const ASQLText: AnsiString;
  const ABufPtr: POdbcFetchCols
): Boolean;
var
  VRes: SQLRETURN;
begin
  Assert(ABufPtr<>nil);

  CheckSQLResult(SQLAllocHandle(SQL_HANDLE_STMT, Fhdbc, ABufPtr^.Stmt));

  VRes := SQLExecDirectA(ABufPtr^.Stmt, PAnsiChar(ASQLText), Length(ASQLText));
  CheckStatementResult(ABufPtr^.Stmt, VRes, EODBCOpenFetchError);

  Result := ABufPtr^.DescribeAndBind;
end;

procedure TODBCConnection.SetConnected(const Value: Boolean);
begin
  if Value then
    Connect
  else
    DisConnect;
end;

procedure TODBCConnection.SetDSN(const Value: String);
begin
  FParams.Values['DSN'] := Value;
end;

procedure TODBCConnection.SetParams(const Value: TStrings);
begin
  FParams.Assign(Value);
end;

procedure TODBCConnection.SetPWD(const Value: String);
begin
  FParams.Values['PWD'] := Value;
end;

procedure TODBCConnection.SetUID(const Value: String);
begin
  FParams.Values['UID'] := Value;
end;

function TODBCConnection.TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean;
var
  VFullSQL: AnsiString;
begin
  VFullSQL := 'select 1 as a from ' + AFullyQualifiedQuotedTableName + ' where 0=1';
  Result := ExecuteDirectSQL(VFullSQL, TRUE);
end;

{ TOdbcEnvironment }

procedure TOdbcEnvironment.Close;
begin
  if (HENV <> SQL_NULL_HANDLE) then begin
    SQLFreeHandle(SQL_HANDLE_ENV, HENV);
    HENV := SQL_NULL_HANDLE;
  end;
end;

function TOdbcEnvironment.FindDSN(const ASystemDSN: AnsiString; out ADescription: AnsiString): Boolean;
var
  VResult: SQLRETURN;
  VDirection: SQLUSMALLINT;
  VServerName: array [0..SQL_MAX_DSN_LENGTH] of AnsiChar;
  VDescription: array [0..SQL_MAX_OPTION_STRING_LENGTH] of AnsiChar;
  VSize1, VSize2: SQLSmallint;
  VServerNameStr: AnsiString;
begin
  Load;
  
  Result := FALSE;
  ADescription := '';

  if (0=Length(ASystemDSN)) then
    Exit;

  VDirection := SQL_FETCH_FIRST_SYSTEM; // SQL_FETCH_FIRST;
  repeat
    // перечисляем
    VResult := SQLDataSourcesA(HENV,
      VDirection,
      VServerName,
      SQL_MAX_DSN_LENGTH,
      @VSize1,
      VDescription,
      SQL_MAX_OPTION_STRING_LENGTH,
      @VSize2
    );

    if SQL_SUCCEEDED(VResult) then begin
      // ok
      if (VSize1 = Length(ASystemDSN)) then begin
        SetString(VServerNameStr, PAnsiChar(@(VServerName[0])), VSize1);

        // check servername
        if SameText(VServerNameStr, ASystemDSN) then begin
          // found
          SetString(ADescription, PAnsiChar(@(VDescription[0])), VSize2);
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
