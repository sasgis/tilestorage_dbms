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

{$if defined(USE_DIRECT_ODBC)}
  odbcsql,
  t_ODBC_Connection,
  t_ODBC_Buffer,
{$elseif defined(ETS_USE_ZEOS)}
  // ZEOS
  u_DBMS_Zeos,
  {$if defined(USE_ODBC_DATASET)}
  ZDataset,
  {$ifend}
{$else}
  // DBX
  u_DBMS_DBX,
  DBXCommon,
  SQLExpr,
{$ifend}
  t_ETS_Path,
  t_ETS_Tiles;

type
  TDBMS_Custom_Connection = class(
{$if defined(USE_MODBC)}
    {$if defined(USE_ODBC_DATASET)}
    TmDataBase
    {$else}
    TODBCConnection
    {$ifend}
{$elseif defined(USE_DIRECT_ODBC)}
    TODBCConnection
{$elseif defined(ETS_USE_ZEOS)}
    TZeosDatabase
{$else}
    TDBXDatabase
{$ifend}
  )
  protected
    FETS_INTERNAL_SYNC_SQL_MODE: Integer;
{$if defined(USE_ODBC_DATASET)}
  protected
    FSYNC_SQL_MODE_CS: TRTLCriticalSection;
  protected
    procedure BeforeSQL(out ALocked: Boolean);
    procedure AfterSQL(const ALocked: Boolean);
{$ifend}
  public
{$if defined(USE_ODBC_DATASET)}
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
{$else}
    constructor Create;
{$ifend}
  end;

  // base dataset

  { TDBMS_Dataset }

{$if defined(USE_ODBC_DATASET)}

  TDBMS_Dataset = class(
{$if defined (USE_MODBC)}
    TmCustomQuery // modbc
{$elseif defined(USE_DIRECT_ODBC)}
    TSQLQuery // ODBC
{$elseif defined(ETS_USE_ZEOS)}
    TZQuery
{$else}
    TSQLQuery // DBX
{$ifend}
  )
  private
{$if defined(ETS_USE_ZEOS)}
    FUsePingServer: Boolean;
{$ifend}
  public
    // set SQL text and open it
    procedure OpenSQL(const ASQLText: TDBMS_String);

    // get value as ansichar
    function GetAnsiCharFlag(
      const AFieldName: TDBMS_String;
      const ADefaultValue: AnsiChar
    ): AnsiChar;

    // ������ �������� ����, ���� ��� ����, ����� �������� �� ���������
    function GetOptionalSmallInt(
      const AFieldName: TDBMS_String;
      const ADefaultValue: SmallInt = 0
    ): SmallInt;

    // get CLOB value, returns (NOT NULL)
    function ClobAsWideString(
      const AFieldName: TDBMS_String;
      out AResult: TDBMS_String
    ): Boolean;

  private
    // set BLOB buffer to param (if exists)
    procedure SetParamBlobData(
      const AParamName: TDBMS_String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt
    );

  public
    // reads BLOB from field via stream
    function CreateFieldBlobReadStream(const AFieldName: TDBMS_String): TStream;

    procedure SetSQLTextAsString(const ASQLText: TDBMS_String);
    procedure SetSQLTextAsStrings(const ASQLText: TStrings);

    // reassign both modes
    procedure ExecSQLDirect; deprecated;
    procedure ExecSQLParsed; deprecated;
    procedure ExecSQLSpecified(const ADirectExec: Boolean); deprecated;
  end;
{$ifend}

  IDBMS_Connection = interface
  ['{D5809427-36C7-49D7-83ED-72C567BD6E08}']
{$if defined(USE_ODBC_DATASET)}
    // ��� ���������
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
{$ifend}

    // �����������, ���� ��� �� ����������
    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    // ���������� �������� ������� ��������
    function ExecuteDirectSQL(
      const ASQLText: TDBMS_String;
      const ASilentOnError: Boolean = FALSE // ����� �� ��������������
    ): Boolean;

    // ���������� ������� � ���������� ���� blob ��������
    function ExecuteDirectWithBlob(
      const ASQLText: TDBMS_String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean = FALSE // ����� �� ��������������
    ): Boolean;

    // �������� ������������� �������
    function TableExists(const AFullyQualifiedQuotedTableName: TDBMS_String): Boolean;

    // ��� ������� ��
    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;

    // ���������� ���������
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;

    // ����� ������ ��� �����������
    function GetConnectionErrorMessage: String;
    procedure ResetConnectionError;

    // ���������� �������� �������������� �� �����
    procedure ApplyCredentialsFormParams(const AFormParams: TStrings);
    function AllowSavePassword: Boolean;

    // �������� ��� ���� ���� ���� � �� ������
    function CheckDirectSQLSingleNotNull(
      const ASQLText: String
    ): Boolean;

    // �������� ������� ����� ������� ���� ������ �����
    function OpenDirectSQLFetchCols(
      const ASQLText: String;
      const ABufPtr: POdbcFetchCols
    ): Boolean;
  end;

  TDBMS_Connection = class(TInterfacedObject, IDBMS_Connection)
  private
{$if defined(USE_ODBC_DATASET)}
    FSyncPool: IReadWriteSync;
{$ifend}
    FPath: TETS_Path_Divided_W;
    FSQLConnection: TDBMS_Custom_Connection;
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
  protected
    procedure SaveInternalParameter(const AParamName, AParamValue: String);
    procedure KeepAuthenticationInfo;
    function ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
    function ApplyConnectionParams: Byte;
    function ApplySystemDSNtoConnection: Byte;
    function ApplyParamsToConnection(const AParams: TStrings): Byte;
    function IsTrustedConnection: Boolean;
    function GetEngineTypeUsingSQL(const ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode): TEngineType;
    function calc_exclusive_mode: AnsiChar;
  private
    function PasswordStorage_SaveParams(const AUserNameToSave, APasswordToSave: String): Boolean;
    function PasswordStorage_ReadParams(var ASavedUserName, ASavedPassword: String): Boolean;
    function PasswordStorage_ApplyStored: Boolean;
  private
    { IDBMS_Connection }
    
{$if defined(USE_ODBC_DATASET)}
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
{$ifend}

    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    function ExecuteDirectSQL(
      const ASQLText: TDBMS_String;
      const ASilentOnError: Boolean = FALSE // ����� �� ��������������
    ): Boolean;

    function ExecuteDirectWithBlob(
      const ASQLText: TDBMS_String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean = FALSE // ����� �� ��������������
    ): Boolean;

    function TableExists(const AFullyQualifiedQuotedTableName: TDBMS_String): Boolean;

    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;

    function GetConnectionErrorMessage: String;
    procedure ResetConnectionError;

    procedure ApplyCredentialsFormParams(const AFormParams: TStrings);
    function AllowSavePassword: Boolean;

    function CheckDirectSQLSingleNotNull(
      const ASQLText: String
    ): Boolean;

    function OpenDirectSQLFetchCols(
      const ASQLText: String;
      const ABufPtr: POdbcFetchCols
    ): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  end;

// get connection by path (create new or use existing)
function GetConnectionByPath(const APath: PETS_Path_Divided_W): IDBMS_Connection;
// free connection
procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);

implementation

uses
  IniFiles,
  Contnrs,
  u_PStoreTools,
  u_Synchronizer,
  u_DBMS_Utils;

{$if defined(USE_ODBC_DATASET)}
type
  TDBMS_Pooled_Dataset = class(TDBMS_Dataset)
  private
    FUsedInPool: Boolean;
  end;
{$ifend}

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

function GetConnectionByPath(const APath: PETS_Path_Divided_W): IDBMS_Connection;
{$if defined(DBMS_REUSE_CONNECTIONS)}
{$else}
var
  t: TDBMS_Connection;
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
  // create new connection and add it to p
  t := TDBMS_Connection.Create;
  t.FPath.CopyFrom(APath);
  Result := t;
{$ifend}
end;

procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);
begin
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.FSyncList.BeginWrite;
  try
    AConnection := nil;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
{$else}
  AConnection := nil;
{$ifend}
end;

{ TDBMS_Connection }

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
  VSectionName := FPath.AsEndpoint;

  // ���� �������� ����������� ����� ������ ODBC ������ ��� ��������� �������������� ���������� (��������, � ASE)
  // ����� ��������� ������� ������ � ������� ini

  // ����� ��� ������� � ��� �����, ������ ��� ��������� ������������ �� ����������� � ����
  // ��� ����������� ������� �� ��������� ������ ��������� ������������� � ������ �����
  VFilename :=
  GetModuleFileNameWithoutExt(
    TRUE,
{$if defined(USE_DIRECT_ODBC)}
    c_SQL_ODBC_Prefix_Ini,
{$elseif defined(ETS_USE_ZEOS)}
    c_SQL_ZEOS_Prefix_Ini,
{$else}
    c_SQL_DBX_Prefix_Ini,
{$ifend}
    ''
  ) + c_SQL_Ext_Ini;
  
  if FileExists(VFilename) then begin
    VIni:=TIniFile.Create(VFilename);
    try
      if VIni.SectionExists(VSectionName) then begin
        // found - read entire section
        VParams := TStringList.Create;
        try
          VIni.ReadSectionValues(VSectionName, VParams);
          // apply all params
          Result := ApplyParamsToConnection(VParams);
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
{$if defined(USE_DIRECT_ODBC)}
    // ��� ODBC ��������� ��������������� ���������� System DSN
    Result := ApplySystemDSNtoConnection;
{$else}
    // �� ��� ODBC ����� �� ������� ���������������
    Result := ETS_RESULT_INI_FILE_NOT_FOUND;
{$ifend}
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
    FSQLConnection.FETS_INTERNAL_SYNC_SQL_MODE := StrToIntDef(AParamValue, c_SYNC_SQL_MODE_None);
    Exit;
  end else if SameText(ETS_INTERNAL_PWD_Save, AParamName) then begin
    // ���������� ������ ����������� ������ (� ��� �� - ���������� ��������� ������) + ����� Lsa
    FSavePwdAsLsaSecret := SameText(AParamValue, ETS_INTERNAL_PWD_Save_Lsa);
    FReadPrevSavedPwd := FSavePwdAsLsaSecret or (StrToIntDef(AParamValue, 0) <> 0);
    Exit;
  end else if SameText(ETS_INTERNAL_ODBC_ConnectWithParams, AParamName) then begin
{$if defined(USE_DIRECT_ODBC)}
    FSQLConnection.ConnectWithParams := (StrToIntDef(AParamValue, 0) <> 0);
{$ifend}
    Exit;
  end else if SameText(ETS_INTERNAL_DBX_LibraryName, AParamName) then begin
{$if defined(ETS_USE_DBX)}
    FSQLConnection.LibraryName := AParamValue;
{$ifend}
    Exit;
  end else if SameText(ETS_INTERNAL_DBX_GetDriverFunc, AParamName) then begin
{$if defined(ETS_USE_DBX)}
    FSQLConnection.GetDriverFunc := AParamValue;
{$ifend}
    Exit;
  end else if SameText(ETS_INTERNAL_DBX_VendorLib, AParamName) then begin
{$if defined(ETS_USE_DBX)}
    FSQLConnection.VendorLib := AParamValue;
{$ifend}
    Exit;
  end;

  if (nil=FInternalParams) then
    FInternalParams := TStringList.Create;
  // ������ ���������� ��������� � ������
  FInternalParams.Values[AParamName] := AParamValue;
end;

function TDBMS_Connection.TableExists(const AFullyQualifiedQuotedTableName: TDBMS_String): Boolean;
begin
  Result := FSQLConnection.TableExistsDirect(AFullyQualifiedQuotedTableName);
end;

procedure TDBMS_Connection.ApplyCredentialsFormParams(const AFormParams: TStrings);
begin
  // ��������� ����� � ������
  if (FSQLConnection<>nil) then begin
{$if defined(USE_DIRECT_ODBC)}
    FSQLConnection.UID := AFormParams.Values[c_Cred_UserName];
    //FSQLConnection.Params.Values['UID'] := AFormParams.Values[c_Cred_UserName];
    FSQLConnection.PWD := AFormParams.Values[c_Cred_Password];
    //FSQLConnection.Params.Values['PWD'] := AFormParams.Values[c_Cred_Password];
{$elseif defined(ETS_USE_ZEOS)}
    FSQLConnection.User := AFormParams.Values[c_Cred_UserName];
    FSQLConnection.Password := AFormParams.Values[c_Cred_Password];
{$else}
    FSQLConnection.Params.Values[TDBXPropertyNames.UserName] := AFormParams.Values[c_Cred_UserName];
    FSQLConnection.Params.Values[TDBXPropertyNames.Password] := AFormParams.Values[c_Cred_Password];
{$ifend}
  end;

  // ����� ���� ������� ��������� ��������� ����������� - �������� ��
  if (AFormParams.Values[c_Cred_SaveAuth]='1') then begin
    PasswordStorage_SaveParams(AFormParams.Values[c_Cred_UserName], AFormParams.Values[c_Cred_Password]);
  end;
end;

function TDBMS_Connection.ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
{$if defined(USE_DIRECT_ODBC)}
{$elseif defined(ETS_USE_ZEOS)}
{$else}
var
  i: Integer;
  VParamName: String;
{$ifend}
begin
{$if defined(USE_DIRECT_ODBC)}
  // ODBC in delphi
  Result := ETS_RESULT_OK;
{$elseif defined(ETS_USE_ZEOS)}
  // zeos in delphi
  Result := ETS_RESULT_OK;
{$else}
  FSQLConnection.LoginPrompt := FALSE;
  FSQLConnection.LoadParamsOnConnect := FALSE;

  // set drivername and clear all params
  FSQLConnection.ConnectionName := '';
  FSQLConnection.DriverName := c_ODBC_DriverName;
  FSQLConnection.LibraryName := c_SQL_SubFolder + c_ODBC_LibraryName;
  FSQLConnection.GetDriverFunc := c_ODBC_GetDriverFunc;
  FSQLConnection.VendorLib := c_ODBC_VendorLib;

  // set params
  FSQLConnection.Params.Values[TDBXPropertyNames.DriverName] := FSQLConnection.DriverName;
  FSQLConnection.Params.Values[TDBXPropertyNames.Database] := FPath.Path_Items[0];

  if (AOptionalList<>nil) then
  if (AOptionalList.Count>0) then
  for i := 0 to AOptionalList.Count-1 do begin
    // ����������� ��������� ������� (�� �� ���!)
    VParamName := AOptionalList.Names[i];
    if SameText(Copy(VParamName,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // ������������� ���������� ��������
      SaveInternalParameter(VParamName, AOptionalList.ValueFromIndex[i]);
    end else begin
      // ���� � ��� �� ��� �����������
      if (not SameText(VParamName,TDBXPropertyNames.DriverName)) then begin
        FSQLConnection.Params.Values[VParamName] := AOptionalList.ValueFromIndex[i];
      end;
    end;
  end;

  // set connection name
  FSQLConnection.ConnectionName := FSQLConnection.DriverName + c_RTL_Connection + Format('%p',[Pointer(FSQLConnection)]);

  Result := ETS_RESULT_OK;
{$ifend}
end;

function TDBMS_Connection.ApplyParamsToConnection(const AParams: TStrings): Byte;
{$if defined(USE_DIRECT_ODBC)}
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
{$elseif defined(ETS_USE_ZEOS)}
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
{$else}
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
  VOldValue: WideString;
  VDBXProperties: TDBXProperties;
  VUseODBC: Boolean;
{$ifend}
begin
{$if defined(USE_DIRECT_ODBC)}
  // �� ��� �� ���������� - ����� � ��������� �����������
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // ������������� ���������� ��������
      SaveInternalParameter(VCurItem, VNewValue);
    end else begin
      // � ��������� �����������
      FSQLConnection.Params.Values[VCurItem] := VNewValue;
    end;
  end;

  // done

  if FReadPrevSavedPwd then begin
    PasswordStorage_ApplyStored;
  end;

  Result := ETS_RESULT_OK;
{$elseif defined(ETS_USE_ZEOS)}
  // ���� ����� ���������� � ��������, ������ ����� - � ������ �������� )):
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // ������������� ���������� ��������
      SaveInternalParameter(VCurItem, VNewValue);
    end else begin
      // ���������� ���� ������
      if SameText(VCurItem, c_ZEOS_Protocol) then
        FSQLConnection.Protocol := VNewValue
      else if SameText(VCurItem, c_ZEOS_HostName) then
        FSQLConnection.HostName := VNewValue
      else if SameText(VCurItem, c_ZEOS_Port) then
        FSQLConnection.Port := StrToIntDef(VNewValue,0)
      else if SameText(VCurItem, c_ZEOS_Database) then
        FSQLConnection.Database := VNewValue
      else if SameText(VCurItem, c_ZEOS_Catalog) then
        FSQLConnection.Catalog  := VNewValue
      else if SameText(VCurItem, c_ZEOS_User) then
        FSQLConnection.User     := VNewValue
      else if SameText(VCurItem, c_ZEOS_Password) then
        FSQLConnection.Password := VNewValue
      else // ������� - � ������ �������
        FSQLConnection.Properties.Values[VCurItem] := VNewValue;
    end;
  end;

  // done
  FSQLConnection.LoginPrompt := FALSE;
  Result := ETS_RESULT_OK;
{$else}
  // ������� ��� �������� �� ����������� ����������
  i := AParams.IndexOfName(TDBXPropertyNames.DriverName);
  if (i>=0) then begin
    // ������� ������
    VNewValue := AParams.Values[TDBXPropertyNames.DriverName];
    AParams.Delete(i);
    // ��������, ����� ���� ������� ��� ���� � ���������� �����������
    VOldValue := FSQLConnection.Params.Values[TDBXPropertyNames.DriverName];

    // ����� ������� ������� ����� ������� ODBC - ����� ��������� ��������� ���������
    VUseODBC := SameText(VNewValue, c_ODBC_DriverName);

    // compare
    if (not VUseODBC) then
    if (not WideSameText(VNewValue, VOldValue)) then begin
      // set new DriverName
      FSQLConnection.LoadParamsOnConnect := (AParams.Values[ETS_INTERNAL_LOAD_PARAMS_ON_CONNECT]='1');
      FSQLConnection.DriverName := VNewValue;
      FSQLConnection.ConnectionName := VNewValue + c_RTL_Connection;
      // default params
      VDBXProperties := TDBXConnectionFactory.GetConnectionFactory.GetDriverProperties(VNewValue);
      FSQLConnection.Params.Assign(VDBXProperties.Properties);
    end;
  end else begin
    // ������� �� ������ - ������ ���������� ������� ODBC
    VUseODBC := TRUE;
  end;

  if (Length(FPath.Path_Items[0])>0) then
    FSQLConnection.Params.Values[TDBXPropertyNames.HostName] := FPath.Path_Items[0]
  else
    FSQLConnection.Params.Values[TDBXPropertyNames.HostName] := '';

  if (Length(FPath.Path_Items[1])>0) then
    FSQLConnection.Params.Values[TDBXPropertyNames.Database] := FPath.Path_Items[1]
  else
    FSQLConnection.Params.Values[TDBXPropertyNames.Database] := '';

  // ���� �������� ����� ������� ODBC - ��������� ��������� � �����
  if VUseODBC then begin
    if Load_DSN_Params_from_ODBC(FPath.Path_Items[0], FODBCDescription) then begin
      // �������� ������ � ��������� DSN
      Result := ApplyODBCParamsToConnection(AParams);
    end else begin
      // �������� �� ������
      Result := ETS_RESULT_UNKNOWN_ODBC_DSN;
    end;
    Exit;
  end;

  // ����� ������ ���� �������� �� ����� ������� ODBC

  // apply other params
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // ������������� ���������� ��������
      SaveInternalParameter(VCurItem, AParams.ValueFromIndex[i]);
    end else begin
      // ����������� � ��
      VNewValue := AParams.ValueFromIndex[i];
      // current value
      VOldValue := FSQLConnection.Params.Values[VCurItem];
      // compare
      if (not WideSameText(VOldValue, VNewValue)) then begin
        // set new value
        FSQLConnection.Params.Values[VCurItem] := VNewValue;
      end;
    end;
  end;

  // set connection name (skip if set params on connect!)
  if (not FSQLConnection.LoadParamsOnConnect) then begin
    VCurItem := FSQLConnection.DriverName + c_RTL_Connection + Format('%p',[Pointer(FSQLConnection)]);
    if (not SameText(FSQLConnection.ConnectionName,VCurItem)) then begin
      // set or replace
      FSQLConnection.ConnectionName := VCurItem;
    end;
  end;

  Result := ETS_RESULT_OK;
{$ifend}
end;

function TDBMS_Connection.ApplySystemDSNtoConnection: Byte;
var
  VSystemDSNName: AnsiString;
begin
  // ���������� ���������� ����������� ��� ini-���
  // �������� �� ��� ���� ����
  VSystemDSNName := FPath.Path_Items[0];
  if Load_DSN_Params_from_ODBC(VSystemDSNName, FODBCDescription) then begin
    // ������� SystemDSN
    FSQLConnection.DSN := VSystemDSNName;

    PasswordStorage_ApplyStored;

    Result := ETS_RESULT_OK;
  end else begin
    // �� ��� ����
    Result := ETS_RESULT_INI_FILE_NOT_FOUND;
  end;
end;

function TDBMS_Connection.calc_exclusive_mode: AnsiChar;
begin
  case FSQLConnection.FETS_INTERNAL_SYNC_SQL_MODE of
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

function TDBMS_Connection.CheckDirectSQLSingleNotNull(const ASQLText: String): Boolean;
begin
  Result := FSQLConnection.CheckDirectSQLSingleNotNull(ASQLText);
end;

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Connection.CompactPool;
var
  i: Integer;
  t: TComponent;
begin
  FSyncPool.BeginWrite;
  try
    if (0<FSQLConnection.ComponentCount) then
    for i := FSQLConnection.ComponentCount-1 downto 0 do begin
      // get child component
      t := FSQLConnection.Components[i];
      if (t is TDBMS_Pooled_Dataset) then begin
        // pooled dataset
        if (not TDBMS_Pooled_Dataset(t).FUsedInPool) then begin
          // free if unused
          TDBMS_Pooled_Dataset(t).Free;
        end;
      end;
    end;
  finally
    FSyncPool.EndWrite;
  end;
end;
{$ifend}

constructor TDBMS_Connection.Create;
begin
  FEngineType := et_Unknown;
  FODBCDescription := '';
  inherited Create;
  FSavePwdAsLsaSecret := FALSE;
  FReadPrevSavedPwd := FALSE;
{$if defined(USE_ODBC_DATASET)}
  FSyncPool := MakeSync_Tiny(Self);
  FSQLConnection := TDBMS_Custom_Connection.Create(nil);
{$else}
  FSQLConnection := TDBMS_Custom_Connection.Create;
{$ifend}
  FInternalLoadLibraryStd := 0;
  FInternalLoadLibraryAlt := 0;
  FInternalParams := nil;
  FETS_INTERNAL_SCHEMA_PREFIX := '';
  FConnectionErrorMessage := '';
  FConnectionErrorCode := ETS_RESULT_OK;
end;

destructor TDBMS_Connection.Destroy;
begin
  // called from FreeDBMSConnection - not need to sync
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.InternalRemoveConnection(Self);
{$ifend}

{$if defined(USE_ODBC_DATASET)}
  CompactPool;
{$ifend}

  try
{$if defined(USE_DIRECT_ODBC)}
    // �����
{$elseif defined(ETS_USE_ZEOS)}
    FSQLConnection.CloseAllDataSets;
    //FSQLConnection.CloseAllSequences;
{$else}
    FSQLConnection.CloseDataSets;
{$ifend}
  except
  end;

  try
{$if defined(USE_DIRECT_ODBC)}
    FSQLConnection.Disconnect;
{$elseif defined(ETS_USE_ZEOS)}
    FSQLConnection.Disconnect;
{$else}
    FSQLConnection.Close;
{$ifend}
  except
  end;

  try
    FreeAndNil(FSQLConnection);
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

{$if defined(USE_ODBC_DATASET)}
  FSyncPool := nil;
{$ifend}

  inherited;
end;

function TDBMS_Connection.ExecuteDirectSQL(
  const ASQLText: TDBMS_String;
  const ASilentOnError: Boolean
): Boolean;
begin
{$if defined(USE_DIRECT_ODBC)}
  Result := FSQLConnection.ExecuteDirectSQL(ASQLText, ASilentOnError);
{$elseif defined(ETS_USE_ZEOS)}
  // ZEOS
  Result := FSQLConnection.ExecuteDirect(ASQLText);
{$else}
  // DBX
  FSQLConnection.ExecuteDirect(ASQLText);
  Result := TRUE;
{$ifend}
end;

function TDBMS_Connection.ExecuteDirectWithBlob(
  const ASQLText: TDBMS_String;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  const ASilentOnError: Boolean
): Boolean;
{$if not defined(USE_DIRECT_ODBC)}
var
  VDBMS_Dataset: TDBMS_Dataset;
{$ifend}
begin
  // ����� � ��� ������ ��� ��������� ':tile_body' aka c_RTL_Tile_Body_Paramname
{$if defined(USE_DIRECT_ODBC)}
  Result := FSQLConnection.ExecuteDirectWithBlob(ASQLText, c_RTL_Tile_Body_Paramname, ABufferAddr, ABufferSize, ASilentOnError);
{$elseif defined(ETS_USE_ZEOS)}
  // ZEOS
  VDBMS_Dataset := Self.MakePoolDataset;
  try
    VDBMS_Dataset.SQL.Text := ASQLText;
    VDBMS_Dataset.SetParamBlobData(c_RTL_Tile_Body_Paramsrc, ABufferAddr, ABufferSize);
    VDBMS_Dataset.ExecSQL;
    Result := TRUE;
  finally
    Self.KillPoolDataset(VDBMS_Dataset);
  end;
{$else}
  // DBX
  VDBMS_Dataset := Self.MakePoolDataset;
  try
    VDBMS_Dataset.SQL.Text := ASQLText;
    VDBMS_Dataset.SetParamBlobData(c_RTL_Tile_Body_Paramsrc, ABufferAddr, ABufferSize);
    VDBMS_Dataset.ExecSQL;
    Result := TRUE;
  finally
    Self.KillPoolDataset(VDBMS_Dataset);
  end;
{$ifend}
end;

function TDBMS_Connection.EnsureConnected(
  const AllowTryToConnect: Boolean;
  AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
): Byte;
begin
  if FSQLConnection.Connected then begin
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

      // ��������� ����� � ����
      if (AStatusBuffer<>nil) then
      with (AStatusBuffer^) do begin
        if wSize>=SizeOf(AStatusBuffer^) then
          exclusive_mode := calc_exclusive_mode;
      end;

      // try to connect
      try
        FSQLConnection.Connected := TRUE;
        FConnectionErrorMessage := '';
        FConnectionErrorCode := ETS_RESULT_OK;

        // connected - ��������� ������� � ����
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

          // failed - ��������� ������� � ����
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
      FSQLConnection.CheckByteaAsLoOff(et_PostgreSQL=GetCheckedEngineType);

      KeepAuthenticationInfo;
      Result := ETS_RESULT_OK;
    end else begin
      // cannot connect
      Result := ETS_RESULT_NEED_EXCLUSIVE;
    end;
  end;
end;

function TDBMS_Connection.ForcedSchemaPrefix: String;
begin
  Result := FETS_INTERNAL_SCHEMA_PREFIX;
end;

function TDBMS_Connection.FullSyncronizeSQL: Boolean;
begin
  // ���� c_SYNC_SQL_MODE_All_In_DLL - ���������������� ������� ���������
  Result := (FSQLConnection.FETS_INTERNAL_SYNC_SQL_MODE=c_SYNC_SQL_MODE_All_In_DLL) or (not FSQLConnection.Connected);
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
{$if defined(USE_DIRECT_ODBC)}
        if Load_DSN_Params_from_ODBC(
{$if defined(USE_ODBC_DATASET)}
          FSQLConnection.SystemDSN,
{$else}
          FSQLConnection.DSN,
{$ifend}
          FODBCDescription
        ) then
          FEngineType := GetEngineTypeByODBCDescription(FODBCDescription, VSecondarySQLCheckServerTypeMode)
        else
          FEngineType := GetEngineTypeByODBCDescription(
{$if defined(USE_ODBC_DATASET)}
            FSQLConnection.SystemDSN,
{$else}
            FSQLConnection.DSN,
{$ifend}
            VSecondarySQLCheckServerTypeMode
          );
{$elseif defined(ETS_USE_ZEOS)}
        FEngineType := GetEngineTypeByZEOSLibProtocol(FSQLConnection.Protocol);
{$else}
        FEngineType := GetEngineTypeByDBXDriverName(FSQLConnection.DriverName, FODBCDescription, VSecondarySQLCheckServerTypeMode);
{$ifend}
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
{$if defined(USE_ODBC_DATASET)}
  VDataset: TDBMS_Dataset;
{$else}
  VOdbcFetchColsEx: TOdbcFetchCols12;
{$ifend}
  VSQLText: TDBMS_String;
  VText: AnsiString;
begin
  if (not FSQLConnection.Connected) then begin
    // not connected
    Result := et_Unknown;
  end else begin
    // connected
{$if defined(USE_ODBC_DATASET)}
    VDataset := MakePoolDataset;
{$else}
    VOdbcFetchColsEx.Init;
{$ifend}
    try
      // ����������� ���� ������� ������ �� ��� ������� �� ��������� ��������

      // ������ �������� select @@version // MSSQL+ASE+ASA
      VSQLText := 'SELECT @@VERSION as v';
      try
{$if defined(USE_ODBC_DATASET)}
        VDataset.OpenSQL(VSQLText);
{$else}
        FSQLConnection.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));
{$ifend}

{$if defined(USE_ODBC_DATASET)}
        if VDataset.FieldCount>0 then
        if (VDataset.Fields[0].DataType in [ftString, ftFixedChar, ftMemo, ftWideString, ftFixedWideChar, ftWideMemo, ftFmtMemo]) then begin
          VText := UpperCase(VDataset.Fields[0].AsString);
          if GetEngineTypeUsingSQL_Version_Upper(VText, Result) then
            Exit;
        end;
{$else}
        // ����� ������ ����
        VOdbcFetchColsEx.Base.ColToAnsiString(1, VText);
        if GetEngineTypeUsingSQL_Version_Upper(VText, Result) then
          Exit;
{$ifend}

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
{$if defined(USE_ODBC_DATASET)}
      KillPoolDataset(VDataset);
{$else}
      VOdbcFetchColsEx.Base.Close;
{$ifend}
    end;
  end;
end;

function TDBMS_Connection.IsTrustedConnection: Boolean;
{$if defined(USE_DIRECT_ODBC)}
{$elseif defined(ETS_USE_ZEOS)}
{$else}
var
  VEngineType: TEngineType;
  VDriverParam: String;
  VValue: WideString;
{$ifend}
begin
{$if defined(USE_DIRECT_ODBC)}
  Result := (0=Length(FSQLConnection.UID));
{$elseif defined(ETS_USE_ZEOS)}
  Result := (0=Length(FSQLConnection.User));
{$else}
  VEngineType := GetCheckedEngineType;

  // �������� �������� 'OS Authentication' ��� MSSQL
  if (et_MSSQL=VEngineType) then begin
    VValue := FSQLConnection.Params.Values[c_RTL_Trusted_Connection];
    if (0<Length(VValue)) then begin
      // ���-�� �������
      Result :=  (WideSameText(VValue, 'true') or WideSameText(VValue, 'yes'));
      Exit;
    end;
  end;

  // ������� ��������
  VDriverParam := c_SQL_Integrated_Security[VEngineType];
  Result := (0<Length(VDriverParam));
  if (not Result) then
    Exit;

  VValue := FSQLConnection.Params.Values[VDriverParam];
  Result := (0<Length(VValue)) and (WideSameText(VValue, 'true') or WideSameText(VValue, 'yes'));
{$ifend}
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
    VServer := G_ConnectionList.InternalGetServerObject(FPath.Path_Items[0]);
    if (VServer<>nil) then begin
      if (not VServer.FAuthDefined) then begin
{$if defined(USE_DIRECT_ODBC)}
        VServer.FUsername := FSQLConnection.UID;
        VServer.FPassword := FSQLConnection.PWD;
{$elseif defined(ETS_USE_ZEOS)}
        VServer.FUsername := FSQLConnection.User;
        VServer.FPassword := FSQLConnection.Password;
{$else}
        VServer.FUsername := FSQLConnection.Params.Values[TDBXPropertyNames.UserName];
        VServer.FPassword := FSQLConnection.Params.Values[TDBXPropertyNames.Password];
{$ifend}
      end;
      VServer.FAuthFailed := FALSE;
      VServer.FAuthOK := TRUE;
    end;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
{$ifend}
end;

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Connection.KillPoolDataset(var ADataset: TDBMS_Dataset);
begin
  if (ADataset<>nil) then
    ADataset.Close;

  if (ADataset is TDBMS_Pooled_Dataset) then begin
    // check if in its pool
    Assert((ADataset.Owner=FSQLConnection),'KillPoolDataset mismatch');
    // dataset in pool
    FSyncPool.BeginWrite;
    try
      TDBMS_Pooled_Dataset(ADataset).FUsedInPool := FALSE;
    finally
      FSyncPool.EndWrite;
    end;
    ADataset := nil;
  end else begin
    // common dataset
    FreeAndNil(ADataset);
  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
function TDBMS_Connection.MakePoolDataset: TDBMS_Dataset;
var
  i: Integer;
  t: TComponent;
begin
  FSyncPool.BeginWrite;
  try
    // get any unused object
    if (0<FSQLConnection.ComponentCount) then
    for i := FSQLConnection.ComponentCount-1 downto 0 do begin
      // get child component
      t := FSQLConnection.Components[i];
      if (t is TDBMS_Pooled_Dataset) then begin
        // pooled dataset
        if (not TDBMS_Pooled_Dataset(t).FUsedInPool) then begin
          // returns unused object
          TDBMS_Pooled_Dataset(t).FUsedInPool := TRUE;
          Result := TDBMS_Pooled_Dataset(t);
          Exit;
        end;
      end;
    end;

    // no unused objects - make new object
    Result := TDBMS_Pooled_Dataset.Create(FSQLConnection);
    TDBMS_Pooled_Dataset(Result).FUsedInPool := TRUE;
{$if defined(USE_MODBC)}
    Result.DataBase := FSQLConnection;
{$elseif defined(USE_DIRECT_ODBC)}
    Result.SQLConnection := FSQLConnection;
{$elseif defined(ETS_USE_ZEOS)}
    Result.Connection := FSQLConnection;
    Result.FUsePingServer := c_ZEOS_Use_PingServer[GetCheckedEngineType];
{$else}
    // DBX
    Result.SQLConnection := FSQLConnection;
{$ifend}
  finally
    FSyncPool.EndWrite;
  end;
end;
{$ifend}

function TDBMS_Connection.OpenDirectSQLFetchCols(const ASQLText: String; const ABufPtr: POdbcFetchCols): Boolean;
begin
  Result := FSQLConnection.OpenDirectSQLFetchCols(ASQLText, ABufPtr);
end;

function TDBMS_Connection.PasswordStorage_ApplyStored: Boolean;
var
  VSavedUserName, VSavedPassword: String;
begin
  Result := PasswordStorage_ReadParams(VSavedUserName, VSavedPassword);
  if Result then begin
    FSQLConnection.Params.Values['UID'] := VSavedUserName;
    FSQLConnection.Params.Values['PWD'] := VSavedPassword;
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

  if VPKeyedCrypter.LoadSecret(FPath.AsEndpoint, VSecretValue) then begin
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

  Result := VPKeyedCrypter.SaveSecret(FPath.AsEndpoint, VSecretValue);
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
  p := InternalGetServerObject(AConnection.FPath.Path_Items[0]);
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
  p := InternalGetServerObject(APath^.Path_Items[0]);
  if (nil=p) then begin
    // create new server
    p := TDBMS_Server.Create;
    p.OwnsObjects := FALSE;
    p.FServerName := APath^.Path_Items[0];
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
      if WideSameStr(FPath.Path_Items[0], APath^.Path_Items[0]) then
      if WideSameStr(FPath.Path_Items[1], APath^.Path_Items[1]) then{
      if WideSameStr(FPath.Path_Items[2], APath^.Path_Items[2]) then} begin
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

{ TDBMS_Dataset }

{$if defined(USE_ODBC_DATASET)}
function TDBMS_Dataset.ClobAsWideString(
  const AFieldName: TDBMS_String;
  out AResult: TDBMS_String
): Boolean;
var
  VSqlTextField: TField;
begin
  VSqlTextField := Self.FieldByName(AFieldName);
  Result := (not VSqlTextField.IsNull);
  if Result then begin
{$if defined(USE_WIDESTRING_FOR_SQL)}
    AResult := VSqlTextField.AsWideString;
{$else}
    AResult := VSqlTextField.AsString;
{$ifend}
  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
function TDBMS_Dataset.CreateFieldBlobReadStream(const AFieldName: TDBMS_String): TStream;
var
  F: TField;
  //S: String;
  {$if defined(USE_MODBC)}
  VStream: TStream;
  {$ifend}
begin
  F := Self.FindField(AFieldName);
  if (nil=F) then begin
    Result := nil;
    Exit;
  end;
(*
  if (F is TVarBytesField) then begin
    // �������� ���������
    S := TVarBytesField(F).AsString;
    Result := TMemoryStream.Create;
    Result.Write(PChar(S)^, Length(S));
    Result.Position := 0;
  end else begin
*)
    // ������ BLOB
    {$if defined(USE_MODBC)}
    VStream := Self.CreateBlobStream(F, bmRead);
    try
      Result := TMemoryStream.Create;
      Result.CopyFrom(VStream, VStream.Size);
      Result.Position := 0;
    finally
      VStream.Free;
    end;
    {$else}
    Result := Self.CreateBlobStream(F, bmRead);
    {$ifend}
//  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.ExecSQLDirect;
var VLocked: Boolean;
begin
{$if defined(USE_MODBC)}
  TDBMS_Custom_Connection(DataBase).BeforeSQL(VLocked);
  try
    ExecSQL;
  finally
    TDBMS_Custom_Connection(DataBase).AfterSQL(VLocked);
  end;
{$elseif defined(USE_DIRECT_ODBC)}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    SQLConnection.ExecuteDirectSQL(CommandText, FALSE);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$elseif defined(ETS_USE_ZEOS)}
  TDBMS_Custom_Connection(Connection).BeforeSQL(VLocked);
  try
    if FUsePingServer then begin
      Connection.PingServer;
    end;
    ExecSQL;
  finally
    TDBMS_Custom_Connection(Connection).AfterSQL(VLocked);
  end;
{$else}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    ExecSQL(TRUE);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$ifend}
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.ExecSQLParsed;
var VLocked: Boolean;
begin
{$if defined(USE_MODBC)}
  TDBMS_Custom_Connection(DataBase).BeforeSQL(VLocked);
  try
    ExecSQL;
  finally
    TDBMS_Custom_Connection(DataBase).AfterSQL(VLocked);
  end;
{$elseif defined(USE_DIRECT_ODBC)}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    SQLConnection.ExecuteDirectSQL(CommandText, FALSE);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$elseif defined(ETS_USE_ZEOS)}
  TDBMS_Custom_Connection(Connection).BeforeSQL(VLocked);
  try
    if FUsePingServer then begin
      Connection.PingServer;
    end;
    ExecSQL;
  finally
    TDBMS_Custom_Connection(Connection).AfterSQL(VLocked);
  end;
{$else}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    ExecSQL(FALSE);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$ifend}
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.ExecSQLSpecified(const ADirectExec: Boolean);
var VLocked: Boolean;
begin
{$if defined(USE_MODBC)}
  TDBMS_Custom_Connection(DataBase).BeforeSQL(VLocked);
  try
     ExecSQL;
  finally
    TDBMS_Custom_Connection(DataBase).AfterSQL(VLocked);
  end;
{$elseif defined(USE_DIRECT_ODBC)}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    SQLConnection.ExecuteDirectSQL(CommandText, FALSE);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$elseif defined(ETS_USE_ZEOS)}
  TDBMS_Custom_Connection(Connection).BeforeSQL(VLocked);
  try
    if FUsePingServer then begin
      Connection.PingServer;
    end;
    ExecSQL;
  finally
    TDBMS_Custom_Connection(Connection).AfterSQL(VLocked);
  end;
{$else}
  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    ExecSQL(ADirectExec);
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$ifend}
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
function TDBMS_Dataset.GetAnsiCharFlag(
  const AFieldName: TDBMS_String;
  const ADefaultValue: AnsiChar
): AnsiChar;
var
  VField: TField;
  VValue: String;
begin
  VField := Self.FindField(AFieldName);

  // if field not found or is NULL - use default value
  if (nil=VField) or (VField.IsNull) then begin
    Result := ADefaultValue;
    Exit;
  end;

  // common string field
  if (VField is TStringField) then begin
    VValue := TStringField(VField).Value;
    if (0=Length(VValue)) then begin
      // empty string
      Result := ADefaultValue;
    end else begin
      // with value
      Result := VValue[1];
    end;
    Exit;
  end;

  // unsupported fields
  Result := ADefaultValue;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
function TDBMS_Dataset.GetOptionalSmallInt(
  const AFieldName: TDBMS_String;
  const ADefaultValue: SmallInt
): SmallInt;
var
  VField: TField;
begin
  VField := Self.FindField(AFieldName);

  // if field not found or is NULL - use default value
  if (nil=VField) or (VField.IsNull) then begin
    Result := ADefaultValue;
    Exit;
  end;

  try
    Result := VField.AsInteger;
  except
    Result := ADefaultValue;
  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.OpenSQL(const ASQLText: TDBMS_String);
var VLocked: Boolean;
begin
  // ������� ���� ������� �������
  if Active then
    Close;

{$if defined(USE_MODBC)}
  // ��������� ����� �������
  Self.SQL.Text := ASQLText;

  TDBMS_Custom_Connection(DataBase).BeforeSQL(VLocked);
  try
    Self.Open;
  finally
    TDBMS_Custom_Connection(DataBase).AfterSQL(VLocked);
  end;
  
{$elseif defined(ETS_USE_ZEOS)}
  // ��������� ����� �������
  Self.SQL.Text := ASQLText;

  TDBMS_Custom_Connection(Connection).BeforeSQL(VLocked);
  try
    if FUsePingServer then begin
      Connection.PingServer;
    end;

    Self.Open;
    
    if VLocked then begin
      FetchAll;
    end;
  finally
    TDBMS_Custom_Connection(Connection).AfterSQL(VLocked);
  end;
{$else}
  // DBX � ODBC
  // ��������� ����� �������
  Self.CommandText := ASQLText;

  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    Self.Open;
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$ifend}
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.SetParamBlobData(const AParamName: TDBMS_String;
  const ABufferAddr: Pointer; const ABufferSize: LongInt);
begin
  with Self.Params.ParamByName(AParamName) do begin
    if (ABufferSize>0) then
      SetBlobData(ABufferAddr, ABufferSize)
    else
      Clear;
  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.SetSQLTextAsString(const ASQLText: TDBMS_String);
begin
{$if defined(USE_VSAODBC)}
  CommandText := ASQLText;
{$else}
  SQL.Text := ASQLText;
{$ifend}
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Dataset.SetSQLTextAsStrings(const ASQLText: TStrings);
begin
{$if defined(USE_VSAODBC)}
  CommandText := ASQLText.Text;
{$else}
  SQL.Clear;
  SQL.AddStrings(ASQLText);
{$ifend}
end;
{$ifend}

{ TDBMS_Custom_Connection }

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Custom_Connection.AfterSQL(const ALocked: Boolean);
begin
  if ALocked then begin
    LeaveCriticalSection(FSYNC_SQL_MODE_CS);
  end;
end;
{$ifend}

{$if defined(USE_ODBC_DATASET)}
procedure TDBMS_Custom_Connection.BeforeSQL(out ALocked: Boolean);
begin
  ALocked := (FETS_INTERNAL_SYNC_SQL_MODE=c_SYNC_SQL_MODE_Statements);
  if ALocked then begin
    EnterCriticalSection(FSYNC_SQL_MODE_CS);
  end;
end;
{$ifend}

constructor TDBMS_Custom_Connection.Create
{$if defined(USE_ODBC_DATASET)}
(AOwner: TComponent)
{$ifend}
;
begin
  inherited Create
{$if defined(USE_ODBC_DATASET)}
  (AOwner)
{$ifend}
  ;
  FETS_INTERNAL_SYNC_SQL_MODE := 0;
{$if defined(USE_ODBC_DATASET)}
  InitializeCriticalSection(FSYNC_SQL_MODE_CS);
{$ifend}
end;

{$if defined(USE_ODBC_DATASET)}
destructor TDBMS_Custom_Connection.Destroy;
begin
  DeleteCriticalSection(FSYNC_SQL_MODE_CS);
  inherited Destroy;
end;
{$ifend}

{$if defined(DBMS_REUSE_CONNECTIONS)}
initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
{$ifend}
end.
