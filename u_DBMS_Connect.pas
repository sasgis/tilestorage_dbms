unit u_DBMS_Connect;

interface

uses
  SysUtils,
  Classes,
  DB,
  DBXCommon,
  SQLExpr,
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
    function EnsureConnected(const AllowTryToConnect: Boolean): Byte;
  end;

  TDBMS_Connection = class(TInterfacedObject, IDBMS_Connection)
  private
    FSyncPool: IReadWriteSync;
    FPath: TETS_Path_Divided_W;
    FSQLConnection: TSQLConnection;
  private
    function ApplyAuthenticationInfo: Byte;
    procedure KeepAuthenticationInfo;
    procedure ApplyODBCParamsToConnection;
    procedure ApplyConnectionParams;
    procedure ApplyParamsToConnection(const AParams: TStrings);
  private
    function IsTrustedConnection: Boolean;
  private
    { IDBMS_Connection }
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
    function EnsureConnected(const AllowTryToConnect: Boolean): Byte;
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
var
  VServer: TDBMS_Server;
  VUsername: WideString;
  VPassword: WideString;
begin
  VUsername := '';
  VPassword := '';

  // if Trusted_Connection=True - keep empty
  if not IsTrustedConnection then begin
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
          // TODO: not defined - get it from storage
          VUsername := 'sa';
          VPassword := '';
        end;
      end else begin
        // fuckup - try empty values
      end;
    finally
      G_ConnectionList.FSyncList.EndWrite;
    end;
  end;

  // apply User_Name and Password
  FSQLConnection.Params.Values[TDBXPropertyNames.UserName] := VUsername;
  FSQLConnection.Params.Values[TDBXPropertyNames.Password] := VPassword;

  FSQLConnection.LoginPrompt := FALSE;

  Result := ETS_RESULT_OK;
end;

procedure TDBMS_Connection.ApplyConnectionParams;
var
  VSectionName: String;
  VFilename: String;
  VIni: TIniFile;
  VParams: TStringList;
  VDescription: WideString;
begin
  VSectionName := FPath.AsEndpoint;

  // 1. check for [MAIN\gis] section in 'TileStorage_DBMS.ini' with strings like
  // ClientAppName=sas_DBMS
  // ClientCharSet=cp1251
  // DriverName=ASE
  // or
  // Trusted_Connection=True
  VFilename := GetModuleFileNameWithoutExt+'.ini';
  if FileExists(VFilename) then begin
    VIni:=TIniFile.Create(VFilename);
    try
      if VIni.SectionExists(VSectionName) then begin
        // found - read entire section
        VParams := TStringList.Create;
        try
          VIni.ReadSectionValues(VSectionName, VParams);
          // apply all params
          ApplyParamsToConnection(VParams);
        finally
          VParams.Free;
        end;
        // done
        Exit;
      end;
    finally
      VIni.Free;
    end;
  end;

  // 2. get params from ODBC sources (only by ODBCSERVERNAME) and add DATABASENAME if not defined
  if Load_DSN_Params_from_ODBC(FPath.Path_Items[0], VDescription) then begin
    // VDescription is the description of the driver associated with the data source
    // For example, dBASE or SQL Server
    ApplyODBCParamsToConnection;
  end;
end;

procedure TDBMS_Connection.ApplyODBCParamsToConnection;
begin
(*
ConnectionName = 'OdbcConnection'
DriverName = 'Odbc'
GetDriverFunc = 'getSQLDriverODBC'
LibraryName = 'dbxoodbc.dll'
LoginPrompt = False
Params.Strings = (
  'DriverName=Odbc'
  'Database=DSN'
  'User_Name=user'
  'Password=password')
VendorLib = 'ODBC32.DLL'
*)
  FSQLConnection.LoginPrompt := FALSE;
  FSQLConnection.LoadParamsOnConnect := FALSE;

  // set drivername and clear all params
  FSQLConnection.ConnectionName := '';
  FSQLConnection.DriverName := 'Odbc';
  // FSQLConnection.Params.Clear;
  FSQLConnection.LibraryName := 'dbxoodbc.dll';
  FSQLConnection.GetDriverFunc := 'getSQLDriverODBC';

  // set params
  FSQLConnection.Params.Values[TDBXPropertyNames.DriverName] := FSQLConnection.DriverName;
  FSQLConnection.Params.Values[TDBXPropertyNames.Database] := FPath.Path_Items[0];
  
  // set connection name
  FSQLConnection.ConnectionName := FSQLConnection.DriverName + 'Connection' + Format('%p',[Pointer(FSQLConnection)]);
end;

procedure TDBMS_Connection.ApplyParamsToConnection(const AParams: TStrings);
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
  VOldValue: WideString;
  VDBXProperties: TDBXProperties;
begin
  // get DriverName from params
  i := AParams.IndexOfName(TDBXPropertyNames.DriverName);
  if (i>=0) then begin
    // found
    VNewValue := AParams.Values[TDBXPropertyNames.DriverName];
    AParams.Delete(i);
    // check in params
    VOldValue := FSQLConnection.Params.Values[TDBXPropertyNames.DriverName];

    // compare
    if (not WideSameText(VNewValue, VOldValue)) then begin
      // set new DriverName
      FSQLConnection.LoadParamsOnConnect := FALSE;
      FSQLConnection.DriverName := VNewValue;
      FSQLConnection.ConnectionName := VNewValue + 'Connection';
      // default params
      VDBXProperties := TDBXConnectionFactory.GetConnectionFactory.GetDriverProperties(VNewValue);
      FSQLConnection.Params.Assign(VDBXProperties.Properties);
    end;
  end;

  if (Length(FPath.Path_Items[0])>0) then
    FSQLConnection.Params.Values[TDBXPropertyNames.HostName] := FPath.Path_Items[0]
  else
    FSQLConnection.Params.Values[TDBXPropertyNames.HostName] := '';

  if (Length(FPath.Path_Items[1])>0) then
    FSQLConnection.Params.Values[TDBXPropertyNames.Database] := FPath.Path_Items[1]
  else
    FSQLConnection.Params.Values[TDBXPropertyNames.Database] := '';
        
  // apply other params
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    // current value
    VOldValue := FSQLConnection.Params.Values[VCurItem];
    // compare
    if (not WideSameText(VOldValue, VNewValue)) then begin
      // set new value
      FSQLConnection.Params.Values[VCurItem] := VNewValue;
    end;
  end;

  // set connection name
  VCurItem := FSQLConnection.DriverName + 'Connection' + Format('%p',[Pointer(FSQLConnection)]);
  if (not SameText(FSQLConnection.ConnectionName,VCurItem)) then begin
    // set or replace
    FSQLConnection.ConnectionName := VCurItem;
  end;
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
  inherited Create;
  FSyncPool := MakeSync_Tiny(Self);
  FSQLConnection := TSQLConnection.Create(nil);
end;

destructor TDBMS_Connection.Destroy;
begin
  // called from FreeDBMSConnection - not need to sync
  G_ConnectionList.InternalRemoveConnection(Self);
  
  CompactPool;
  FreeAndNil(FSQLConnection);

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
      ApplyConnectionParams;

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

function TDBMS_Connection.IsTrustedConnection: Boolean;
var
  VValue: WideString;
begin
  VValue := FSQLConnection.Params.Values['Trusted_Connection'];
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
  Self.CommandText := ASQLText;
  Self.Open;
end;

initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
end.
