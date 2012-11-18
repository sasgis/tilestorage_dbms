unit u_DBMS_Connect;

interface

uses
  SysUtils,
  Windows,
  Classes,
  t_SQL_types,
  t_DBMS_Template,
  t_DBMS_Connect,
{$if defined(ETS_USE_ZEOS)}

{$else}
  DB,
  DBXCommon,
  DBXDynaLink,
  //DBX34Drv,
  SQLExpr,
{$ifend}
  t_ETS_Path,
  t_ETS_Tiles;

type
  // base dataset
  TDBMS_Dataset = class(TSQLQuery) // TSQLQuery  // TSQLDataSet
  public
    // set SQL text and open it
    procedure OpenSQL(const ASQLText: WideString);
    // get value as ansichar
    function GetAnsiCharFlag(
      const AFieldName: WideString;
      const ADefaultValue: AnsiChar
    ): AnsiChar;
  end;

  IDBMS_Connection = interface
  ['{D5809427-36C7-49D7-83ED-72C567BD6E08}']
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
    function MakeNonPooledDataset: TDBMS_Dataset;
    function EnsureConnected(const AllowTryToConnect: Boolean): Byte;
    // ��� ������� ��
    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;
    // ���������� ���������
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
  end;

  TDBMS_Connection = class(TInterfacedObject, IDBMS_Connection)
  private
    FSyncPool: IReadWriteSync;
    FPath: TETS_Path_Divided_W;
    FSQLConnection: TSQLConnection;
    FEngineType: TEngineType;
    FODBCDescription: WideString;
    // ���������� ��������� �� ini
    FInternalParams: TStringList;
    // ���� ����� ����� ����� DLL - ���������� �� TStringList
    FInternalLoadLibrary: THandle;
  private
    procedure SaveInternalParameter(const AParamName, AParamValue: String);
    function ApplyAuthenticationInfo: Byte;
    procedure KeepAuthenticationInfo;
    function ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
    function ApplyConnectionParams: Byte;
    function ApplyParamsToConnection(const AParams: TStrings): Byte;
  private
    function IsTrustedConnection: Boolean;
    function GetEngineTypeUsingSQL: TEngineType;
  private
    { IDBMS_Connection }
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
    function MakeNonPooledDataset: TDBMS_Dataset;
    function EnsureConnected(const AllowTryToConnect: Boolean): Byte;
    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
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
  u_Synchronizer,
  u_DBMS_Utils,
  u_ODBC_DSN;

type
  TDBMS_Pooled_Dataset = class(TDBMS_Dataset)
  private
    FUsedInPool: Boolean;
  end;

  TDBMS_Server = class(TObjectList)
  private
    // credentials
    FServerName: WideString;
    FUsername: WideString;
    FPassword: WideString;
    FAuthDefined: Boolean;
    FAuthOK: Boolean;
    FAuthFailed: Boolean;
  end;

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

var
  G_ConnectionList: TDBMS_ConnectionList;

function GetConnectionByPath(const APath: PETS_Path_Divided_W): IDBMS_Connection;
begin
  G_ConnectionList.FSyncList.BeginWrite;
  try
    Result := G_ConnectionList.SafeMakeConnection(APath);
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
end;

procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);
begin
  G_ConnectionList.FSyncList.BeginWrite;
  try
    AConnection := nil;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
end;

{ TDBMS_Connection }

function TDBMS_Connection.ApplyAuthenticationInfo: Byte;
(*
var
  VServer: TDBMS_Server;
  VUIDParamName, VPwdParamName: WideString;
  VUsername: WideString;
  VPassword: WideString;
*)
begin
  // ���� ��� �� ������ �� ini
(*
  if SameText(FSQLConnection.DriverName,c_RTL_Interbase) then begin
    VUIDParamName := 'UID';
    VPwdParamName := 'PWD';
  end else begin
    VUIDParamName := TDBXPropertyNames.UserName;
    VPwdParamName := TDBXPropertyNames.Password;
  end;

  VUsername := '';
  VPassword := '';

  if IsTrustedConnection then begin
    // if Trusted_Connection=True - keep empty
    FSQLConnection.Params.Values[VUIDParamName] := '';
    FSQLConnection.Params.Values[VPwdParamName] := '';
  end else begin
    // get info from G_ConnectionList
    G_ConnectionList.FSyncList.BeginWrite;
    try
      VServer := G_ConnectionList.InternalGetServerObject(FPath.Path_Items[0]);
      if (VServer<>nil) then begin
        // if failed - returns with error
        if VServer.FAuthFailed then begin
          Result := ETS_RESULT_AUTH_FAILED;
          Exit;
        end;

        // server found - get flags and values
        if VServer.FAuthDefined then begin
          // has some credentials
          VUsername := VServer.FUsername;
          VPassword := VServer.FPassword;
        end else begin
          // �������� ����� ���� �������� ����������� ��� ������
          if (0<Length(c_SQL_Integrated_Security[GetCheckedEngineType])) then begin
            // �� ���� ��� ��������
            VUsername := '';
            VPassword := '';
            //FSQLConnection.Params.Values[c_SQL_Integrated_Security[GetCheckedEngineType]] := 'true';
          end else begin
            // ����������� ����� ����� � ������
            // TODO: �������� ��� �� ���������
            VUsername := 'sa';
            VPassword := '';
          end;
        end;
      end else begin
        // fuckup - try empty values
      end;
    finally
      G_ConnectionList.FSyncList.EndWrite;
    end;

    // apply User_Name and Password
    FSQLConnection.Params.Values[VUIDParamName] := VUsername;
    FSQLConnection.Params.Values[VPwdParamName] := VPassword;
  end;

*)
  FSQLConnection.LoginPrompt := FALSE;

  Result := ETS_RESULT_OK;
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
  VFilename := GetModuleFileNameWithoutExt(TRUE, c_SQL_DBX_Prefix_Ini, '')+c_SQL_Ext_Ini;
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
    Result := ETS_RESULT_INI_FILE_NOT_FOUND;
  end;

  (*
  // 2. get params from ODBC sources (only by ODBCSERVERNAME) and add DATABASENAME if not defined
  if Load_DSN_Params_from_ODBC(FPath.Path_Items[0], FODBCDescription) then begin
    // VDescription is the description of the driver associated with the data source
    // For example, dBASE or SQL Server
    ApplyODBCParamsToConnection(nil);
  end;
  *)
end;

procedure TDBMS_Connection.SaveInternalParameter(const AParamName, AParamValue: String);
begin
  // ���� ����������� DLL ���������� - �� ����� � ��������� � ������ ���������� ����������
  if SameText(ETS_INTERNAL_LOAD_LIBRARY, AParamName) and (FInternalLoadLibrary=0) and (0<Length(AParamValue)) then begin
    FInternalLoadLibrary := LoadLibrary(PChar(AParamValue));
    if (FInternalLoadLibrary<>0) then
      Exit;
  end;

  // ���� ��� ��������� ��� ������� �������� DBX - ����� � ��������� ��
  if SameText(ETS_INTERNAL_DBX_LibraryName, AParamName) then begin
    FSQLConnection.LibraryName := AParamValue;
    Exit;
  end else if SameText(ETS_INTERNAL_DBX_GetDriverFunc, AParamName) then begin
    FSQLConnection.GetDriverFunc := AParamValue;
    Exit;
  end else if SameText(ETS_INTERNAL_DBX_VendorLib, AParamName) then begin
    FSQLConnection.VendorLib := AParamValue;
    Exit;
  end;

  if (nil=FInternalParams) then
    FInternalParams := TStringList.Create;
  // ������ ���������� ��������� � ������
  FInternalParams.Values[AParamName] := AParamValue;
end;

function TDBMS_Connection.ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
var
  i: Integer;
  VParamName: String;
begin
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
      // ���� � �� ��� ��� �����������
      if (not SameText(VParamName,TDBXPropertyNames.DriverName)) then begin
        FSQLConnection.Params.Values[VParamName] := AOptionalList.ValueFromIndex[i];
      end;
    end;
  end;

  // set connection name
  FSQLConnection.ConnectionName := FSQLConnection.DriverName + c_RTL_Connection + Format('%p',[Pointer(FSQLConnection)]);

  Result := ETS_RESULT_OK;
end;

function TDBMS_Connection.ApplyParamsToConnection(const AParams: TStrings): Byte;
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
  VOldValue: WideString;
  VDBXProperties: TDBXProperties;
  VUseODBC: Boolean;
begin
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
end;

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

constructor TDBMS_Connection.Create;
begin
  FEngineType := et_Unknown;
  FODBCDescription := '';
  inherited Create;
  FSyncPool := MakeSync_Tiny(Self);
  FSQLConnection := TSQLConnection.Create(nil);
  FInternalLoadLibrary := 0;
  FInternalParams := nil;
end;

destructor TDBMS_Connection.Destroy;
begin
  // called from FreeDBMSConnection - not need to sync
  G_ConnectionList.InternalRemoveConnection(Self);
  
  CompactPool;

  try
    FSQLConnection.CloseDataSets;
  except
  end;

  try
    FSQLConnection.Close;
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

  if (FInternalLoadLibrary<>0) then begin
    FreeLibrary(FInternalLoadLibrary);
    FInternalLoadLibrary:=0;
  end;

  FSyncPool := nil;

  inherited;
end;

function TDBMS_Connection.EnsureConnected(const AllowTryToConnect: Boolean): Byte;
begin
  if FSQLConnection.Connected then begin
    // connected
    Result := ETS_RESULT_OK;
  end else begin
    // not connected
    if AllowTryToConnect then begin
      // apply params and try to connect
      Result := ApplyConnectionParams;
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // apply auth info
      Result := ApplyAuthenticationInfo;
      if (ETS_RESULT_OK<>Result) then
        Exit;
      
      // try to connect
      try
        FSQLConnection.Connected := TRUE;
        KeepAuthenticationInfo;
        Result := ETS_RESULT_OK;
      except
        // TODO: transfer exception message to host
        Result := ETS_RESULT_NOT_CONNECTED;
        // Result := ETS_RESULT_AUTH_FAILED;
      end;
    end else begin
      // cannot connect
      Result := ETS_RESULT_NEED_EXCLUSIVE;
    end;
  end;
end;

function TDBMS_Connection.ForcedSchemaPrefix: String;
begin
  Result := GetInternalParameter(ETS_INTERNAL_SCHEMA);
  if (0<Length(Result)) then begin
    Result := Result + '.';
  end;
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

function TDBMS_Connection.GetEngineType(const ACheckMode: TCheckEngineTypeMode): TEngineType;
begin
  case ACheckMode of
    cetm_Check: begin
      // check if not checked
      // allow get info from driver
      if (et_Unknown=FEngineType) then begin
        FEngineType := GetEngineTypeByDBXDriverName(FSQLConnection.DriverName, FODBCDescription);
        if (et_Unknown=FEngineType) then begin
          // use sql requests
          FEngineType := GetEngineTypeUsingSQL;
        end;
      end;
    end;
    cetm_Force: begin
      // (re)check via SQL requests
      FEngineType := GetEngineTypeUsingSQL;
    end;
  end;

  Result := FEngineType;
end;

function TDBMS_Connection.GetEngineTypeUsingSQL: TEngineType;
var
  VDataset: TDBMS_Dataset;
  VText: String;
begin
  if (EnsureConnected(FALSE) <> ETS_RESULT_OK) then begin
    // not connected
    Result := et_Unknown;
  end else begin
    // connected
    VDataset := MakePoolDataset;
    try
      // first check
      try
        VDataset.OpenSQL(c_SQLCMD_VERSION_S);
        if VDataset.FieldCount>0 then
        if (VDataset.Fields[0].DataType in [ftString, ftFixedChar, ftMemo, ftWideString, ftFixedWideChar, ftWideMemo]) then begin
          VText := LowerCase(VDataset.Fields[0].AsString);
          if GetEngineTypeUsingSQL_Version_S(VText, Result) then
            Exit;
        end;
        // unknown
        Result := et_Unknown;
      except
        on E: Exception do begin
          // TODO: check message is about 'FROM' clause
        end;
      end;

      // second check
      try
        VDataset.OpenSQL(c_SQLCMD_FROM_DUAL);
        // TODO: check resultset
      except
        on E: Exception do begin
          // TODO: check message
        end;
      end;
      
    finally
      KillPoolDataset(VDataset);
    end;
  end;
end;

function TDBMS_Connection.IsTrustedConnection: Boolean;
var
  VEngineType: TEngineType;
  VDriverParam: String;
  VValue: WideString;
begin
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

  // www.connectionstrings.com

  // MySQL (allow):
  // Server=myServerAddress;Database=myDataBase;IntegratedSecurity=yes;Uid=auth_windows;

  // SQL Server 2008 (allow):
  // Data Source=myServerAddress;Initial Catalog=myDataBase;Integrated Security=SSPI;
  // Server=myServerAddress;Database=myDataBase;Trusted_Connection=True;
  // Server=.\SQLExpress;AttachDbFilename=|DataDirectory|mydbfile.mdf;Database=dbname;Trusted_Connection=Yes;

  // Oracle (allow):
  // Data Source=TORCL;User Id=myUsername;Password=myPassword;
  // Data Source=TORCL;Integrated Security=SSPI;
  // Data Source=myOracle;User Id=/;
  // Provider=msdaora;Data Source=MyOracleDB;Persist Security Info=False;Integrated Security=Yes;
  // Provider=OraOLEDB.Oracle;Data Source=MyOracleDB;OSAuthent=1;

  // Postgre SQL (allow):
  // Driver={PostgreSQL};Server=IP address;Port=5432;Database=myDataBase;Uid=myUsername;Pwd=myPassword;
  // Server=127.0.0.1;Port=5432;Database=myDataBase;Integrated Security=true;

  // Mimer SQL (allow)
  // Database=myDataBase;Protocol=local;User Id=myUsername;Password=myPassword;
  // Database=myDataBase;Protocol=local;Integrated Security=true;
end;

procedure TDBMS_Connection.KeepAuthenticationInfo;
var
  VServer: TDBMS_Server;
begin
  // get info from G_ConnectionList
  G_ConnectionList.FSyncList.BeginWrite;
  try
    VServer := G_ConnectionList.InternalGetServerObject(FPath.Path_Items[0]);
    if (VServer<>nil) then begin
      if (not VServer.FAuthDefined) then begin
        VServer.FUsername := FSQLConnection.Params.Values[TDBXPropertyNames.UserName];
        VServer.FPassword := FSQLConnection.Params.Values[TDBXPropertyNames.Password];
      end;
      VServer.FAuthFailed := FALSE;
      VServer.FAuthOK := TRUE;
    end;
  finally
    G_ConnectionList.FSyncList.EndWrite;
  end;
end;

procedure TDBMS_Connection.KillPoolDataset(var ADataset: TDBMS_Dataset);
begin
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

function TDBMS_Connection.MakeNonPooledDataset: TDBMS_Dataset;
begin
  Result := TDBMS_Dataset.Create(nil);
  Result.SQLConnection := FSQLConnection;
end;

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
    Result.SQLConnection := FSQLConnection;
  finally
    FSyncPool.EndWrite;
  end;
end;

{ TDBMS_ConnectionList }

constructor TDBMS_ConnectionList.Create;
begin
  FSyncList := MakeSync_Tiny(Self);
  //Self.OwnsObjects := TRUE; // TRUE is by default
end;

destructor TDBMS_ConnectionList.Destroy;
begin
  FSyncList.BeginWrite;
  try
    Self.Clear;
  finally
    FSyncList.EndWrite;
  end;
  FSyncList := nil;
  inherited;
end;

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

{ TDBMS_Dataset }

function TDBMS_Dataset.GetAnsiCharFlag(
  const AFieldName: WideString;
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

procedure TDBMS_Dataset.OpenSQL(const ASQLText: WideString);
begin
  if Active then
    Close;
  // Params.Clear;
  Self.CommandText := ASQLText;
  Self.Open;
end;

initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
end.
