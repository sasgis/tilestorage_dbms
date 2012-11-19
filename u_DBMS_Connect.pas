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
  DB, // common unit
{$if defined(ETS_USE_ZEOS)}
  ZConnection,
  ZDataset,
{$else}
  DBXCommon,
  DBXDynaLink,
  SQLExpr,
{$ifend}
  t_ETS_Path,
  t_ETS_Tiles;

type
  TDBMS_Custom_Connection = class(
{$if defined(ETS_USE_ZEOS)}
    TZConnection
{$else}
    TSQLConnection
{$ifend}
  )
  protected
    FETS_INTERNAL_SYNC_SQL_MODE: Integer;
    FSYNC_SQL_MODE_CS: TRTLCriticalSection;
  protected
    procedure BeforeSQL(out ALocked: Boolean);
    procedure AfterSQL(const ALocked: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // base dataset
  TDBMS_Dataset = class(
{$if defined(ETS_USE_ZEOS)}
    TZQuery
{$else}
    TSQLQuery
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

    // get CLOB value, returns (NOT NULL)
    function ClobAsWideString(
      const AFieldName: TDBMS_String;
      out AResult: TDBMS_String
    ): Boolean;

    // set BLOB buffer to param (if exists)
    procedure SetParamBlobData(
      const AParamName: WideString;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt
    );

    // reads BLOB from field via stream
    function CreateFieldBlobReadStream(const AFieldName: WideString): TStream;

    // reassign both modes
    procedure ExecSQLDirect;
    procedure ExecSQLParsed;
    procedure ExecSQLSpecified(const ADirectExec: Boolean);
  end;

  IDBMS_Connection = interface
  ['{D5809427-36C7-49D7-83ED-72C567BD6E08}']
    procedure CompactPool;
    procedure KillPoolDataset(var ADataset: TDBMS_Dataset);
    function MakePoolDataset: TDBMS_Dataset;
    function MakeNonPooledDataset: TDBMS_Dataset;
    function EnsureConnected(const AllowTryToConnect: Boolean): Byte;
    // тип сервера БД
    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;
    // внутренние параметры
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;
  end;

  TDBMS_Connection = class(TInterfacedObject, IDBMS_Connection)
  private
    FSyncPool: IReadWriteSync;
    FPath: TETS_Path_Divided_W;
    FSQLConnection: TDBMS_Custom_Connection;
    FEngineType: TEngineType;
    FODBCDescription: WideString;
    // внутренние параметры из ini
    FInternalParams: TStringList;
    FETS_INTERNAL_SCHEMA: String;
    // если будет более одной DLL - переделать на TStringList
    FInternalLoadLibraryStd: THandle;
    FInternalLoadLibraryAlt: THandle;
  protected
    procedure SaveInternalParameter(const AParamName, AParamValue: String);
    function ApplyAuthenticationInfo: Byte;
    procedure KeepAuthenticationInfo;
    function ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
    function ApplyConnectionParams: Byte;
    function ApplyParamsToConnection(const AParams: TStrings): Byte;
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
    function FullSyncronizeSQL: Boolean;
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
    FServerName: TDBMS_String;
    FUsername: TDBMS_String;
    FPassword: TDBMS_String;
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
  // пока что всё только из ini
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
          // проверим может быть возможно подключение без логина
          if (0<Length(c_SQL_Integrated_Security[GetCheckedEngineType])) then begin
            // по идее это возможно
            VUsername := '';
            VPassword := '';
            //FSQLConnection.Params.Values[c_SQL_Integrated_Security[GetCheckedEngineType]] := 'true';
          end else begin
            // обязательно нужен логин и пароль
            // TODO: вычитать его из хранилища
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

  // хотя возможно подключение через дрйвер ODBC вообще без настройки дополнительных параметров (например, к ASE)
  // будем требовать наличия секции в файлике ini

  // здесь нет добавок в имя файла, потому что настройки определяются ДО подключения к СУБД
  // для визуального отличия от остальных файлов добавляем подчёркивание в начало имени
  VFilename :=
  GetModuleFileNameWithoutExt(
    TRUE,
{$if defined(ETS_USE_ZEOS)}
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
        // секция не найдена
        Result := ETS_RESULT_INI_SECTION_NOT_FOUND;
      end;
    finally
      VIni.Free;
    end;
  end else begin
    // файл ini не найден
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
  // если запрошенная DLL загрузится - не будет её добавлять в список внутренних параметров
  if SameText(ETS_INTERNAL_LOAD_LIBRARY, AParamName) and (FInternalLoadLibraryStd=0) and (0<Length(AParamValue)) then begin
    FInternalLoadLibraryStd := LoadLibrary(PChar(AParamValue));
    if (FInternalLoadLibraryStd<>0) then
      Exit;
  end else if SameText(ETS_INTERNAL_LOAD_LIBRARY_ALT, AParamName) and (FInternalLoadLibraryAlt=0) and (0<Length(AParamValue)) then begin
    FInternalLoadLibraryAlt := LoadLibraryEx(PChar(AParamValue), 0, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (FInternalLoadLibraryAlt<>0) then
      Exit;
  end else if SameText(ETS_INTERNAL_SCHEMA, AParamName) then begin
    // для более быстрого доступа
    FETS_INTERNAL_SCHEMA := AParamValue;
    if (0<Length(FETS_INTERNAL_SCHEMA)) then begin
      FETS_INTERNAL_SCHEMA := FETS_INTERNAL_SCHEMA + '.';
    end;
    Exit;
  end else if SameText(ETS_INTERNAL_SYNC_SQL_MODE, AParamName) then begin
    // для более быстрого доступа
    FSQLConnection.FETS_INTERNAL_SYNC_SQL_MODE := StrToIntDef(AParamValue, 0);
    Exit;
  end;

{$if defined(ETS_USE_ZEOS)}

{$else}
  // если это параметры для свойств драйвера DBX - сразу и пропихнём их
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
{$ifend}

  if (nil=FInternalParams) then
    FInternalParams := TStringList.Create;
  // просто складываем параметры в список
  FInternalParams.Values[AParamName] := AParamValue;
end;

function TDBMS_Connection.ApplyODBCParamsToConnection(const AOptionalList: TStrings): Byte;
{$if defined(ETS_USE_ZEOS)}
{$else}
var
  i: Integer;
  VParamName: String;
{$ifend}
begin
{$if defined(ETS_USE_ZEOS)}
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
    // пропихиваем параметры снаружи (но не все!)
    VParamName := AOptionalList.Names[i];
    if SameText(Copy(VParamName,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // исключительно внутренний параметр
      SaveInternalParameter(VParamName, AOptionalList.ValueFromIndex[i]);
    end else begin
      // даже и тут не все пропихиваем
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
{$if defined(ETS_USE_ZEOS)}
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
{$if defined(ETS_USE_ZEOS)}
  // тут всё просто - одна часть параметров в свойства, другая часть - в другие свойства )):

  // apply other params
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // исключительно внутренний параметр
      SaveInternalParameter(VCurItem, VNewValue);
    end else begin
      // сравниваем куда пихать
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
      else // остатки - в список свойств
        FSQLConnection.Properties.Values[VCurItem] := VNewValue;
    end;
  end;

  // done
  FSQLConnection.LoginPrompt := FALSE;
  Result := ETS_RESULT_OK;
{$else}
  // вытащим имя драйвера из прочитанных параметров
  i := AParams.IndexOfName(TDBXPropertyNames.DriverName);
  if (i>=0) then begin
    // драйвер указан
    VNewValue := AParams.Values[TDBXPropertyNames.DriverName];
    AParams.Delete(i);
    // проверим, может быть драйвер уже есть в параметрах подключения
    VOldValue := FSQLConnection.Params.Values[TDBXPropertyNames.DriverName];

    // может сказано грузить через драйвер ODBC - тогда пропихнём остальные параметры
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
    // драйвер не указан - значит используем драйвер ODBC
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

  // если работаем через драйвер ODBC - применяем параметры и валим
  if VUseODBC then begin
    if Load_DSN_Params_from_ODBC(FPath.Path_Items[0], FODBCDescription) then begin
      // источник найден в системных DSN
      Result := ApplyODBCParamsToConnection(AParams);
    end else begin
      // источник не найден
      Result := ETS_RESULT_UNKNOWN_ODBC_DSN;
    end;
    Exit;
  end;

  // здесь только если работаем не через драйвер ODBC

  // apply other params
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // исключительно внутренний параметр
      SaveInternalParameter(VCurItem, AParams.ValueFromIndex[i]);
    end else begin
      // пропихиваем в БД
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
  FSQLConnection := TDBMS_Custom_Connection.Create(nil);
  FInternalLoadLibraryStd := 0;
  FInternalLoadLibraryAlt := 0;
  FInternalParams := nil;
  FETS_INTERNAL_SCHEMA := '';
end;

destructor TDBMS_Connection.Destroy;
begin
  // called from FreeDBMSConnection - not need to sync
  G_ConnectionList.InternalRemoveConnection(Self);
  
  CompactPool;

  try
{$if defined(ETS_USE_ZEOS)}
    FSQLConnection.CloseAllDataSets;
    //FSQLConnection.CloseAllSequences;
{$else}
    FSQLConnection.CloseDataSets;
{$ifend}
  except
  end;

  try
{$if defined(ETS_USE_ZEOS)}
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
  Result := FETS_INTERNAL_SCHEMA;
end;

function TDBMS_Connection.FullSyncronizeSQL: Boolean;
begin
  // если 1 - синхронизируются запросы полностью
  Result := (FSQLConnection.FETS_INTERNAL_SYNC_SQL_MODE=1) or (not FSQLConnection.Connected);
end;

function TDBMS_Connection.GetInternalParameter(const AInternalParameterName: String): String;
begin
  // тащим значение из внутренних параметров
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
{$if defined(ETS_USE_ZEOS)}
        FEngineType := GetEngineTypeByZEOSLibProtocol(FSQLConnection.Protocol);
{$else}
        FEngineType := GetEngineTypeByDBXDriverName(FSQLConnection.DriverName, FODBCDescription);
{$ifend}
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
(*
var
  VDataset: TDBMS_Dataset;
  VText: String;
*)
begin
  Result := et_Unknown;
(*
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
*)
end;

function TDBMS_Connection.IsTrustedConnection: Boolean;
{$if defined(ETS_USE_ZEOS)}
{$else}
var
  VEngineType: TEngineType;
  VDriverParam: String;
  VValue: WideString;
{$ifend}
begin
{$if defined(ETS_USE_ZEOS)}
  Result := (0=Length(FSQLConnection.User));
{$else}
  VEngineType := GetCheckedEngineType;

  // отдельно проверим 'OS Authentication' для MSSQL
  if (et_MSSQL=VEngineType) then begin
    VValue := FSQLConnection.Params.Values[c_RTL_Trusted_Connection];
    if (0<Length(VValue)) then begin
      // что-то указано
      Result :=  (WideSameText(VValue, 'true') or WideSameText(VValue, 'yes'));
      Exit;
    end;
  end;

  // обычная проверка
  VDriverParam := c_SQL_Integrated_Security[VEngineType];
  Result := (0<Length(VDriverParam));
  if (not Result) then
    Exit;

  VValue := FSQLConnection.Params.Values[VDriverParam];
  Result := (0<Length(VValue)) and (WideSameText(VValue, 'true') or WideSameText(VValue, 'yes'));
{$ifend}

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
{$if defined(ETS_USE_ZEOS)}
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
{$if defined(ETS_USE_ZEOS)}
  Result.Connection := FSQLConnection;
  Result.FUsePingServer := c_ZEOS_Use_PingServer[GetCheckedEngineType];
{$else}
  Result.SQLConnection := FSQLConnection;
{$ifend}
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
{$if defined(ETS_USE_ZEOS)}
    Result.Connection := FSQLConnection;
    Result.FUsePingServer := c_ZEOS_Use_PingServer[GetCheckedEngineType];
{$else}
    Result.SQLConnection := FSQLConnection;
{$ifend}
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
    AResult := VSqlTextField.AsWideString;
  end;
end;

function TDBMS_Dataset.CreateFieldBlobReadStream(const AFieldName: WideString): TStream;
var
  F: TField;
  //S: String;
begin
  F := Self.FieldByName(AFieldName);
(*
  if (F is TVarBytesField) then begin
    // бинарное хранилище
    S := TVarBytesField(F).AsString;
    Result := TMemoryStream.Create;
    Result.Write(PChar(S)^, Length(S));
    Result.Position := 0;
  end else begin
*)
    // просто BLOB
    Result := Self.CreateBlobStream(F, bmRead);
//  end;
end;

procedure TDBMS_Dataset.ExecSQLDirect;
var VLocked: Boolean;
begin
{$if defined(ETS_USE_ZEOS)}
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

procedure TDBMS_Dataset.ExecSQLParsed;
var VLocked: Boolean;
begin
{$if defined(ETS_USE_ZEOS)}
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

procedure TDBMS_Dataset.ExecSQLSpecified(const ADirectExec: Boolean);
var VLocked: Boolean;
begin
{$if defined(ETS_USE_ZEOS)}
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

procedure TDBMS_Dataset.OpenSQL(const ASQLText: TDBMS_String);
var VLocked: Boolean;
begin
  // закроем если датасет активен
  if Active then
    Close;

{$if defined(ETS_USE_ZEOS)}
  // пропихнём текст запроса
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
  Self.CommandText := ASQLText;

  TDBMS_Custom_Connection(SQLConnection).BeforeSQL(VLocked);
  try
    Self.Open;
  finally
    TDBMS_Custom_Connection(SQLConnection).AfterSQL(VLocked);
  end;
{$ifend}
end;

procedure TDBMS_Dataset.SetParamBlobData(
  const AParamName: WideString;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer
);
var
  VParam: TParam;
begin
  VParam := Self.Params.FindParam(AParamName);
  if (VParam<>nil) then begin
    if (ABufferSize>0) then
      VParam.SetBlobData(ABufferAddr, ABufferSize)
    else
      VParam.Clear;
  end;
end;

{ TDBMS_Custom_Connection }

procedure TDBMS_Custom_Connection.AfterSQL(const ALocked: Boolean);
begin
  if ALocked then begin
    LeaveCriticalSection(FSYNC_SQL_MODE_CS);
  end;
end;

procedure TDBMS_Custom_Connection.BeforeSQL(out ALocked: Boolean);
begin
  ALocked := (FETS_INTERNAL_SYNC_SQL_MODE=2);
  if ALocked then begin
    EnterCriticalSection(FSYNC_SQL_MODE_CS);
  end;
end;

constructor TDBMS_Custom_Connection.Create(AOwner: TComponent);
begin
  inherited;
  InitializeCriticalSection(FSYNC_SQL_MODE_CS);
end;

destructor TDBMS_Custom_Connection.Destroy;
begin
  DeleteCriticalSection(FSYNC_SQL_MODE_CS);
  inherited;
end;

initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
end.
