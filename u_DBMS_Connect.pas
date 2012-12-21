unit u_DBMS_Connect;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  t_types,
  t_SQL_types,
  t_DBMS_Template,
  t_DBMS_Connect,
  odbcsql,
  t_ODBC_Connection,
  t_ODBC_Buffer,
  t_TSS,
  t_ETS_Path,
  t_ETS_Tiles;

type
{$if defined(CONNECTION_AS_CLASS)}
  IDBMS_Connection = interface(IODBCConnection)
    ['{52201DDE-CC76-4861-BAB1-1CDE050CB509}']

    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    function GetCheckedEngineType: TEngineType;
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;

    function GetConnectionErrorMessage: String;
    procedure ResetConnectionError;

    procedure ApplyCredentialsFormParams(const AFormParams: TStrings);
    function AllowSavePassword: Boolean;
    
  end;
{$ifend}


{$if defined(CONNECTION_AS_RECORD)}
  IDBMS_Connection = ^TDBMS_Connection;
{$ifend}

  TDBMS_Connection =
{$if defined(CONNECTION_AS_RECORD)}
  record
{$else}
  class(TODBCConnection, IDBMS_Connection)
{$ifend}

  public
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder: TODBCConnection;
{$ifend}

{$if defined(CONNECTION_AS_CLASS)}
  private
{$ifend}
    // ������� �� �������
    FNextSectionConn: IDBMS_Connection; // ��������� ������ � �������
    FPrimaryConn: IDBMS_Connection; // ������������ ������ �� ��������� ������
    FTSS_Info_Ptr: PTSS_Info; // ��������� ���������������
    FRealODBCPtr: IODBCConnection; // �������� ������������ � �������� (��������� �� ���� ��� �� ��������)

    procedure Init(const APathPtr: PETS_Path_Divided_W);
    procedure Uninit;

  private
    FPathDiv: TETS_Path_Divided_W;
    FEngineType: TEngineType;
    FODBCDescription: AnsiString;
    // ���������� ��������� �� ini
    FInternalParams: TStringList;
    // ��������� ��� �� �����, � ������� ��������� (��� ������������� - � ������ � ����� quoted)
    FETS_INTERNAL_SCHEMA_PREFIX: String;
    // ���� ����� ����� ����� DLL - ���������� �� TStringList
    FInternalLoadLibraryStd: THandle;
    FInternalLoadLibraryAlt: THandle;
    // �������� ��������� �������� � �������
    FConnectionErrorMessage: String;
    FConnectionErrorCode: Byte;
    // ���� TRUE - ������ ����� ����������� ��� Lsa Secret
    // ���� FALSE - ������ � ������� (� ����� ������� �� ���������)
    FSavePwdAsLsaSecret: Boolean;
    FReadPrevSavedPwd: Boolean;
  private
    // ������ ��������� �� INI � ��������� ��
    // ��� ������������� ������ �������� ������
    function ApplyConnectionParams: Byte;
  private
    procedure SaveInternalParameter(const AParamName, AParamValue: String);
    procedure KeepAuthenticationInfo;
    procedure ProcessTSSParameter(
      const AParams: TStrings;
      const AParamName, AParamValue: String
    );
    function IsTSSParameter(const AInternalParamName: String): Boolean;
    function IsInternalParameter(const AParamName: String): Boolean;
    function AllowReadParamsFromIni: Boolean; inline;
    function ApplySystemDSNtoConnection: Byte;
    function ApplyParamsFromINI(const AParams: TStrings): Byte;
    function GetEngineTypeUsingSQL(const ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode): TEngineType;
    function calc_exclusive_mode: AnsiChar;
  private
    function PasswordStorage_SaveParams(const AUserNameToSave, APasswordToSave: String): Boolean;
    function PasswordStorage_ReadParams(var ASavedUserName, ASavedPassword: String): Boolean;
    function PasswordStorage_ApplyStored: Boolean;

  public
{$if defined(CONNECTION_AS_RECORD)}
    function ExecuteDirectSQL(
      const ASQLText: AnsiString;
      const ASilentOnError: Boolean
    ): Boolean; inline;
{$ifend}

{$if defined(CONNECTION_AS_RECORD)}
    function TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean; inline;
{$ifend}

{$if defined(CONNECTION_AS_RECORD)}
    function OpenDirectSQLFetchCols(
      const ASQLText: AnsiString;
      const ABufPtr: POdbcFetchCols
    ): Boolean; inline;
{$ifend}

{$if defined(CONNECTION_AS_RECORD)}
    function ExecuteDirectWithBlob(
      const ASQLText, AFullParamName: AnsiString;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean
    ): Boolean; inline;
{$ifend}

{$if defined(CONNECTION_AS_RECORD)}
    function CheckDirectSQLSingleNotNull(const ASQLText: AnsiString): Boolean; inline;
{$ifend}

  public
    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;

    function GetConnectionErrorMessage: String;
    procedure ResetConnectionError;

    procedure ApplyCredentialsFormParams(const AFormParams: TStrings);
    function AllowSavePassword: Boolean;

{$if defined(CONNECTION_AS_CLASS)}
  public
    constructor Create(const APathPtr: PETS_Path_Divided_W);
    destructor Destroy; override;
{$ifend}
  end;

// get connection by path (create new or use existing)
function GetConnectionByPath(const APathPtr: PETS_Path_Divided_W): IDBMS_Connection;
// free connection
procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);

implementation

uses
  IniFiles,
  Contnrs,
  u_PStoreTools,
  u_Synchronizer,
  u_DBMS_Utils;

{$if defined(DBMS_REUSE_CONNECTIONS)}
type
  TDBMS_Server = class(TObjectList)
  private
    // credentials
    FServerName: TDBMS_String;
    FUsername: TDBMS_String;
    FPassword: TDBMS_String;
    FAuthDefined: Boolean;
    FAuthOK: Boolean;
    FAuthFailed: Boolean;
  end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
type
  TDBMS_ConnectionList = class(TObjectList)
  private
    // list of servers
    FSyncList: IReadWriteSync;
  private
    function InternalGetServerObject(const AServerName: WideString): TDBMS_Server;
    procedure InternalRemoveConnection(const AConnection: TDBMS_Connection);
  private
    function SafeMakeConnection(const APath: PETS_Path_Divided_W): IDBMS_Connection;
  public
    constructor Create;
    destructor Destroy; override;
  end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
var
  G_ConnectionList: TDBMS_ConnectionList;
{$ifend}

function GetConnectionByPath(const APathPtr: PETS_Path_Divided_W): IDBMS_Connection;
{$if defined(DBMS_REUSE_CONNECTIONS)}
{$else}
  {$if defined(CONNECTION_AS_CLASS)}
var
  t: TDBMS_Connection;
  {$ifend}
{$ifend}
begin
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.FSyncList.BeginWrite;
  try
    Result := G_ConnectionList.SafeMakeConnection(APath);
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
{$else}
  {$if defined(CONNECTION_AS_CLASS)}
  // create new connection and add it to p
  t := TDBMS_Connection.Create(APathPtr);
  Result := t;
  {$else}
  New(Result);
  Result^.Init(APathPtr);
  {$ifend}
{$ifend}
end;

procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);
begin
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.FSyncList.BeginWrite;
  try
  {$if defined(CONNECTION_AS_RECORD)}
    AConnection^.Uninit;
    Dispose(AConnection);
  {$ifend}
    AConnection := nil;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
{$else}
  {$if defined(CONNECTION_AS_RECORD)}
  AConnection^.Uninit;
  Dispose(AConnection);
  {$ifend}
  AConnection := nil;
{$ifend}
end;

{ TDBMS_Connection }

function TDBMS_Connection.AllowReadParamsFromIni: Boolean;
begin
  // ������ ��������� �� ini, ���� ������� ������:
  // �) ���������
  // �) ���� Section
  // �� ������ ��������� �� ini, ���� ������� ������:
  // �) ���� Prefix (���������� ����������� ��������� ������)
  // �) ���� DSN (������ ��� ����������, ����� ����� ini ����� ���)
  Result := (FTSS_Info_Ptr=nil) or (not (FTSS_Info_Ptr^.DestType in [tsst_DSN, tsst_Prefix]))
end;

function TDBMS_Connection.AllowSavePassword: Boolean;
begin
  Result := FReadPrevSavedPwd;
end;

function TDBMS_Connection.ApplyConnectionParams: Byte;
var
  VSectionName: String;
  VFilename: String;
  VIni: TIniFile;
  VParams: TStringList;
begin
  VSectionName := FPathDiv.AsEndpoint;

  // ���� �������� ����������� ����� ������ ODBC ������ ��� ��������� �������������� ����������,
  // ����� ��������� ������� ������ � ������� ini, ���� ���� ini ����

  // ����� ��� ������� � ��� �����, ������ ��� ��������� ������������ �� ����������� � ����
  // ��� ����������� ������� �� ��������� ������ ��������� ������������� � ������ �����
  VFilename :=
  GetModuleFileNameWithoutExt(
    TRUE,
    c_SQL_ODBC_Prefix_Ini,
    ''
  ) + c_SQL_Ext_Ini;
  
  if FileExists(VFilename) then begin
    VIni:=TIniFile.Create(VFilename);
    try
      if VIni.SectionExists(VSectionName) then begin
        // ������ ������� - ������ � �������
        VParams := TStringList.Create;
        try
          VIni.ReadSectionValues(VSectionName, VParams);
          // ��������� ��������� ������
          Result := ApplyParamsFromINI(VParams);
        finally
          VParams.Free;
        end;
      end else begin
        // ������ �� �������
        Result := ETS_RESULT_INI_SECTION_NOT_FOUND;
      end;
    finally
      VIni.Free;
    end;
  end else begin
    // ���� ini �� ������
    // ��� ODBC ��������� ��������������� ���������� System DSN
    Result := ApplySystemDSNtoConnection;
  end;
end;

procedure TDBMS_Connection.SaveInternalParameter(const AParamName, AParamValue: String);
begin
  // ���� ����������� DLL ���������� - �� ����� � ��������� � ������ ���������� ����������
  if SameText(ETS_INTERNAL_LOAD_LIBRARY, AParamName) and (FInternalLoadLibraryStd=0) and (0<Length(AParamValue)) then begin
    FInternalLoadLibraryStd := LoadLibrary(PChar(AParamValue));
    if (FInternalLoadLibraryStd<>0) then
      Exit;
  end else if SameText(ETS_INTERNAL_LOAD_LIBRARY_ALT, AParamName) and (FInternalLoadLibraryAlt=0) and (0<Length(AParamValue)) then begin
    FInternalLoadLibraryAlt := LoadLibraryEx(PChar(AParamValue), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (FInternalLoadLibraryAlt<>0) then
      Exit;
  end else if SameText(ETS_INTERNAL_SCHEMA_PREFIX, AParamName) then begin
    // ��� ����� �������� �������
    FETS_INTERNAL_SCHEMA_PREFIX := AParamValue;
    Exit;
  end else if SameText(ETS_INTERNAL_SYNC_SQL_MODE, AParamName) then begin
    // ��� ����� �������� �������
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.
{$ifend}
    SYNC_SQL_MODE := StrToIntDef(AParamValue, c_SYNC_SQL_MODE_None);
    Exit;
  end else if SameText(ETS_INTERNAL_PWD_Save, AParamName) then begin
    // ���������� ������ ���������� ������ (� ��� �� - ���������� ��������� ������) + ����� Lsa
    FSavePwdAsLsaSecret := SameText(AParamValue, ETS_INTERNAL_PWD_Save_Lsa);
    FReadPrevSavedPwd := FSavePwdAsLsaSecret or (StrToIntDef(AParamValue, 0) <> 0);
    Exit;
  end else if SameText(ETS_INTERNAL_ODBC_ConnectWithParams, AParamName) then begin
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.
{$ifend}
    ConnectWithParams := (StrToIntDef(AParamValue, 0) <> 0);
    Exit;
  end;

  if (nil=FInternalParams) then
    FInternalParams := TStringList.Create;
  // ������ ���������� ��������� � ������
  FInternalParams.Values[AParamName] := AParamValue;
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean;
begin
  Result := FRealODBCPtr^.TableExistsDirect(AFullyQualifiedQuotedTableName)
end;
{$ifend}

procedure TDBMS_Connection.Uninit;
begin
  // called from FreeDBMSConnection - not need to sync
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.InternalRemoveConnection(Self);
{$ifend}

  // ������� ���������� �� �������
  if (FNextSectionConn<>nil) then begin
{$if defined(CONNECTION_AS_RECORD)}
    FNextSectionConn^.Uninit;
    Dispose(FNextSectionConn);
{$ifend}
    // ������� ������ (���� ��������� - ����)
    FNextSectionConn := nil;
  end;

  try
{$if defined(CONNECTION_AS_RECORD)}
    // ����� �� FRealODBCPtr^ � ������ ���� �������
    FODBCConnectionHolder.Disconnect;
{$else}
    Disconnect;
{$ifend}
  except
  end;

  try
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.Uninit;
{$ifend}
  except
  end;

  try
    FreeAndNil(FInternalParams);
  except
  end;

  if (FInternalLoadLibraryAlt<>0) then begin
    FreeLibrary(FInternalLoadLibraryAlt);
    FInternalLoadLibraryAlt:=0;
  end;

  if (FInternalLoadLibraryStd<>0) then begin
    FreeLibrary(FInternalLoadLibraryStd);
    FInternalLoadLibraryStd:=0;
  end;

  FRealODBCPtr := nil;
  FPrimaryConn := nil;

  if (FTSS_Info_Ptr <> nil) then begin
    FTSS_Info_Ptr^.Clear;
    Dispose(FTSS_Info_Ptr);
    FTSS_Info_Ptr := nil;
  end;
end;

procedure TDBMS_Connection.ApplyCredentialsFormParams(const AFormParams: TStrings);
begin
  // ��������� ����� � ������
{$if defined(CONNECTION_AS_RECORD)}
  with FODBCConnectionHolder do begin
{$ifend}
    UID := AFormParams.Values[c_Cred_UserName];
    PWD := AFormParams.Values[c_Cred_Password];
{$if defined(CONNECTION_AS_RECORD)}
  end;
{$ifend}

  // ����� ���� ������� ��������� ��������� ����������� - �������� ��
  if (AFormParams.Values[c_Cred_SaveAuth]='1') then begin
    PasswordStorage_SaveParams(AFormParams.Values[c_Cred_UserName], AFormParams.Values[c_Cred_Password]);
  end;
end;

function TDBMS_Connection.ApplyParamsFromINI(const AParams: TStrings): Byte;
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
begin
  // �� ��� �� ���������� - ����� � ��������� �����������
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if IsInternalParameter(VCurItem) then begin
      // ������������� ���������� ��������
      if IsTSSParameter(VCurItem) then begin
        // ��������� TSS
        ProcessTSSParameter(AParams, VCurItem, VNewValue);
      end else begin
        // ��������� ����������
        SaveInternalParameter(VCurItem, VNewValue);
      end;
    end else begin
      // � ��������� �����������
{$if defined(CONNECTION_AS_RECORD)}
      FODBCConnectionHolder.
{$ifend}
      Params.Values[VCurItem] := VNewValue;
    end;
  end;

  // done

  if FReadPrevSavedPwd then begin
    PasswordStorage_ApplyStored;
  end;

  Result := ETS_RESULT_OK;
end;

function TDBMS_Connection.ApplySystemDSNtoConnection: Byte;
var
  VSystemDSNName: AnsiString;
begin
  // ���������� ���������� ����������� ��� ini-���
  // �������� �� ��� ���� ����
  VSystemDSNName := FPathDiv.ServerName;
  if Load_DSN_Params_from_ODBC(VSystemDSNName, FODBCDescription) then begin
    // ������� SystemDSN
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.
{$ifend}
    DSN := VSystemDSNName;

    PasswordStorage_ApplyStored;

    Result := ETS_RESULT_OK;
  end else begin
    // �� ��� ����
    Result := ETS_RESULT_INI_FILE_NOT_FOUND;
  end;
end;

function TDBMS_Connection.calc_exclusive_mode: AnsiChar;
begin
{$if defined(CONNECTION_AS_RECORD)}
  with FODBCConnectionHolder do
{$ifend}
  case SYNC_SQL_MODE of
    c_SYNC_SQL_MODE_All_In_EXE: begin
      Result := ETS_HEM_EXCLISUVE;
    end;
    c_SYNC_SQL_MODE_Query_In_EXE: begin
      Result := ETS_HEM_QUERY_ONLY;
    end;
    else begin
      Result := ETS_HEM_DEFAULT;
    end;
  end;
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.CheckDirectSQLSingleNotNull(const ASQLText: AnsiString): Boolean;
begin
  Result := FRealODBCPtr^.CheckDirectSQLSingleNotNull(ASQLText)
end;
{$ifend}

{$if defined(CONNECTION_AS_CLASS)}
constructor TDBMS_Connection.Create(const APathPtr: PETS_Path_Divided_W);
begin
  inherited Create;
  Init(APathPtr);
end;
{$ifend}

{$if defined(CONNECTION_AS_CLASS)}
destructor TDBMS_Connection.Destroy;
begin
  Uninit;
  try
    inherited;
  except
  end;
end;
{$ifend}

function TDBMS_Connection.EnsureConnected(
  const AllowTryToConnect: Boolean;
  AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
): Byte;
begin
  if
{$if defined(CONNECTION_AS_RECORD)}
     // � ��� ��� ��� ��� ����� ���������� �����������
     // ����� ���� ������ ��������� �� �������� - ���� �� ������ � ��
     FRealODBCPtr^.
{$ifend}
     Connected then begin
    // connected
    Result := ETS_RESULT_OK;
  end else if (FConnectionErrorCode<>ETS_RESULT_OK) then begin
    // critical error - cannot connect to server
    Result := FConnectionErrorCode;
  end else begin
    // not connected
    if AllowTryToConnect then begin
      // apply params and try to connect
      Result := ApplyConnectionParams;
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // �������� ����� � ����
      if (AStatusBuffer<>nil) then
      with (AStatusBuffer^) do begin
        if wSize>=SizeOf(AStatusBuffer^) then
          exclusive_mode := calc_exclusive_mode;
      end;

      // try to connect
      try
{$if defined(CONNECTION_AS_RECORD)}
        // ����������� ������
        FODBCConnectionHolder.
{$ifend}
        Connect;
        
        FConnectionErrorMessage := '';
        FConnectionErrorCode := ETS_RESULT_OK;

        // connected - �������� ������� � ����
        if (AStatusBuffer<>nil) then
        with (AStatusBuffer^) do begin
          if wSize>=SizeOf(AStatusBuffer^) then
            malfunction_mode := ETS_PMM_ESTABLISHED;
        end;
      except
        on E: Exception do begin
          // '08001:17:[Microsoft][ODBC SQL Server Driver][TCP/IP Sockets]SQL-������ �� ����������, ��� ����������� ������.'
          // '28P01:210:�����: ������������ "postgres" �� ������ �������� ����������� (�� ������)'
          // 'HY000:A password is required for this connection.'#$D#$A
          // '08001:101:Could not connect to the server;'#$A'No connection could be made because the target machine actively refused it.'#$D#$A' [::1:5432]'
          // '08001:30012:[Sybase][ODBC Driver]Client unable to establish a connection'
          // '08001:-100:[Sybase][ODBC Driver][SQL Anywhere]Database server not found'
          // 'HY000:2003:[MySQL][ODBC 5.2(w) Driver]Can't connect to MySQL server on '127.0.0.1' (10061)'
          // '08001:-21054:[MIMER][ODBC Mimer Driver]Database server for database sasgis_yandex not started'
          // '08004:[MIMER][ODBC Mimer Driver][Mimer SQL]MIMER logins are currently disabled, try again later'#$D#$A
          // '08004:-904:[ODBC Firebird Driver]unavailable database'
          // 'HY000:12541:[Oracle][ODBC][Ora]ORA-12541: TNS:no listener'#$A
          // 'HY000:12514:[Oracle][ODBC][Ora]ORA-12514: TNS:listener does not currently know of service requested in connect descriptor'#$A
          // 'HY000:12528:[Oracle][ODBC][Ora]ORA-12528: TNS:listener: all appropriate instances are blocking new connections'#$A
          // '08001:1001:[Relex][Linter ODBC Driver] SQLConnect: #1001 ������� ���� Linter �� ������� (��� ��������� ����)'
          // '08001:-30081:[IBM][CLI Driver] SQL30081N  A communication error has been detected. Communication protocol being used: "TCP/IP".  Communication API being used: "SOCKETS".  Location where the error was detected: "192.168.1.8".  Communication function detecting the error: "connect".  Protocol specific error code(s): "10061", "*", "*".  SQLSTATE=08001'#$D#$A
          // '08004:-908:[Informix][Informix ODBC Driver][Informix]Attempt to connect to database server (ol_informix1170) failed.'

          FConnectionErrorMessage := E.Message;
          FConnectionErrorCode := ETS_RESULT_NOT_CONNECTED;
          Result := ETS_RESULT_NOT_CONNECTED;

          // failed - �������� ������� � ����
          if (AStatusBuffer<>nil) then
          with (AStatusBuffer^) do begin
            if wSize>=SizeOf(AStatusBuffer^) then
              malfunction_mode := ETS_PMM_FAILED_CONNECT;
          end;

          Exit;
        end;

      end;

      // ��������� ����������� ������� ��� PostgreSQL
      // ����� ������� ����� ODBC �������� ����������
      // �� ��������� ������� "bytea as LO"
{$if defined(CONNECTION_AS_RECORD)}
      FODBCConnectionHolder.
{$ifend}
      CheckByteaAsLoOff(et_PostgreSQL=GetCheckedEngineType);

      KeepAuthenticationInfo;
      Result := ETS_RESULT_OK;
    end else begin
      // cannot connect
      Result := ETS_RESULT_NEED_EXCLUSIVE;
    end;
  end;
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.ExecuteDirectWithBlob(const ASQLText,
  AFullParamName: AnsiString; const ABufferAddr: Pointer;
  const ABufferSize: Integer; const ASilentOnError: Boolean): Boolean;
begin
  Result := FRealODBCPtr^.ExecuteDirectWithBlob(
    ASQLText,AFullParamName, ABufferAddr,
    ABufferSize, ASilentOnError);
end;
{$ifend}

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.ExecuteDirectSQL(
  const ASQLText: AnsiString;
  const ASilentOnError: Boolean
): Boolean;
begin
  Result := FRealODBCPtr^.ExecuteDirectSQL(ASQLText, ASilentOnError);
end;
{$ifend}

function TDBMS_Connection.ForcedSchemaPrefix: String;
begin
  Result := FETS_INTERNAL_SCHEMA_PREFIX;
end;

function TDBMS_Connection.FullSyncronizeSQL: Boolean;
begin
  // ���� c_SYNC_SQL_MODE_All_In_DLL - ���������������� ������� ���������
{$if defined(CONNECTION_AS_RECORD)}
  // �� ���������� ������
  with FRealODBCPtr^ do
{$ifend}
  Result := (SYNC_SQL_MODE=c_SYNC_SQL_MODE_All_In_DLL) or (not Connected);
end;

function TDBMS_Connection.GetInternalParameter(const AInternalParameterName: String): String;
begin
  // ����� �������� �� ���������� ����������
  if FInternalParams<>nil then begin
    Result := Trim(FInternalParams.Values[AInternalParameterName]);
  end else begin
    Result := '';
  end;
end;

function TDBMS_Connection.GetCheckedEngineType: TEngineType;
begin
  Result := GetEngineType(cetm_Check);
end;

function TDBMS_Connection.GetConnectionErrorMessage: String;
begin
  Result := FConnectionErrorMessage;
end;

function TDBMS_Connection.GetEngineType(const ACheckMode: TCheckEngineTypeMode): TEngineType;
var
  VSecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode;
begin
  case ACheckMode of
    cetm_Check: begin
      // check if not checked
      // allow get info from driver
      if (et_Unknown=FEngineType) then begin
        VSecondarySQLCheckServerTypeMode := schstm_None;

        if Load_DSN_Params_from_ODBC(
{$if defined(CONNECTION_AS_RECORD)}
          // �� ���������� ������
          FRealODBCPtr^.
{$ifend}
          DSN,
          FODBCDescription
        ) then
          FEngineType := GetEngineTypeByODBCDescription(FODBCDescription, VSecondarySQLCheckServerTypeMode)
        else
          FEngineType := GetEngineTypeByODBCDescription(
{$if defined(CONNECTION_AS_RECORD)}
            // �� ���������� ������
            FRealODBCPtr^.
{$ifend}
            DSN,
            VSecondarySQLCheckServerTypeMode
          );

        if (et_Unknown=FEngineType) then begin
          // use sql requests
          FEngineType := GetEngineTypeUsingSQL(VSecondarySQLCheckServerTypeMode);
        end;
      end;
    end;
    cetm_Force: begin
      // (re)check via SQL requests
      FEngineType := GetEngineTypeUsingSQL(schstm_None);
    end;
  end;

  Result := FEngineType;
end;

function TDBMS_Connection.GetEngineTypeUsingSQL(const ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode): TEngineType;
var
  VOdbcFetchColsEx: TOdbcFetchCols12;
  VSQLText: TDBMS_String;
  VText: AnsiString;
begin
  if (not
{$if defined(CONNECTION_AS_RECORD)}
          // ���������� ������
          FRealODBCPtr^.
{$ifend}
          Connected) then begin
    // not connected
    Result := et_Unknown;
  end else begin
    // connected
    VOdbcFetchColsEx.Init;
    try
      // ����������� ���� ������� ������ �� ��� ������� �� ��������� ��������

      // ������ �������� select @@version // MSSQL+ASE+ASA
      VSQLText := 'SELECT @@VERSION as v';
      try
        OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));

        // ����� ������ ����
        VOdbcFetchColsEx.Base.ColToAnsiString(1, VText);
        if GetEngineTypeUsingSQL_Version_Upper(VText, Result) then
          Exit;

        // unknown
        Result := et_Unknown;
      except on E: Exception do
        // � ��� ������� ���� ���������� � ������
        Result := GetEngineTypeUsingSelectVersionException(E);
      end;

      if (et_Unknown=Result) then begin
      (*
      // second check
      try
        VDataset.OpenSQL(c_SQLCMD_FROM_DUAL);
        // TODO: check resultset
      except
        on E: Exception do begin
          // TODO: check message
        end;
      end;
      *)
      end;
      
    finally
      VOdbcFetchColsEx.Base.Close;
    end;
  end;
end;

procedure TDBMS_Connection.Init(const APathPtr: PETS_Path_Divided_W);
begin
  FRealODBCPtr := nil;
  FPrimaryConn := nil;
  FTSS_Info_Ptr := nil;
  FNextSectionConn := nil;
  FPathDiv.CopyFrom(APathPtr);
  FEngineType := et_Unknown;
  FODBCDescription := '';
  FSavePwdAsLsaSecret := FALSE;
  FReadPrevSavedPwd := FALSE;
{$if defined(CONNECTION_AS_RECORD)}
  FODBCConnectionHolder.Init;
  FRealODBCPtr := @FODBCConnectionHolder;
{$else}
  FRealODBCPtr := Self;
{$ifend}
  FInternalLoadLibraryStd := 0;
  FInternalLoadLibraryAlt := 0;
  FInternalParams := nil;
  FETS_INTERNAL_SCHEMA_PREFIX := '';
  FConnectionErrorMessage := '';
  FConnectionErrorCode := ETS_RESULT_OK;
end;

function TDBMS_Connection.IsInternalParameter(const AParamName: String): Boolean;
begin
  Assert(1=Length(ETS_INTERNAL_PARAMS_PREFIX));
  Result := (Length(AParamName) > 0) and (ETS_INTERNAL_PARAMS_PREFIX = AParamName[1]);
end;

function TDBMS_Connection.IsTSSParameter(const AInternalParamName: String): Boolean;
begin
  // ������������� ���, ��� ��� ��������� TSS ����� ���� ����� (���� ��������� ������)
  Result := (Length(ETS_INTERNAL_TSS_DEST)<=Length(AInternalParamName)) and
            (0=StrLIComp(PChar(AInternalParamName), PChar(ETS_INTERNAL_TSS_), Length(ETS_INTERNAL_TSS_)));
end;

procedure TDBMS_Connection.KeepAuthenticationInfo;
{$if defined(DBMS_REUSE_CONNECTIONS)}
var
  VServer: TDBMS_Server;
{$ifend}
begin
{$if defined(DBMS_REUSE_CONNECTIONS)}
  // get info from G_ConnectionList
  G_ConnectionList.FSyncList.BeginWrite;
  try
    VServer := G_ConnectionList.InternalGetServerObject(FPath.ServerName);
    if (VServer<>nil) then begin
      if (not VServer.FAuthDefined) then begin
        VServer.FUsername := FSQLConnection.UID;
        VServer.FPassword := FSQLConnection.PWD;
      end;
      VServer.FAuthFailed := FALSE;
      VServer.FAuthOK := TRUE;
    end;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
{$ifend}
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.OpenDirectSQLFetchCols(const ASQLText: AnsiString; const ABufPtr: POdbcFetchCols): Boolean;
begin
  Result := FRealODBCPtr^.OpenDirectSQLFetchCols(ASQLText, ABufPtr)
end;
{$ifend}

function TDBMS_Connection.PasswordStorage_ApplyStored: Boolean;
var
  VSavedUserName, VSavedPassword: String;
begin
  Result := PasswordStorage_ReadParams(VSavedUserName, VSavedPassword);
  if Result then
{$if defined(CONNECTION_AS_RECORD)}
  // ������� ������, ���� ��� ����� ������������ � ��
  with FODBCConnectionHolder do
{$ifend}
  begin
    UID := VSavedUserName;
    PWD := VSavedPassword;
  end;
end;

function TDBMS_Connection.PasswordStorage_ReadParams(var ASavedUserName, ASavedPassword: String): Boolean;
var
  VPStore: IPStore;
  VPKeyedCrypter: IPKeyedCrypter;
  VSecretValue: WideString;
  VList: TStringList;
begin
  Result := FALSE;

  if (not FReadPrevSavedPwd) then
    Exit;

  VPStore := GetPStoreIface;

  if (nil=VPStore) then
    Exit;

  VPKeyedCrypter := VPStore.CreateDefaultCrypter(FSavePwdAsLsaSecret);

  if (nil=VPKeyedCrypter) or (not VPKeyedCrypter.KeyAvailable) then
    Exit;

  if VPKeyedCrypter.LoadSecret(FPathDiv.AsEndpoint, VSecretValue) then begin
    VList:=TStringList.Create;
    try
      VList.Text := VSecretValue;
      Result := (VList.IndexOfName('UID')>=0) and (VList.IndexOfName('PWD')>=0);
      if Result then begin
        ASavedUserName := VList.Values['UID'];
        ASavedPassword := VList.Values['PWD'];
      end;
    finally
      VList.Free;
    end;
  end;
end;

function TDBMS_Connection.PasswordStorage_SaveParams(const AUserNameToSave, APasswordToSave: String): Boolean;
var
  VPStore: IPStore;
  VPKeyedCrypter: IPKeyedCrypter;
  VSecretValue: WideString;
  VList: TStringList;
begin
  Result := FALSE;

  if (not FReadPrevSavedPwd) then
    Exit;

  VPStore := GetPStoreIface;

  if (nil=VPStore) then
    Exit;

  VPKeyedCrypter := VPStore.CreateDefaultCrypter(FSavePwdAsLsaSecret);

  if (nil=VPKeyedCrypter) or (not VPKeyedCrypter.KeyAvailable) then
    Exit;

  VList:=TStringList.Create;
  try
    VList.Values['UID'] := AUserNameToSave;
    VList.Values['PWD'] := APasswordToSave;
    VSecretValue := VList.Text;
  finally
    VList.Free;
  end;

  Result := VPKeyedCrypter.SaveSecret(FPathDiv.AsEndpoint, VSecretValue);
end;

procedure TDBMS_Connection.ProcessTSSParameter(
  const AParams: TStrings;
  const AParamName, AParamValue: String
);
var
  VTSSSuffix: String;
  VTSS_Definition: TTSS_Definition;
  VNewTSSPtr: PTSS_Info;
  VLastSection: IDBMS_Connection;
begin
  // ������ �������� TSS ������ ���� ��������� ������ ��� ������ ���� Section
  if (not AllowReadParamsFromIni) then
    Exit;

  // ��������� �� ������������� ������������� ��������� TSS
  // TODO: ������� ����� �������� � �������� ����� ����������
  if not SameText(AParamName, ETS_INTERNAL_TSS_DEST) then
    Exit;

  // ���� ��� ������ ��� ������� - ���� ��������� ������
  VTSSSuffix := '';
  // ��������� ��������� ������ �� INI
  with VTSS_Definition do begin
    DestSource := AParamValue;
    AreaSource := AParams.Values[ETS_INTERNAL_TSS_AREA+VTSSSuffix];
    ZoomSource := AParams.Values[ETS_INTERNAL_TSS_ZOOM+VTSSSuffix];
    FullSource := AParams.Values[ETS_INTERNAL_TSS_FULL+VTSSSuffix];
    ModeSource := AParams.Values[ETS_INTERNAL_TSS_MODE+VTSSSuffix];
    SyncSource := AParams.Values[ETS_INTERNAL_TSS_SYNC+VTSSSuffix];
  end;

  VNewTSSPtr := nil;
  try
    New(VNewTSSPtr);

    if VNewTSSPtr^.ApplyDefinition(VTSS_Definition) then begin
      // ������ �������� ����� ����� � ����� ��������

      // ����� ��������� ������ � ������� (� �������� ��� ������ �� ���������)
      VLastSection := @Self;
      while (VLastSection<>nil) and (VLastSection^.FNextSectionConn<>nil) do begin
        VLastSection := VLastSection^.FNextSectionConn;
      end;

      // ������ ����� ������
      New(VLastSection^.FNextSectionConn);
      VLastSection^.FNextSectionConn.Init(nil);
      case VNewTSSPtr^.DestType of
        tsst_Section, tsst_DSN: begin
          // ����� ������ �� ������ ��������� ������ � INI
          // ����� ������ ��� ���������� �� ������ System DSN
          VLastSection^.FNextSectionConn.FTSS_Info_Ptr := VNewTSSPtr;
          VNewTSSPtr := nil;
          // �������� ��� ������ (�� � ��� ������� ��� �������)
          VLastSection^.FNextSectionConn.FPathDiv.ApplyFrom(VNewTSSPtr^.DestValue, FPathDiv.ServiceName);
          // �� - ��������
          VLastSection^.FNextSectionConn.FPrimaryConn := @Self;
          // ������ ������ ����� ����
          VLastSection^.FNextSectionConn.FRealODBCPtr := @(VLastSection^.FNextSectionConn.FODBCConnectionHolder);
        end;
        tsst_Prefix: begin
          // ����� ������ �� ������ ��������� (�������), �� �� ����������� ���������
          VLastSection^.FNextSectionConn.FTSS_Info_Ptr := VNewTSSPtr;
          VNewTSSPtr := nil;
          // �� �������� ��� ������
          // �� - ��������
          VLastSection^.FNextSectionConn.FPrimaryConn := @Self;
          // ������ ������ ����� ��� (��������)
          VLastSection^.FNextSectionConn.FRealODBCPtr := @(Self.FODBCConnectionHolder);
        end;
      end;

(*
    // ������� �� �������
    FNextSectionConn: IDBMS_Connection; // ��������� � �������
    FPrimaryConn: IDBMS_Connection; // ������������ ������ �� ���������
    FTSS_Info_Ptr: PTSS_Info; // ��������� ���������������
    FRealODBCPtr: IODBCConnection; // �������� ������������ � �������� (��������� �� ���� ��� �� ��������)
*)
    end;
  finally
    // ���� ������ �������� - �������
    if (VNewTSSPtr<>nil) then
      Dispose(VNewTSSPtr);
  end;
end;

procedure TDBMS_Connection.ResetConnectionError;
begin
  //FConnectionErrorMessage := '';
  FConnectionErrorCode := ETS_RESULT_OK;
end;

{ TDBMS_ConnectionList }

{$if defined(DBMS_REUSE_CONNECTIONS)}
constructor TDBMS_ConnectionList.Create;
begin
  inherited Create;
  FSyncList := MakeSync_Tiny(Self);
  //Self.OwnsObjects := TRUE; // TRUE is by default
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
destructor TDBMS_ConnectionList.Destroy;
begin
  FSyncList.BeginWrite;
  try
    Self.Clear;
  finally
    FSyncList.EndWrite;
  end;
  FSyncList := nil;
  inherited Destroy;
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
function TDBMS_ConnectionList.InternalGetServerObject(const AServerName: WideString): TDBMS_Server;
var
  i: Integer;
  p: TObject;
begin
  if (Self.Count>0) then
  for i := 0 to Self.Count-1 do begin
    p := Self.Items[i];
    if (p is TDBMS_Server) and WideSameStr(TDBMS_Server(p).FServerName, AServerName) then begin
      Result := TDBMS_Server(p);
      Exit;
    end;
  end;
  Result := nil;
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
procedure TDBMS_ConnectionList.InternalRemoveConnection(const AConnection: TDBMS_Connection);
var
  k: Integer;
  p: TDBMS_Server;
begin
  // find server object
  p := InternalGetServerObject(AConnection.FPath.ServerName);
  if (nil<>p) then begin
    // find connection
    k := TDBMS_Server(p).IndexOf(AConnection);
    if (k>=0) then begin
      p.Delete(k);
    end;
  end;
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
function TDBMS_ConnectionList.SafeMakeConnection(const APath: PETS_Path_Divided_W): IDBMS_Connection;
var
  i: Integer;
  p: TDBMS_Server;
  t: TDBMS_Connection;
begin
  // find server object
  p := InternalGetServerObject(APath^.ServerName);
  if (nil=p) then begin
    // create new server
    p := TDBMS_Server.Create;
    p.OwnsObjects := FALSE;
    p.FServerName := APath^.ServerName;
    p.FUsername := '';
    p.FPassword := '';
    p.FAuthDefined := FALSE;
    p.FAuthOK := FALSE;
    p.FAuthFailed := FALSE;
    Self.Add(p); // add server object to list
  end else begin
    // server exists - find existing connection
    i := p.Count-1;
    while (i>=0) do begin
      // check
      if (p.Items[i] is TDBMS_Connection) then
      with TDBMS_Connection(p.Items[i]) do
      if WideSameStr(FPath.AsEndpoint, APath^.AsEndpoint) then begin
        // found (skip last identifier - service name)
        Result := TDBMS_Connection(p.Items[i]);
        Exit;
      end;
      // prev
      Dec(i);
    end;
  end;

  // create new connection and add it to p
  t := TDBMS_Connection.Create;
  t.FPath.CopyFrom(APath);
  p.Add(t);
  Result := t;
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
{$ifend}
end.
