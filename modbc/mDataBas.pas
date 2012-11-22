unit mDataBas;

{$I mODBC.INC}

interface

uses
  Windows, SysUtils, Classes,
  Forms, Db,controls,
  mSession, ODBCsql;

type
  TmDataBase = class;
  TmDriverCompletion = (sdPrompt,sdComplete,sdCompleteReq,sdNoPrompt);
  TmOdbcCursors = (ocUSE_IF_NEEDED, ocUSE_ODBC, ocUSE_DRIVER);
  TmOdbcCreateDSN = (cdADD_DSN, cdCONFIG_DSN, cdREMOVE_DSN, cdADD_SYSDSN,
                     cdCONFIG_SYSDSN, cdREMOVE_SYSDSN);
  TmLoginEvent = procedure(Database: TmDatabase) of object;
  //TmIsolationLevels = (TxnDefault, TxnDirtyRead, TxnReadCommitted, TxnRepeatableRead, TxnSerializable);

  TmDataBase = class(TComponent)
  private
    { Private declarations }
//    FDataBaseName: String; stored in Fparams
    FDsnParams: String;
    FDataSetList:  TList;
    FDriverCompletion: TmDriverCompletion;
    fhdbc: SQLHDBC;
    FOdbcCursors: TmOdbcCursors;
    FOnLogin: TmLoginEvent;
    FParams: TStrings;
    FSession: TmSession;
    //FTransIsolation: TmIsolationLevels;
    FWaitCursor: TCursor;
    FOldCursor: TCursor;
    FShowWaitCursor: boolean;
    FConnectWithParams: Boolean;
    function GetConnected:Boolean;
    procedure SetParams(Value: TStrings);
    procedure CheckSQLResult( sqlres:SQLRETURN);
    procedure SetSession( s:TmSession);
    function GetDatabaseName:String;
    function GetUID: String;
    function GetPWD: String;
    procedure SetDatabaseName(Name:String);
    procedure SetWaitCursor(const Value: TCursor);
    procedure SetOldCursor(const Value: TCursor);
    procedure SetShowWaitCursor(const Value: boolean);
    procedure SetConnected(const Value: Boolean);
  protected
    { Protected declarations }
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    property OldCursor:TCursor read FOldCursor write SetOldCursor;
  public
    { Public declarations }
    property Connected: Boolean read GetConnected write SetConnected;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function BDE2SqlType( aFieldType: TFieldType): SQLSMALLINT;
    procedure Connect;
    procedure DisConnect;
    function GetHENV:SQLHANDLE;
    procedure ODBCDriverInfo(
        InfoType:SQLUSMALLINT;
        InfoValuePtr:SQLPOINTER; BufferLength:SQLSMALLINT;
        StringLengthPtr:PSQLSMALLINT);
    procedure ConfigureDSN(
        Action: TmOdbcCreateDSN;
        DsnName: string;
        Driver: string;
        Parameters: TStringList);
    function DriverOfDataSource( DSN:String):String;
    property hdbc: SQLHDBC read fhdbc;
    procedure GetColumnNames(const ATable: string; AList:TStrings);
    procedure GetDatSourceNames( tlist: TStrings);
    procedure GetDriverNames( tlist: TStrings);
    procedure GetTableNames( AList: TStrings);
    procedure GetPrimaryKeys(const ATable: string; AList:TStrings);
    procedure GetProcNames( AList: TStrings);
    procedure GetDsnParams( AList: TStrings);
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    procedure IncludeDataSet( Adataset: TDataSet);
    procedure ExcludeDataSet( Adataset: TDataSet);
    procedure BusyCursor;
    procedure RestoreCursor;

    procedure ExecuteDirectSQL(const ASQLText: String);

    property SystemDSN: String read GetDataBaseName;
    property UID: String read GetUID;
    property PWD: String read GetPWD;

    property ConnectWithParams: Boolean read FConnectWithParams write FConnectWithParams default FALSE;

  published
    { Published declarations }
    property DataBaseName: String read GetDataBaseName write SetDataBaseName;
    property DriverCompletion: TmDriverCompletion read    FDriverCompletion
                                                  write   FDriverCompletion
                                                  default sdCompleteReq;
    property OdbcCursors: TmOdbcCursors
               read FOdbcCursors write FOdbcCursors default ocUSE_DRIVER;
    property OnConnect: TmLoginEvent read FOnLogin write FOnLogin;
    property Params: TStrings read FParams write SetParams;
    property Session: TmSession read FSession write SetSession;
    (*
    property TransIsolation: TmIsolationLevels read FTransIsolation
                                               write FTransIsolation
                                               default TxnDefault;
    *)
    property WaitCursor:TCursor read FWaitCursor write SetWaitCursor;
    property ShowWaitCursor:boolean read FShowWaitCursor write SetShowWaitCursor;

  end;

implementation

uses mQuery, mconst, mExcept;

const SQL_NAME_LEN = 128;

constructor TmDatabase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConnectWithParams := FALSE;
  FDataSetList      := TList.Create;
  FParams           := TStringList.Create;
  FDriverCompletion := sdCompleteReq;
  FOdbcCursors      := ocUSE_DRIVER;
  FSession          := nil;
  //FTransIsolation   := TxnDefault;
  fhdbc             := 0;
  FWaitCursor       :=crSQLWait;
end;

destructor TmDataBase.Destroy;
begin
  if Connected then
    DisConnect;
  FDataSetList.free;
  FParams.Free;
  inherited Destroy;
end;

procedure TmDataBase.CheckSQLResult( sqlres:SQLRETURN);
begin
  if (sqlres <> SQL_SUCCESS) and (sqlres <> SQL_SUCCESS_WITH_INFO) then
    raise ESQLerror.CreateDiag( SQL_HANDLE_DBC, fhdbc, sqlres);
end;

procedure TmDataBase.StartTransaction;
var
   us: SQLUSMALLINT;
begin
  ODBCDriverInfo( SQL_TXN_CAPABLE, SQLPOINTER(@us), Sizeof( SQLUSMALLINT), nil);

  if us = SQL_TC_NONE then
    raise Exception.Create('Driver not support transactions');

  CheckSQLResult( SQLSetConnectAttr( hdbc, SQL_ATTR_AUTOCOMMIT,
                                     SQLPOINTER( SQL_AUTOCOMMIT_OFF),
                                     SQL_IS_UINTEGER));
end;

procedure TmDataBase.Commit;
begin
  CheckSQLResult( SQLEndTran( SQL_HANDLE_DBC, hdbc, SQL_COMMIT));
end;

procedure TmDataBase.Rollback;
begin
  CheckSQLResult( SQLEndTran( SQL_HANDLE_DBC, hdbc, SQL_ROLLBACK));
end;

procedure TmDataBase.Connect;
var
  i, VConnectResult: SQLRETURN;
  SServer: array [0..1025] of Char;
  cbout:   SQLSMALLINT;
  ConnectionString, VUID, VPWD: String;
  dc:      SQLUSMALLINT;
begin
  if Connected then
    exit;
  try
    BusyCursor;
    if SQLAllocHandle(SQL_HANDLE_DBC, GetHENV, fhdbc)<>SQL_SUCCESS then
      raise Exception.Create( SmAllocateHDBCError);

    try
      case FOdbcCursors of
        ocUSE_IF_NEEDED: dc:=SQL_CUR_USE_IF_NEEDED;
        ocUSE_ODBC:      dc:=SQL_CUR_USE_ODBC;
        ocUSE_DRIVER:    dc:=SQL_CUR_USE_DRIVER;
        else             dc:=SQL_CUR_USE_DRIVER;
      end;

      CheckSQLResult( SQLSetConnectAttr( hdbc, SQL_ATTR_ODBC_CURSORS,
                                         SQLPOINTER( dc),
                                         SQL_IS_UINTEGER));
      if Assigned(FOnLogin) then
        FOnLogin( Self);
  {
      if DataBaseName <> ''
        then ConnectionString := 'DSN=' + DataBaseName
        else }ConnectionString := '';

      for i := 0 to FParams.Count-1 do
      begin
        if Length(ConnectionString) > 0 then
          ConnectionString := ConnectionString + ';';
        ConnectionString := ConnectionString+FParams[i];
      end;

      case DriverCompletion of
        sdPrompt:      dc := SQL_DRIVER_PROMPT;
        sdComplete:    dc := SQL_DRIVER_COMPLETE;
        sdCompleteReq: dc := SQL_DRIVER_COMPLETE_REQUIRED;
        sdNoPrompt:    dc := SQL_DRIVER_NOPROMPT;
        else           dc := SQL_DRIVER_COMPLETE_REQUIRED;
      end;

      FDsnParams:='';
      try
        if ConnectWithParams then begin
          // via connectionstring
          VConnectResult := SQLDriverConnect(
            fhdbc,
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
          ConnectionString := SystemDSN;
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

        CheckSQLResult(VConnectResult);
      except on E: ESQLerror do
        if E.NativeError = SQL_NO_DATA then
        begin
           E.Message:=SmDatabaseNotOpened;
           raise;
        end else
        if (E.SqlState <> '01000') then
          raise;
      end;
      FDsnParams := StrPas(SServer);

      (*
      case FTransIsolation of
        TxnDirtyRead:     dc := SQL_TXN_READ_UNCOMMITTED;
        TxnReadCommitted: dc := SQL_TXN_READ_COMMITTED;
        TxnRepeatableRead:dc := SQL_TXN_REPEATABLE_READ;
        TxnSerializable:  dc := SQL_TXN_SERIALIZABLE;
        else              dc := 0;
      end;

      if dc <> 0 then
        CheckSQLResult( SQLSetConnectAttr( hdbc, SQL_ATTR_TXN_ISOLATION,
                                           SQLPOINTER( dc),
                                           SQL_IS_INTEGER));
      *)
    except
      SQLFreeHandle( SQL_HANDLE_DBC, fhdbc);
      fhdbc := 0;
      raise;
    end;
  finally
    restorecursor;
  end;
end;

procedure TmDataBase.DisConnect;
var
  i: integer;
begin
  if not Connected then
    exit;
  try
    BusyCursor;
    for i := 0 to FDataSetList.Count-1 do
      with TmCustomQuery(FDataSetList.Items[i]) do
         FreeStmt;

    SQLDisConnect(fhdbc);
    SQLFreeHandle(SQL_HANDLE_DBC, fhdbc);
    fhdbc := 0;
  finally
    restorecursor;
  end;
end;

function TmDataBase.GetConnected:Boolean;
begin
  Result:=(fhdbc<>0);
end;

procedure TmDataBase.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (Operation = opInsert) and (AComponent is TmCustomQuery) then
  begin
    with TmCustomQuery(AComponent) do
      if DataBase = nil then
        DataBase := Self;
  end;
end;

procedure TmDatabase.SetParams(Value: TStrings);
begin
  FParams.Assign(Value);
end;

procedure TmDatabase.ODBCDriverInfo( InfoType:SQLUSMALLINT;
                                     InfoValuePtr:SQLPOINTER;
                                     BufferLength:SQLSMALLINT;
                                     StringLengthPtr:PSQLSMALLINT);
var
  sqlres: SQLRETURN;
begin
  sqlres := SQLGetInfo( hdbc, InfoType, InfoValuePtr, BufferLength, StringLengthPtr);
  case sqlres of
    SQL_SUCCESS:;
    SQL_SUCCESS_WITH_INFO: raise ESQLerror.CreateDiag( SQL_HANDLE_DBC, hdbc, sqlres);
    SQL_STILL_EXECUTING:   raise ESQLerror.Create('SQL_STILL_EXECUTING');
    SQL_ERROR:             raise ESQLerror.CreateDiag( SQL_HANDLE_DBC, hdbc, sqlres);
    SQL_INVALID_HANDLE:    raise ESQLerror.Create( 'SQL_INVALID_HANDLE');
    else                   raise ESQLerror.Create( 'unknown SQL result');
  end;
end;

function TmDatabase.DriverOfDataSource( DSN:String):String;
var
  ServerName: array [0..SQL_MAX_DSN_LENGTH] of Char;
  DriverName: array [0..255] of Char;
begin
  Result := '';
  if SQLDataSources( GetHENV, SQL_FETCH_FIRST,
                     ServerName, SQL_MAX_DSN_LENGTH, nil,
                     DriverName, 255, nil) = SQL_SUCCESS then
  repeat
    if StrPas(ServerName) = DSN then
    begin
      Result := StrPas( DriverName);
      exit;
    end;
  until SQLDataSources( GetHENV, SQL_FETCH_NEXT,
                        ServerName, SQL_MAX_DSN_LENGTH, nil,
                        DriverName, 255, nil) <> SQL_SUCCESS;
end;


procedure TmDatabase.ConfigureDSN( Action: TmOdbcCreateDSN;
                                   DsnName: string;
                                   Driver: string;
                                   Parameters: TStringList);
var
  sParameters: string;
  iAction: integer;
  i: integer;
  fErrorCode: SQLINTEGER;
  lpszErrorMsg: array [0..80] of Char;
  cbErrorMsg: SQLUSMALLINT;
  w_handle:Integer;
begin
  case Action of
    cdADD_DSN        : iAction := ODBC_ADD_DSN;
    cdCONFIG_DSN     : iAction := ODBC_CONFIG_DSN;
    cdREMOVE_DSN     : iAction := ODBC_REMOVE_DSN;
    cdADD_SYSDSN     : iAction := ODBC_ADD_SYS_DSN;
    cdCONFIG_SYSDSN  : iAction := ODBC_CONFIG_SYS_DSN;
    cdREMOVE_SYSDSN  : iAction := ODBC_REMOVE_SYS_DSN;
    else               iAction := 0;
  end;

  sParameters := '';
  sParameters := sParameters + 'DSN=' + DsnName + ';';

  if Assigned(Parameters) then
    for i:=0 to Parameters.Count-1 do
      sParameters := sParameters + Parameters[i]+';';

  if sParameters <> '' then
    Delete(sParameters,Length(sParameters),1);

  if (Action in [cdCONFIG_DSN,cdCONFIG_SYSDSN,
                 cdREMOVE_DSN,cdCONFIG_SYSDSN]) and (Driver='') then
    Driver := DriverOfDataSource(DsnName);
  if DriverCompletion=sdNoPrompt then w_handle := SQL_NULL_HANDLE
                                 else w_handle := Application.Handle;
  if iAction <> 0 then
    if SQLConfigDataSource( w_handle, iAction, Driver, sParameters)<>1 then
    begin
      SQLInstallerError(1, @fErrorCode, lpszErrorMsg, 80, @cbErrorMsg);
      raise ESQLerror.Create( 'SQLConfigDataSource:' + #13 + StrPas( lpszErrorMsg));
    end;
end;

procedure TmDatabase.GetDatSourceNames( tlist: TStrings);
var
  ServerName: array [0..SQL_MAX_DSN_LENGTH] of Char;
  sl:         SQLSMALLINT;
  sqlResult: integer;
begin
  tlist.Clear;
  if SQLDataSources( GetHENV, SQL_FETCH_FIRST,
                     ServerName, SQL_MAX_DSN_LENGTH, @sl,
                     nil, 0, nil) = SQL_SUCCESS then
  repeat
    tlist.add( StrPas(ServerName));
    sqlresult := SQLDataSources( GetHENV, SQL_FETCH_NEXT,
                                 ServerName, SQL_MAX_DSN_LENGTH, @sl,
                                 nil, 0, nil)
  until (sqlResult <> SQL_SUCCESS) and (sqlResult <> SQL_SUCCESS_WITH_INFO)
end;

procedure TmDatabase.GetDriverNames( tlist: TStrings);
var
  DriverName: array [0..SQL_MAX_OPTION_STRING_LENGTH] of Char;
  sl:         SQLSMALLINT;
  sqlResult: integer;
begin
  tlist.Clear;

  sqlResult := SQLDrivers( GetHENV, SQL_FETCH_FIRST, DriverName,
                           SQL_MAX_OPTION_STRING_LENGTH, @sl, nil, 0, nil);

  if (sqlResult = SQL_SUCCESS) or (sqlResult = SQL_SUCCESS_WITH_INFO) then
  repeat
    tlist.add( StrPas(DriverName));
    sqlResult := SQLDrivers( GetHENV, SQL_FETCH_NEXT, DriverName,
                             SQL_MAX_OPTION_STRING_LENGTH, @sl, nil, 0, nil);

  until (sqlResult <> SQL_SUCCESS) and
        (sqlResult <> SQL_SUCCESS_WITH_INFO)
end;

procedure TmDatabase.GetTableNames( AList: TStrings);
var
  h : SQLHANDLE;
  ATableName : array[0..SQL_NAME_LEN + 1] of char;
  ATableType : array[0..SQL_NAME_LEN + 1] of char;
  l : SQLINTEGER;//DWORD;
  Res : SQLRETURN;
begin
  AList.Clear;
  Connect;

  if SQLAllocHandle( SQL_HANDLE_STMT, hdbc,h ) = SQL_SUCCESS then
  try
    Busycursor;
    Res := SQLTables( h, nil, 0, nil, 0, nil, 0, nil, 0);
    if Res = SQL_SUCCESS then
    begin
      SQLBindCol( h, 3, SQL_CHAR, @ATableName[0], SQL_NAME_LEN, @l);
      SQLBindCol( h, 4, SQL_CHAR, @ATableType[0], SQL_NAME_LEN, @l);

      Res := SQLFetch( h );
      while ( Res = SQL_SUCCESS ) do
      begin
        if StrPas( ATableType)<>'SYSTEM TABLE' then
          AList.Add( StrPas( ATableName ));
        Res := SQLFetch( h);
      end;
    end;
  finally
    SQLFreeHandle( SQL_HANDLE_STMT,h );
    restorecursor;
  end;
end;

function TmDataBase.GetUID: String;
begin
  Result := FParams.Values['UID'];
end;

procedure TmDatabase.GetProcNames( AList: TStrings);
var
  h: SQLHANDLE;
  AProcName: array[0..SQL_NAME_LEN + 1] of char;
  l: SQLINTEGER;
  Res: SQLRETURN;
begin
  Connect;

  if SQLAllocHandle( SQL_HANDLE_STMT, hdbc,h ) = SQL_SUCCESS then
  try
    AList.beginupdate;
    AList.Clear;
    Res := SQLProcedures( h, nil, 0, nil, 0,nil, 0);
    if Res = SQL_SUCCESS then
    begin
      SQLBindCol( h, 3, SQL_CHAR, @AProcName[0], SQL_NAME_LEN, @l);

      Res := SQLFetch( h );
      while ( Res = SQL_SUCCESS ) do
      begin
        AList.Add( StrPas( AProcName ) );
        Res := SQLFetch( h );
      end;
    end;
  finally
    SQLFreeHandle( SQL_HANDLE_STMT,h );
    AList.Endupdate;
  end;
end;


function TmDataBase.GetPWD: String;
begin
  Result := FParams.Values['PWD'];
end;

procedure TmDatabase.IncludeDataSet( Adataset: Tdataset);
begin
  if FdataSetList.IndexOf(Adataset)<0 then
    FdataSetList.add(adataset);
end;

procedure TmDatabase.ExcludeDataSet( Adataset: Tdataset);
var
  i: integer;
begin
  i := FdataSetList.IndexOf(Adataset);
  if i >= 0 then
    FdataSetList.delete(i);
end;

procedure TmDataBase.ExecuteDirectSQL(const ASQLText: String);
begin
  CheckSQLResult(SQLExecDirect(hdbc, PChar(ASQLText), Length(ASQLText)));
end;

procedure TmDataBase.GetColumnNames(const ATable: string; AList: TStrings);
var
  h: SQLHANDLE;
  ATableName: array[0..SQL_NAME_LEN + 1] of char;
  l: SQLINTEGER;// DWORD;
  Res: SQLRETURN;
begin
  AList.BeginUpdate;
  AList.Clear;
  Connect;
  if SQLAllocHandle( SQL_HANDLE_STMT, hdbc,h ) = SQL_SUCCESS then
  begin
    try
      Res := SQLColumns( h, nil, 0, nil, 0, pchar(ATable), length(Atable), nil, 0);
      if Res = SQL_SUCCESS then
      begin
        SQLBindCol( h, 4, SQL_CHAR, @ATableName[0], SQL_NAME_LEN, @l);
        Res := SQLFetch( h );
        while ( Res = SQL_SUCCESS ) do
        begin
          AList.Add( StrPas( ATableName ) );
          Res := SQLFetch( h );
        end;
      end;
    finally
      SQLFreeHandle( SQL_HANDLE_STMT,h );
      AList.EndUpdate;
    end;
  end;
end;

procedure TmDataBase.GetPrimaryKeys(const ATable: string; AList: TStrings);
var
  h: SQLHANDLE;
  ATableName: array[0..SQL_NAME_LEN + 1] of char;
  l: SQLINTEGER;
  Res: SQLRETURN;
begin
  AList.BeginUpdate;
  AList.Clear;
  Connect;
  if SQLAllocHandle( SQL_HANDLE_STMT, hdbc, h ) = SQL_SUCCESS then
  begin
    try
       Res := SQLPrimaryKeys( h, nil, 0, nil, 0, pchar(ATable), length(Atable));
       if Res = SQL_SUCCESS then
       begin
         SQLBindCol( h, 4, SQL_CHAR, @ATableName[0], SQL_NAME_LEN, @l);
         Res := SQLFetch( h );
         while ( Res = SQL_SUCCESS ) do
         begin
           AList.Add( StrPas( ATableName ) );
           Res := SQLFetch( h );
         end;
       end;
     finally
       SQLFreeHandle( SQL_HANDLE_STMT,h );
       AList.EndUpdate;
    end;
  end;
end;

procedure TmDataBase.SetSession( s:TmSession);
begin
  DisConnect;
  FSession := s;
end;

function TmDatabase.GetHENV:SQLHANDLE;
begin
  if FSession <> nil
    then Result := FSession.HENV
    else Result := GlobalSession.HENV;
end;

procedure TmDatabase.GetDsnParams( AList: TStrings);
begin
    Alist.Text := FDsnParams;
end;

function TmDataBase.GetDatabaseName: String;
begin
  Result := FParams.Values['DSN'];
end;

procedure TmDataBase.SetConnected(const Value: Boolean);
begin
  if Value then
    Connect
  else
    DisConnect;
end;

procedure TmDataBase.SetDatabaseName(Name: String);
begin
  FParams.Values['DSN'] := Name;
end;

function TmDataBase.BDE2SqlType( aFieldType: TFieldType): SQLSMALLINT;
begin // datatypes depend from driver
  case aFieldType of
    ftString:   result := SQL_CHAR;
    ftWord:     result := SQL_SMALLINT;
    ftSmallint: result := SQL_SMALLINT;
    ftInteger,
    ftAutoInc:  result := SQL_INTEGER;
//    ftTime:
    ftDate:     result := SQL_DATE; //SQL_TYPE_DATE;
    ftDateTime: result := SQL_TIMESTAMP; //SQL_TYPE_TIMESTAMP;
    ftBCD,
    ftCurrency,
    ftFloat:    result := SQL_DOUBLE;
    ftBoolean:  result := SQL_SMALLINT;
    ftMemo:     result := SQL_LONGVARCHAR;
    ftBlob:     result := SQL_LONGVARBINARY;
    else        result := 0;
  end;
end;

procedure TmDataBase.SetWaitCursor(const Value: TCursor);
begin
  FWaitCursor := Value;
end;

procedure TmDataBase.SetOldCursor(const Value: TCursor);
begin
  FOldCursor := Value;
end;

procedure TmDataBase.BusyCursor;
begin
  if ShowWaitCursor then
  begin
    if screen.cursor<>WaitCursor then
    begin
      oldcursor:=screen.cursor;
      screen.cursor:=WaitCursor;
    end;
  end;
end;

procedure TmDataBase.RestoreCursor;
begin
  if ShowWaitCursor then
  begin
    if screen.cursor=WaitCursor then
    begin
      screen.cursor:=oldcursor;
    end;
  end;
end;

procedure TmDataBase.SetShowWaitCursor(const Value: boolean);
begin
  FShowWaitCursor := Value;
end;

end.
