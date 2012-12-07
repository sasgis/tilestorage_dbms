unit u_ODBC;

interface

uses
  SysUtils,
  DB,
  OdbcApi,
  u_ODBC_ENV,
  u_ODBC_STMT,
  u_ODBC_UTILS,
  Classes;

(*
   simple ODBC realization
*)

type
  EConnectFlag = (eConnect, eReconnect, eDisconnect);

  TODBCConnection = class(TCustomConnection)
  private
    // Environment object
    FEnvironment: IODBCEnvironment;
    // Connection Handle
    FDBCHandle: SQLHDBC;
    FConnectionResult: SQLRETURN;
  private
    FConnectWithParams: Boolean;
    FKeepConnection: Boolean;
    FParams: TStrings;
    procedure SetParams(const Value: TStrings);
    function GetSystemDSN: String;
    function GetPWD: String;
    function GetUID: String;
  private
    function InternalConnected: Boolean; inline;
    procedure InternalDeallocateConnectionHandle;
  private
    procedure CheckActive;
    procedure CheckInactive;
    procedure CheckConnection(const eFlag: eConnectFlag);
  protected
    procedure DoConnect; override;
    procedure DoDisconnect; override;
    function GetConnected: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    // close all registered datasets
    procedure CloseDataSets;

    function ExecuteDirectSQL(
      const ASQLText: String;
      const ASilentOnError: Boolean
    ): Boolean;

    function ExecuteDirectWithBlob(
      const ASQLText: String;
      const AFullParamName: String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean
    ): Boolean;

    function OpenDirectSQL(
      const ASQLText: String;
      out AStatement: IODBCStatement;
      const ASilentOnError: Boolean
    ): Boolean;

    function OpenDirectWithBlob(
      const ASQLText: String;
      const AFullParamName: String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      out AStatement: IODBCStatement;
      const ASilentOnError: Boolean
    ): Boolean;

    function TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
  public
    property ConnectWithParams: Boolean read FConnectWithParams write FConnectWithParams default FALSE;
    property KeepConnection: Boolean read FKeepConnection write FKeepConnection default FALSE;
    property Params: TStrings read FParams write SetParams;
    property SystemDSN: String read GetSystemDSN;
    property UID: String read GetUID;
    property PWD: String read GetPWD;
  end;

  // very simple dataset with params
  TODBCDataset = class(TDataSet)
  private
    FConnection: TODBCConnection;
    FCommandText: String;
    FParsedSQL: WideString;
    FParams: TParams;
    FAutoCreateParams: Boolean;
  private
    procedure SetCommandText(const Value: String);
    procedure SetParameters(const Value: TParams);
    procedure SetConnection(const Value: TODBCConnection);
    procedure SetAutoCreateParams(const Value: Boolean);
  protected
    procedure BeforeSQLTextChanged;
    procedure AfterSQLTextChanged;
    procedure DoParseSQL;
  protected { abstract methods required for all datasets }
    function GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult; override;
    procedure InternalClose; override;
    procedure InternalHandleException; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalOpen; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    property AutoCreateParams: Boolean read FAutoCreateParams write SetAutoCreateParams default FALSE;
    property CommandText: String read FCommandText write SetCommandText;
    property SQLConnection: TODBCConnection read FConnection write SetConnection;
    property Params: TParams read FParams write SetParameters;
  end;

  // dataset to execute (un)prepared statements
  // to insert/update blobs
  TSQLQuery = class(TODBCDataset)
  protected
    FStatement: IODBCStatement;
  protected { abstract methods required for all datasets }
    function IsCursorOpen: Boolean; override;
  public
    function ExecSQL(const AExecDirect: Boolean = FALSE): Integer; deprecated;
  end;

  // dataset to open
  TSQLFetchableQuery = class(TSQLQuery)
  private
    // äëÿ ïîëó÷åíèÿ çíà÷åíèé â òåêóùåé çàïèñè
    FColumnCount: SmallInt;
  protected { abstract methods required for all datasets }
    procedure InternalClose; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalOpen; override;
  protected
    function AllocRecordBuffer: PChar; override;
    procedure FreeRecordBuffer(var Buffer: PChar); override;
    function GetRecordSize: Word; override;
    procedure InternalInitRecord(Buffer: PChar); override;
  public
    function GetFieldData(Field: TField; Buffer: Pointer): Boolean; overload; override;
  end;

implementation

uses
  SqlConst;

{ TODBCConnection }

procedure TODBCConnection.CheckActive;
begin
  if (not InternalConnected) then DatabaseError(SDatabaseClosed, Self);
end;

procedure TODBCConnection.CheckConnection(const eFlag: eConnectFlag);
begin
  if (eFlag in [eDisconnect, eReconnect]) then
    Close;
  if (eFlag in [eConnect, eReconnect]) then
    Open
end;

procedure TODBCConnection.CheckInactive;
begin
  if InternalConnected then
    if csDesigning in ComponentState then
      Close
    else
      DatabaseError(SdatabaseOpen, Self);
end;

procedure TODBCConnection.CloseDataSets;
begin
  //
end;

constructor TODBCConnection.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FKeepConnection := FALSE;
  FConnectWithParams := FALSE;
  FEnvironment := nil;
end;

destructor TODBCConnection.Destroy;
begin
  FEnvironment := nil;
  inherited Destroy;
end;

procedure TODBCConnection.DoConnect;
var
  VSystemDSN, VUID, VPWD: WideString;
begin
  // empty
  // inherited DoConnect;

  // check environment
  if (nil=FEnvironment) then
  begin
    if (nil=g_ODBCEnvironment) then begin
      g_ODBCEnvironment:=TODBCEnvironment.Create;
    end;
    FEnvironment:=g_ODBCEnvironment;
  end;

  // check env allocated
  FEnvironment.CheckErrors;

  // allocate connection handle
  FConnectionResult := SQLAllocHandle(SQL_HANDLE_DBC, FEnvironment.GetODBCHandle, FDBCHandle);
  if not SQL_SUCCEEDED(FConnectionResult) then
    raise EODBCNoConnection.CreateWithDiag(FConnectionResult, SQL_HANDLE_ENV, FEnvironment.GetODBCHandle);
  
  try
    if ConnectWithParams then begin
      // TODO: make ConnectionString and call SQLDriverConnect
      raise EODBCNotImplementedYetException.Create('SQLDriverConnect');
    end else begin
      // simple connect without additional params
      VSystemDSN := SystemDSN;
      VUID := UID;
      VPWD := PWD;
      FConnectionResult := SQLConnectW(
        FDBCHandle,
        PWideChar(VSystemDSN),
        Length(VSystemDSN),
        PWideChar(VUID),
        Length(VUID),
        PWideChar(VPWD),
        Length(VPWD)
      );
    end;

    if not SQL_SUCCEEDED(FConnectionResult) then
      raise EODBCConnectionError.CreateWithDiag(FConnectionResult, SQL_HANDLE_DBC, FDBCHandle);
  except
    // failed to connect - deallocate connection
    InternalDeallocateConnectionHandle;
    raise;
  end;
end;

procedure TODBCConnection.DoDisconnect;
begin
  // empty
  // inherited DoDisconnect;

  if InternalConnected then begin
    SQLDisconnect(FDBCHandle);
    InternalDeallocateConnectionHandle;
  end;
end;

function TODBCConnection.ExecuteDirectSQL(
  const ASQLText: String;
  const ASilentOnError: Boolean
): Boolean;
var
  VStatement: IODBCStatement;
begin
  Result := OpenDirectSQL(ASQLText, VStatement, ASilentOnError);
end;

function TODBCConnection.ExecuteDirectWithBlob(
  const ASQLText, AFullParamName: String;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  const ASilentOnError: Boolean
): Boolean;
var
  VStatement: IODBCStatement;
begin
  Result := OpenDirectWithBlob(ASQLText, AFullParamName, ABufferAddr, ABufferSize, VStatement, ASilentOnError);
end;

function TODBCConnection.GetConnected: Boolean;
begin
  Result := InternalConnected;
end;

function TODBCConnection.GetPWD: String;
begin
  Result := FParams.Values['PWD'];
end;

function TODBCConnection.GetSystemDSN: String;
begin
  Result := FParams.Values['SERVER'];
(*

--------------------------------------------------------------------------------------------------------------------------------
ASA:
Driver=Adaptive Server Anywhere 7.0;ENG=server.database_name;UID=myUsername;PWD=myPassword;DBN=myDataBase;LINKS=TCPIP(HOST=serverNameOrAddress);
Driver=Adaptive Server Anywhere 7.0;ENG=server.database_name;UID=myUsername;PWD=myPassword;DBN=myDataBase;LINKS=TCPIP(HOST=Server1:3322,Server2:7799);
Driver={Sybase SQL Anywhere 5.0};DefaultDir=c:\dbfolder\;Dbf=c:\mydatabase.db;Uid=myUsername;Pwd=myPassword;Dsn="";

--------------------------------------------------------------------------------------------------------------------------------
ASE:
Driver={SYBASE ASE ODBC Driver};Srvr=myServerAddress;Uid=myUsername;Pwd=myPassword;
Driver={SYBASE ASE ODBC Driver};NA=Hostname,Portnumber;Uid=myUsername;Pwd=myPassword;
Driver={Sybase ASE ODBC Driver};NetworkAddress=myServerAddress,5000;Db=myDataBase;Uid=myUsername;Pwd=myPassword;
Driver={Adaptive Server Enterprise};app=myAppName;server=myServerAddress;port=myPortnumber;db=myDataBase;uid=myUsername;pwd=myPassword;
Driver={SYBASE SYSTEM 11};Srvr=myServerAddress;Uid=myUsername;Pwd=myPassword;Database=myDataBase;

--------------------------------------------------------------------------------------------------------------------------------
DB2:
Driver={IBM DB2 ODBC DRIVER};Database=myDataBase;Hostname=myServerAddress;Port=1234;Protocol=TCPIP;Uid=myUsername;Pwd=myPassword;
Driver={IBM DB2 ODBC DRIVER};DBALIAS=DatabaseAlias;Uid=myUsername;Pwd=myPassword;
Driver={IBM DB2 ODBC DRIVER};Database=myDataBase;Hostname=myServerAddress;Port=1234;Protocol=TCPIP;Uid=myUsername;Pwd=myPassword;CurrentSchema=mySchema;

--------------------------------------------------------------------------------------------------------------------------------
Firebird:
DRIVER=Firebird/InterBase(r) driver;UID=SYSDBA;PWD=masterkey;DBNAME=C:\database\myData.fdb;
DRIVER=Firebird/InterBase(r) driver;UID=SYSDBA;PWD=masterkey;DBNAME=MyServer/3051:C:\database\myData.fdb;
DRIVER=Firebird/InterBase(r) driver;UID=SYSDBA;PWD=masterkey;DBNAME=aliasname;

--------------------------------------------------------------------------------------------------------------------------------
Informix:
Dsn='';Driver={INFORMIX 3.30 32 BIT};Host=hostname;Server=myServerAddress;Service=service-name;Protocol=olsoctcp;Database=myDataBase;Uid=myUsername;Pwd=myPassword;

--------------------------------------------------------------------------------------------------------------------------------
MSSQL:
Driver={SQL Server Native Client 11.0};Server=myServerAddress;Database=myDataBase;Uid=myUsername;Pwd=myPassword;


--------------------------------------------------------------------------------------------------------------------------------
MySQL:
Driver={MySQL ODBC 5.1 Driver};Server=localhost;Database=myDataBase;User=myUsername;Password=myPassword;Option=3;
Driver={MySQL ODBC 5.1 Driver};Server=myServerAddress;Database=myDataBase;User=myUsername;Password=myPassword;Option=3;
------
Driver={MySQL ODBC 3.51 Driver};Server=myServerAddress;Database=myDataBase;
User=myUsername;Password=myPassword;sslca=c:\cacert.pem;sslcert=c:\client-cert.pem;
sslkey=c:\client-key.pem;sslverify=1;Option=3;
------


--------------------------------------------------------------------------------------------------------------------------------
Oracle:
Driver={Oracle in OraHome92};Dbq=myTNSServiceName;Uid=myUsername;Pwd=myPassword;
Driver={Oracle in OraClient11g_home1};Dbq=myTNSServiceName;Uid=myUsername;Pwd=myPassword;
Driver={Microsoft ODBC for Oracle};Server=myServerAddress;Uid=myUsername;Pwd=myPassword;
------
Driver={Microsoft ODBC for Oracle};
CONNECTSTRING=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=server)(PORT=7001))(CONNECT_DATA=(SERVICE_NAME=myDb)));
Uid=myUsername;Pwd=myPassword;
------
Driver=(Oracle in XEClient);dbq=111.21.31.99:1521/XE;Uid=myUsername;Pwd=myPassword;

--------------------------------------------------------------------------------------------------------------------------------
PostgreSQL:
Driver={PostgreSQL};Server=IP address;Port=5432;Database=myDataBase;Uid=myUsername;Pwd=myPassword;
Driver={PostgreSQL ANSI};Server=IP address;Port=5432;Database=myDataBase;Uid=myUsername;Pwd=myPassword;
Driver={PostgreSQL UNICODE};Server=IP address;Port=5432;Database=myDataBase;Uid=myUsername;Pwd=myPassword;
Driver={PostgreSQL ANSI};Server=IP address;Port=5432;Database=myDataBase;Uid=myUsername;Pwd=myPassword;sslmode=require;
------
DRIVER={PostgreSQL ODBC Driver(UNICODE)};DATABASE=/*database*/;SERVER=students.ami.nstu.ru;PORT=5432;UID=/*user*/;PWD=/*pass*/;
SSLmode=disable;ReadOnly=0;Protocol=8.0;FakeOidIndex=0;ShowOidColumn=0;RowVersioning=0;ShowSystemTables=0;
ConnSettings=;Fetch=100;Socket=4096;UnknownSizes=0;MaxVarcharSize=255;MaxLongVarcharSize=8190;Debug=0;CommLog=0;
Optimizer=0;Ksqo=1;UseDeclareFetch=0;TextAsLongVarchar=1;UnknownsAsLongVarchar=0;BoolsAsChar=1;
Parse=0;CancelAsFreeStmt=0;ExtraSysTablePrefixes=dd_;LFConversion=1;UpdatableCursors=1;DisallowPremature=0;
TrueIsMinus1=0;BI=0;ByteaAsLongVarBinary=0;UseServerSidePrepare=0;LowerCaseIdentifier=0;XaOpt=1"
------
Connect Timeout=3600;Extended Properties=COMMAND_TIMEOUT=0

--------------------------------------------------------------------------------------------------------------------------------



*)

end;

function TODBCConnection.GetUID: String;
begin
  Result := FParams.Values['UID'];
end;

function TODBCConnection.InternalConnected: Boolean;
begin
  Result := (FDBCHandle<>nil)
end;

procedure TODBCConnection.InternalDeallocateConnectionHandle;
begin
  SQLFreeHandle(SQL_HANDLE_DBC, FDBCHandle);
  FDBCHandle := nil;
end;

function TODBCConnection.OpenDirectSQL(
  const ASQLText: String;
  out AStatement: IODBCStatement;
  const ASilentOnError: Boolean
): Boolean;
begin
  CheckActive;

  AStatement := TODBCStatement.CreateAndExecDirect(FDBCHandle, ASQLText);
  Result := SQL_SUCCEEDED(AStatement.GetLastResult);

  if (not AStatement.IsAllocated) OR ((not Result) and (not ASilentOnError)) then
    AStatement.CheckErrors;
end;

function TODBCConnection.OpenDirectWithBlob(
  const ASQLText, AFullParamName: String;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  out AStatement: IODBCStatement;
  const ASilentOnError: Boolean
): Boolean;
begin

end;

procedure TODBCConnection.SetParams(const Value: TStrings);
begin
  CheckInactive;
  FParams.Assign(Value);
end;

function TODBCConnection.TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
var
  VFullSQL: String;
begin
  VFullSQL := 'select 1 as a from ' + AFullyQualifiedQuotedTableName + ' where 0=1';
  Result := ExecuteDirectSQL(VFullSQL, TRUE);
end;

{ TODBCDataset }

procedure TODBCDataset.AfterSQLTextChanged;
begin
  if FAutoCreateParams then begin
    DoParseSQL;
  end;
end;

procedure TODBCDataset.BeforeSQLTextChanged;
begin

end;

constructor TODBCDataset.Create(AOwner: TComponent);
begin
  inherited;
  FCommandText := '';
  FParsedSQL := '';
  FConnection := nil;
  FParams := TParams.Create(Self);
  FAutoCreateParams := FALSE;
  SetUniDirectional(TRUE);
end;

destructor TODBCDataset.Destroy;
begin
  Close;
  SetConnection(nil);
  FreeAndNil(FParams);
  inherited;
end;

procedure TODBCDataset.DoParseSQL;
begin
  if (0=Length(CommandText)) then begin
    // nothing
    FParsedSQL := '';
    FParams.Clear;
  end else begin
    FParsedSQL := FParams.ParseSQL(CommandText, TRUE);
  end;
end;

function TODBCDataset.GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult;
begin
  // abstract inherited;

end;

procedure TODBCDataset.InternalClose;
begin
  // abstract inherited;
  // nothing
end;

procedure TODBCDataset.InternalHandleException;
begin
  // abstract inherited;
  // nothing
end;

procedure TODBCDataset.InternalInitFieldDefs;
begin
  // abstract inherited;
  // nothing
end;

procedure TODBCDataset.InternalOpen;
begin
  // abstract inherited;
  // nothing
end;

procedure TODBCDataset.SetAutoCreateParams(const Value: Boolean);
begin
  if (Value=FAutoCreateParams) then
    Exit;
  FAutoCreateParams := Value;
  if (FAutoCreateParams) then begin
    // parse
    DoParseSQL;
  end else begin
    // clear
    FParsedSQL := '';
  end;
end;

procedure TODBCDataset.SetCommandText(const Value: String);
begin
  if Value <> FCommandText then begin
    CheckInactive;
    BeforeSQLTextChanged;
    // apply new value
    FCommandText := Value; //Trim(Value);
    // reparse params
    AfterSQLTextChanged;
    // no datalinks
    DataEvent(dePropertyChange, 0);
  end;
end;

procedure TODBCDataset.SetConnection(const Value: TODBCConnection);
begin
  if (Value=FConnection) then
    Exit;

  // only if closed
  CheckInactive;

  // deregister from existing
  if Assigned(FConnection) then
    FConnection.UnRegisterClient(Self);

  // apply
  FConnection := Value;
  
  if Assigned(FConnection) then
  begin
    // register at new
    FConnection.RegisterClient(Self, nil);
  end;
end;

procedure TODBCDataset.SetParameters(const Value: TParams);
begin
  FParams.AssignValues(Value);
end;

{ TSQLQuery }

function TSQLQuery.ExecSQL(const AExecDirect: Boolean): Integer;
begin
  // don't care
  Result := 0;
  
  // ODBC allows direct execution
  if AExecDirect then begin
    FConnection.ExecuteDirectSQL(CommandText, FALSE);
    Exit;
  end;


  if (not AutoCreateParams) then
    DoParseSQL;

  // allocate statement
  FStatement := TODBCStatement.Create(FConnection.FDBCHandle, FParsedSQL);
  try
    // check
    FStatement.CheckErrors;

    // bind params
    if (Params <> nil) and (Params.count > 0) then begin
      FStatement.BindParams(Params);
    end;

    // execute
    FStatement.Execute;
  finally
    FStatement := nil;
  end;
end;

function TSQLQuery.IsCursorOpen: Boolean;
begin
  Result := (nil<>FStatement);
end;

{ TSQLFetchableQuery }

function TSQLFetchableQuery.AllocRecordBuffer: PChar;
var VRecordSize: Word;
begin
  VRecordSize := RecordSize;
  if (VRecordSize>0) then begin
    GetMem(Result, VRecordSize);
    InternalInitRecord(Result);
  end else begin
    Result := nil;
  end;
end;

procedure TSQLFetchableQuery.FreeRecordBuffer(var Buffer: PChar);
begin
  if (Buffer<>nil) then begin
    FreeMem(Buffer);
    Buffer:=nil;
  end;
end;

function TSQLFetchableQuery.GetFieldData(Field: TField; Buffer: Pointer): Boolean;
begin
  // extract data from resultset
end;

function TSQLFetchableQuery.GetRecordSize: Word;
begin
  Result := FColumnCount * SizeOf(TColumnBufferItem);
end;

procedure TSQLFetchableQuery.InternalClose;
begin
  // abstract inherited;

  Active := FALSE;

  // common actions
  BindFields(False);
  if DefaultFields then
    DestroyFields;

  // kill statement
  FStatement := nil;
end;

procedure TSQLFetchableQuery.InternalInitFieldDefs;
const
  c_ColumnNameDefaultLength = 128;
  c_DefaultBLOBSize = 0;
var
  i: SqlSmallint;
  VResult: SQLRETURN;
  VSTMTHandle: SQLHSTMT;
  VColumnName: AnsiString;
  VNameLength, VDataType, VDecimalDigits, VNullable: SQLSMALLINT;
  VColumnSize: SQLULEN;
  VFieldType: TFieldType;
  VFieldSize: Integer;
  VFieldDef: TFieldDef;
begin
  // abstract inherited;

  FieldDefs.Clear;

  VSTMTHandle := FStatement.GetODBCHandle;

  // obtain number of cols
  VResult := SQLNumResultCols(VSTMTHandle, FColumnCount);
  if not SQL_SUCCEEDED(VResult) then
    raise EODBCSQLNumResultColsError.CreateWithDiag(VResult, SQL_HANDLE_STMT, VSTMTHandle);

  if (FColumnCount<=0) then begin
    // TODO: something wrong
  end;

  // columns numerated from 1
  for i := 1 to FColumnCount do begin
    // allocate uniqe string
    SetLength(VColumnName, c_ColumnNameDefaultLength);
    
    // describe col
    VResult := SQLDescribeColA(
      VSTMTHandle,
      i,
      @VColumnName[1],
      c_ColumnNameDefaultLength,
      VNameLength,
      VDataType,
      VColumnSize,
      VDecimalDigits,
      VNullable
    );
    if not SQL_SUCCEEDED(VResult) then
      raise EODBCSQLDescribeColError.CreateWithDiag(VResult, SQL_HANDLE_STMT, VSTMTHandle);

    SetLength(VColumnName, VNameLength);

    // don't care about very long column names

    // switch on type
    // http://msdn.microsoft.com/en-us/library/windows/desktop/ms710150(v=vs.85).aspx
    case VDataType of
      SQL_CHAR: begin
        // CHAR(n) - Character string of fixed string length n
        VFieldType:=ftFixedChar;
        VFieldSize:=VColumnSize;
      end;
      SQL_VARCHAR: begin
        // VARCHAR(n) - Variable-length character string with a maximum string length n
        VFieldType:=ftString;
        VFieldSize:=VColumnSize;
      end;
      SQL_LONGVARCHAR: begin
        // LONG VARCHAR or TEXT or CLOB - Variable length character data. Maximum length is data source–dependent
        VFieldType:=ftMemo;
        VFieldSize:=c_DefaultBLOBSize;
      end;
      SQL_WCHAR: begin
        // WCHAR(n) - Unicode character string of fixed string length n
        VFieldType:=ftFixedWideChar;
        VFieldSize:=VColumnSize*SizeOf(Widechar);
      end;
      SQL_WVARCHAR: begin
        // VARWCHAR(n) - Unicode variable-length character string with a maximum string length n
        VFieldType:=ftWideString;
        VFieldSize:=VColumnSize*SizeOf(Widechar);
      end;
      SQL_WLONGVARCHAR: begin
        // LONGWVARCHAR - Unicode variable-length character data. Maximum length is data source–dependent
        VFieldType:=ftWideMemo;
        VFieldSize:=c_DefaultBLOBSize;
      end;
      SQL_DECIMAL: begin
        // DECIMAL(p,s) - Signed, exact, numeric value with a precision of at least p and scale s
        // TODO: make FmtBCD
        VFieldType := ftFloat;
        VFieldSize := 0;
      end;
      SQL_NUMERIC: begin
        // NUMERIC(p,s) - Signed, exact, numeric value with a precision p and scale s
        // TODO: make FmtBCD
        VFieldType := ftFloat;
        VFieldSize := 0;
      end;
      SQL_SMALLINT: begin
        // SMALLINT or INT2 - Exact numeric value with precision 5 and scale 0
        VFieldType := ftSmallint;
        VFieldSize := 0;
      end;
      SQL_INTEGER: begin
        // INTEGER or INT4 - Exact numeric value with precision 10 and scale 0
        VFieldType := ftInteger;
        VFieldSize := 0;
      end;
      SQL_REAL: begin
        // REAL - Signed, approximate, numeric value with a binary precision 24
        VFieldType := ftFloat;
        VFieldSize := 0;
      end;
      SQL_FLOAT: begin
        // FLOAT(p) - Signed, approximate, numeric value with a binary precision of at least p
        VFieldType := ftFloat;
        VFieldSize := 0;
      end;
      SQL_DOUBLE: begin
        // DOUBLE PRECISION - Signed, approximate, numeric value with a binary precision 53
        VFieldType := ftFloat;
        VFieldSize := 0;
      end;
      SQL_BIT: begin
        // BIT - Single bit binary data
        VFieldType := ftBoolean;
        VFieldSize := 0;
      end;
      SQL_TINYINT: begin
        // TINYINT or INT1 - Exact numeric value with precision 3 and scale 0
        VFieldType := ftSmallint;
        VFieldSize := 0;
      end;
      SQL_BIGINT: begin
        // BIGINT - Exact numeric value with precision 19 (if signed) or 20 (if unsigned) and scale 0
        VFieldType := ftLargeint;
        VFieldSize := 0;
      end;
      SQL_BINARY: begin
        // BINARY(n) - Binary data of fixed length n
        VFieldType := ftBytes;
        VFieldSize := VColumnSize;
      end;
      SQL_VARBINARY: begin
        // VARBINARY(n) - Variable length binary data of maximum length n. The maximum is set by the user.
        VFieldType := ftVarBytes;
        VFieldSize := VColumnSize;
      end;
      SQL_LONGVARBINARY: begin
        // LONG VARBINARY or IMAGE or BLOB - Variable length binary data. Maximum length is data source–dependent.
        VFieldType := ftBlob;
        VFieldSize := c_DefaultBLOBSize;
      end;
      SQL_TYPE_DATE: begin
        // DATE - Year, month, and day fields, conforming to the rules of the Gregorian calendar
        VFieldType := ftDate;
        VFieldSize := 0;
      end;
      SQL_TYPE_TIME: begin
        // TIME(p) - Hour, minute, and second fields. Precision p indicates the seconds precision.
        VFieldType := ftTime;
        VFieldSize := 0;
      end;
      SQL_TYPE_TIMESTAMP: begin
        // TIMESTAMP(p) - Year, month, day, hour, minute, and second fields, with valid values as defined for the DATE and TIME data types.
        VFieldType := ftDateTime;
        VFieldSize := 0;
      end;
      (*
      SQL_TYPE_UTCDATETIME: begin
        // UTCDATETIME - Year, month, day, hour, minute, second, utchour, and utcminute fields.
        VFieldType := ftDateTime;
        VFieldSize := 0;
      end;
      SQL_TYPE_UTCTIME: begin
        // UTCTIME - Hour, minute, second, utchour, and utcminute fields.
        VFieldType := ftTime;
        VFieldSize := 0;
      end;
      *)
      SQL_INTERVAL_MONTH,
      SQL_INTERVAL_YEAR,
      SQL_INTERVAL_YEAR_TO_MONTH,
      SQL_INTERVAL_DAY,
      SQL_INTERVAL_HOUR,
      SQL_INTERVAL_MINUTE,
      SQL_INTERVAL_SECOND,
      SQL_INTERVAL_DAY_TO_HOUR,
      SQL_INTERVAL_DAY_TO_MINUTE,
      SQL_INTERVAL_DAY_TO_SECOND,
      SQL_INTERVAL_HOUR_TO_MINUTE,
      SQL_INTERVAL_HOUR_TO_SECOND,
      SQL_INTERVAL_MINUTE_TO_SECOND: begin
        // intervals
        VFieldType := ftDateTime;
        VFieldSize := 0;
      end;
      SQL_GUID: begin
        // GUID - Fixed length GUID
        VFieldType := ftGuid;
        VFieldSize := 38; // see TGuidField.Create
      end;

      // additional values

      // OLD
      SQL_DATE: begin
        VFieldType := ftDate;
        VFieldSize := 0;
      end;
      SQL_TIMESTAMP: begin
        VFieldType := ftDateTime; // not ftTimeStamp
        VFieldSize := 0;
      end;
      SQL_TIME: begin
        // aka SQL_INTERVAL
        VFieldType := ftTime;
        VFieldSize := 0;
      end;

      // DB2
      SQL_GRAPHIC: begin
        VFieldType := ftGraphic;
        VFieldSize := VColumnSize;
      end;
      SQL_VARGRAPHIC: begin
        VFieldType := ftGraphic;
        VFieldSize := VColumnSize;
      end;
      SQL_LONGVARGRAPHIC: begin
        VFieldType := ftGraphic;
        VFieldSize := VColumnSize;
      end;
      SQL_BLOB: begin
        VFieldType := ftBlob;
        VFieldSize := c_DefaultBLOBSize;
      end;
      SQL_CLOB: begin
        VFieldType := ftMemo;
        VFieldSize := c_DefaultBLOBSize;
      end;
      SQL_DBCLOB: begin
        VFieldType := ftMemo;
        VFieldSize := c_DefaultBLOBSize;
      end;
      SQL_XML: begin
        VFieldType := ftFmtMemo;
        VFieldSize := c_DefaultBLOBSize;
      end;
      SQL_DATALINK: begin
        VFieldType := ftUnknown;
        VFieldSize := 0;
      end;
      SQL_USER_DEFINED_TYPE: begin
        VFieldType := ftUnknown;
        VFieldSize := VColumnSize;
      end;
      SQL_BLOB_LOCATOR: begin
        VFieldType := ftUnknown;
        VFieldSize := 0;
      end;
      SQL_CLOB_LOCATOR: begin
        VFieldType := ftUnknown;
        VFieldSize := 0;
      end;
      SQL_DBCLOB_LOCATOR: begin
        VFieldType := ftUnknown;
        VFieldSize := 0;
      end;
      
      // MSSQL
      SQL_VARIANT: begin
        VFieldType := ftVariant;
        VFieldSize := VColumnSize;
      end;

      // ORACLE
      SQL_REFCURSOR: begin
        VFieldType := ftCursor;
        VFieldSize := VColumnSize;
      end;

      // unknown for server/driver
      SQL_UNKNOWN_TYPE: begin
        VFieldType := ftUnknown;
        VFieldSize := VColumnSize;
      end;

      else begin
        // something unknown - but server/driver knows about it - RTFM
        VFieldType := ftUnknown;
        VFieldSize := 0;
      end;
    end;

    // restrict maximum string size
    if (VFieldSize >= dsMaxStringSize) then
    if (DefaultFieldClasses[VFieldType]=TStringField) then begin
      VFieldSize := (dsMaxStringSize-1);
    end;

    // raise on unknown field type
    if (ftUnknown=VFieldType) then
      raise EODBCUnknownFieldType.Create(
        // show field attribs
        'DataType='+IntToStr(VDataType)+', ColumnSize='+IntToStr(VColumnSize)+', ColumnName='+VColumnName
      );

    // make
    VFieldDef := FieldDefs.AddFieldDef;
    with VFieldDef do begin
      FieldNo := i;
      Name := VColumnName;
      DataType := VFieldType;
      Size := VFieldSize;
      Precision := VDecimalDigits;
      Required := FALSE;
    end;
  end;
end;

procedure TSQLFetchableQuery.InternalInitRecord(Buffer: PChar);
var VRecordSize: Word;
begin
  // empty inherited;
  if (Buffer<>nil) then begin
    VRecordSize := RecordSize;
    if (VRecordSize>0) then begin
      FillChar(Buffer^, VRecordSize, 0);
    end;
  end;
end;

procedure TSQLFetchableQuery.InternalOpen;
begin
  // abstract inherited;

  // opens sql
  FStatement := TODBCStatement.CreateAndExecDirect(FConnection.FDBCHandle, CommandText);
  FStatement.CheckErrors;
  //FSelectRecordCount := FStatement.GetAffectedRows;

  //InternalInitFieldDefs;
  FieldDefs.Updated := FALSE;
  FieldDefs.Update;
  
  if DefaultFields then
    CreateFields;

  BindFields(TRUE);
end;

end.
