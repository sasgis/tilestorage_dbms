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
  t_ETS_Path,
  t_ETS_Tiles;

type

  IDBMS_Connection = interface
  ['{D5809427-36C7-49D7-83ED-72C567BD6E08}']
    // подключение, если ещё не подключено
    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    // выполнение простого запроса напрямую
    function ExecuteDirectSQL(
      const ASQLText: TDBMS_String;
      const ASilentOnError: Boolean = FALSE // может не поддерживаться
    ): Boolean;

    // выполнение запроса с параметром типв blob напрямую
    function ExecuteDirectWithBlob(
      const ASQLText: TDBMS_String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean = FALSE // может не поддерживаться
    ): Boolean;

    // проверка существования таблицы
    function TableExists(const AFullyQualifiedQuotedTableName: TDBMS_String): Boolean;

    // тип сервера БД
    function GetEngineType(const ACheckMode: TCheckEngineTypeMode = cetm_None): TEngineType;
    function GetCheckedEngineType: TEngineType;

    // внутренние параметры
    function GetInternalParameter(const AInternalParameterName: String): String;
    function ForcedSchemaPrefix: String;
    function FullSyncronizeSQL: Boolean;

    // текст ошибки при подключении
    function GetConnectionErrorMessage: String;
    procedure ResetConnectionError;

    // применение настроек аутентификации из формы
    procedure ApplyCredentialsFormParams(const AFormParams: TStrings);
    function AllowSavePassword: Boolean;

    // проверка что одно поле есть и не пустое
    function CheckDirectSQLSingleNotNull(
      const ASQLText: String
    ): Boolean;

    // открытие запроса чтобы фетчить кучу разных полей
    function OpenDirectSQLFetchCols(
      const ASQLText: String;
      const ABufPtr: POdbcFetchCols
    ): Boolean;
  end;

  TDBMS_Connection = class(TInterfacedObject , IDBMS_Connection)
  private
    FPath: TETS_Path_Divided_W;
    FSQLConnection: TODBCConnection;
    FEngineType: TEngineType;
    FODBCDescription: AnsiString;
    // внутренние параметры из ini
    FInternalParams: TStringList;
    // формально это не схема, а префикс полностью (при необходимости - с точкой и сразу quoted)
    FETS_INTERNAL_SCHEMA_PREFIX: String;
    // если будет более одной DLL - переделать на TStringList
    FInternalLoadLibraryStd: THandle;
    FInternalLoadLibraryAlt: THandle;
    // кэшируем результат коннекта к серверу
    FConnectionErrorMessage: String;
    FConnectionErrorCode: Byte;
    // если TRUE - пароль будет сохраняться как Lsa Secret
    // если FALSE - просто в реестре (в обоих случаях он шифруется)
    FSavePwdAsLsaSecret: Boolean;
    FReadPrevSavedPwd: Boolean;
  protected
    procedure SaveInternalParameter(const AParamName, AParamValue: String);
    procedure KeepAuthenticationInfo;
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

    function EnsureConnected(
      const AllowTryToConnect: Boolean;
      AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS
    ): Byte;

    function ExecuteDirectSQL(
      const ASQLText: TDBMS_String;
      const ASilentOnError: Boolean = FALSE // может не поддерживаться
    ): Boolean;

    function ExecuteDirectWithBlob(
      const ASQLText: TDBMS_String;
      const ABufferAddr: Pointer;
      const ABufferSize: LongInt;
      const ASilentOnError: Boolean = FALSE // может не поддерживаться
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

  // хотя возможно подключение через дрйвер ODBC вообще без настройки дополнительных параметров (например, к ASE)
  // будем требовать наличия секции в файлике ini

  // здесь нет добавок в имя файла, потому что настройки определяются ДО подключения к СУБД
  // для визуального отличия от остальных файлов добавляем подчёркивание в начало имени
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
    // для ODBC попробуем воспользоваться одноимённым System DSN
    Result := ApplySystemDSNtoConnection;
  end;
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
  end else if SameText(ETS_INTERNAL_SCHEMA_PREFIX, AParamName) then begin
    // для более быстрого доступа
    FETS_INTERNAL_SCHEMA_PREFIX := AParamValue;
    Exit;
  end else if SameText(ETS_INTERNAL_SYNC_SQL_MODE, AParamName) then begin
    // для более быстрого доступа
    FSQLConnection.SYNC_SQL_MODE := StrToIntDef(AParamValue, c_SYNC_SQL_MODE_None);
    Exit;
  end else if SameText(ETS_INTERNAL_PWD_Save, AParamName) then begin
    // разрешение читать сохранённый пароль (и оно же - разрешение сохранять пароль) + режим Lsa
    FSavePwdAsLsaSecret := SameText(AParamValue, ETS_INTERNAL_PWD_Save_Lsa);
    FReadPrevSavedPwd := FSavePwdAsLsaSecret or (StrToIntDef(AParamValue, 0) <> 0);
    Exit;
  end else if SameText(ETS_INTERNAL_ODBC_ConnectWithParams, AParamName) then begin
    FSQLConnection.ConnectWithParams := (StrToIntDef(AParamValue, 0) <> 0);
    Exit;
  end;

  if (nil=FInternalParams) then
    FInternalParams := TStringList.Create;
  // просто складываем параметры в список
  FInternalParams.Values[AParamName] := AParamValue;
end;

function TDBMS_Connection.TableExists(const AFullyQualifiedQuotedTableName: TDBMS_String): Boolean;
begin
  Result := FSQLConnection.TableExistsDirect(AFullyQualifiedQuotedTableName);
end;

procedure TDBMS_Connection.ApplyCredentialsFormParams(const AFormParams: TStrings);
begin
  // применяем логин и пароль
  FSQLConnection.UID := AFormParams.Values[c_Cred_UserName];
  FSQLConnection.PWD := AFormParams.Values[c_Cred_Password];

  // здесь если указано сохранять настройки подключения - сохраним их
  if (AFormParams.Values[c_Cred_SaveAuth]='1') then begin
    PasswordStorage_SaveParams(AFormParams.Values[c_Cred_UserName], AFormParams.Values[c_Cred_Password]);
  end;
end;

function TDBMS_Connection.ApplyParamsToConnection(const AParams: TStrings): Byte;
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
begin
  // всё что не внутреннее - пишем в параметры подключения
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if SameText(Copy(VCurItem,1,Length(ETS_INTERNAL_PARAMS_PREFIX)),ETS_INTERNAL_PARAMS_PREFIX) then begin
      // исключительно внутренний параметр
      SaveInternalParameter(VCurItem, VNewValue);
    end else begin
      // в параметры подключения
      FSQLConnection.Params.Values[VCurItem] := VNewValue;
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
  // применение параметров подключения без ini-шки
  // доступно не для всех СУБД
  VSystemDSNName := FPath.Path_Items[0];
  if Load_DSN_Params_from_ODBC(VSystemDSNName, FODBCDescription) then begin
    // нашёлся SystemDSN
    FSQLConnection.DSN := VSystemDSNName;

    PasswordStorage_ApplyStored;

    Result := ETS_RESULT_OK;
  end else begin
    // не наш лось
    Result := ETS_RESULT_INI_FILE_NOT_FOUND;
  end;
end;

function TDBMS_Connection.calc_exclusive_mode: AnsiChar;
begin
  case FSQLConnection.SYNC_SQL_MODE of
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

constructor TDBMS_Connection.Create;
begin
  FEngineType := et_Unknown;
  FODBCDescription := '';
  inherited Create;
  FSavePwdAsLsaSecret := FALSE;
  FReadPrevSavedPwd := FALSE;
{$if defined(CONNECTION_AS_RECORD)}
  FSQLConnection.Init;
{$else}
  FSQLConnection := TODBCConnection.Create;
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

  try
    FSQLConnection.Disconnect;
  except
  end;

  try
{$if defined(CONNECTION_AS_RECORD)}
    FSQLConnection.Uninit;
{$else}
    FreeAndNil(FSQLConnection);
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

  inherited;
end;

function TDBMS_Connection.ExecuteDirectSQL(
  const ASQLText: TDBMS_String;
  const ASilentOnError: Boolean
): Boolean;
begin
  Result := FSQLConnection.ExecuteDirectSQL(ASQLText, ASilentOnError);
end;

function TDBMS_Connection.ExecuteDirectWithBlob(
  const ASQLText: TDBMS_String;
  const ABufferAddr: Pointer;
  const ABufferSize: Integer;
  const ASilentOnError: Boolean
): Boolean;
begin
  // блобы у нас только для параметра ':tile_body' aka c_RTL_Tile_Body_Paramname
  Result := FSQLConnection.ExecuteDirectWithBlob(ASQLText, c_RTL_Tile_Body_Paramname, ABufferAddr, ABufferSize, ASilentOnError);
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

      // пропихнём опции в хост
      if (AStatusBuffer<>nil) then
      with (AStatusBuffer^) do begin
        if wSize>=SizeOf(AStatusBuffer^) then
          exclusive_mode := calc_exclusive_mode;
      end;

      // try to connect
      try
        FSQLConnection.Connect;
        FConnectionErrorMessage := '';
        FConnectionErrorCode := ETS_RESULT_OK;

        // connected - пропихнём признак в хост
        if (AStatusBuffer<>nil) then
        with (AStatusBuffer^) do begin
          if wSize>=SizeOf(AStatusBuffer^) then
            malfunction_mode := ETS_PMM_ESTABLISHED;
        end;
      except
        on E: Exception do begin
          // '08001:17:[Microsoft][ODBC SQL Server Driver][TCP/IP Sockets]SQL-сервер не существует, или отсутствует доступ.'
          // '28P01:210:ВАЖНО: пользователь "postgres" не прошёл проверку подлинности (по паролю)'
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
          // '08001:1001:[Relex][Linter ODBC Driver] SQLConnect: #1001 очередь ядра Linter не найдена (нет активного ядра)'
          // '08001:-30081:[IBM][CLI Driver] SQL30081N  A communication error has been detected. Communication protocol being used: "TCP/IP".  Communication API being used: "SOCKETS".  Location where the error was detected: "192.168.1.8".  Communication function detecting the error: "connect".  Protocol specific error code(s): "10061", "*", "*".  SQLSTATE=08001'#$D#$A
          // '08004:-908:[Informix][Informix ODBC Driver][Informix]Attempt to connect to database server (ol_informix1170) failed.'

          FConnectionErrorMessage := E.Message;
          FConnectionErrorCode := ETS_RESULT_NOT_CONNECTED;
          Result := ETS_RESULT_NOT_CONNECTED;

          // failed - пропихнём признак в хост
          if (AStatusBuffer<>nil) then
          with (AStatusBuffer^) do begin
            if wSize>=SizeOf(AStatusBuffer^) then
              malfunction_mode := ETS_PMM_FAILED_CONNECT;
          end;

          Exit;
        end;

      end;

      // установим специальный признак для PostgreSQL
      // чтобы вставка через ODBC работала независимо
      // от состояния галочки "bytea as LO"
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
  // если c_SYNC_SQL_MODE_All_In_DLL - синхронизируются запросы полностью
  Result := (FSQLConnection.SYNC_SQL_MODE=c_SYNC_SQL_MODE_All_In_DLL) or (not FSQLConnection.Connected);
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
          FSQLConnection.DSN,
          FODBCDescription
        ) then
          FEngineType := GetEngineTypeByODBCDescription(FODBCDescription, VSecondarySQLCheckServerTypeMode)
        else
          FEngineType := GetEngineTypeByODBCDescription(
            FSQLConnection.DSN,
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
  if (not FSQLConnection.Connected) then begin
    // not connected
    Result := et_Unknown;
  end else begin
    // connected
    VOdbcFetchColsEx.Init;
    try
      // определение типа сервера исходя из его реакции на шаблонные действия

      // сперва проверим select @@version // MSSQL+ASE+ASA
      VSQLText := 'SELECT @@VERSION as v';
      try
        FSQLConnection.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));

        // тащим первое поле
        VOdbcFetchColsEx.Base.ColToAnsiString(1, VText);
        if GetEngineTypeUsingSQL_Version_Upper(VText, Result) then
          Exit;

        // unknown
        Result := et_Unknown;
      except on E: Exception do
        // а тут смотрим чего понаписали в ошибку
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

function TDBMS_Connection.IsTrustedConnection: Boolean;
begin
  Result := (0=Length(FSQLConnection.UID));
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

{$if defined(DBMS_REUSE_CONNECTIONS)}
initialization
  G_ConnectionList := TDBMS_ConnectionList.Create;
finalization
  FreeAndNil(G_ConnectionList);
{$ifend}
end.
