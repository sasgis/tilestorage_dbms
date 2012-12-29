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

    procedure NeedReconnect;
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
    // деление по секциям
    FNextSectionConn: IDBMS_Connection; // следуюшая секция в цепочке
    FPrimaryConn: IDBMS_Connection; // опциональная ссылка на первичную секцию
    FTSS_Info_Ptr: PTSS_Info; // параметры секционирования
    FTSS_Primary_Params: TTSS_Primary_Params;

    FPathDiv: TETS_Path_Divided_W;

    procedure Init(const APathPtr: PETS_Path_Divided_W);
    procedure Uninit;

  private
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
    // признак необходимости переподключиться из-за разрыва соединения
    FReconnectPending: Boolean;
  private
    // читает настройки из INI и применяет их
    // при необходимости создаёт дочерние секции
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

    procedure NeedReconnect;

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
  // для первичной секции параметры читаются сразу
  t.ApplyConnectionParams;
  Result := t;
  {$else}
  New(Result);
  Result^.Init(APathPtr);
  // для первичной секции параметры читаются сразу
  Result^.ApplyConnectionParams;
  {$ifend}
{$ifend}
end;

procedure FreeDBMSConnection(var AConnection: IDBMS_Connection);
begin
  if (nil=AConnection) then
    Exit;
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

  // хотя возможно подключение через дрйвер ODBC вообще без настройки дополнительных параметров,
  // будем требовать наличия секции в файлике ini, если файл ini есть

  // здесь нет добавок в имя файла, потому что настройки определяются ДО подключения к СУБД
  // для визуального отличия от остальных файлов добавляем подчёркивание в начало имени
  VFilename :=
  GetModuleFileNameWithoutExt(
    FALSE,
    TRUE,
    '',
    ''
  ) + c_SQL_Ext_Ini;
  
  if FileExists(VFilename) then begin
    VIni:=TIniFile.Create(VFilename);
    try
      if VIni.SectionExists(VSectionName) then begin
        // секция найдена - читаем её целиком
        VParams := TStringList.Create;
        try
          VIni.ReadSectionValues(VSectionName, VParams);
          // применяем параметры секции
          Result := ApplyParamsFromINI(VParams);
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
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.
{$ifend}
    SYNC_SQL_MODE := StrToIntDef(AParamValue, c_SYNC_SQL_MODE_None);
    Exit;
  end else if SameText(ETS_INTERNAL_PWD_Save, AParamName) then begin
    // разрешение читать сохранённый пароль (и оно же - разрешение сохранять пароль) + режим Lsa
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
  // просто складываем параметры в список
  FInternalParams.Values[AParamName] := AParamValue;
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.TableExistsDirect(const AFullyQualifiedQuotedTableName: AnsiString): Boolean;
begin
  Result := FODBCConnectionHolder.TableExistsDirect(AFullyQualifiedQuotedTableName)
end;
{$ifend}

procedure TDBMS_Connection.Uninit;
begin
  // called from FreeDBMSConnection - not need to sync
{$if defined(DBMS_REUSE_CONNECTIONS)}
  G_ConnectionList.InternalRemoveConnection(Self);
{$ifend}

  // убиваем рекурсивно по цепочке
  if (FNextSectionConn<>nil) then begin
{$if defined(CONNECTION_AS_RECORD)}
    FNextSectionConn^.Uninit;
    Dispose(FNextSectionConn);
{$ifend}
    // убиваем ссылку (если интерфейс - умрёт)
    FNextSectionConn := nil;
  end;

  try
{$if defined(CONNECTION_AS_RECORD)}
    // здесь не FRealODBCPtr^ а всегда свой коннект
    // чужой (родительский) не имеем права разрывать
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

  FPrimaryConn := nil;

  if (FTSS_Info_Ptr <> nil) then begin
    FTSS_Info_Ptr^.Clear;
    Dispose(FTSS_Info_Ptr);
    FTSS_Info_Ptr := nil;
  end;
end;

procedure TDBMS_Connection.ApplyCredentialsFormParams(const AFormParams: TStrings);
begin
  // применяем логин и пароль
{$if defined(CONNECTION_AS_RECORD)}
  with FODBCConnectionHolder do begin
{$ifend}
    // только к своему коннекту (родительский коннект сам пропихнёт параметры)
    UID := AFormParams.Values[c_Cred_UserName];
    PWD := AFormParams.Values[c_Cred_Password];
{$if defined(CONNECTION_AS_RECORD)}
  end;
{$ifend}

  // здесь если указано сохранять настройки подключения - сохраним их
  if (AFormParams.Values[c_Cred_SaveAuth]='1') then begin
    PasswordStorage_SaveParams(AFormParams.Values[c_Cred_UserName], AFormParams.Values[c_Cred_Password]);
  end;
end;

function TDBMS_Connection.ApplyParamsFromINI(const AParams: TStrings): Byte;
var
  i: Integer;
  VNewValue, VCurItem: String; // String from TStrings
begin
  // всё что не внутреннее - пишем в параметры подключения
  if (AParams.Count>0) then
  for i := 0 to AParams.Count-1 do begin
    VCurItem := AParams.Names[i];
    VNewValue := AParams.ValueFromIndex[i];
    if IsInternalParameter(VCurItem) then begin
      // исключительно внутренний параметр
      if IsTSSParameter(VCurItem) then begin
        // параметры TSS
        ProcessTSSParameter(AParams, VCurItem, VNewValue);
      end else begin
        // остальные внутренние
        SaveInternalParameter(VCurItem, VNewValue);
      end;
    end else begin
      // в параметры подключения
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
  // применение параметров подключения без ini-шки
  // доступно не для всех СУБД
  VSystemDSNName := FPathDiv.ServerName;
  if Load_DSN_Params_from_ODBC(VSystemDSNName, FODBCDescription) then begin
    // нашёлся SystemDSN
{$if defined(CONNECTION_AS_RECORD)}
    FODBCConnectionHolder.
{$ifend}
    DSN := VSystemDSNName;

    PasswordStorage_ApplyStored;

    Result := ETS_RESULT_OK;
  end else begin
    // не наш лось
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
  Result := FODBCConnectionHolder.CheckDirectSQLSingleNotNull(ASQLText)
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
  // проверка необходимости переподключения из-за разрыва соединения
  if FReconnectPending then begin
    // только эксклюзивно, если можем подключаться
    if (not AllowTryToConnect) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    // переподключаемся
{$if defined(CONNECTION_AS_RECORD)}
    with FODBCConnectionHolder do
{$ifend}
    begin
      DisConnect;
      Connect;
    end;
    FReconnectPending := FALSE;
  end;

  if
{$if defined(CONNECTION_AS_RECORD)}
     FODBCConnectionHolder.
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
      (*
      Result := ApplyConnectionParams;
      if (ETS_RESULT_OK<>Result) then
        Exit;
      *)

      // пропихнём опции в хост
      if (AStatusBuffer<>nil) then
      with (AStatusBuffer^) do begin
        if wSize>=SizeOf(AStatusBuffer^) then
          exclusive_mode := calc_exclusive_mode;
      end;

      // try to connect
      try
{$if defined(CONNECTION_AS_RECORD)}
        // подключение секции
        FODBCConnectionHolder.
{$ifend}
        Connect;
        
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
          // 'ZZZZZ:11216:[Sybase][ODBC Driver][Adaptive Server Enterprise]Internal Ct-Lib/Cs-Lib error 84083972: 'ct_connect(): network packet layer: internal net library error: Net-Lib protocol driver call to connect two endpoints failed'.'
          // 'ZZZZZ:11206:[Sybase][ODBC Driver][Adaptive Server Enterprise]Unable to connect to server 'ASEMAIN'.'

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
  Result := FODBCConnectionHolder.ExecuteDirectWithBlob(
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
  Result := FODBCConnectionHolder.ExecuteDirectSQL(ASQLText, ASilentOnError);
end;
{$ifend}

function TDBMS_Connection.ForcedSchemaPrefix: String;
begin
  Result := FETS_INTERNAL_SCHEMA_PREFIX;
end;

function TDBMS_Connection.FullSyncronizeSQL: Boolean;
begin
  // если c_SYNC_SQL_MODE_All_In_DLL - синхронизируются запросы полностью
{$if defined(CONNECTION_AS_RECORD)}
  with FODBCConnectionHolder do
{$ifend}
  Result := (SYNC_SQL_MODE=c_SYNC_SQL_MODE_All_In_DLL) or (not Connected);
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
{$if defined(CONNECTION_AS_RECORD)}
          FODBCConnectionHolder.
{$ifend}
          DSN,
          FODBCDescription
        ) then
          FEngineType := GetEngineTypeByODBCDescription(FODBCDescription, VSecondarySQLCheckServerTypeMode)
        else
          FEngineType := GetEngineTypeByODBCDescription(
{$if defined(CONNECTION_AS_RECORD)}
            FODBCConnectionHolder.
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
  //VSQLText: TDBMS_String;
  VText: AnsiString;
  VColIndex: SmallInt;
  VSecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode;

  function _CheckSqlFromClause(const ACheckType: TEngineType; out AResult: TEngineType): Boolean;
  var V: LongInt;
  begin
    try
      VOdbcFetchColsEx.Base.Close;
      Result := OpenDirectSQLFetchCols('SELECT 1 as a' +
                                        ' FROM ' + c_SQL_FROM[ACheckType], @(VOdbcFetchColsEx.Base)) and
                VOdbcFetchColsEx.Base.FetchRecord;
      if Result then begin
        VOdbcFetchColsEx.Base.ColToLongInt(1, V);
        Result := (1=V);
        if Result then begin
          // нашли
          AResult := ACheckType;
        end;
      end;
    except
      Result := FALSE;
    end;
  end;
  
begin
  if (not
{$if defined(CONNECTION_AS_RECORD)}
          FODBCConnectionHolder.
{$ifend}
          Connected) then begin
    // not connected
    Result := et_Unknown;
  end else begin
    // connected
    VOdbcFetchColsEx.Init;
    try
      // определение типа сервера исходя из его реакции на шаблонные действия

      // сперва проверим select @@version // MSSQL+ASE+ASA
      try
        if OpenDirectSQLFetchCols('SELECT @@VERSION as v', @(VOdbcFetchColsEx.Base)) then
        if VOdbcFetchColsEx.Base.FetchRecord then begin
          // тащим первое поле
          VOdbcFetchColsEx.Base.ColToAnsiString(1, VText);
          if GetEngineTypeUsingSQL_Version_Upper(UpperCase(VText), Result) then
            Exit;
        end;

        // unknown
        Result := et_Unknown;
      except on E: Exception do
        // а тут смотрим чего понаписали в ошибку
        Result := GetEngineTypeUsingSelectVersionException(E);
      end;

      // если определилось - валим
      if (et_Unknown<>Result) then
        Exit;

      // вторая проверка - select version()
      try
        VOdbcFetchColsEx.Base.Close;
        if OpenDirectSQLFetchCols('SELECT version()', @(VOdbcFetchColsEx.Base)) then
        if VOdbcFetchColsEx.Base.FetchRecord then begin
          // PostgreSQL или MySQL
          // тащим первое поле
          VOdbcFetchColsEx.Base.ColToAnsiString(1, VText);
          Result := GetEngineTypeByODBCDescription(VText, VSecondarySQLCheckServerTypeMode);
          if (et_Unknown<>Result) then
            Exit;
        end;
      except on E: Exception do
        // а тут смотрим чего понаписали в ошибку
        Result := GetEngineTypeUsingSelectVersionException(E);
      end;

      // третья проверка - select * from dual
      // DUAL может быть стандартной таблицей или вьюхой
      // а может быть нашей вьюхой
      // комментарий должен сработать для MySQL начиная с версии 1
      try
        VOdbcFetchColsEx.Base.Close;
        if OpenDirectSQLFetchCols('SELECT * FROM DUAL', @(VOdbcFetchColsEx.Base)) then
        if VOdbcFetchColsEx.Base.FetchRecord then begin
          // смотрим что за поля вернулись
          // ENGINE_VERSION
          VColIndex := VOdbcFetchColsEx.Base.ColIndex('ENGINE_VERSION');
          if (VColIndex>0) then begin
            VOdbcFetchColsEx.Base.ColToAnsiString(VColIndex, VText);
            Result := GetEngineTypeByODBCDescription(VText, VSecondarySQLCheckServerTypeMode);
            if (et_Unknown<>Result) then
              Exit;
          end;
          // ENGINETYPE
          VColIndex := VOdbcFetchColsEx.Base.ColIndex('ENGINETYPE');
          if (VColIndex>0) then begin
            VOdbcFetchColsEx.Base.ColToAnsiString(VColIndex, VText);
            Result := GetEngineTypeByODBCDescription(VText, VSecondarySQLCheckServerTypeMode);
            if (et_Unknown<>Result) then
              Exit;
          end;
          // открылось и не наша вьюха - тут скорее всего Oracle
          VColIndex := VOdbcFetchColsEx.Base.ColIndex('DUMMY');
          if (VColIndex>0) and (1=VOdbcFetchColsEx.Base.ColumnCount) then begin
            // одно поле
            Result := et_Oracle;
            Exit;
          end;
        end;
      except on E: Exception do
        // а тут смотрим чего понаписали в ошибку
        Result := GetEngineTypeUsingSelectFromDualException(E);
      end;

      // если определилось - валим
      if (et_Unknown<>Result) then
        Exit;

      // имеем непроинсталлированную БД (без вьюхи DUAL) и один из серверов:
      // Oracle, Informix, DB2, Mimer, Firebird

      // остальные проверки - исходя из разных вариантов обязательных источников данных в секции FROM
      if _CheckSqlFromClause(et_DB2, Result) then
        Exit;
      if _CheckSqlFromClause(et_Mimer, Result) then
        Exit;
      if _CheckSqlFromClause(et_Firebird, Result) then
        Exit;
      if _CheckSqlFromClause(et_Informix, Result) then
        Exit;
      if _CheckSqlFromClause(et_Oracle, Result) then
        Exit;

      Result := et_Unknown;
    finally
      VOdbcFetchColsEx.Base.Close;
    end;
  end;
end;

procedure TDBMS_Connection.Init(const APathPtr: PETS_Path_Divided_W);
begin
{$if defined(CONNECTION_AS_RECORD)}
  FillChar(Self, SizeOf(Self), 0);
{$else}
  FRealODBCPtr := nil;
  FPrimaryConn := nil;
  FTSS_Info_Ptr := nil;
  FNextSectionConn := nil;
  FSavePwdAsLsaSecret := FALSE;
  FReadPrevSavedPwd := FALSE;
  FReconnectPending := FALSE;
  FTSS_Primary_Params.Algorithm := tssal_None;
  FTSS_Primary_Params.Guides_Link := tsslt_Primary;
  FTSS_Primary_Params.Undefined_Link := tsslt_Primary;
  FTSS_Primary_Params.NewTileTable_Link := tsslt_Primary;
  FTSS_Primary_Params.HasSectionWithoutCode := FALSE;
  FInternalLoadLibraryStd := 0;
  FInternalLoadLibraryAlt := 0;
  FInternalParams := nil;
{$ifend}
  // прочее
  FPathDiv.CopyFrom(APathPtr);
  FEngineType := et_Unknown;
  FODBCDescription := '';
{$if defined(CONNECTION_AS_RECORD)}
  FODBCConnectionHolder.Init;
{$else}
{$ifend}
  FETS_INTERNAL_SCHEMA_PREFIX := '';
  FTSS_Primary_Params.NewTileTable_Proc := '';
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
  // воспользуемся тем, что все параметры TSS имеют одну длину (плюс возможный индекс)
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

procedure TDBMS_Connection.NeedReconnect;
begin
  FReconnectPending:=TRUE;
end;

{$if defined(CONNECTION_AS_RECORD)}
function TDBMS_Connection.OpenDirectSQLFetchCols(const ASQLText: AnsiString; const ABufPtr: POdbcFetchCols): Boolean;
begin
  Result := FODBCConnectionHolder.OpenDirectSQLFetchCols(ASQLText, ABufPtr)
end;
{$ifend}

function TDBMS_Connection.PasswordStorage_ApplyStored: Boolean;
var
  VSavedUserName, VSavedPassword: String;
begin
  Result := PasswordStorage_ReadParams(VSavedUserName, VSavedPassword);
  if Result then
{$if defined(CONNECTION_AS_RECORD)}
  // текушая секция, если она будет подключаться к БД
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
  VNewSection: IDBMS_Connection;
  VLastSection: IDBMS_Connection;
  VResult: Byte;
begin
  if SameText(ETS_INTERNAL_TSS_Algorithm, AParamName) then begin
    // общий алгоритм секционирования
    FTSS_Primary_Params.ApplyAlgorithmValue(AParamValue);
    Exit;
  end;

  // если отключено секционирование - тут нечего делать
  if (tssal_None = FTSS_Primary_Params.Algorithm) then
    Exit;

  if SameText(ETS_INTERNAL_TSS_NewTileTable_Proc, AParamName) then begin
    // имя процедуры для создания объектов
    FTSS_Primary_Params.NewTileTable_Proc := AParamValue;
    Exit;
  end;

  if SameText(ETS_INTERNAL_TSS_NewTileTable_Link, AParamName) then begin
    // секция для запуска процедуры для создания объектов
    with FTSS_Primary_Params do
      ApplyLinkValue(AParamValue, @NewTileTable_Link);
    Exit;
  end;

  if SameText(ETS_INTERNAL_TSS_Guides_Link, AParamName) then begin
    // секция для справочников
    with FTSS_Primary_Params do
      ApplyLinkValue(AParamValue, @Guides_Link);
    Exit;
  end;

  if SameText(ETS_INTERNAL_TSS_Undefined_Link, AParamName) then begin
    // секция для тайлов, не попавших ни в одну из секций
    with FTSS_Primary_Params do
      ApplyLinkValue(AParamValue, @Undefined_Link);
    Exit;
  end;

  // проверяем по единственному обязательному параметру TSS
  if not SameText(System.Copy(AParamName, 1, Length(ETS_INTERNAL_TSS_DEST)), ETS_INTERNAL_TSS_DEST) then
    Exit;

  // индекс секции (суффикс параметра)
  VTSSSuffix := System.Copy(AParamName, (Length(ETS_INTERNAL_TSS_DEST)+1), Length(AParamName));

  // заполняем структуру полями из INI
  with VTSS_Definition do begin
    DestSource := AParamValue;
    AreaSource := AParams.Values[ETS_INTERNAL_TSS_AREA+VTSSSuffix];
    ZoomSource := AParams.Values[ETS_INTERNAL_TSS_ZOOM+VTSSSuffix];
    FullSource := AParams.Values[ETS_INTERNAL_TSS_FULL+VTSSSuffix];
    ModeSource := AParams.Values[ETS_INTERNAL_TSS_MODE+VTSSSuffix];
    CodeSource := AParams.Values[ETS_INTERNAL_TSS_CODE+VTSSSuffix];
  end;

  VNewTSSPtr := nil;
  VNewSection := nil;
  //VLastSection := nil;
  try
    New(VNewTSSPtr);

    if VNewTSSPtr^.ApplyDefinition(VTSS_Definition) then begin
      // секция возможно имеет смысл и будет работать

      // найдём последний объект в цепочке (у которого нет ссылки на следующий)
      VLastSection := @Self;
      while (VLastSection<>nil) and (VLastSection^.FNextSectionConn<>nil) do begin
        VLastSection := VLastSection^.FNextSectionConn;
      end;

      // создаём новую секцию
      New(VNewSection);
      VNewSection.Init(nil);

      // пристегнём параметры
      VNewSection.FTSS_Info_Ptr := VNewTSSPtr;

      // пропихнём имя секции (ну и имя сервиса для порядка)
      VNewSection.FPathDiv.ApplyFrom(VNewTSSPtr^.DestValue, FPathDiv.ServiceName);
      // сбросим ссылку, дальше за неё отвечает подключение
      VNewTSSPtr := nil;

      // мы - родитель
      VNewSection.FPrimaryConn := @Self;

      // читаем параметры для новой секции
      VResult := VNewSection.ApplyConnectionParams;
      if (ETS_RESULT_OK = VResult) then begin
        // поднимем признак на первичной секции (у нас), что есть секция без кода
        if (0 = VNewSection.FTSS_Info_Ptr^.CodeValue) then begin
          Self.FTSS_Primary_Params.HasSectionWithoutCode := TRUE;
        end;
        // всё в порядке
        VLastSection^.FNextSectionConn := VNewSection;
        VNewSection := nil;
      end;
    end;
  finally
    // если ссылка осталась - прибьём всё что насоздавали (ошибка)
    if (VNewSection<>nil) then begin
      VNewSection.Uninit;
      Dispose(VNewSection);
    end;
    if (VNewTSSPtr<>nil) then begin
      VNewTSSPtr.Clear;
      Dispose(VNewTSSPtr);
    end;
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
