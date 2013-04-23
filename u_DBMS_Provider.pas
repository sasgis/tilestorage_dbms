unit u_DBMS_Provider;

{$include i_DBMS.inc}

{$R-}

interface

uses
  Windows,
  SysUtils,
  Classes,
  t_types,
  t_SQL_types,
  t_ETS_Tiles,
  t_ETS_Path,
  t_ETS_Provider,
  t_DBMS_version,
  t_DBMS_contenttype,
  t_DBMS_service,
  t_DBMS_Template,
  i_DBMS_Provider,
  t_DBMS_Connect,
  u_DBMS_Connect,
  t_ODBC_Connection,
  t_ODBC_Buffer,
  t_TSS,
  u_ExecuteSQLArray,
  u_DBMS_Utils;

type
  TDBMS_Provider = class(TInterfacedObject, IDBMS_Provider, IDBMS_Worker)
  private
    // initialization
    FStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
    FInitFlags: LongWord;  // see ETS_INIT_* constants
    FHostPointer: Pointer; // MANDATORY
    
    // sync object for common work
    FProvSync: IReadWriteSync;
    // sync object for work with guides
    FGuidesSync: IReadWriteSync;

    // flag
    FCompleted: Boolean;
    // if unitialized
    FUninitialized: Boolean;

    // callbacks
    FHostCallbacks: TDBMS_INFOCLASS_Callbacks;
    
    // GlobalStorageIdentifier and ServiceName
    FPath: TETS_Path_Divided_W;

    // первичное подключение
    FPrimaryConnnection: IDBMS_Connection;
    // подключение для справочников (только ссылка, не закрывать!)
    FGuidesConnnection: IDBMS_Connection;
    // подключение для непопавших никуда тайлов
    FUndefinedConnnection: IDBMS_Connection;

    // guides
    FVersionList: TVersionList;
    FContentTypeList: TContentTypeList;
    // primary ContentTpye from Host (from Map params)
    FPrimaryContentType: AnsiString;

    // признак что для сервиса прочитаны параметры из БД
    FDBMS_Service_OK: Boolean;
    // service and global server params
    FDBMS_Service_Info: TDBMS_Service_Info;
    // service code (in DB only)
    FDBMS_Service_Code: AnsiString;

    // настройки формата для дат и чисел
    FFormatSettings: TFormatSettings;

    // неизвестные исключения
    FUnknownExceptions: TStringList;

    // для создания версии
    FLastMakeVersionSource: String;

  private
    // определяет подключение для справочников, сервисов и т.п. и для непопавших никуда тайлов
    procedure CheckSecondaryConnections;
    function GetGuidesConnection: IDBMS_Connection; inline;
    function GetUndefinedConnection: IDBMS_Connection; inline;

    // секционирование по табличным координатам (иначе по тайловым)
    function UseSectionByTableXY: Boolean; inline;
    function UseSectionByTileXY: Boolean; inline;

  private
    { IDBMS_Worker }
    // common work
    procedure DoBeginWork(
      const AExclusively: Boolean;
      const AOperation: TSqlOperation;
      out AExclusivelyLocked: Boolean
    );
    procedure DoEndWork(const AExclusivelyLocked: Boolean);
    // check if uninitialized
    function IsUninitialized: Boolean;
  private
    // work with guides
    procedure GuidesBeginWork(const AExclusively: Boolean);
    procedure GuidesEndWork(const AExclusively: Boolean);

    procedure ReadVersionsFromDB(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean
    );
    procedure ReadContentTypesFromDB(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean
    );
  private
    procedure InternalProv_Cleanup;

    function InternalProv_SetStorageIdentifier(
      const AInfoSize: LongWord;
      const AInfoData: PETS_SET_IDENTIFIER_INFO;
      const AInfoResult: PLongWord
    ): Byte;

    function InternalProv_Connect(
      const AExclusively: Boolean;
      const AXYZ: PTILE_ID_XYZ;
      const AAllowNewObjects: Boolean;
      ASQLTilePtr: PSQLTile;
      out ATilesConnection: IDBMS_Connection
    ): Byte;
    
    function InternalProv_ReadServiceInfo(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean
    ): Byte;
    
    procedure InternalProv_ClearServiceInfo;
    procedure InternalProv_Disconnect;
    procedure InternalProv_ClearGuides;

    // возвращает имя сервиса, используемое в БД (внутреннее)
    function InternalGetServiceNameByDB: TDBMS_String; inline;
    // возвращает имя сервиса, используемое в хосте (внешнее)
    function InternalGetServiceNameByHost: TDBMS_String; inline;

    // get version from cache (if not found - read from server)
    function InternalGetVersionAnsiValues(
      const AGuideConnection: IDBMS_Connection;
      const Aid_ver: SmallInt;
      const AExclusively: Boolean;
      const AVerValuePtr: PPAnsiChar;
      out AVerValueStr: AnsiString
    ): Boolean;

    // get contenttype from cache (if not found - read from server)
    function InternalGetContentTypeAnsiValues(
      const AGuideConnection: IDBMS_Connection;
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean;
      const AContentTypeTextPtr: PPAnsiChar;
      out AContentTypeTextStr: AnsiString
    ): Boolean;

  private
    // for cached version
    function GetVersionAnsiPointer(
      const AGuideConnection: IDBMS_Connection;
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetVersionWideString(
      const AGuideConnection: IDBMS_Connection;
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

    // for cached contenttype
    function GetContentTypeAnsiPointer(
      const AGuideConnection: IDBMS_Connection;
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetContentTypeWideString(
      const AGuideConnection: IDBMS_Connection;
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

  private
    // для списка неизвестных исключений
    FUnknownExceptionsCS: IReadWriteSync;
    procedure SaveUnknownException(const AException: Exception);
    procedure ClearUnknownExceptions;
    function HasUnknownExceptions: Boolean;
    function GetUnknownExceptions: String;
  private
    function SQLDateTimeToDBValue(
      const ATilesConnection: IDBMS_Connection;
      const ADateTime: TDateTime
    ): TDBMS_String;
    function SQLDateTimeToVersionValue(const ADateTime: TDateTime): TDBMS_String;

    function GetSQLIntName_Div(
      const ATilesConnection: IDBMS_Connection;
      const AXYMaskWidth, AZoom: Byte
    ): String;

    function GetStatementExceptionType(
      const ATilesConnection: IDBMS_Connection;
      const AException: Exception
    ): TStatementExceptionType;

    procedure DoOnDeadConnection(const ATilesConnection: IDBMS_Connection);
    procedure DoResetConnectionError(const ATilesConnection: IDBMS_Connection);

    function UpdateServiceVerComp(
      const AGuideConnection: IDBMS_Connection;
      const ANewVerCompMode: AnsiChar;
      out AErrorText: String
    ): Byte;

    function UpdateTileLoadMode(
      const AGuideConnection: IDBMS_Connection;
      const ANewTLMFlag: Byte;
      const AEnabled: Boolean;
      out AErrorText: String
    ): Byte;

    function UpdateTileSaveMode(
      const AGuideConnection: IDBMS_Connection;
      const ANewTSMFlag: Byte;
      const AEnabled: Boolean;
      out AErrorText: String
    ): Byte;

    function UpdateVerByTileMode(
      const AGuideConnection: IDBMS_Connection;
      const ANewVerByTileMode: SmallInt;
      out AErrorText: String
    ): Byte;

    function ParseVersionSource(
      const AVersionSource: String;
      const AVerParsedInfo: PVersionAA
    ): Byte;

    function ParseMakeVersionSource(
      const AGuideConnection: IDBMS_Connection;
      const AMakeVersionSource: String;
      const AVerFoundInfo, AVerParsedInfo: PVersionAA;
      out AVersionFound: Boolean
    ): Byte;

    function MakeVersionByFormParams(
      const AGuideConnection: IDBMS_Connection;
      const AFormParams: TStrings
    ): Byte;

    function SwitchHostToVersion(
      const AVersionToSwitch: String
    ): Byte;

  private
    function CreateAllBaseTablesFromScript(const ATilesConnection: IDBMS_Connection): Byte;
    
    // автоматическое создание записи о текущем сервисе (регистрация сервиса в БД)
    function AutoCreateServiceRecord(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean
    ): Byte;

    // автоматическое создание версии для сервиса
    function AutoCreateServiceVersion(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean;
      const AVersionAutodetected: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AReqVersionPtr: PVersionAA;
      out ARequestedVersionFound: Boolean
    ): Byte;

    function TryToObtainVerByTile(
      const AExclusively: Boolean;
      var ARequestedVersionFound: Boolean;
      const AIdContentType: SmallInt;
      var AVersionAutodetected: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      AReqVersionPtr: PVersionAA
    ): Byte;

    function GetMaxNextVersionInts(
      const AGuideConnection: IDBMS_Connection;
      const ANewVersionPtr: PVersionAA;
      const AKeepVerNumber: Boolean
    ): Boolean;

    // функция для разбора строкового значения версии в целое число для нецелочисленных версий
    function ParseVerValueToVerNumber(
      const AGivenVersionValue: String;
      out ADoneVerNumber: Boolean;
      out ADateTimeIsDefined: Boolean;
      out ADateTimeValue: TDateTime
    ): Integer;

    // создание версии в БД работает по подключению для справочников
    function MakePtrVersionInDB(
      const AGuideConnection: IDBMS_Connection;
      const ANewVersionPtr: PVersionAA;
      const AExclusively: Boolean
    ): Boolean;
    
    function MakeEmptyVersionInDB(
      const AGuideConnection: IDBMS_Connection;
      const AIdVersion: SmallInt;
      const AExclusively: Boolean
    ): Boolean;
    
    function VersionExistsInDBWithIdVer(
      const AGuideConnection: IDBMS_Connection;
      const AIdVersion: SmallInt
    ): Boolean;

    function GetNewIdService(const AGuideConnection: IDBMS_Connection): SmallInt;

    // check if tile is in common tiles
    function CheckTileInCommonTiles(
      const ATileBuffer: Pointer;
      const ATileSize: LongInt;
      out AUseAsTileSize: LongInt
    ): Boolean;

    // create table using SQL commands from special table
    function CreateTableByTemplate(
      const ATilesConnection: IDBMS_Connection;
      const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
      const AZoom: Byte;
      const ATableForTiles: Boolean
    ): Byte;

    // divide XY into parts (upper - to tablename, lower - to identifiers)
    procedure InternalDivideXY(
      const AXY: TPoint;
      const ASQLTile: PSQLTile
    );

    function InternalCalcSQLTile(
      const AXYZ: PTILE_ID_XYZ;
      const ASQLTile: PSQLTile;
      const AAllowNewObjects: Boolean;
      out AResultConnection: IDBMS_Connection
    ): Byte;

    function FillTableNamesForTiles(
      ASQLTile: PSQLTile;
      const AAllowNewObjects: Boolean;
      var AResultConnection: IDBMS_Connection
    ): Boolean;

    function GetSQL_AddIntWhereClause(
      var AWhereClause: TDBMS_String;
      const AFieldName: TDBMS_String;
      const AWithMinBound, AWithMaxBound: Boolean;
      const AMinBoundValue, AMaxBoundValue: Integer
    ): Boolean;

    function GetSQL_CheckPrevVersion(
      const ATilesConnection: IDBMS_Connection;
      ASQLTilePtr: PSQLTile;
      const AVerInfoPtr: PVersionAA
    ): TDBMS_String;

  private
    procedure AddVersionOrderBy(
      const ATilesConnection: IDBMS_Connection;
      const ASQLParts: PSQLParts;
      const AVerInfoPtr: PVersionAA;
      const ACutOnVersion: Boolean
    );

    // формирование текста SQL для чтения тайлов из разных режимов
    function GetSQL_SelectTilesInternal(
      const ATilesConnection: IDBMS_Connection;
      const ASQLTile: PSQLTile;
      const AVersionIn: Pointer;
      const AOptionsIn: LongWord;
      const AInitialWhere: TDBMS_String;
      const AGetManyTilesWithXY: Boolean;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
    // формирование текста SQL для получения (SELECT) тайла или маркера TNE
    function GetSQL_SelectTile(
      const ATilesConnection: IDBMS_Connection;
      const ASQLTilePtr: PSQLTile;
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // формирование текста SQL для вставки (INSERT) и обновления (UPDATE) тайла или маркера TNE
    // в тексте SQL возможны только параметр tile_body как ?, остальное подставляется сразу
    function GetSQL_InsertUpdateTile(
      const ATilesConnection: IDBMS_Connection;
      const ASQLTilePtr: PSQLTile;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
      out AInsertUpdateSubType: TInsertUpdateSubType;
      out AUpsert: Boolean;
      out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
    ): Byte;

    // формирование текста SQL для удаления (DELETE) тайла или маркера TNE
    function GetSQL_DeleteTile(
      const ATilesConnection: IDBMS_Connection;
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      ASQLTilePtr: PSQLTile;
      out ADeleteSQLResult: TDBMS_String
    ): Byte;

    // формирование текста SQL для получения (SELECT) списка существующих версий тайла (XYZ)
    function GetSQL_EnumTileVersions(
      const ATilesConnection: IDBMS_Connection;
      const ASQLTilePtr: PSQLTile;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // формирует список команд SQL для получения карты заполнения по нескольким таблицам
    function GetSQL_GetTileRectInfo(
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN;
      const AExclusively: Boolean;
      ASelectInRectList: TSelectInRectList
    ): Byte;

    function GetSQL_InsertIntoService(
      const AGuideConnection: IDBMS_Connection;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
  private
    // выбор секционированного соединения
    function ChooseConnection(
      const AZoom: Byte;
      const AXYPtr: PPoint;
      const AAllowNewObjects: Boolean
    ): IDBMS_Connection;
  private
    { IDBMS_Provider }
    function DBMS_Complete(const AFlags: LongWord): Byte;

    function DBMS_SetInformation(
      const AInfoClass: Byte; // see ETS_INFOCLASS_* constants
      const AInfoSize: LongWord;
      const AInfoData: Pointer;
      const AInfoResult: PLongWord
    ): Byte;

    function DBMS_SelectTile(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_InsertTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean
    ): Byte;

    function DBMS_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN
    ): Byte;

    function DBMS_EnumTileVersions(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_GetTileRectInfo(
      const ACallbackPointer: Pointer;
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
    ): Byte;

    function DBMS_MakeTileEnum(
      const AEnumTilesHandle: PETS_EnumTiles_Handle;
      const AFlags: LongWord;
      const AHostPointer: Pointer
    ): Byte;

    function DBMS_ExecOption(
      const ACallbackPointer: Pointer;
      const AExecOptionIn: PETS_EXEC_OPTION_IN
    ): Byte;

    function Uninitialize: Byte;
  public
    constructor Create(
      const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
      const AFlags: LongWord;  // see ETS_INIT_* constants
      const AHostPointer: Pointer // MANDATORY
    );
    destructor Destroy; override;
  end;
  
implementation

uses
  u_Synchronizer,
  u_Exif_Parser,
  u_Tile_Parser,
  u_Lang,
  u_DBMS_TileEnum,
  u_DBMS_Template;

{ TDBMS_Provider }

procedure TDBMS_Provider.AddVersionOrderBy(
  const ATilesConnection: IDBMS_Connection;
  const ASQLParts: PSQLParts;
  const AVerInfoPtr: PVersionAA;
  const ACutOnVersion: Boolean
);

  procedure _AddWithoutFieldValue(const AFieldName: TDBMS_String);
  begin
    ASQLParts^.SelectSQL := ASQLParts^.SelectSQL + ',w.' + AFieldName;

    ASQLParts^.OrderBySQL := ' order by ' + AFieldName + ' desc';
  
    // добавляем таблицу с версиями
    ASQLParts^.FromSQL := ASQLParts^.FromSQL + ', ' + c_Prefix_Versions + InternalGetServiceNameByDB + ' w';

    ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=w.id_ver';
  end;

  procedure _AddWithFieldValue(const AFieldName, AGreatestValueForDB: TDBMS_String);
  begin
    _AddWithoutFieldValue(AFieldName);

    if ACutOnVersion then begin
      // compare using AFieldName field
      ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and w.' + AFieldName + '<=' + AGreatestValueForDB;
    end;
  end;

begin
  case FStatusBuffer^.id_ver_comp of
    TILE_VERSION_COMPARE_ID: begin
      // order by id_ver - not need to link versions
      if ACutOnVersion then begin
        // AVerInfoPtr<>nil
        ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver<=' + IntToStr(AVerInfoPtr^.id_ver);
      end;
      ASQLParts^.OrderBySQL := ' order by id_ver desc';
    end;
    TILE_VERSION_COMPARE_VALUE: begin
      // order by ver_value
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_value', DBMSStrToDB(AVerInfoPtr^.ver_value))
      else
        _AddWithoutFieldValue('ver_value');
    end;
    TILE_VERSION_COMPARE_DATE: begin
      // order by ver_date
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_date', SQLDateTimeToDBValue(ATilesConnection, AVerInfoPtr^.ver_date))
      else
        _AddWithoutFieldValue('ver_date');
    end;
    TILE_VERSION_COMPARE_NUMBER: begin
      // order by ver_number
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_number', IntToStr(AVerInfoPtr^.ver_number))
      else
        _AddWithoutFieldValue('ver_number');
    end;
    else {TILE_VERSION_COMPARE_NONE:} begin
      // cannot compare versions
      if (AVerInfoPtr<>nil) then begin
        ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=' + IntToStr(AVerInfoPtr^.id_ver);
      end;
    end;
  end;
end;

function TDBMS_Provider.AutoCreateServiceRecord(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean
): Byte;
var
  VSQLText: TDBMS_String;
  VStatementExceptionType: TStatementExceptionType;
begin
  // регистрация картосервиса в БД выполняется только в эксклюзивном режиме
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  // сформируем текст SQL для создания записи
  Result := GetSQL_InsertIntoService(AGuideConnection, AExclusively, VSQLText);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // исполняем INSERT (вставляем запись о сервисе)
  VStatementExceptionType := set_Success;
  try
    AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
    Result := ETS_RESULT_OK;
  except on E: Exception do
    VStatementExceptionType := GetStatementExceptionType(AGuideConnection, E);
  end;

  StandardExceptionType(VStatementExceptionType, FALSE, Result);
end;

function TDBMS_Provider.AutoCreateServiceVersion(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean;
  const AVersionAutodetected: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AReqVersionPtr: PVersionAA;
  out ARequestedVersionFound: Boolean
): Byte;
var
  VVerIsInt: Boolean;
  VKeepVerNumber: Boolean;
  VGenerateNewIdVer: Boolean;
  VFoundAnotherVersionAA: TVersionAA;
  VDateTimeIsDefined: Boolean;
begin
  // запрошенные версии создаются только в эксклюзивном режиме
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  if AVersionAutodetected then begin
    VVerIsInt := FALSE;
    VGenerateNewIdVer := TRUE;
  end else begin
    // версия не определена автоматически - получим запрошенную версию
    if (nil=AInsertBuffer^.szVersionIn) then begin
      // нет версии
      AReqVersionPtr^.ver_value := '';
    end else if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
      // как Ansi
      AReqVersionPtr^.ver_value := AnsiString(PAnsiChar(AInsertBuffer^.szVersionIn));
    end else begin
      // как Wide
      AReqVersionPtr^.ver_value := WideString(PWideChar(AInsertBuffer^.szVersionIn));
    end;

    // если пустая версия
    if (0=Length(AReqVersionPtr^.ver_value)) then begin
      // возможно СУБД не допускает пустую версию
      if c_SQL_Empty_Version_Denied[AGuideConnection.GetCheckedEngineType] then begin
        Result := ETS_RESULT_EMPTY_VERSION_DENIED;
        Exit;
      end;

      // TODO: try to use 0 as id_ver
      if (not VersionExistsInDBWithIdVer(AGuideConnection, 0)) then begin
        // создаём пустую версию только если СУБД это допускает
        if not c_SQL_Empty_Version_Denied[AGuideConnection.GetCheckedEngineType] then begin
          MakeEmptyVersionInDB(AGuideConnection, 0, AExclusively);
        end;
        // читаем список версий
        ReadVersionsFromDB(AGuideConnection, AExclusively);
        ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(0, AReqVersionPtr);
        if ARequestedVersionFound then begin
          Result := ETS_RESULT_OK;
          Exit;
        end;
      end;

      ARequestedVersionFound := FALSE;
      Result := ETS_RESULT_UNKNOWN_VERSION;
      Exit;
    end;

    VDateTimeIsDefined := FALSE;
    VVerIsInt := TryStrToInt(AReqVersionPtr^.ver_value, AReqVersionPtr^.ver_number);
    // flag to keep ver_number=ver_value even if incrementing id_ver
    VKeepVerNumber := FALSE;
    VGenerateNewIdVer := FALSE;
    // предобработка для большинства сервисов с версиями (для целочисленной версии)
    // для простоты отладки реализовано отдельными кусками

    // если версия целочисленная
    // и если она влазит в SmallInt (AReqVersionPtr^.ver_number между -32768 to 32767 - для простоты забём на -32768)
    // и такой id_ver ещё нет
    // то пробуем пропихнуть запрошенную версию AReqVersionPtr^.ver_value
    // в поле id_ver (SmallInt)
    // и в поле ver_number (Integer)
  end;

  if AVersionAutodetected then begin
    // если сработало автоопределение версии по тайлу - значит всё кроме id_ver уже определено
    VDateTimeIsDefined := TRUE;
    VKeepVerNumber := TRUE;
    VGenerateNewIdVer := TRUE;
  end else if VVerIsInt and (Abs(AReqVersionPtr^.ver_number)<=32767) then begin
    // версия - небольшое целое число, влазящее в id_ver SmallInt
    AReqVersionPtr^.id_ver := AReqVersionPtr^.ver_number;
    VKeepVerNumber := TRUE;
    if FVersionList.FindItemByIdVerInternal(AReqVersionPtr^.id_ver, @VFoundAnotherVersionAA) then begin
      // нашлась версия с таким id_ver (но очевидно с другим значением ver_value)
      ARequestedVersionFound := (VFoundAnotherVersionAA.ver_value = AReqVersionPtr^.ver_value);
      if ARequestedVersionFound then begin
        // однако что-то в логике, и версия такая есть
        Result := ETS_RESULT_OK;
        Exit;
      end else begin
        // всё в порядке с логикой - найденная версия с другим значением ver_value
        // значит ниже надо генерить версию с переданным значением ver_value и с новым уникальным id_ver
        VGenerateNewIdVer := TRUE;
      end;
    end else begin
      // версии с таким id_ver не нашлось - это идеальный вариант
      // можем создать версию с переданным значением id_ver, ver_number и ver_value
    end;
  end else if VVerIsInt then begin
    // версия - большое целое число, не влазящее в в id_ver SmallInt
    // так что id_ver всё равно генерить, а ver_number и ver_value будут переданными
    VGenerateNewIdVer := TRUE;
    VKeepVerNumber := TRUE;
  end else begin
    // версия вообще не целое число (например yandex)
    // в любом случае генерим id_ver
    // но вот в ver_number возможно что-нибудь тут просунуть
    VGenerateNewIdVer := TRUE;
    AReqVersionPtr^.ver_number := ParseVerValueToVerNumber(AReqVersionPtr^.ver_value, VKeepVerNumber, VDateTimeIsDefined, AReqVersionPtr^.ver_date);
  end;

  if VGenerateNewIdVer then begin
    // генерим новый id_ver (и возможно ver_number)
    GetMaxNextVersionInts(AGuideConnection, AReqVersionPtr, VKeepVerNumber);
  end;

  if (not VDateTimeIsDefined) then begin
    AReqVersionPtr^.ver_date := NowUTC;
  end;

  repeat
    if MakePtrVersionInDB(AGuideConnection, AReqVersionPtr, AExclusively) then begin
      ReadVersionsFromDB(AGuideConnection, AExclusively);
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(AReqVersionPtr^.id_ver, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;

    // TODO: make correct loop
    ARequestedVersionFound := FALSE;
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  until FALSE;
end;

procedure TDBMS_Provider.CheckSecondaryConnections;
begin
  // здесь FPrimaryConnnection уже есть
  if (nil = FPrimaryConnnection.FNextSectionConn) then begin
    // нет секций
    FGuidesConnnection := FPrimaryConnnection;
    FUndefinedConnnection := FPrimaryConnnection;
  end else begin
    // секции есть - подключение для справочников
    if (tsslt_Secondary = FPrimaryConnnection.FTSS_Primary_Params.Guides_Link) then
      FGuidesConnnection := FPrimaryConnnection.FNextSectionConn
    else
      FGuidesConnnection := FPrimaryConnnection;
    // а теперь - подключение для непопавших никуда тайлов
    if (tsslt_Secondary = FPrimaryConnnection.FTSS_Primary_Params.Undefined_Link) then
      FUndefinedConnnection := FPrimaryConnnection.FNextSectionConn
    else
      FUndefinedConnnection := FPrimaryConnnection;
  end;
end;

function TDBMS_Provider.CheckTileInCommonTiles(
  const ATileBuffer: Pointer;
  const ATileSize: LongInt;
  out AUseAsTileSize: LongInt
): Boolean;
begin
  Result := FALSE;
  AUseAsTileSize := ATileSize;
  // TODO: check size and hash
end;

function TDBMS_Provider.ChooseConnection(
  const AZoom: Byte;
  const AXYPtr: PPoint;
  const AAllowNewObjects: Boolean
): IDBMS_Connection;
begin
  // выбираем соединение (секцию) исходя из табличных или тайловых кооринат
  Result := GetGuidesConnection;

  // если можно работать только по одному коннекту
  // то сразу можем вернуть подключение для справочников
  if FPrimaryConnnection.FTSS_Primary_Params.UseSingleConn(AAllowNewObjects) then
    Exit;

  if (nil=AXYPtr) or (nil=Result^.FNextSectionConn) then
    Exit;

  // далее цикл от первичного подключения
  Result := FPrimaryConnnection;
  repeat
    // к следующей секции по цепочке
    Result := Result^.FNextSectionConn;

    if (nil=Result) then begin
      // так ничего и не нашлось - будем использовать подключение для неопределившихся тайлов
      Result := GetUndefinedConnection;
      Exit;
    end;

    // проверяем, залетает ли координата в секцию
    if (Result^.FTSS_Info_Ptr<>nil) then
    if (Result^.FTSS_Info_Ptr^.TileInSection(AZoom, AXYPtr)) then begin
      // секция нашлась
      Exit;
    end;

  until FALSE;
end;

procedure TDBMS_Provider.ClearUnknownExceptions;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    FreeAndNil(FUnknownExceptions);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

constructor TDBMS_Provider.Create(
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
  const AFlags: LongWord;
  const AHostPointer: Pointer
);
begin
  inherited Create;

  GetLocaleFormatSettings(GetThreadLocale, FFormatSettings);
  FFormatSettings.DecimalSeparator := '.';
  FFormatSettings.DateSeparator    := c_Date_Separator;
  FFormatSettings.TimeSeparator    := c_Time_Separator;

  FCompleted := FALSE;
  FUninitialized := False;
  
  // initialization
  FStatusBuffer := AStatusBuffer;
  FInitFlags := AFlags;
  FHostPointer := AHostPointer;

  FPrimaryContentType := '';
  FLastMakeVersionSource := '';

  // sync objects
  FProvSync := MakeSyncRW_Std(Self);
  FGuidesSync := MakeSyncRW_Std(Self);

  FPrimaryConnnection := nil;
  FGuidesConnnection := nil;
  FUndefinedConnnection := nil;

  // если всё нормально настроено - сюда ничего не залетит
  // так что заранее создавать этот объект нелогично
  // достаточно критической секции
  FUnknownExceptionsCS := MakeSyncSection(Self);
  FUnknownExceptions := nil;

  FVersionList := TVersionList.Create;
  FContentTypeList := TContentTypeList.Create;

  InternalProv_Cleanup;
end;

function TDBMS_Provider.CreateAllBaseTablesFromScript(const ATilesConnection: IDBMS_Connection): Byte;
var
  VSQLTemplates: TSQLScriptParser_SQL;
begin
  // создадим объект для генерации структуры для конкретного типа БД
  VSQLTemplates := TSQLScriptParser_SQL.Create(ATilesConnection);
  try
    // исполним всё что есть
    Result := VSQLTemplates.ExecuteAllSQLs;
  finally
    VSQLTemplates.Free;
  end;
end;

function TDBMS_Provider.CreateTableByTemplate(
  const ATilesConnection: IDBMS_Connection;
  const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
  const AZoom: Byte;
  const ATableForTiles: Boolean
): Byte;
var
  VOdbcFetchColsEx: TOdbcFetchCols5;
  VExecuteSQLArray: TExecuteSQLArray;
  VSQLText, VExecuteAfterALL: TDBMS_String;
  Vignore_errors: AnsiChar;
  VReplaceNumeric: String;
  VIndexSQL: SmallInt;
  i: Integer;
  VExecuteSQLItem: TExecuteSQLItem;
  // код секции (обязателен для выполнения процедуры)
  VSectionCode: LongInt;
  // подключение для выполнения процедуры NewTileTable
  // если NIL - значит не выполняем процедуру
  VNewTileProcConn: IDBMS_Connection;
  // подключение для  выполнения CREATE TABLE
  VCreateTableConn: IDBMS_Connection;

  function _GetTxtSQL(out ATxtSql: AnsiString): Boolean;
  var VColIdx: SmallInt;
  begin
    VColIdx := VOdbcFetchColsEx.Base.ColIndex('txt_sql');
    if (VColIdx>0) then begin
      VOdbcFetchColsEx.Base.ColToAnsiString(VColIdx, ATxtSql);
      Result := (0<Length(ATxtSql));
    end else
      Result := FALSE;
  end;
 
begin
  // а вдруг нет базовой таблицы с шаблонами
  if (not ATilesConnection.TableExistsDirect(ATilesConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
    // создадим базовые таблицы
    CreateAllBaseTablesFromScript(ATilesConnection);
    // а вдруг обломались?
    if (not ATilesConnection.TableExistsDirect(ATilesConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
      // полный отстой и нам тут делать нечего
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // если запрошенная таблица уже есть - валим
  if (ATilesConnection.TableExistsDirect(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // по умолчанию процедуру не выполняем
  VNewTileProcConn := nil;
  VSectionCode := 0;

  // определим используемые подключения для создания таблицы
  if (not ATableForTiles) then begin
    // таблица не тайловая - значит используем подключение для справочников
    VCreateTableConn  := GetGuidesConnection;
  end else begin
    // тайловая таблица - возможны разные варианты
    // определим нужные подключения
    if (ATilesConnection.FTSS_Info_Ptr<>nil) then begin
      // код целевой секции
      VSectionCode := ATilesConnection.FTSS_Info_Ptr^.CodeValue;
    end;

    // только если есть процедура и есть код целевой секции
    if (VSectionCode <> 0) then
    if (0 < Length(FPrimaryConnnection.FTSS_Primary_Params.NewTileTable_Proc)) then
    case FPrimaryConnnection.FTSS_Primary_Params.NewTileTable_Link of
      tsslt_Destination: begin
        // целевое подключение
        VNewTileProcConn := ATilesConnection;
      end;
      tsslt_Secondary: begin
        // вторичное, если нет - первичное
        VNewTileProcConn := FPrimaryConnnection;
        if VNewTileProcConn.FNextSectionConn<>nil then
          VNewTileProcConn := VNewTileProcConn.FNextSectionConn;
      end;
      else begin
        // первичное
        VNewTileProcConn := FPrimaryConnnection;
      end;
    end;

    // однако ещё должны уметь выполнять процедуры на этом сервере
    if (VNewTileProcConn <> nil) then
    if (pnm_None = c_SQL_ProcedureNew_Mode[VNewTileProcConn.GetCheckedEngineType]) then begin
      // к сожалению, не умеем
      VNewTileProcConn := nil;
    end;

    // определим подключение для выполнения CREATE TABLE
    // если секционирование настроено через удалённые таблицы, то
    // будем выполняться на подключении для процедуры
    // иначе будем использовать целевое подключение
    if (VNewTileProcConn <> nil) and (tssal_Linked = FPrimaryConnnection.FTSS_Primary_Params.Algorithm) then begin
      VCreateTableConn := VNewTileProcConn;
    end else begin
      // нет секционирования или ручное секционирование - используем целевое подключение
      VCreateTableConn := ATilesConnection;
    end;
  end;

  // читаем Z_ALL_SQL на целевой секции
  VSQLText := 'SELECT index_sql,ignore_errors,object_sql' +
               ' FROM ' + ATilesConnection.ForcedSchemaPrefix + Z_ALL_SQL+
              ' WHERE object_name=' + DBMSStrToDB(ATemplateName) +
                ' AND object_oper=''C'' AND skip_sql=''0''' +
              ' ORDER BY index_sql';

  // вытащим все запросы SQL для CREATE (операция "C") для запрошенного шаблона
  VExecuteSQLArray := nil;
  VOdbcFetchColsEx.Init;
  try
    try
      VOdbcFetchColsEx.Base.EnableCLOBChecking;
      ATilesConnection.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));

      if (not VOdbcFetchColsEx.Base.IsActive) then begin
        // ничего не прочиталось - значит нет шаблона
        Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
        Exit;
      end;

      // что-то в датасете есть
      VExecuteSQLArray := TExecuteSQLArray.Create;

      while VOdbcFetchColsEx.Base.FetchRecord do begin
        // тащим текст SQL для исполнения в порядке очерёдности
        VOdbcFetchColsEx.Base.ColToSmallInt(1, VIndexSQL);
        VOdbcFetchColsEx.Base.ColToAnsiCharDef(2, Vignore_errors, ETS_UCT_YES);

        // если есть текст - добавляем его в список
        VOdbcFetchColsEx.Base.ColToAnsiString(3, VSQLText);
        if (0<Length(VSQLText)) then begin
          // а тут надо подменить имя таблицы
          VSQLText := StringReplace(VSQLText, ATemplateName, AUnquotedTableNameWithoutPrefix, [rfReplaceAll,rfIgnoreCase]);

          if ATableForTiles then begin
            // таблица для хранения тайлов
            // также необходимо подставить нужные типы полей для оптимального хранения XY
            // а именно - заменить numeric на INT нужной ширины
            VReplaceNumeric := GetSQLIntName_Div(ATilesConnection, FDBMS_Service_Info.XYMaskWidth, AZoom);
            VSQLText := StringReplace(VSQLText, c_RTL_Numeric, VReplaceNumeric, [rfReplaceAll,rfIgnoreCase]);
          end;

          VExecuteSQLArray.AddSQLItem(
            VIndexSQL,
            VSQLText,
            (Vignore_errors<>ETS_UCT_NO)
          );
        end;
      end;

    finally
      VOdbcFetchColsEx.Base.Close;
      VOdbcFetchColsEx.Base.DisableCLOBChecking;
    end;

    // а теперь если чего залетело в список - выполним
    if (VExecuteSQLArray<>nil) then
    if (VExecuteSQLArray.Count>0) then begin
      for i := 0 to VExecuteSQLArray.Count-1 do begin
        VExecuteSQLItem := VExecuteSQLArray.GetSQLItem(i);
        VSQLText := VExecuteSQLItem.Text;
        VExecuteAfterALL := '';

        // если это таблица для хранения тайлов - то возможно, что запрос надо подправить
        // или вообще заменить, выполнить другой и т.п.
        if (VNewTileProcConn <> nil) then begin
          // зовём процедуру или функцию
          with VOdbcFetchColsEx.Base do begin
            Close;
            WorkFlags := WorkFlags or WF_COLNAME;
          end;
          // текст с параметрами для запроса
          // index_sql, object_oper, object_name, section_code
          VReplaceNumeric := IntToStr(VExecuteSQLItem.IndexSQL) + ',''C'',' +
                             DBMSStrToDB(AUnquotedTableNameWithoutPrefix) + ',' +
                             IntToStr(VSectionCode);
          // доделаем запрос
          case c_SQL_ProcedureNew_Mode[VNewTileProcConn.GetCheckedEngineType] of
            pnm_ExecuteProcedure: begin
              VReplaceNumeric := 'exec ' + FPrimaryConnnection.FTSS_Primary_Params.NewTileTable_Proc + ' ' + VReplaceNumeric;
            end;
            pnm_SelectFromFunction: begin
              VReplaceNumeric := 'select * from ' + FPrimaryConnnection.FTSS_Primary_Params.NewTileTable_Proc + '(' + VReplaceNumeric + ')';
            end;
          end;

          // выполняем процедуру на подключении для процедуры
          if VNewTileProcConn.OpenDirectSQLFetchCols(VReplaceNumeric, @(VOdbcFetchColsEx.Base)) then
          while VOdbcFetchColsEx.Base.FetchRecord do begin
            // есть что-то интересненькое
            // вернуться должен датасет не более 5 полей
            // анализируются в порядке чтения следующие поля:
            // txt_mod - char    - чего делаем
            // txt_pos - int     - куда делаем
            // txt_sql - varchar - что за текст
            case VOdbcFetchColsEx.Base.GetOptionalAnsiChar('txt_mod', #0) of
              'A': begin
                // Append at the end of text
                if _GetTxtSQL(VReplaceNumeric) then begin
                  VSQLText := VSQLText + VReplaceNumeric;
                end;
              end;
              'I': begin
                // Insert at position
                if _GetTxtSQL(VReplaceNumeric) then begin
                  System.Insert(VReplaceNumeric, VSQLText, VOdbcFetchColsEx.Base.GetOptionalLongInt('txt_pos'));
                end;
              end;
              'R': begin
                // Replace full SQL text
                if _GetTxtSQL(VReplaceNumeric) then begin
                  VSQLText := VReplaceNumeric;
                end;
              end;
              'E': begin
                // Execute this SQL after all (only if success!)
                if _GetTxtSQL(VReplaceNumeric) then begin
                  VExecuteAfterALL := VReplaceNumeric;
                end;
              end;
              'S': begin
                // Skip this command
                VSQLText := '';
                break;
              end;
            end;
          end;

          VOdbcFetchColsEx.Base.Close;
        end;

        if (0<Length(VSQLText)) then
        try
          // выполняем напрямую
          VCreateTableConn.ExecuteDirectSQL(VSQLText, FALSE)
        except
          on E: Exception do begin
            // тут если стандартные критичные ошибки - надо валить и сообщать юзеру
            if StandardExceptionType(GetStatementExceptionType(VCreateTableConn, E), TRUE, Result) then
              Exit;
            // прочее покажем в зависимости от настройки
            if (not VExecuteSQLItem.SkipErrorsOnExec) then
              raise;
          end;
        end;
      end;
    end;
  finally
    VOdbcFetchColsEx.Base.Close;
    FreeAndNil(VExecuteSQLArray);
  end;

  // проверяем что табла успешно создалась
  // проверяем на целевом подключении
  if (ATilesConnection.TableExistsDirect(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // облом
  Result := ETS_RESULT_INVALID_STRUCTURE;
end;

function TDBMS_Provider.DBMS_Complete(const AFlags: LongWord): Byte;
begin
  FCompleted := TRUE;
  Result := ETS_RESULT_OK;

  // пропихнём признак в хост
  if (FStatusBuffer<>nil) then
  with (FStatusBuffer^) do begin
    if wSize>=SizeOf(FStatusBuffer^) then
      malfunction_mode := ETS_PMM_HAS_COMPLETED;
  end;
end;

function TDBMS_Provider.DBMS_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN
): Byte;
var
  VExclusive: Boolean;
  VDeleteSQL: TDBMS_String;
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
  VSQLTile: TSQLTile;
  VConnectionToDeleteTile: IDBMS_Connection;
begin
  VExclusive := ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Delete, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive, ADeleteBuffer^.XYZ, FALSE, @VSQLTile, VConnectionToDeleteTile);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // make DELETE statements
    Result := GetSQL_DeleteTile(
      VConnectionToDeleteTile,
      ADeleteBuffer,
      @VSQLTile,
      VDeleteSQL
    );
      
    if (ETS_RESULT_OK<>Result) then
      Exit;

    VStatementExceptionType := set_Success;
    try
      // execute DELETE statement
      VConnectionToDeleteTile.ExecuteDirectSQL(VDeleteSQL, TRUE);
      // done (successfully DELETEed)
      // Result := ETS_RESULT_OK;
    except on E: Exception do
      VStatementExceptionType := GetStatementExceptionType(VConnectionToDeleteTile, E);
    end;

    // что случилось
    if not StandardExceptionType(VStatementExceptionType, FALSE, Result) then
    case VStatementExceptionType of
      set_Success, set_TableNotFound: begin
        // нет таблицы - нет и тайла
        Result := ETS_RESULT_OK;
      end;
      set_PrimaryKeyViolation: begin
        // такого тут быть не должно
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_EnumTileVersions(
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte;
var
  VExclusive, VVersionFound: Boolean;
  VOdbcFetchCols: TOdbcFetchCols2;
  VEnumOut: TETS_ENUM_TILE_VERSION_OUT;
  VETS_VERSION_W: TETS_VERSION_W;
  VETS_VERSION_A: TETS_VERSION_A;
  VVersionAA: TVersionAA;
  VSQLText: TDBMS_String;
  VVersionValueW, VVersionCommentW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
  VFetchedIdVer: SmallInt;
  VSQLTile: TSQLTile;
  VConnectionToEnumVersions: IDBMS_Connection;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_EnumVersions, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive, ASelectBufferIn.XYZ, FALSE, @VSQLTile, VConnectionToEnumVersions);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // fill full sql text and open
    Result := GetSQL_EnumTileVersions(
      VConnectionToEnumVersions,
      @VSQLTile,
      VSQLText
    );
    if (ETS_RESULT_OK<>Result) then
      Exit;

    FillChar(VEnumOut, SizeOf(VEnumOut), 0);

    if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
      // Ansi record
      FillChar(VETS_VERSION_A, SizeOf(VETS_VERSION_A), 0);
      VEnumOut.ResponseValue := @VETS_VERSION_A;
    end else begin
      // Wide record
      FillChar(VETS_VERSION_W, SizeOf(VETS_VERSION_W), 0);
      VEnumOut.ResponseValue := @VETS_VERSION_W;
    end;

    // if connected - SELECT id_ver from DB
    VOdbcFetchCols.Init;
    try
      // open sql
      VStatementExceptionType := set_Success;
      try
        VConnectionToEnumVersions.OpenDirectSQLFetchCols(VSQLText, @VOdbcFetchCols);
      except on E: Exception do
        VStatementExceptionType := GetStatementExceptionType(VConnectionToEnumVersions, E);
      end;

      if StandardExceptionType(VStatementExceptionType, FALSE, Result) then begin
        // предопределённые известные критичные ошибки
        Exit
      end;

      case VStatementExceptionType of
        set_Success: begin
          // пусто
        end;
        set_TableNotFound: begin
          // нет таблицы - нет и тайлов
          Result := ETS_RESULT_OK;
          Exit;
        end;
        set_PrimaryKeyViolation: begin
          Result := ETS_RESULT_INVALID_STRUCTURE;
          Exit;
        end;
      end;

      if not VOdbcFetchCols.Base.IsActive then begin
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else begin
        // для работы без датасетов число записей заранее неизвестно
        VEnumOut.ResponseCount := -1; // unknown count

        while (VOdbcFetchCols.Base.FetchRecord) do begin
          // возьмём суррогатный идентификатор версии
          // значения NULL тут быть не может
          VOdbcFetchCols.Base.ColToSmallInt(1, VFetchedIdVer);

          // find selected version
          VVersionFound := FVersionList.FindItemByIdVerInternal(VFetchedIdVer, @VVersionAA);

          if (not VVersionFound) then begin
            // необходимо обновление версии, так как вытащили из БД неизвестную ранее версию
            // очевидно она залетела в другом коннекте
            if (not VExclusive) then begin
              Result := ETS_RESULT_NEED_EXCLUSIVE;
              Exit;
            end;
            ReadVersionsFromDB(GetGuidesConnection, VExclusive);
            VVersionFound := FVersionList.FindItemByIdVerInternal(VFetchedIdVer, @VVersionAA);
          end;

          if (not VVersionFound) then begin
            // OMG WTF
            VVersionAA.id_ver := VFetchedIdVer;
            VVersionAA.ver_value := '';
            VVersionAA.ver_comment := '';
          end;

          // make params for callback
          if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
            // Ansi record
            VETS_VERSION_A.id_ver := VVersionAA.id_ver;
            VETS_VERSION_A.ver_value := PAnsiChar(VVersionAA.ver_value);
            VETS_VERSION_A.ver_comment := PAnsiChar(VVersionAA.ver_comment);
          end else begin
            // Wide record
            VETS_VERSION_W.id_ver := VVersionAA.id_ver;
            VVersionValueW := VVersionAA.ver_value;
            VETS_VERSION_W.ver_value := PWideChar(VVersionValueW);
            VVersionCommentW := VVersionAA.ver_comment;
            VETS_VERSION_W.ver_comment := PWideChar(VVersionCommentW);
          end;

          // call host's callback
          Result := TETS_EnumTileVersions_Callback(FHostCallbacks[ETS_INFOCLASS_EnumTileVersions_Callback])(
            FHostPointer,
            ACallbackPointer,
            ASelectBufferIn,
            @VEnumOut
          );

          if (Result<>ETS_RESULT_OK) then
            break;

          // next record
          Inc(VEnumOut.ResponseIndex);

        end;

      end;
      
    finally
      VOdbcFetchCols.Base.Close;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_ExecOption(
  const ACallbackPointer: Pointer;
  const AExecOptionIn: PETS_EXEC_OPTION_IN
): Byte;
const
  c_EO_SetTLM         = 'SetTLM';
  c_EO_SetTSM         = 'SetTSM';
  c_EO_SetVerByTile   = 'SetVerByTile';
  c_EO_SetVerComp     = 'SetVerComp';
  c_EO_GetVersions    = 'GetVersions';
  c_EO_MakeVersion    = 'MakeVersion';
  c_EO_ExecMakeVer    = 'ExecMakeVer';
  c_EO_ReloadVersions = 'ReloadVersions';
  c_EO_ResetConnError = 'ResetConnError';
  c_EO_GetUnknErrors  = 'GetUnknErrors';
  c_EO_ClearErrors    = 'ClearErrors';
  c_EO_SetAuthOpt     = 'SetAuthOpt';
  c_EO_ApplyAuthOpt   = 'ApplyAuthOpt';
  c_EO_CalcTableCoord = 'CalcTableCoord';

var
  VFullPrefix: String;
  VConnectionForOptions: IDBMS_Connection;


  function _AddReturnFooter: String;
  begin
    Result := '<br>' + // additional!
              '<a href="'+VFullPrefix+'">Return to Options</a>';
  end;

  function _AddTileLoadSaveModeLine(
    const AOption: Byte; // FStatusBuffer^.tile_load_mode or FStatusBuffer^.tile_save_mode
    const AFlag: Byte;
    const AExecOptionName: String; // c_EO_SetTLM or c_EO_SetTSM
    const ADescription: String
  ): String;
  var
    VEnabled: Boolean;
  begin
    VEnabled := ((AOption and AFlag) <> 0);

    if VEnabled then begin
      // enabled - click to disable
      Result := 'dis';
    end else begin
      // disabled - click to enable
      Result := 'en';
    end;

    Result := '<tr><td>' + ADescription + '</td><td>' + BoolToStr(VEnabled, TRUE) + '</td><td>' +
              'Click <a href="' +
              VFullPrefix + '/' + AExecOptionName + '/' + IntToStr(AFlag) + '/' + IntToStr(Ord(not VEnabled)) +
              '">HERE</a> to ' + Result + 'able</td></tr>';
  end;

  function _AddTileLoadModeLine(
    const AFlag: Byte;
    const ADescription: String
  ): String;
  begin
    Result := _AddTileLoadSaveModeLine(FStatusBuffer^.tile_load_mode, AFlag, c_EO_SetTLM, ADescription);
  end;

  function _AddTileSaveModeLine(
    const AFlag: Byte;
    const ADescription: String
  ): String;
  begin
    Result := _AddTileLoadSaveModeLine(FStatusBuffer^.tile_save_mode, AFlag, c_EO_SetTSM, ADescription);
  end;

  function _AddTable3ColHeader(const AFirstColCaption: String): String;
  begin
    Result := '<table><tr><td>'+AFirstColCaption+'</td><td>Enabled</td><td>Change</td></tr>';
  end;

  function _AddVerCompItem(const AVerCompMode: AnsiChar): String;
  begin
    if (AVerCompMode=FDBMS_Service_Info.id_ver_comp) then begin
      // current mode
      Result := 'Current';
    end else begin
      Result := '<a href="' + VFullPrefix + '/' + c_EO_SetVerComp + '/' + AVerCompMode + '">Select</a>';
    end;
  end;

  function _AddVerByTileItem(const AVerByTileValue: SmallInt; const ACaption: String): String;
  begin
    if (AVerByTileValue=FDBMS_Service_Info.new_ver_by_tile) then begin
      // current mode
      Result := 'Current';
    end else begin
      Result := '<a href="' + VFullPrefix + '/' + c_EO_SetVerByTile + '/' + IntToStr(AVerByTileValue) + '">Select</a>';
    end;
    Result := '<tr><td>' + ACaption + '</td><td>' + Result + '</td></tr>';
  end;

  procedure _TrimLeftDelims(var AFromSource: String);
  begin
    while (Length(AFromSource)>0) and (AFromSource[1]='/') do begin
      System.Delete(AFromSource,1,1);
    end;
  end;

  function _ExtractPart(var AFromSource: String): String;
  var p: Integer;
  begin
    if (0=Length(AFromSource)) then begin
      Result := '';
      Exit;
    end;

    p := System.Pos('/', AFromSource);
    if (p>0) then begin
      Result := System.Copy(AFromSource, 1, p-1);
      System.Delete(AFromSource, 1, p);
      _TrimLeftDelims(AFromSource);
    end else begin
      Result := AFromSource;
      AFromSource := '';
    end;
  end;

  function _AddPreamble(var AResponseText: String): Boolean;
  var
    VUsedCount, VUnusedCount: Integer;
  begin
    AResponseText := AResponseText +
                 '<br>' +
                 'Service code is "' + FDBMS_Service_Code + '"' +
                 '<br>' +
                 'Database server defined as ' + c_SQL_Engine_Name[VConnectionForOptions.GetCheckedEngineType] + '<br>';

    Result := (nil<>VConnectionForOptions) and (ETS_RESULT_OK=VConnectionForOptions.EnsureConnected(FALSE, nil));
    if (Result) then begin
      // connected
      VConnectionForOptions.FODBCConnectionHolder.StatementCache.GetStatistics(VUsedCount, VUnusedCount);
      if (VUsedCount<>0) or (VUnusedCount<>0) then begin
        AResponseText := AResponseText +
        'Statement used: ' + IntToStr(VUsedCount) + ', cached: ' + IntToStr(VUnusedCount) + '<br>';
      end;
    end else begin
      // not connected
      AResponseText := AResponseText +
                   '<br>' +
                   '<h1>Not connected</h1>' +
                   '<br>' +
                   VConnectionForOptions.GetConnectionErrorMessage +
                   '<br>' +
                   '<br>' +
                   'Click <a href="' + VFullPrefix + '/' + c_EO_SetAuthOpt + '">HERE</a> to set or change Authentication options' +
                   '<br>' +
                   'Click <a href="' + VFullPrefix + '/' + c_EO_ResetConnError + '">HERE</a> to reset connection information if you want another try';
    end;
  end;

  procedure _ReloadVersions;
  var
    VExclusivelyLocked: Boolean;
  begin
    DoBeginWork(TRUE, so_ReloadVersions, VExclusivelyLocked);
    try
      ReadVersionsFromDB(GetGuidesConnection, TRUE);
    finally
      DoEndWork(VExclusivelyLocked);
    end;
  end;

  procedure _AddListOfVersions(var AResponseText: String);
  var
    VExclusivelyLocked: Boolean;
    i: SmallInt;
    pVer: PVersionAA;
  begin
    AResponseText := AResponseText +
                   '<br>' +
                   '<br>' +
                   '<table><tr><td>id_ver</td><td>ver_value</td><td>ver_date</td><td>ver_number</td><td>ver_comment</td></tr>';
    DoBeginWork(FALSE, so_OutputVersions, VExclusivelyLocked);
    try
      if (FVersionList.Count>0) then
      for i := 0 to FVersionList.Count - 1 do begin
        pVer := FVersionList.GetItemByIndex(i);
        if (pVer<>nil) then begin
          AResponseText := AResponseText +
                     '<tr><td>'+IntToStr(pVer^.id_ver)+
                     '</td><td>'+pVer^.ver_value+
                     '</td><td>'+FormatDateTime(c_DateTimeToListOfVersions, pVer^.ver_date)+
                     '</td><td>'+IntToStr(pVer^.ver_number)+
                     '</td><td>'+pVer^.ver_comment+'</td></tr>';
        end;
      end;
    finally
      DoEndWork(VExclusivelyLocked);
    end;

    AResponseText := AResponseText + '</table>';
  end;

  function _AllowSavePassword: Boolean;
  begin
    // TODO: параметр важен на каждой секции
    Result := (nil <> VConnectionForOptions) and (VConnectionForOptions.AllowSavePassword);
  end;

  function _AddHtmlLabelCheckbox(const ANameId, ALabelText: String; const AChecked: Boolean): String;
  begin
    if AChecked then
      Result := 'checked="checked" '
    else
      Result := '';
    Result := '<label><input type="checkbox" name="' + ANameId + '" id="' + ANameId + '" value="1" ' + Result + '/>' + ALabelText + '</label>';
  end;

  function _CalcSQLTileFromForm(const AForm: TStrings): String;
  var
    VRes: Byte;
    VZoom: Integer;
    VRetConnection: IDBMS_Connection;
    VXYZ: TTILE_ID_XYZ;
    VSQLTile: TSQLTile;
  begin
    if TryStrToInt(AForm.Values[c_CalcTableCoord_Z], VZoom) and
       (VZoom>0) and (VZoom<=26) and
       TryStrToInt(AForm.Values[c_CalcTableCoord_X], VXYZ.xy.X) and
       TryStrToInt(AForm.Values[c_CalcTableCoord_Y], VXYZ.xy.Y) then begin
      // целые значения - можно работать
      VXYZ.z := VZoom;
      VRes := InternalCalcSQLTile(@VXYZ, @VSQLTile, FALSE, VRetConnection);
      // выводим результат
      if (VRes<>ETS_RESULT_OK) then begin
        // ошибка
        Result := 'Error: ' + IntToStr(VRes);
      end else begin
        // всё в порядке
        Result := 'Tile Table Name: ' + VSQLTile.UnquotedTileTableName + '<br>' +
                  'Upper to Table Name: (' + IntToStr(VSQLTile.XYUpperToTable.X) + ',' + IntToStr(VSQLTile.XYUpperToTable.Y) + ')' + '<br>' +
                  'Lower to Table Id: (' + IntToStr(VSQLTile.XYLowerToID.X) + ',' + IntToStr(VSQLTile.XYLowerToID.Y) + ')' + '<br>';

        if (VRetConnection<>GetGuidesConnection) then begin
          Result := Result + 'Use Secondary connection' + '<br>';
        end;
      end;
    end else begin
      Result := 'Incorrect input values';
    end;
    Result := '<br>' + Result;
  end;

  function _ParseFormValues(const ASourceText: String; out AResponse: String): Boolean;
  var
    p: Integer;
    VFormAction: String;
    VFormParams: TStringList;
    VGuidesConnection: IDBMS_Connection;
  begin
    p := System.Pos('?', ASourceText);
    Result := (p>0);
    if not Result then
      Exit;
    VFormAction := System.Copy(ASourceText, 1, (p-1));
    if SameText(c_EO_ApplyAuthOpt, VFormAction) then begin
      // ApplyAuthOpt - сохранение и применение логина и пароля

      // начало ответа
      AResponse := '<h1>Apply Authentication options</h1>';

      // тело ответа
      VFormParams:=TStringList.Create;
      try
        VFormParams.Delimiter := '&';
        VFormParams.DelimitedText := System.Copy(ASourceText, (p+1), Length(ASourceText));

        // тут распарсились параметры - применяем их
        // TODO: важно уметь это на каждой секции
        if (nil<>VConnectionForOptions) then begin
          VConnectionForOptions.ApplyCredentialsFormParams(VFormParams);

          // сброс ошибки подключения
          if (VFormParams.Values[c_Cred_ResetErr]='1') then begin
            DoResetConnectionError(VConnectionForOptions);
            AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE or ETS_EOO_NEED_REFRESH;
          end;

          AResponse := AResponse +
                   '<br>' +
                   'Done';
        end else begin
          // некуда их применить
          AResponse := AResponse +
                   '<br>' +
                   'No connection - nothing to apply';
        end;
      finally
        VFormParams.Free;
      end;

      // конец ответа
      AResponse := AResponse +
                   '<br>' +
                   _AddReturnFooter;
      // конец ApplyAuthOpt
    end else if SameText(c_EO_CalcTableCoord, VFormAction) then begin
      // CalcTableCoord - форма расчёта табличных координат по тайловым

      // начало ответа
      AResponse := '<h1>Calculate table coordinates</h1>';

      // тело ответа
      VFormParams:=TStringList.Create;
      try
        VFormParams.Delimiter := '&';
        VFormParams.DelimitedText := System.Copy(ASourceText, (p+1), Length(ASourceText));

        // пример:
        // z=16
        // &
        // x=123
        // &
        // y=32

        // (снова) рисуем форму
        AResponse := AResponse +
              '<br>' +
              '<form method="GET" name="form_calc_coord" action="' + VFullPrefix+'/'+c_EO_CalcTableCoord + '">' +
              '<table>' +
              '<tr><td>' +
              c_CalcTableCoord_Z +
              '<br>' +
              '<input type="text" id="' + c_CalcTableCoord_Z + '" name="' + c_CalcTableCoord_Z + '" value="' + VFormParams.Values[c_CalcTableCoord_Z] + '" size="30" />' +
              '</td></tr>' +
              '<tr><td>' +
              c_CalcTableCoord_X +
              '<br>' +
              '<input type="text" id="' + c_CalcTableCoord_X + '" name="' + c_CalcTableCoord_X + '" value="' + VFormParams.Values[c_CalcTableCoord_X] + '"  size="30" />' +
              '</td></tr>' +
              '<tr><td>' +
              c_CalcTableCoord_Y +
              '<br>' +
              '<input type="text" id="' + c_CalcTableCoord_Y + '" name="' + c_CalcTableCoord_Y + '" value="' + VFormParams.Values[c_CalcTableCoord_Y] + '"  size="30" />' +
              '</td></tr>' +
              '<tr><td>' +
              '<input type="submit" class="button" value="Calc" />' +
              '</td></tr>' +
              '</table>' +
              '</form>';

        // а тут результат для текущих значений
        AResponse := AResponse + _CalcSQLTileFromForm(VFormParams);
      finally
        VFormParams.Free;
      end;

      AResponse := AResponse + '<br>' + _AddReturnFooter;
      // конец CalcTableCoord
    end else if SameText(c_EO_ExecMakeVer, VFormAction) then begin
      // ExecMakeVer - создание версии по параметрам

      // начало ответа
      AResponse := '<h1>Make Version</h1>';

      // тело ответа
      VFormParams:=TStringList.Create;
      try
        VFormParams.Delimiter := '&';
        VFormParams.DelimitedText := System.Copy(ASourceText, (p+1), Length(ASourceText));

        // пример:
        // ver_value=ae1371a7a7ae56e357643268c9d05f05
        // &
        // ver_date=2011-05-13+08%3A02%3A41.000
        // &
        // ver_number=358588961
        // &
        // ver_comment=Panchromatic%2C0.50%2Ccountry_coverage%2CWV01%2CDigitalGlobe

        // тут распарсились параметры - применяем их
        VGuidesConnection := GetGuidesConnection;
        if (nil<>VGuidesConnection) then begin
          p := MakeVersionByFormParams(VGuidesConnection, VFormParams);
          if (ETS_RESULT_OK = LoByte(p)) then
            VFormAction := 'Done'
          else if (ETS_RESULT_SKIP_EXISTING = LoByte(p)) then
            VFormAction := 'Existing Version remains unmodified'
          else if (ETS_RESULT_DEFAULT_UNCHANGEABLE = LoByte(p)) then
            VFormAction := 'Failed: cannot change default Version'
          else
            VFormAction := 'Failed: error = ' + IntToStr(LoByte(p));

          AResponse := AResponse +
                   '<br>' +
                   VFormAction;
        end else begin
          // некуда их применить
          AResponse := AResponse +
                   '<br>' +
                   'No connection - nothing to make';
        end;
      finally
        VFormParams.Free;
      end;

      // конец ответа
      AResponse := AResponse +
                   '<br>' +
                   '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetVersions+'">Show list of Versions</a>' +
                   '<br>' +
                   _AddReturnFooter;
      // конец ExecMakeVer
    end else begin
      // фигню подсунули
      Result := FALSE;
    end;
  end;

  function _GetUrlForRequestType(const ASourceText: String; out AResponse: String): Byte;
  var
    VParsedVersion: TVersionAA;
  begin
    case AExecOptionIn^.dwRequestType of
      1: begin
        // надо вернуть ПОЛНЫЙ урл для создания версии
        FLastMakeVersionSource := ASourceText;
        AResponse := VFullPrefix+'/'+c_EO_MakeVersion;
        Result := ETS_RESULT_OK;
      end;
      2: begin
        // парсим запрос и возвращаем версию (уникальное строковое значение)
        Result := ParseVersionSource(ASourceText, @VParsedVersion);
        if (ETS_RESULT_OK = Result) then begin
          AResponse := VParsedVersion.ver_value;
          if not FVersionList.FindItemByVersion(AResponse, nil) then
            Result := ETS_RESULT_UNKNOWN_VERSION;
        end;
      end;
      else begin
        AResponse := '';
        Result := ETS_RESULT_NOT_IMPLEMENTED;
      end;
    end;
  end;

  function _AddFormWithPreparedMakeVersion(const AMakeVersionSrc: String): String;
  var
    VExistingVersion, VParsedVersion: TVersionAA;
    VVersionFound: Boolean;
  begin
    ParseMakeVersionSource(GetGuidesConnection, AMakeVersionSrc, @VExistingVersion, @VParsedVersion, VVersionFound);
    
    Result := '<br>' +
              '<form method="GET" name="form_make_ver" action="' + VFullPrefix+'/'+c_EO_ExecMakeVer + '">' +
              'Parsed parameters to Make Version (allow to change):' +
              '<table>' +
              '<tr><td>' +
              c_MkVer_Value +
              '<br>' +
              '<input type="text" id="' + c_MkVer_Value + '" name="' + c_MkVer_Value + '" value="' + VParsedVersion.ver_value + '" size="60" />' +
              '</td></tr>' +
              '<tr><td>' +
              c_MkVer_Date +
              '<br>' +
              '<input type="text" id="' + c_MkVer_Date + '" name="' + c_MkVer_Date + '" value="' + SQLDateTimeToVersionValue(VParsedVersion.ver_date) + '"  size="30" />' +
              '</td></tr>' +
              '<tr><td>' +
              c_MkVer_Number +
              '<br>' +
              '<input type="text" id="' + c_MkVer_Number + '" name="' + c_MkVer_Number + '" value="' + IntToStr(VParsedVersion.ver_number) + '" />' +
              '</td></tr>' +
              '<tr><td>' +
              c_MkVer_Comment +
              '<br>' +
              '<input type="text" id="' + c_MkVer_Comment + '" name="' + c_MkVer_Comment + '" value="' + VParsedVersion.ver_comment + '" size="160" />' +
              '</td></tr>' +
              '<tr><td>' +
              _AddHtmlLabelCheckbox(c_MkVer_SwitchToVer, 'Switch to this Version (note that downloads switch to this version too!)', VVersionFound) +
              '</td></tr>';

    if VVersionFound then
      Result := Result +
              '<tr><td>' +
              _AddHtmlLabelCheckbox(c_MkVer_UpdOld, 'Update existing version', FALSE) +
              '</td></tr>';
              
    Result := Result +
              '<tr><td>' +
              '<input type="submit" class="button" value="Make" />' +
              '</td></tr>' +
              '</table>' +
              '</form>';
  end;

var
  VValueW: WideString;
  VRequest: String;
  VResponse: String;
  VSetTLMValue: String;
  VSetTLMIndex: Integer;
begin
  Result := ETS_RESULT_OK;
  VResponse := '';

  // по умолчанию опции работают по подключению для справочников
  VConnectionForOptions := GetGuidesConnection;
  
  // get input values
  VRequest := '';
  if ((AExecOptionIn^.dwOptionsIn and ETS_EOI_ANSI_VALUES) <> 0) then begin
    VFullPrefix := PAnsiChar(AExecOptionIn^.szFullPrefix);
    if (AExecOptionIn^.szRequest<>nil) then begin
      VRequest    := PAnsiChar(AExecOptionIn^.szRequest);
    end;
  end else begin
    VValueW     := PWideChar(AExecOptionIn^.szFullPrefix);
    VFullPrefix := VValueW;
    if (AExecOptionIn^.szRequest<>nil) then begin
      VValueW     := PWideChar(AExecOptionIn^.szRequest);
      VRequest    := VValueW;
    end;
  end;

  try
    if ((AExecOptionIn^.dwOptionsIn and ETS_EOI_REQUEST_TYPE) <> 0) then begin
      // special mode to get URLs
      Result := _GetUrlForRequestType(VRequest, VResponse);
      Exit;
    end;

    _TrimLeftDelims(VRequest);
    
    if (0=Length(VRequest)) then begin
      // get information for empty request

      VResponse := '<h1>Options</h1>';

      if not _AddPreamble(VResponse) then
        Exit;
      
      // show version compare information
      
      VResponse := VResponse +
                   '<br>' +
                   'How to compare versions' + '<br>' +
                   '<table><tr><td>None</td><td>By ID</td><td>By Value</td><td>By Date</td><td>By Number</td></tr><tr><td>';

      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_NONE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_ID);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_VALUE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_DATE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_NUMBER);

      VResponse := VResponse + '</td></tr></table>';

      // show tile_load_mode parsed information
      VResponse := VResponse +
                   '<br>' +
                   _AddTable3ColHeader('What to do if tile not found');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_WITHOUT_VERSION, 'Show tile without version if no tile for request with version');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_PREV_VERSION,    'Show tile with prevoius version if no tile for request with version');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_LAST_VERSION,    'Show tile with last version if no tile for request without version');
      VResponse := VResponse + '</table>';


      // show tile_save_mode parsed information
      VResponse := VResponse +
                   '<br>' +
                   _AddTable3ColHeader('Storage can parse saving tile to obtain its version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_EMPTY,   'Allow to parse tile without version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_UNKNOWN, 'Allow to parse tile with unknown version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_KNOWN,   'Allow to parse tile with known version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_ALLOW_NO_EXIF, 'Can save tile without version for parser (for another zoom generation)');
      VResponse := VResponse + '</table>';

      // VER_by_TILE algorithm
      VResponse := VResponse +
                   '<br>' +
                   'Select algorithm to use by tile parser' + '<br>' +
                   '<table><tr><td>Algorithm</td><td>State</td></tr>';

      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_None,            'None');
      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_NMC_Unique, 'NMC by unique TileIdentifier');
      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_NMC_Latest, 'NMC by latest AcquisitionDate');
      //VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_DG_Catalog, 'DG Catalog mode');

      VResponse := VResponse + '</table>';


      // show list of versions
      VResponse := VResponse + '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetVersions+'">Show list of Versions</a>';

      // форма для расчёта табличных координат по тайловым
      VResponse := VResponse + '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_CalcTableCoord+'?">Calculate table coordinates</a>';

      // unknown exceptions
      if HasUnknownExceptions then begin
        // has items - add link to show
        VResponse := VResponse + '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetUnknErrors+'">Show Errors</a>';
      end;

      Exit;
    end;

    // parse as form values
    if _ParseFormValues(VRequest, VResponse) then
      Exit;

    // extract first command
    VSetTLMValue := _ExtractPart(VRequest);

    if SameText(c_EO_SetTLM, VSetTLMValue) then begin
      // SetTLM
      // remains: 3 chars like '4/1' or '2/0'
      // ignore others
      if (3<=Length(VRequest)) then
      if TryStrToInt(VRequest[1], VSetTLMIndex) then
      if LoByte(VSetTLMIndex) in [ETS_TLM_WITHOUT_VERSION, ETS_TLM_PREV_VERSION, ETS_TLM_LAST_VERSION] then begin
        // ok
        // если 3-й символ равен 1 - включаем, иначе выключаем
        Result := UpdateTileLoadMode(GetGuidesConnection, LoByte(VSetTLMIndex), (VRequest[3]='1'), VSetTLMValue);
        // check
        if (ETS_RESULT_OK=Result) then begin
          // success
          if (VRequest[3]='1') then
            VResponse := 'Enabled'
          else
            VResponse := 'Disabled';

          if (0<Length(VSetTLMValue)) then begin
            VResponse := VResponse + '<br>' + VSetTLMValue;
          end;

          VResponse := VResponse + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;

        AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE or ETS_EOO_NEED_REFRESH;
      end;
    end else if SameText(c_EO_SetTSM, VSetTLMValue) then begin
      // SetTSM
      // remains: 3-4 chars like '4/1' or '8/0' or '16/1'
      // ignore others
      if (3<=Length(VRequest)) then
      if TryStrToInt(Copy(VRequest,1,Length(VRequest)-2), VSetTLMIndex) then
      if LoByte(VSetTLMIndex) in [ETS_TSM_PARSE_EMPTY, ETS_TSM_PARSE_UNKNOWN, ETS_TSM_PARSE_KNOWN,ETS_TSM_ALLOW_NO_EXIF] then begin
        // ok
        // если 3-й символ равен 1 - включаем, иначе выключаем
        Result := UpdateTileSaveMode(GetGuidesConnection, LoByte(VSetTLMIndex), (VRequest[Length(VRequest)]='1'), VSetTLMValue);
        // check
        if (ETS_RESULT_OK=Result) then begin
          // success
          if (VRequest[Length(VRequest)]='1') then
            VResponse := 'Enabled'
          else
            VResponse := 'Disabled';

          if (0<Length(VSetTLMValue)) then begin
            VResponse := VResponse + '<br>' + VSetTLMValue;
          end;

          VResponse := VResponse + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;
        // здесь не надо сбрасывать кэш в памяти
      end;
    end else if SameText(c_EO_SetVerByTile, VSetTLMValue) then begin
      // SetVerByTile
      // remains: Smallint
      if TryStrToInt(VRequest, VSetTLMIndex) then
      if Abs(VSetTLMIndex)<=32767 then begin
        // ok
        Result := UpdateVerByTileMode(GetGuidesConnection, VSetTLMIndex, VSetTLMValue);
        // check result
        if (ETS_RESULT_OK=Result) then begin
          // success
          VResponse := 'Updated successfully' + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;
        // здесь не надо сбрасывать кэш в памяти
      end;
    end else if SameText(c_EO_SetVerComp, VSetTLMValue) then begin
      // SetVerComp
      // remains: ONE char
      if (1<=Length(VRequest)) then
      case VRequest[1] of
        TILE_VERSION_COMPARE_NONE,
        TILE_VERSION_COMPARE_ID,
        TILE_VERSION_COMPARE_VALUE,
        TILE_VERSION_COMPARE_DATE,
        TILE_VERSION_COMPARE_NUMBER: begin
          // ok
          Result := UpdateServiceVerComp(GetGuidesConnection, VRequest[1], VSetTLMValue);
          // check result
          if (ETS_RESULT_OK=Result) then begin
            // success
            VResponse := 'Updated successfully' + '<br>' + _AddReturnFooter;
            AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE or ETS_EOO_NEED_REFRESH;
          end else begin
            // failed
            VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
          end;
        end;
      end;
    end else if SameText(c_EO_SetAuthOpt, VSetTLMValue) then begin
      // SetAuthOpt
      // show form to enter values
      VResponse := '<h1>Authentication options</h1>' +
                   '<br>' +
                   'Credentials' +
                   '<br>' +
                   '<form method="GET" name="form_set_auth" action="' + VFullPrefix+'/'+c_EO_ApplyAuthOpt + '">' +
                   '<table>' +
                   '<tr><td>' +
                   'UserName' +
                   '<br>' +
                   '<input type="text" id="' + c_Cred_UserName + '" name="' + c_Cred_UserName + '" value="" />' +
                   '</td></tr>' +
                   '<tr><td>' +
                   'Authentication' +
                   '<br>' +
                   '<input type="password" id="' + c_Cred_Password + '" name="' + c_Cred_Password + '" />' +
                   '</td></tr>';

      if _AllowSavePassword then
        VResponse := VResponse +
                   '<tr><td>' +
                   _AddHtmlLabelCheckbox(c_Cred_SaveAuth, 'Save', TRUE) +
                   '</td></tr>';
                   
      VResponse := VResponse +
                   '<tr><td>' +
                   _AddHtmlLabelCheckbox(c_Cred_ResetErr, 'Reset connection information', TRUE) +
                   '</td></tr>' +
                   '<tr><td>' +
                   '<input type="submit" class="button" value="Apply" />' +
                   '</td></tr>' +
                   '</table>' +
                   '</form>';
      // последнее
      VResponse := VResponse +
                   '<br>' +
                   _AddReturnFooter;
    end else if SameText(c_EO_ResetConnError, VSetTLMValue) then begin
      // ResetConnError
      VResponse := '<h1>Reset connection information</h1>';
      if (VConnectionForOptions=nil) then begin
        // nothing to reset
        VResponse := VResponse +
                   '<br>' +
                   'No connection - nothing to reset';
      end else begin
        // can reset
        DoResetConnectionError(VConnectionForOptions);
        AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE or ETS_EOO_NEED_REFRESH;

        VResponse := VResponse +
                   '<br>' +
                   'Done';
      end;

      // последнее
      VResponse := VResponse +
                   '<br>' +
                   _AddReturnFooter;
    end else if SameText(c_EO_GetUnknErrors, VSetTLMValue) then begin
      // GetUnknErrors
      // show all collected unknown errors
      if SameText(VRequest, c_EO_ClearErrors) then begin
        ClearUnknownExceptions;
      end;

      VResponse := '<h1>Errors</h1>';

      VSetTLMValue := GetUnknownExceptions;

      if (0<Length(VSetTLMValue)) then begin
        // add clear link
        VResponse := VResponse +
                   '<br>' +
                   'Click <a href="'+VFullPrefix+'/'+c_EO_GetUnknErrors+'/'+c_EO_ClearErrors+'">HERE</a> to clear Errors';

        VResponse := VResponse +
                   '<br>' +
                   '<br>' +
                   'List of Errors:' +
                   '<br>' +
                   '<br>' +
                   VSetTLMValue;
      end else begin
        VResponse := VResponse +
                   '<br>' +
                   'No Errors';
      end;


      VResponse := VResponse + '<br>' + _AddReturnFooter;

    end else if SameText(c_EO_MakeVersion, VSetTLMValue) then begin
      // MakeVersion
      if (0=Length(VRequest)) then begin
        // get stored version
        VRequest := FLastMakeVersionSource;
      end;

      VResponse := '<h1>Make Version</h1>';

      if not _AddPreamble(VResponse) then
        Exit;

      if (0<Length(VRequest)) then begin
        // можно пытаться создавать версию
        VResponse := VResponse +
                   '<br>' +
                   'Original source to Make Version:' +
                   '<br>' +
                   VRequest +
                   '<br>' +
                   _AddFormWithPreparedMakeVersion(VRequest);
      end else begin
        // нечего создавать - нет данных
        VResponse := VResponse +
                   '<br>' +
                   'No Data';
      end;

      // show list of versions and back to options
      VResponse := VResponse +
                   '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetVersions+'">Show list of Versions</a>' +
                   '<br>' +
                    _AddReturnFooter;

      // end of MakeVersion
    end else if SameText(c_EO_GetVersions, VSetTLMValue) then begin
      // GetVersions
      // enumerate all versions and show
      if SameText(VRequest, c_EO_ReloadVersions) then begin
        _ReloadVersions;
      end;

      VResponse := '<h1>Versions</h1>';

      if not _AddPreamble(VResponse) then
        Exit;

      VResponse := VResponse +
                   '<br>' +
                   'Total count = ' + IntToStr(FVersionList.Count);

      if vf_EmptyVersion in FVersionList.VersionFlags then begin
        VResponse := VResponse +
                   '<br>' +
                   'Empty version has id_ver = ' + IntToStr(FVersionList.EmptyVersionIdVer);
      end;

      if (FVersionList.Count>0) then begin
        _AddListOfVersions(VResponse);
      end;

      // add reload link
      VResponse := VResponse +
                   '<br>' +
                   'Click <a href="'+VFullPrefix+'/'+c_EO_GetVersions+'/'+c_EO_ReloadVersions+'">HERE</a> to reload Versions from DB';

      VResponse := VResponse + '<br>' + _AddReturnFooter;
    end;

  finally
    if (0<Length(VResponse)) then begin
      // allocate memory and copy response
      VSetTLMIndex := (Length(VResponse)+1)*SizeOf(Char);
      AExecOptionIn.szResponse := GetMemory(VSetTLMIndex);
      CopyMemory(AExecOptionIn.szResponse, PChar(VResponse), VSetTLMIndex);
      if SizeOf(Char)=SizeOf(AnsiChar) then begin
        AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_ANSI_VALUES;
      end;
    end;
  end;
end;

function TDBMS_Provider.DBMS_GetTileRectInfo(
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte;
var
  VExclusive: Boolean;
  VOdbcFetchColsEx: TOdbcFetchCols12;
  VColIndex: SmallInt;
  VEnumOut: TETS_GET_TILE_RECT_OUT;
  VExclusivelyLocked: Boolean;
  VSelectInRectList: TSelectInRectList;
  VSelectInRectItem: PSelectInRectItem;
  i: Integer;
  // здесь подключение фиктивно, так как могут вернуться данных из некольких секций
  VConnectionDummy: IDBMS_Connection;
begin
  VExclusive := ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_SelectInRect, VExclusivelyLocked);
  try
    // connect (if not connected)
    // здесь нельзя заранее выбрать одно подключение, так как граница области может пересечь несколько секций
    // так что вернётся первичное
    Result := InternalProv_Connect(VExclusive, nil, FALSE, nil, VConnectionDummy);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    FillChar(VEnumOut, SizeOf(VEnumOut), 0);
      
    // при построении карты заполнения, если включено деление на таблицы, может использоваться несколько запросов
    // поэтому сначала сгенерим все необходимые запросы, а потом будем их выполнять по очереди
    VSelectInRectList := TSelectInRectList.Create;
    try
      // генеримся
      Result := GetSQL_GetTileRectInfo(ATileRectInfoIn, VExclusive, VSelectInRectList);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // общее число записей здесь не должно зависеть от способа разбиения на таблицы
      // следовательно в общем случае здесь оно недоступно
      // VEnumOut.ResponseCount := -1;

      // так как версия всегда только запрошенная - здесь не надо искать вытащенную из БД версию
      //VEnumOut.TileInfo.szVersionOut := nil;
      // тело тайла здесь не возвращаем
      //VEnumOut.TileInfo.ptTileBuffer := nil;
      // TODO: content-type вроде бы может быть кому-то будет интересен
      //VEnumOut.TileInfo.szContentTypeOut := nil;

      // по очереди на выход
      if VSelectInRectList.Count>0 then begin
        VOdbcFetchColsEx.Init;
        try
          // для каждой интересующей нас таблички
          for i := 0 to VSelectInRectList.Count-1 do begin
            // рабочая структура
            VSelectInRectItem := VSelectInRectList.SelectInRectItems[i];

            // для выхода из обоих циклов по ошибке из хоста инициализируем результат
            Result:=ETS_RESULT_OK;

            // открываемся
            try
              VOdbcFetchColsEx.Base.Close;
              VSelectInRectItem^.UsedConnection.OpenDirectSQLFetchCols(VSelectInRectItem^.FullSqlText, @(VOdbcFetchColsEx.Base));
            except
              // нет таблицы - нет данных - молча пропускаем
            end;

            if VOdbcFetchColsEx.Base.IsActive then begin
              // что-то открылось - перечислим это в хост
              while (VOdbcFetchColsEx.Base.FetchRecord) do begin
                // заполняем параметры
                VEnumOut.TileInfo.dwOptionsOut := ETS_ROO_SAME_VERSION;

                // заполняем TilePos тайловыми координатами тайла
                FDBMS_Service_Info.CalcBackToTilePos(
                  VOdbcFetchColsEx.Base.GetOptionalLongInt('x'),
                  VOdbcFetchColsEx.Base.GetOptionalLongInt('y'),
                  VSelectInRectItem.TabSQLTile.XYUpperToTable,
                  @(VEnumOut.TilePos)
                );

                // заполняем данные о тайле
                VColIndex := VOdbcFetchColsEx.Base.ColIndex('load_date');
                VOdbcFetchColsEx.Base.ColToDateTime(VColIndex, VEnumOut.TileInfo.dtLoadedUTC);
                VColIndex := VOdbcFetchColsEx.Base.ColIndex('tile_size');
                VOdbcFetchColsEx.Base.ColToLongInt(VColIndex, VEnumOut.TileInfo.dwTileSize);

                // check if tile of tne
                if (VEnumOut.TileInfo.dwTileSize<=0) then begin
                  // tne
                  VEnumOut.TileInfo.dwOptionsOut := VEnumOut.TileInfo.dwOptionsOut or ETS_ROO_TNE_EXISTS;
                end else begin
                  // tile
                  VEnumOut.TileInfo.dwOptionsOut := VEnumOut.TileInfo.dwOptionsOut or ETS_ROO_TILE_EXISTS;
                end;

                // зовём хост
                Result := TETS_GetTileRectInfo_Callback(FHostCallbacks[ETS_INFOCLASS_GetTileRectInfo_Callback])(
                  FHostPointer,
                  ACallbackPointer,
                  ATileRectInfoIn,
                  @VEnumOut
                );

                // тут должны выйти из обоих циклов: и из while, и из for
                if (Result<>ETS_RESULT_OK) then
                  break;

              end;

            end;

            // тут должны выйти из обоих циклов: и из while, и из for
            if (Result<>ETS_RESULT_OK) then
              break;
          end; // for

        finally
          VOdbcFetchColsEx.Base.Close;
        end;
      end;

    finally
      FreeAndNil(VSelectInRectList);
    end;

  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_InsertTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean
): Byte;
var
  VExclusive: Boolean;
  VInsertSQL, VUpdateSQL: TDBMS_String;
  VUnquotedTableNameWithoutPrefix: TDBMS_String;
  VQuotedTableNameWithPrefix: TDBMS_String;
  VStatementRepeatType: TStatementRepeatType;
  VInsertUpdateSubType: TInsertUpdateSubType;
  //VCastBodyAsHexLiteral: Boolean;
  //VBodyAsLiteralValue: TDBMS_String;
  VExecuteWithBlob: Boolean;
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
  VSQLTile: TSQLTile;
  VConnectionForInsert: IDBMS_Connection;
  VUpsert: Boolean;
begin
  VExclusive := ((AInsertBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Insert, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive, AInsertBuffer^.XYZ, TRUE, @VSQLTile, VConnectionForInsert);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - INSERT tile to DB
      VStatementRepeatType := srt_None;
      
      // получим выражения INSERT и UPDATE
      // если используется UPSERT - текст залетает в INSERT, а UPDATE пустой
      Result := GetSQL_InsertUpdateTile(
        VConnectionForInsert,
        @VSQLTile,
        AInsertBuffer,
        AForceTNE,
        VExclusive,
        VInsertSQL,
        VUpdateSQL,
        VInsertUpdateSubType,
        VUpsert,
        VUnquotedTableNameWithoutPrefix,
        VQuotedTableNameWithPrefix
      );
      if (ETS_RESULT_OK<>Result) then
        Exit;

      (*
      if (iust_TILE=VInsertUpdateSubType) then begin
        // тело тайла есть в запросе
{$if defined(ETS_USE_DBX)}
        // только для DBX
        VCastBodyAsHexLiteral := c_DBX_CastBlobToHexLiteral[FConnection.GetCheckedEngineType];
        if VCastBodyAsHexLiteral then
          VBodyAsLiteralValue := ConvertTileToHexLiteralValue(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize)
        else
          VBodyAsLiteralValue := '';
{$else}
        VCastBodyAsHexLiteral := FALSE;
        VBodyAsLiteralValue := '';
{$ifend}
      end else begin
        // тело тайла вообще отсутствует в запросе
        VCastBodyAsHexLiteral := FALSE;
        VBodyAsLiteralValue := '';
      end;
      *)

      // запрос с передачей BLOBа или нет
      VExecuteWithBlob := (iust_TILE=VInsertUpdateSubType) {and (not VCastBodyAsHexLiteral)};

      // выполним INSERT
      VStatementExceptionType := set_Success;
      try
        // может BLOB надо писать как 16-ричный литерал
        {
        if VCastBodyAsHexLiteral then begin
          VInsertSQL := StringReplace(VInsertSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
        end;
        }

        if VExecuteWithBlob then begin
          // INSERT with BLOB
          VConnectionForInsert.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE);
        end else begin
          // INSERT without BLOB
          VConnectionForInsert.ExecuteDirectSQL(VInsertSQL, FALSE);
        end;
        
        // готово (вставлено!)
        Result := ETS_RESULT_OK;
      except on E: Exception do
        // обломались со вставкой новой записи
        VStatementExceptionType := GetStatementExceptionType(VConnectionForInsert, E);
      end;

      if StandardExceptionType(VStatementExceptionType, FALSE, Result) then begin
        // предопределённые известные критичные ошибки
        Exit;
      end;

      case VStatementExceptionType of
        set_Success: begin
          // пусто
        end;
        set_TableNotFound: begin
          // нет таблицы в БД
          if (not VExclusive) then begin
            // таблицы создаём только в эксклюзивном режиме
            Result := ETS_RESULT_NEED_EXCLUSIVE;
            Exit;
          end;

          // пробуем создать таблицу по шаблону
          CreateTableByTemplate(
            VConnectionForInsert,
            c_Templated_RealTiles,
            VUnquotedTableNameWithoutPrefix,
            VQuotedTableNameWithPrefix,
            AInsertBuffer^.XYZ.z,
            TRUE
          );

          // проверяем существование таблицы
          if (not VConnectionForInsert.TableExistsDirect(VQuotedTableNameWithPrefix)) then begin
            // не удалось даже создать - валим
            Result := ETS_RESULT_TILE_TABLE_NOT_FOUND;
            Exit;
          end;

          // повторяем INSERT для только что созданной таблицы
          VStatementRepeatType := srt_Insert;
        end;
        set_PrimaryKeyViolation: begin
          // нарушение уникальности по первичному ключу - надо обновляться
          if VUpsert then begin
            // при upsert такого быть не должно
            Result := ETS_RESULT_INVALID_STRUCTURE;
            Exit;
          end else begin
            VStatementRepeatType := srt_Update;
          end;
        end;
      end;

      // пробуем выполнить INSERT или UPDATE повторно
      while (VStatementRepeatType <> srt_None) do begin
        // подправим литерал для UPDATE как ранее для INSERT
        // после того как обломается UPDATE - уже никогда не выполняем INSERT
        // значит можно просто копировать текст SQL-я из UPDATE в INSERT
        // и пользоваться только одним буфером
        if (VStatementRepeatType = srt_Update) then begin
          {
          if VCastBodyAsHexLiteral then begin
            VUpdateSQL := StringReplace(VUpdateSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
          end;
          }
          VInsertSQL := VUpdateSQL;
        end;

        VStatementExceptionType := set_Success;
        try
          // здесь в VInsertSQL может быть и текст для UPDATE
          if VExecuteWithBlob then begin
            // UPDATE with BLOB
            VConnectionForInsert.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE);
          end else begin
            // UPDATE without BLOB
            VConnectionForInsert.ExecuteDirectSQL(VInsertSQL, FALSE);
          end;

          // однако повторно получилось успешно
          VStatementRepeatType := srt_None;
          Result := ETS_RESULT_OK;
        except on E: Exception do
          // смотрим что за ошибка
          VStatementExceptionType := GetStatementExceptionType(VConnectionForInsert, E);
        end;

        if StandardExceptionType(VStatementExceptionType, FALSE, Result) then begin
          // предопределённые известные критичные ошибки
          Exit;
        end;

        case VStatementExceptionType of
          set_Success: begin
            Result := ETS_RESULT_OK;
            Exit;
          end;
          set_TableNotFound: begin
            // таблицы так и нет - возможно нет линкуемой таблицы, а не основной
            Result := ETS_RESULT_INVALID_STRUCTURE;
            Exit;
          end;
          set_PrimaryKeyViolation: begin
            // если при INSERT - уйдём на новый виток - на этот раз UPDATE
            // если при UPDATE - уйдём в слезах рекаверить датабазу из обломков былой роскоши
            if (VStatementRepeatType=srt_Update) then begin
              Result := ETS_RESULT_INVALID_STRUCTURE;
              Exit;
            end else begin
              // будем исполнять update
              // однако для upsert на update не ходим, а валим
              if VUpsert then begin
                Result := ETS_RESULT_INVALID_STRUCTURE;
                Exit;
              end else begin
                VStatementRepeatType := srt_Update;
              end;
            end;
          end;
        end; // of case
      end; // of while
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_MakeTileEnum(
  const AEnumTilesHandle: PETS_EnumTiles_Handle;
  const AFlags: LongWord;
  const AHostPointer: Pointer
): Byte;
var
  VExclusivelyLocked: Boolean;
  VUseSingleSection: Boolean;
  VConnectionForEnum: IDBMS_Connection;
begin
  // проверим наличие функции обратного вызова
  if (nil = FHostCallbacks[ETS_INFOCLASS_NextTileEnum_Callback]) then begin
    Result := ETS_RESULT_INVALID_CALLBACK_PTR;
    Exit;
  end;

  // создание перечислителя выполняем всегда эксклюзивно
  DoBeginWork(TRUE, so_EnumTiles, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(TRUE, nil, TRUE, nil, VConnectionForEnum);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // типа подключились - смотрим настройки секционирования
    // надо ли ходить по всем секциям, или можно по одной
    VUseSingleSection := FPrimaryConnnection.FTSS_Primary_Params.UseSingleConn(FALSE);

    if (not VUseSingleSection) then begin
      // так как надо пройти по всем секциям (подключениям) - пойдём с самого начала
      VConnectionForEnum := FPrimaryConnnection;
    end;

    // можно создавать перечислитель, так как всё остальное он сделает внутри
    PStub_DBMS_TileEnum(AEnumTilesHandle)^.TileEnum := TDBMS_TileEnum.Create(
      Self,
      @(Self.FDBMS_Service_Info),
      Self.FVersionList,
      Self.FContentTypeList,
      FStatusBuffer,
      AFlags,
      AHostPointer,
      FHostCallbacks[ETS_INFOCLASS_NextTileEnum_Callback],
      VConnectionForEnum,
      VUseSingleSection
    );

    // готово
    Result := ETS_RESULT_OK;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_SelectTile(
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte;
var
  VExclusive: Boolean;
  VOdbcFetchColsEx: TOdbcFetchCols10;
  VColIndex: SmallInt;
  VOut: TETS_SELECT_TILE_OUT;
  Vid_ver, Vid_contenttype: SmallInt;
  VSQLText: TDBMS_String;
  VVersionW, VContentTypeW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
  VSQLTile: TSQLTile;
  VConnectionForSelect: IDBMS_Connection;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Select, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive, ASelectBufferIn^.XYZ, FALSE, @VSQLTile, VConnectionForSelect);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // забацаем полный текст SELECT
    Result := GetSQL_SelectTile(VConnectionForSelect, @VSQLTile, ASelectBufferIn, VExclusive, VSQLText);
    if (ETS_RESULT_OK<>Result) then
      Exit;

    FillChar(VOut, SizeOf(VOut), 0);

    VOdbcFetchColsEx.Init;
    try
      // open sql
      VStatementExceptionType := set_Success;
      try
        VConnectionForSelect.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));
      except on E: Exception do
        VStatementExceptionType := GetStatementExceptionType(VConnectionForSelect, E);
      end;

      if StandardExceptionType(VStatementExceptionType, FALSE, Result) then begin
        // предопределённые известные критичные ошибки
        Exit;
      end;

      case VStatementExceptionType of
        set_Success: begin
          // пусто
        end;
        set_TableNotFound: begin
          // нет таблицы - нет и тайлов
          Result := ETS_RESULT_OK;
          Exit;
        end;
        set_PrimaryKeyViolation: begin
          Result := ETS_RESULT_INVALID_STRUCTURE;
          Exit;
        end;
      end;

      // тащим значения
      
      if (not VOdbcFetchColsEx.Base.IsActive) then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
      if (not VOdbcFetchColsEx.Base.FetchRecord) then begin
        // не смогли фетчнуться - тайла нет
        Result := ETS_RESULT_OK;
        Exit;
      end;

      // берём только одну запись (из-за 'order by' другие не нужны)
      // TODO: пропихнуть признак в запрос и подставлять TOP 1 или аналог
      VColIndex := VOdbcFetchColsEx.Base.ColIndex('load_date');
      VOdbcFetchColsEx.Base.ColToDateTime(VColIndex, VOut.dtLoadedUTC);
      VColIndex := VOdbcFetchColsEx.Base.ColIndex('tile_size');
      VOdbcFetchColsEx.Base.ColToLongInt(VColIndex, VOut.dwTileSize);

      // определяем тайл это или TNE
      if (VOut.dwTileSize<=0) then begin
        // обнаружили маркер TNE
        VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TNE_EXISTS;
      end else begin
        // это тайл
        VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TILE_EXISTS;
        // вытащим тело
        VColIndex := VOdbcFetchColsEx.Base.ColIndex('tile_body');
        if (VColIndex<0) then
          VOut.ptTileBuffer := nil
        else
          VOut.ptTileBuffer := VOdbcFetchColsEx.Base.GetLOBBuffer(VColIndex);
      end;

      // версия
      VColIndex := VOdbcFetchColsEx.Base.ColIndex('id_ver');
      VOdbcFetchColsEx.Base.ColToSmallInt(VColIndex, Vid_ver);

      if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
        // as AnsiString
        VOut.szVersionOut := GetVersionAnsiPointer(GetGuidesConnection, Vid_ver, VExclusive);
      end else begin
        // as WideString
        VVersionW := GetVersionWideString(GetGuidesConnection, Vid_ver, VExclusive);
        VOut.szVersionOut := PWideChar(VVersionW);
      end;

      // contenttype
      VColIndex := VOdbcFetchColsEx.Base.ColIndex('id_contenttype');
      VOdbcFetchColsEx.Base.ColToSmallInt(VColIndex, Vid_contenttype);

      if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_OUT) <> 0) then begin
          // as AnsiString
          VOut.szContentTypeOut := GetContentTypeAnsiPointer(GetGuidesConnection, Vid_contenttype, VExclusive);
      end else begin
          // as WideString
          VContentTypeW := GetContentTypeWideString(GetGuidesConnection, Vid_contenttype, VExclusive);
          VOut.szContentTypeOut := PWideChar(VContentTypeW);
      end;

      // отдаёмся хосту
      Result := TETS_SelectTile_Callback(FHostCallbacks[ETS_INFOCLASS_SelectTile_Callback])(
          FHostPointer,
          ACallbackPointer,
          ASelectBufferIn,
          @VOut
      );
    finally
      VOdbcFetchColsEx.Base.Close;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_SetInformation(
  const AInfoClass: Byte;
  const AInfoSize: LongWord;
  const AInfoData: Pointer;
  const AInfoResult: PLongWord
): Byte;
begin
  if (ETS_INFOCLASS_SetStorageIdentifier=AInfoClass) then begin
    // set GlobalStorageIdentifier and ServiceName from PETS_SET_IDENTIFIER_INFO
    Result := InternalProv_SetStorageIdentifier(AInfoSize, PETS_SET_IDENTIFIER_INFO(AInfoData), AInfoResult);
    Exit;
  end;

  if (ETS_INFOCLASS_SetPrimaryContentType=AInfoClass) then begin
    // set primary ContentType
    if (AInfoSize=SizeOf(AnsiChar)) then begin
      // treat as PAnsiChar
      FPrimaryContentType := AnsiString(PAnsiChar(AInfoData));
      Result := ETS_RESULT_OK;
    end else if (AInfoSize=SizeOf(WideChar)) then begin
      // treat as PWideChar
      FPrimaryContentType := WideString(PWideChar(AInfoData));
      Result := ETS_RESULT_OK;
    end else begin
      // unknown
      Result := ETS_RESULT_INVALID_BUFFER_SIZE;
    end;
    Exit;
  end;

  if (TETS_INFOCLASS_Callbacks(AInfoClass)>=Low(TETS_INFOCLASS_Callbacks)) and (TETS_INFOCLASS_Callbacks(AInfoClass)<=High(TETS_INFOCLASS_Callbacks)) then begin
    // callbacks
    FHostCallbacks[TETS_INFOCLASS_Callbacks(AInfoClass)] := AInfoData;
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // unknown value
  Result := ETS_RESULT_UNKNOWN_INFOCLASS;
end;

destructor TDBMS_Provider.Destroy;
var
  VExclusivelyLocked: Boolean;
begin
  DoBeginWork(TRUE, so_Destroy, VExclusivelyLocked);
  try
    InternalProv_Disconnect;
  finally
    DoEndWork(VExclusivelyLocked);
  end;

  GuidesBeginWork(TRUE);
  try
    InternalProv_ClearGuides;
    FreeAndNil(FVersionList);
    FreeAndNil(FContentTypeList);
  finally
    GuidesEndWork(TRUE);
  end;

  FHostPointer := nil;
  FProvSync := nil;
  FGuidesSync := nil;

  FreeAndNil(FUnknownExceptions);
  FUnknownExceptionsCS := nil;

  inherited Destroy;
end;

procedure TDBMS_Provider.DoBeginWork(
  const AExclusively: Boolean;
  const AOperation: TSqlOperation;
  out AExclusivelyLocked: Boolean
);
begin
  AExclusivelyLocked := AExclusively OR
                        // TODO: надо что-то придумать с этим условием
                        // возможно ли его оформить более корректно
                        (FGuidesConnnection=nil) OR
                        (FGuidesConnnection.FullSyncronizeSQL);

  if AExclusivelyLocked then
    FProvSync.BeginWrite
  else
    FProvSync.BeginRead;
end;

procedure TDBMS_Provider.DoEndWork(const AExclusivelyLocked: Boolean);
begin
  if AExclusivelyLocked then
    FProvSync.EndWrite
  else
    FProvSync.EndRead;
end;

procedure TDBMS_Provider.DoOnDeadConnection(const ATilesConnection: IDBMS_Connection);
begin
  // взводим признак необходимости RECONNECT-а в эксклюзивном режиме
  ATilesConnection.NeedReconnect;

  // пропихнём признак в хост
  if (FStatusBuffer<>nil) then
  with (FStatusBuffer^) do begin
    if wSize>=SizeOf(FStatusBuffer^) then
      malfunction_mode := ETS_PMM_CONNECT_DEAD;
  end;
end;

procedure TDBMS_Provider.DoResetConnectionError(const ATilesConnection: IDBMS_Connection);
begin
  if (ATilesConnection<>nil) then begin
    ATilesConnection.ResetConnectionError;
  end;

  // пропихнём признак в хост
  // НО только если настройка хранилища завершена
  if FCompleted then
  if (FStatusBuffer<>nil) then
  with (FStatusBuffer^) do begin
    if wSize>=SizeOf(FStatusBuffer^) then
      malfunction_mode := ETS_PMM_HAS_COMPLETED;
  end;
end;

function TDBMS_Provider.FillTableNamesForTiles(
  ASQLTile: PSQLTile;
  const AAllowNewObjects: Boolean;
  var AResultConnection: IDBMS_Connection
): Boolean;
var
  VXYMaskWidth: Byte;
  VEngineType: TEngineType;
  VTablePosPtr: PPoint;
begin
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  // определяем здесь подключение ТОЛЬКО если работаем по табличым координатам
  // если работаем по тайловым - оно уже должно быть определено ранее
  if UseSectionByTableXY then begin
    VTablePosPtr := ASQLTile^.HXYToTableNamePos(VXYMaskWidth);

    if (nil=VTablePosPtr) then begin
      // не делимся - одна таблица - используем подключение для справочников
      AResultConnection := GetGuidesConnection;
    end else begin
      AResultConnection := ChooseConnection(ASQLTile^.Zoom, VTablePosPtr, AAllowNewObjects);
    end;
  end;

  ASQLTile^.UnquotedTileTableName := ASQLTile^.ZoomToTableNameChar(Result) +
                                     ASQLTile^.HXToTableNameChar(VXYMaskWidth) +
                                     FDBMS_Service_Info.id_div_mode +
                                     ASQLTile^.HYToTableNameChar(VXYMaskWidth) +
                                     '_' +
                                     InternalGetServiceNameByDB;

  VEngineType := AResultConnection.GetCheckedEngineType;

  // заквотируем или нет
  Result := Result or c_SQL_QuotedIdentifierForcedForTiles[VEngineType];
  if Result then begin
    ASQLTile^.QuotedTileTableName := c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] + ASQLTile^.UnquotedTileTableName + c_SQL_QuotedIdentifierValue[VEngineType, qp_After];
  end else begin
    ASQLTile^.QuotedTileTableName := ASQLTile^.UnquotedTileTableName;
  end;
end;

function TDBMS_Provider.GetContentTypeAnsiPointer(
  const AGuideConnection: IDBMS_Connection;
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(AGuideConnection, Aid_contenttype, AExclusively, @Result, VDummy) then
      Exit;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetContentTypeAnsiPointer(AGuideConnection, Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetContentTypeWideString(
  const AGuideConnection: IDBMS_Connection;
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VContentTypeTextStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(AGuideConnection, Aid_contenttype, AExclusively, nil, VContentTypeTextStr) then begin
      Result := VContentTypeTextStr;
      Exit;
    end;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetContentTypeWideString(AGuideConnection, Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetGuidesConnection: IDBMS_Connection;
begin
  Result := FGuidesConnnection
end;

function TDBMS_Provider.GetMaxNextVersionInts(
  const AGuideConnection: IDBMS_Connection;
  const ANewVersionPtr: PVersionAA;
  const AKeepVerNumber: Boolean
): Boolean;
var
  VOdbcFetchColsEx: TOdbcFetchCols2;
  VSQLText: TDBMS_String;
begin
  VOdbcFetchColsEx.Init;
  try
    // соберём запрос
    VSQLText := 'select max(id_ver) as id_ver';
    if (not AKeepVerNumber) then begin
      // для ver_number тоже потащим максимум
      VSQLText := VSQLText + ', max(ver_number) as ver_number';
    end;
    VSQLText := VSQLText + ' FROM ' + AGuideConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;

    // выполняем
    try
      Result := AGuideConnection.OpenDirectSQLFetchCols(VSQLText, @VOdbcFetchColsEx);
      if Result then
        Result := VOdbcFetchColsEx.Base.FetchRecord;
    except
      Result := FALSE;
    end;

    // смотрим чего наделали
    if Result and (not VOdbcFetchColsEx.Base.IsNull(1)) then begin
      VOdbcFetchColsEx.Base.ColToSmallInt(1, ANewVersionPtr^.id_ver);
    end else begin
      ANewVersionPtr^.id_ver := 0;
    end;

    Inc(ANewVersionPtr^.id_ver);

    // может быть номер версии тоже надо обновить
    if (not AKeepVerNumber) then begin
      if Result and (not VOdbcFetchColsEx.Base.IsNull(2)) then begin
        VOdbcFetchColsEx.Base.ColToLongInt(2, ANewVersionPtr^.ver_number);
      end else begin
        ANewVersionPtr^.ver_number := 0;
      end;
      Inc(ANewVersionPtr^.ver_number);
    end;
  finally
    VOdbcFetchColsEx.Base.Close;
  end;
end;

function TDBMS_Provider.GetNewIdService(const AGuideConnection: IDBMS_Connection): SmallInt;
var
  VOdbcFetchCols: TOdbcFetchCols;
  VSQLText: TDBMS_String;
begin
  // здесь если обломались - надо кидать исключение
  VSQLText := 'SELECT max(id_service) as id_service' +
               ' FROM ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE;

  VOdbcFetchCols.Init;
  try
    Result := 0;
    if AGuideConnection.OpenDirectSQLFetchCols(VSQLText, @VOdbcFetchCols) then
      if VOdbcFetchCols.FetchRecord then
        VOdbcFetchCols.ColToSmallInt(1, Result);
  finally
    VOdbcFetchCols.Close;
  end;

  // инкремент
  Inc(Result);
end;

function TDBMS_Provider.GetSQLIntName_Div(
  const ATilesConnection: IDBMS_Connection;
  const AXYMaskWidth, AZoom: Byte
): String;
var
  VEngineType: TEngineType;
begin
  // если зум не больше чем ширина маски + 1 - значит таблица только одна
  // а значит в тип должен входить диапазон от 0 до 2^(Z-1)-1 включительно:

  // если без учёта ширины маски (для целей совместимости не используем UNSIGNED-поля):

  // зумы, входящие в INT1 (TINYINT):
  // 1  - от 0 до 2^0-1  =   0 NUMBER(1)
  // 2  - от 0 до 2^1-1  =   1
  // 3  - от 0 до 2^2-1  =   3
  // 4  - от 0 до 2^3-1  =   7
  // 5  - от 0 до 2^4-1  =  15 NUMBER(2)
  // 6  - от 0 до 2^5-1  =  31
  // 7  - от 0 до 2^6-1  =  63
  // 8  - от 0 до 2^7-1  = 127 NUMBER(3)
  
  // зумы, входящие в INT2 (SMALLINT):
  // 9  - от 0 до 2^8-1  =   255
  // 10 - от 0 до 2^9-1  =   511
  // 11 - от 0 до 2^10-1 =  1023 NUMBER(4)
  // 12 - от 0 до 2^11-1 =  2047
  // 13 - от 0 до 2^12-1 =  4095
  // 14 - от 0 до 2^13-1 =  8191
  // 15 - от 0 до 2^14-1 = 16383 NUMBER(5)
  // 16 - от 0 до 2^15-1 = 32767

  // зумы, входящие в INT3 (MEDIUMINT):
  // 17 - от 0 до 2^16-1 =   65535
  // 18 - от 0 до 2^17-1 =  131071 NUMBER(6)
  // 19 - от 0 до 2^18-1 =  262143
  // 20 - от 0 до 2^19-1 =  524287
  // 21 - от 0 до 2^20-1 = 1048575 NUMBER(7)
  // 22 - от 0 до 2^21-1 = 2097151
  // 23 - от 0 до 2^22-1 = 4194303
  // 24 - от 0 до 2^23-1 = 8388607

  // зумы, входящие в INT4 (INTEGER):
  // 25 - от 0 до 2^24-1 =   16777215 NUMBER(8)
  // 26 - от 0 до 2^25-1 =   33554431
  // 27 - от 0 до 2^26-1 =   67108863
  // 28 - от 0 до 2^27-1 =  134217727 NUMBER(9)
  // 29 - от 0 до 2^28-1 =  268435455
  // 30 - от 0 до 2^29-1 =  536870911
  // 31 - от 0 до 2^30-1 = 1073741823 NUMBER(10)
  // 32 - от 0 до 2^31-1 = 2147483647

  // если маска 10 - то остаток от деления на 1024 падает в идентификатор тайла
  // а целая часть от деления на 1024 падает в имя таблицы
  // значит тип достаточно взять такой, чтобы входило от 0 до 1023
  // пока что все поддерживаемые маски в диапазоне от 10 до 15, что соответствует делителю от 1024 до 32768:
  // 10 - от 0 до 1023  - INT2 или NUMBER(4)
  // 11 - от 0 до 2047  - INT2 или NUMBER(4)
  // 12 - от 0 до 4095  - INT2 или NUMBER(4)
  // 13 - от 0 до 8191  - INT2 или NUMBER(4)
  // 14 - от 0 до 16383 - INT2 или NUMBER(5)
  // 15 - от 0 до 32767 - INT2 или NUMBER(5)

  // в зависимости от типа сервера БД и расчётов выше будем формировать тип поля
  VEngineType := ATilesConnection.GetCheckedEngineType;

  if UseSingleTable(AXYMaskWidth, AZoom) then begin
    // вообще не делимся по таблицам (или деление отключено, или зум маловат)
    if c_SQL_INT_With_Size[VEngineType] then begin
      // поле с размером, размер указывается в десятичных символах
      if (AZoom>32) then begin
        // поле указываем без размера - максимальная ширина
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AZoom>=31) then begin
        // 10 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(10)';
      end else if (AZoom>=28) then begin
        // 9 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(9)';
      end else if (AZoom>=25) then begin
        // 8 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(8)';
      end else if (AZoom>=21) then begin
        // 7 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(7)';
      end else if (AZoom>=18) then begin
        // 6 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(6)';
      end else if (AZoom>=15) then begin
        // 5 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(5)';
      end else if (AZoom>=11) then begin
        // 4 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(4)';
      end else if (AZoom>=8) then begin
        // 3 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(3)';
      end else if (AZoom>=5) then begin
        // 2 символов
        Result := c_SQL_INT8_FieldName[VEngineType]+'(2)';
      end else begin
        // 1 символ
        Result := c_SQL_INT8_FieldName[VEngineType]+'(1)';
      end;
      // конец для поля с размером
    end else begin
      // поле без размера, просто по ширине в байтах
      if (AZoom>32) then begin
        // просто BIGINT на всякий случай
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AZoom>24) then begin
        // INT4
        Result := c_SQL_INT4_FieldName[VEngineType];
      end else if (AZoom>16) then begin
        // INT3, если нет - INT4
        Result := c_SQL_INT3_FieldName[VEngineType];
        if (0=Length(Result)) then
          Result := c_SQL_INT4_FieldName[VEngineType];
      end else if (AZoom>8) then begin
        // INT2
        Result := c_SQL_INT2_FieldName[VEngineType];
      end else begin
        // INT1, если нет - INT2
        Result := c_SQL_INT1_FieldName[VEngineType];
        if (0=Length(Result)) then
          Result := c_SQL_INT2_FieldName[VEngineType];
      end;
      // конец для поля без размера
    end;
    // конец без деления по таблицам
  end else begin
    // делимся по таблицам на основании ширины маски
    if c_SQL_INT_With_Size[VEngineType] then begin
      // поле с размером
      if (AXYMaskWidth>=16) then begin
        // поле указываем без размера - максимальная ширина
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AXYMaskWidth>=14) then begin
        // 5 символа
        Result := c_SQL_INT8_FieldName[VEngineType]+'(5)';
      end else begin
        // 4 символа
        Result := c_SQL_INT8_FieldName[VEngineType]+'(4)';
      end;
      // конец для поля с размером
    end else begin
      // поле без размера
      if (AXYMaskWidth>=16) then begin
        // просто BIGINT на всякий случай
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else begin
        // INT2 - и не больше, и не меньше
        Result := c_SQL_INT2_FieldName[VEngineType];
      end;
      // конец для поля без размера
    end;
  end;
end;

function TDBMS_Provider.GetSQL_AddIntWhereClause(
  var AWhereClause: TDBMS_String;
  const AFieldName: TDBMS_String;
  const AWithMinBound, AWithMaxBound: Boolean;
  const AMinBoundValue, AMaxBoundValue: Integer
): Boolean;
begin
  Result := FALSE;
  if AWithMinBound then begin
    if AWithMaxBound then begin
      // with maximum
      if (AMinBoundValue=AMaxBoundValue) then begin
        // вообще одно значение
        AWhereClause := AWhereClause + ' and v.' + AFieldName + ' = ' + IntToStr(AMinBoundValue);
      end else begin
        // диапазон
        AWhereClause := AWhereClause + ' and v.' + AFieldName + ' between ' + IntToStr(AMinBoundValue) + ' and ' + IntToStr(AMaxBoundValue);
      end;
    end else begin
      // without maximum
      // только отсечка снизу
      AWhereClause := AWhereClause + ' and v.' + AFieldName + ' >= ' + IntToStr(AMinBoundValue);
    end;
  end else begin
    // without minimum
    if AWithMaxBound then begin
      // with maximum
      // только отсечка сверху
      AWhereClause := AWhereClause + ' and v.' + AFieldName + ' <= ' + IntToStr(AMaxBoundValue);
    end else begin
      // no filtering at all
      // вообще не трогаем текст WHERE
    end;
  end;
end;

function TDBMS_Provider.GetSQL_CheckPrevVersion(
  const ATilesConnection: IDBMS_Connection;
  ASQLTilePtr: PSQLTile;
  const AVerInfoPtr: PVersionAA
): TDBMS_String;
var
  VSQLVerField: TDBMS_String;
  VSQLVerValue: TDBMS_String;
begin
  Result := '';

  if (TILE_VERSION_COMPARE_ID = FStatusBuffer^.id_ver_comp) then begin
    // without additional table
    Result := 'SELECT v.tile_size' +
               ' FROM ' + ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName + ' v' +
              ' WHERE v.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                ' AND v.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                ' AND v.id_ver<' + IntToStr(AVerInfoPtr^.id_ver) +
                ' AND not exists(SELECT 1'+
                                 ' FROM ' + ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName + ' b'+
                                ' WHERE b.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                                  ' AND b.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                                  ' AND b.id_ver<' + IntToStr(AVerInfoPtr^.id_ver) +
                                  ' AND b.id_ver>v.id_ver)';
  end else begin
    // with additional table
    VSQLVerField := '';
    VSQLVerValue := '';
    case FStatusBuffer^.id_ver_comp of
      TILE_VERSION_COMPARE_VALUE: begin
        // order by ver_value
        VSQLVerField := 'ver_value';
        VSQLVerValue := DBMSStrToDB(AVerInfoPtr^.ver_value);
      end;
      TILE_VERSION_COMPARE_DATE: begin
        // order by ver_date
        VSQLVerField := 'ver_date';
        VSQLVerValue := SQLDateTimeToDBValue(ATilesConnection, AVerInfoPtr^.ver_date);
      end;
      TILE_VERSION_COMPARE_NUMBER: begin
        // order by ver_number
        VSQLVerField := 'ver_number';
        VSQLVerValue := IntToStr(AVerInfoPtr^.ver_number);
      end;
      else begin
        Exit;
      end;
    end;
    Result := 'SELECT v.tile_size' +
               ' FROM ' + ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName + ' v,' + c_Prefix_Versions + InternalGetServiceNameByDB + ' w' +
              ' WHERE v.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                ' AND v.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                ' AND v.id_ver=w.id_ver' +
                ' AND w.' + VSQLVerField + '<' + VSQLVerValue +
                ' AND not exists(SELECT 1'+
                                 ' FROM ' + ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName + ' b,' + c_Prefix_Versions + InternalGetServiceNameByDB + ' e' +
                                ' WHERE b.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                                  ' AND b.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                                  ' AND b.id_ver=e.id_ver' +
                                  ' AND e.' + VSQLVerField + '<' + VSQLVerValue +
                                  ' AND e.' + VSQLVerField + '>w.' + VSQLVerField + ')';
  end;
end;

function TDBMS_Provider.GetSQL_DeleteTile(
  const ATilesConnection: IDBMS_Connection;
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  ASQLTilePtr: PSQLTile;
  out ADeleteSQLResult: TDBMS_String
): Byte;
var
  //VSQLTile: TSQLTile;
  VRequestedVersionFound: Boolean;
  VReqVersion: TVersionAA;
begin
  // определяем запрошенную версию
  if ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // как Ansi
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // как Wide
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  // если не смогли определить версию - вернём ошибку
  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // забацаем DELETE
  ADeleteSQLResult := 'delete from ' + ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName +
                      ' where x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                        ' and y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);

  // дополнительное условие совпадения с предыдущей версией
  // только если указано поле для сравнения версий
  if (FStatusBuffer^.id_ver_comp<>TILE_VERSION_COMPARE_NONE) then
  if ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_DONT_SAVE_SAME_PREV) <> 0) then begin
    ADeleteSQLResult := ADeleteSQLResult +
               ' AND tile_size in (' + GetSQL_CheckPrevVersion(ATilesConnection, ASQLTilePtr, @VReqVersion) + ')';
  end;

  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_EnumTileVersions(
  const ATilesConnection: IDBMS_Connection;
  const ASQLTilePtr: PSQLTile;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLParts: TSQLParts;
begin
  // забацаем SELECT
  VSQLParts.SelectSQL := 'SELECT v.id_ver';
  VSQLParts.FromSQL := ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // добавим FROM, WHERE и ORDER BY
  AddVersionOrderBy(ATilesConnection, @VSQLParts, nil, FALSE);

  // соберём всё вместе
  ASQLTextResult := VSQLParts.SelectSQL +
                  ' FROM ' + VSQLParts.FromSQL +
                 ' WHERE v.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                   ' AND v.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_GetTileRectInfo(
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN;
  const AExclusively: Boolean;
  ASelectInRectList: TSelectInRectList
): Byte;
var
  VTileXYZMin, VTileXYZMax: TTILE_ID_XYZ;
  VSQLTileMin, VSQLTileMax: TSQLTile;
  i,j: Integer;
  VSelectInRectItem: PSelectInRectItem;
  VDummyConnection: IDBMS_Connection;
begin
  // смотрим какие координаты и таблицы по углам запрошенного прямоугольника
  if (ATileRectInfoIn^.ptTileRect<>nil) then begin
    // прямоугольник дали - берём min и max
    VTileXYZMin.z  := ATileRectInfoIn.btTileZoom;
    VTileXYZMin.xy := ATileRectInfoIn.ptTileRect^.TopLeft;
    VTileXYZMax.z  := ATileRectInfoIn.btTileZoom;
    VTileXYZMax.xy := ATileRectInfoIn.ptTileRect^.BottomRight;
    // исключаем верхнюю границу, так как из саса нижная граница включается, а верхняя исключается
    VTileXYZMax.xy.X := VTileXYZMax.xy.X-1;
    VTileXYZMax.xy.Y := VTileXYZMax.xy.Y-1;

    // TODO: здесь по идее прямоугольник может пересекаться с секциями
    // так что надо формировать запросы исходя из секции, куда что попало
    // пока что только по подключению для справочников

    // высчитываем координаты в таблицах
    Result := InternalCalcSQLTile(@VTileXYZMin, @VSQLTileMin, FALSE, VDummyConnection);
    if (Result<>ETS_RESULT_OK) then
      Exit;
    Result := InternalCalcSQLTile(@VTileXYZMax, @VSQLTileMax, FALSE, VDummyConnection);
    if (Result<>ETS_RESULT_OK) then
      Exit;

    VSelectInRectItem := nil;

    // контрольная проверка
    if (VSQLTileMin.XYUpperToTable.X<=VSQLTileMax.XYUpperToTable.X) and (VSQLTileMin.XYUpperToTable.Y<=VSQLTileMax.XYUpperToTable.Y) then begin
      // забацаем цикл по X и Y (так как здесь цикл фактически по таблицам - верхняя граница включается)
      for i := VSQLTileMin.XYUpperToTable.X to VSQLTileMax.XYUpperToTable.X do
      for j := VSQLTileMin.XYUpperToTable.Y to VSQLTileMax.XYUpperToTable.Y do
      try
        New(VSelectInRectItem);
        // а тут смотрим, крайние или нет у нас таблички в нашем диапазоне (для некрайних берём таблицу целиком)
        // потому что преобразование тайловых координат в табличные в рамках одной таблицы всегда связное
        with VSelectInRectItem^.TabSQLTile do begin
          XYUpperToTable.X := i;
          XYUpperToTable.Y := j;
          Zoom := ATileRectInfoIn.btTileZoom;
        end;

        with VSelectInRectItem^ do begin
          InitialWhereClause := '';

          // получим имя таблицы
          // а также определим подключение (для секционирования по табличным координатам)
          UsedConnection := VDummyConnection;
          FillTableNamesForTiles(@(VSelectInRectItem^.TabSQLTile), FALSE, UsedConnection);

          // по X
          GetSQL_AddIntWhereClause(
            InitialWhereClause,
            'x',
            (i=VSQLTileMin.XYUpperToTable.X),
            (i=VSQLTileMax.XYUpperToTable.X),
            VSQLTileMin.XYLowerToID.X,
            VSQLTileMax.XYLowerToID.X
          );

          // по Y
          GetSQL_AddIntWhereClause(
            InitialWhereClause,
            'y',
            (j=VSQLTileMin.XYUpperToTable.Y),
            (j=VSQLTileMax.XYUpperToTable.Y),
            VSQLTileMin.XYLowerToID.Y,
            VSQLTileMax.XYLowerToID.Y
          );
        end;

        // а теперь можно забацать SELECT
        Result := GetSQL_SelectTilesInternal(
          VSelectInRectItem^.UsedConnection,
          @(VSelectInRectItem^.TabSQLTile),
          ATileRectInfoIn^.szVersionIn,
          ATileRectInfoIn^.dwOptionsIn,
          VSelectInRectItem^.InitialWhereClause,
          TRUE,
          AExclusively,
          VSelectInRectItem^.FullSqlText
        );
          
        if (Result <> ETS_RESULT_OK) then
          Abort;

        // добавляемся в список
        ASelectInRectList.Add(VSelectInRectItem);
        VSelectInRectItem := nil;
      except
        if (nil <> VSelectInRectItem) then begin
          Dispose(VSelectInRectItem);
          VSelectInRectItem := nil;
        end;
      end;

    // ATileRectInfoIn^.

    end else begin
      // какая-то бредятина
      Result := ETS_RESULT_INVALID_STRUCTURE;
    end;
  end else begin
    // прямоугольник не дали - работаем по всем таблицам переданного зума
    Result := ETS_RESULT_NOT_IMPLEMENTED;
  end;
end;

function TDBMS_Provider.GetSQL_InsertIntoService(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VNewIdService: SmallInt;
  VNewIdContentType: SmallInt;
  VNewServiceCode: AnsiString;
  VSQLText: TDBMS_String;
begin
  // id_service = max(id_service)+1
  // service_code = Trunc(Name,20)
  VNewServiceCode := InternalGetServiceNameByHost;

  if (0=Length(VNewServiceCode)) then begin
    // нет уникального идентификатора сервиса
    Result := ETS_RESULT_INVALID_SERVICE_CODE;
    Exit;
  end;

  // длина внутреннего уникального кода сервиса ограничена 20 символами
  if Length(VNewServiceCode)>20 then
    SetLength(VNewServiceCode, 20);

  // а может такой внутренний код сервиса уже есть
  VSQLText := 'SELECT id_service FROM ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
              ' WHERE service_code='+DBMSStrToDB(VNewServiceCode);

  if AGuideConnection.CheckDirectSQLSingleNotNull(VSQLText) then begin
    // такой сервис уже зарегистрирован в БД (очевидно, с другим внешним уникальным кодом)
    Result := ETS_RESULT_INVALID_SERVICE_CODE;
    Exit;
  end;

  // здесь всегда обновляем список типов тайлов
  ReadContentTypesFromDB(AGuideConnection, AExclusively);

  // получим первичный тип тайла
  if not FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VNewIdContentType) then begin
    // обломались
    Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
    Exit;
  end;

  // следующий идентификатор
  VNewIdService := GetNewIdService(AGuideConnection);

  // генерим текст команды INSERT
  // прочие поля (id_ver_comp, id_div_mode,...) залетают из DEFAULT-ных значений
  // при необходимости DBA может указать нужные значения в таблице, а также изменить значения для сервиса после его регистрации в БД
  ASQLTextResult := 'INSERT INTO ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE + ' (id_service,service_code,service_name,id_contenttype) VALUES (' +
                          IntToStr(VNewIdService) + ',' +
                          DBMSStrToDB(VNewServiceCode) + ',' +
                          DBMSStrToDB(InternalGetServiceNameByHost) + ',' +
                          IntToStr(VNewIdContentType) + ')';
  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_InsertUpdateTile(
  const ATilesConnection: IDBMS_Connection;
  const ASQLTilePtr: PSQLTile;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean;
  const AExclusively: Boolean;
  out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
  out AInsertUpdateSubType: TInsertUpdateSubType;
  out AUpsert: Boolean;
  out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
): Byte;
const
  c_InsertOnDupUpdate_Ins: array [TInsertUpdateSubType] of AnsiString = ('', ',tile_body',                   '');
  c_InsertOnDupUpdate_Sel: array [TInsertUpdateSubType] of AnsiString = ('', ',?',                           '');
  c_InsertOnDupUpdate_Upd: array [TInsertUpdateSubType] of AnsiString = ('', ',tile_body=VALUES(tile_body)', ',tile_body=null');
  //
  c_DualMerge_Sel: array [TInsertUpdateSubType] of AnsiString = ('NULL', 'cast (? as BLOB)',             'NULL'); // cast (? as BLOB) или просто ?
  c_DualMerge_Ins: array [TInsertUpdateSubType] of AnsiString = ('',     ',tile_body',    '');
  c_DualMerge_Val: array [TInsertUpdateSubType] of AnsiString = ('',     ',tb',           '');
  c_DualMerge_Upd: array [TInsertUpdateSubType] of AnsiString = ('',     ',tile_body=tb', ',tile_body=null');
  //
  c_Merge_Sel: array [TInsertUpdateSubType] of AnsiString = ('NULL', '?',                        'NULL');
  c_Merge_Ins: array [TInsertUpdateSubType] of AnsiString = ('',     ',tile_body',               '');
  c_Merge_Val: array [TInsertUpdateSubType] of AnsiString = ('',     ',d.tile_body',             '');
  c_Merge_Upd: array [TInsertUpdateSubType] of AnsiString = ('',     ',g.tile_body=d.tile_body', ',g.tile_body=null');
  //
  c_Insert_Ins: array [TInsertUpdateSubType] of AnsiString = ('',     ',tile_body',    '');
  c_Insert_Val: array [TInsertUpdateSubType] of AnsiString = ('',     ',?',            '');
  c_Update_Upd: array [TInsertUpdateSubType] of AnsiString = ('',     ',tile_body=?',  ',tile_body=null');

var
  VRequestedVersionFound, VRequestedContentTypeFound: Boolean;
  VIdContentType: SmallInt;
  VReqVersion: TVersionAA;
  VUseCommonTiles: Boolean;
  VNewTileSize: LongInt;
  VVersionAutodetected: Boolean;
  VUpsertMode: TUpsertMode;
  VEngineType: TEngineType;
begin
  // если нет начитанных типов тайлов - надо читать
  if (0=FContentTypeList.Count) then begin
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    ReadContentTypesFromDB(GetGuidesConnection, AExclusively);
  end;

  // смотрим что за тип тайла подсунули
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_IN) <> 0) then begin
    // как Ansi
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiContentTypeText(
      PAnsiChar(AInsertBuffer^.szContentType),
      VIdContentType
    );
  end else begin
    // как Wide
    VRequestedContentTypeFound := FContentTypeList.FindItemByWideContentTypeText(
      PWideChar(AInsertBuffer^.szContentType),
      VIdContentType
    );
  end;

  if (not VRequestedContentTypeFound) {or AForceTNE} then begin
    // если нет такого типа тайла - используем первичный
    // TODO: опасно, но глюканёт только если будет более одного неизвестного типа тайла
    // а вообще новые значения ContentType добавляются только руками
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VIdContentType);
  end;

  if (not VRequestedContentTypeFound) then begin
    Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
    Exit;
  end;

  VVersionAutodetected := FALSE;

  // смотрим что за версию подсунули
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // как Ansi
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // как Wide
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  // автоопределение версии по тайлу (если разрешено)
  if (FDBMS_Service_Info.new_ver_by_tile<>c_Tile_Parser_None) then begin
    Result := TryToObtainVerByTile(
      AExclusively,
      VRequestedVersionFound,
      VIdContentType,
      VVersionAutodetected,
      AInsertBuffer,
      @VReqVersion
    );
    if (Result<>ETS_RESULT_OK) then
      Exit;
  end;

  if (not VRequestedVersionFound) then begin
    // если такой версии нет - пробуем создать её автоматически
    Result := AutoCreateServiceVersion(
      GetGuidesConnection,
      AExclusively,
      VVersionAutodetected,
      AInsertBuffer,
      @VReqVersion,
      VRequestedVersionFound);
    // проверяем результат создания новой версии
    if (Result<>ETS_RESULT_OK) then
      Exit;
  end;

  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // отдельно вернём имя таблицы для тайлов (для обработки ошибок)
  AUnquotedTableNameWithoutPrefix := ASQLTilePtr^.UnquotedTileTableName;
  // а здесь таблица будет с префиксом схемы
  AQuotedTableNameWithPrefix := ATilesConnection.ForcedSchemaPrefix + ASQLTilePtr^.QuotedTileTableName;

  if AForceTNE then begin
    // при вставке маркера TNE не проверяем вхождение тайла в часто используемые
    VUseCommonTiles := FALSE;
    VNewTileSize := 0;
  end else begin
    // проверяем что тайл в списке часто используемых тайлов
    VUseCommonTiles := CheckTileInCommonTiles(
      AInsertBuffer^.ptTileBuffer,
      AInsertBuffer^.dwTileSize,
      VNewTileSize // если так и есть - сюда залетит ссылка не него
    );
  end;

  if AForceTNE or (nil=AInsertBuffer^.ptTileBuffer) then begin
    // маркер TNE - нет тела тайла (поля не указываем вообще)
    // ВНИМАНИЕ! здесь если был TILE и залетает TNE - будет tile_size=0, а тело тайла останется!
    // сделано как реализация раздельного хранения тайла и маркера TNE с приоритетом TNE
    // TODO: учитывать хранимый признак (опцию)
    AInsertUpdateSubType := iust_TNE;
  end else if VUseCommonTiles then begin
    // часто используемый тайл - сохраним ссылку на него
    AInsertUpdateSubType := iust_COMMON;
  end else begin
    // обычный тайл (не маркер TNE и не часто используемый)
    AInsertUpdateSubType := iust_TILE;
  end;

  VEngineType := ATilesConnection.GetCheckedEngineType;

  VUpsertMode := ATilesConnection.GetUpsertMode;

  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_DONT_SAVE_SAME_PREV) <> 0) then begin
    // отключаем UPSERT
    VUpsertMode := upsm_None;
  end;

  AUpsert := (VUpsertMode<>upsm_None);

  case VUpsertMode of
    upsm_Merge: begin
      // используем MERGE
      // MSSQL, ASE, ASA, DB2
      // добавляем к внутреннему SELECT-у фиктивную таблицу в секцию FROM
      AInsertSQLResult := c_SQL_FROM[VEngineType];
      if (0<Length(AInsertSQLResult)) then begin
        AInsertSQLResult := ' FROM ' + AInsertSQLResult;
      end;
      AInsertSQLResult := c_Merge_Sel[AInsertUpdateSubType] + AInsertSQLResult;

      // окончательный запрос MERGE
      AInsertSQLResult := 'MERGE INTO ' + AQuotedTableNameWithPrefix + ' as g'+
                         ' USING (SELECT ' + AInsertSQLResult + ') as d (tile_body)'+
                         ' ON (g.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                         ' AND g.y='+IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                         ' AND g.id_ver=' + IntToStr(VReqVersion.id_ver) + ')'+
                         ' WHEN NOT MATCHED THEN INSERT'+
                         ' (x,y,id_ver,id_contenttype,load_date,tile_size' + c_Merge_Ins[AInsertUpdateSubType] + ') VALUES (' +
                          IntToStr(ASQLTilePtr^.XYLowerToID.X) + ','+
                          IntToStr(ASQLTilePtr^.XYLowerToID.Y) + ',' +
                          IntToStr(VReqVersion.id_ver) + ','+
                          IntToStr(VIdContentType) + ',' +
                          SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC) + ',' +
                          IntToStr(VNewTileSize) +
                          c_Merge_Val[AInsertUpdateSubType] +
                          ')' +
                         ' WHEN MATCHED THEN UPDATE'+
                         ' SET g.id_contenttype=' + IntToStr(VIdContentType) +
                            ', g.load_date=' + SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC) +
                            ', g.tile_size=' + IntToStr(VNewTileSize) + c_Merge_Upd[AInsertUpdateSubType]
                          ;

      if (VEngineType in [et_MSSQL]) then begin
        // для MSSQL в конец добавляем ;
        AInsertSQLResult := AInsertSQLResult + ';';
      end;

      // выражения UPDATE нет
      AUpdateSQLResult := '';
    end;

    upsm_DualMerge: begin
      // запрос MERGE
      // Oracle
      // 'HY000:1461:[Oracle][ODBC][Ora]ORA-01461: can bind a LONG value only for insert into a LONG column'
      AInsertSQLResult := 'MERGE INTO ' + AQuotedTableNameWithPrefix + ' g'+
                         ' USING (SELECT ' + IntToStr(ASQLTilePtr^.XYLowerToID.X) + ' di,' + c_DualMerge_Sel[AInsertUpdateSubType] + ' tb FROM ' + c_SQL_FROM[VEngineType] + ') d'+
                         ' ON (g.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                         ' AND g.y='+IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                         ' AND g.id_ver=' + IntToStr(VReqVersion.id_ver) +
                         ' AND g.x=di)'+
                         ' WHEN NOT MATCHED THEN INSERT'+
                         ' (x,y,id_ver,id_contenttype,load_date,tile_size' + c_DualMerge_Ins[AInsertUpdateSubType] + ') VALUES (' +
                          IntToStr(ASQLTilePtr^.XYLowerToID.X) + ','+
                          IntToStr(ASQLTilePtr^.XYLowerToID.Y) + ',' +
                          IntToStr(VReqVersion.id_ver) + ','+
                          IntToStr(VIdContentType) + ',' +
                          SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC) + ',' +
                          IntToStr(VNewTileSize) +
                          c_DualMerge_Val[AInsertUpdateSubType] +
                          ')' +
                         ' WHEN MATCHED THEN UPDATE'+
                         ' SET g.id_contenttype=' + IntToStr(VIdContentType) +
                            ', g.load_date=' + SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC) +
                            ', g.tile_size=' + IntToStr(VNewTileSize) + c_DualMerge_Upd[AInsertUpdateSubType]
                          ;

      // выражения UPDATE нет
      AUpdateSQLResult := '';
    end;

    upsm_InsertOnDupUpdate: begin
      // MySQL
      AInsertSQLResult := 'INSERT INTO ' + AQuotedTableNameWithPrefix + ' (x,y,id_ver,id_contenttype,load_date,tile_size' +
                                           c_InsertOnDupUpdate_Ins[AInsertUpdateSubType] + ') VALUES (' +
                          IntToStr(ASQLTilePtr^.XYLowerToID.X) + ',' +
                          IntToStr(ASQLTilePtr^.XYLowerToID.Y) + ',' +
                          IntToStr(VReqVersion.id_ver) + ',' +
                          IntToStr(VIdContentType) + ',' +
                          SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC) + ',' +
                          IntToStr(VNewTileSize) + c_InsertOnDupUpdate_Sel[AInsertUpdateSubType] + ')' +
                          ' ON DUPLICATE KEY UPDATE' +
                          ' id_contenttype=' + IntToStr(VIdContentType) +
                          ', load_date=VALUES(load_date)' +
                          ', tile_size=' + IntToStr(VNewTileSize) + c_InsertOnDupUpdate_Upd[AInsertUpdateSubType];

      // выражения UPDATE нет
      AUpdateSQLResult := '';
    end;

    else begin
      // одиночные INSERT и UPDATE
      AUpdateSQLResult := SQLDateTimeToDBValue(ATilesConnection, AInsertBuffer^.dtLoadedUTC);
      // соберём выражение INSERT
      // список значений
      AInsertSQLResult := IntToStr(ASQLTilePtr^.XYLowerToID.X) + ',' +
                          IntToStr(ASQLTilePtr^.XYLowerToID.Y) + ',' +
                          IntToStr(VReqVersion.id_ver) + ',' +
                          IntToStr(VIdContentType) + ',' +
                          AUpdateSQLResult + ',' +
                          IntToStr(VNewTileSize) + c_Insert_Val[AInsertUpdateSubType];

      if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_DONT_SAVE_SAME_PREV) <> 0) then begin
        // вставка только тайл если отличается от предыдущей версии
        AInsertSQLResult := 'SELECT ' + AInsertSQLResult;
        if (0<Length(c_SQL_FROM[VEngineType])) then begin
          AInsertSQLResult := AInsertSQLResult + ' FROM ' + c_SQL_FROM[VEngineType];
        end;
        AInsertSQLResult := AInsertSQLResult +
                      ' WHERE NOT (' + IntToStr(VNewTileSize) + ' in (' + GetSQL_CheckPrevVersion(ATilesConnection, ASQLTilePtr, @VReqVersion) + '))';
      end else begin
        // безусловная вставка VALUES
        AInsertSQLResult := 'VALUES (' + AInsertSQLResult + ')';
      end;

      // окончательный INSERT
      AInsertSQLResult := 'INSERT INTO ' + AQuotedTableNameWithPrefix +
                                ' (x,y,id_ver,id_contenttype,load_date,tile_size' + c_Insert_Ins[AInsertUpdateSubType] +') ' +
                                AInsertSQLResult;

      // соберём выражение UPDATE
      AUpdateSQLResult := 'UPDATE ' + AQuotedTableNameWithPrefix +
                            ' SET id_contenttype=' + IntToStr(VIdContentType) +
                               ', load_date=' + AUpdateSQLResult +
                               ', tile_size=' + IntToStr(VNewTileSize) +
                               c_Update_Upd[AInsertUpdateSubType] +
                          ' WHERE x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +
                            ' AND y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y) +
                            ' AND id_ver=' + IntToStr(VReqVersion.id_ver);

      if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_DONT_SAVE_SAME_PREV) <> 0) then begin
        // добавка к UPDATE
        AUpdateSQLResult := AUpdateSQLResult +
                      ' AND NOT (' + IntToStr(VNewTileSize) + ' in (' + GetSQL_CheckPrevVersion(ATilesConnection, ASQLTilePtr, @VReqVersion) + '))';
      end;
    end;
  end;

  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_SelectTile(
  const ATilesConnection: IDBMS_Connection;
  const ASQLTilePtr: PSQLTile;
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
begin
  // забацаем SELECT
  Result := GetSQL_SelectTilesInternal(
    ATilesConnection,
    ASQLTilePtr,
    ASelectBufferIn^.szVersionIn,
    ASelectBufferIn^.dwOptionsIn,
    // тащим один конкретный тайл
    'v.x=' + IntToStr(ASQLTilePtr^.XYLowerToID.X) +' and v.y=' + IntToStr(ASQLTilePtr^.XYLowerToID.Y),
    FALSE, // тащим один известный тайл - его координаты нам ни к чему
    AExclusively,
    ASQLTextResult
  );
end;

function TDBMS_Provider.GetSQL_SelectTilesInternal(
  const ATilesConnection: IDBMS_Connection;
  const ASQLTile: PSQLTile;
  const AVersionIn: Pointer;
  const AOptionsIn: LongWord;
  const AInitialWhere: TDBMS_String;
  const AGetManyTilesWithXY: Boolean;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLParts: TSQLParts;
  VReqVersion: TVersionAA;
  VShowPrevVersion: Boolean;
begin
  Result := ETS_RESULT_OK;

  // заготовки
  VSQLParts.SelectSQL := 'v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := ASQLTile^.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := AInitialWhere;
  VSQLParts.OrderBySQL := '';

  if AGetManyTilesWithXY then begin
    // тащим много тайлов - надо вытащить координаты
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.x,v.y,';
  end;

  // надо ли учитывать часто используемые тайлы
  // и вообще интересует ли тело тайлов
  if (ETS_UCT_NO=FDBMS_Service_Info.use_common_tiles) then begin
    // без часто используемых тайлов
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.tile_size';
    if ((AOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      VSQLParts.SelectSQL := VSQLParts.SelectSQL + ',v.tile_body';
    end;
  end else begin
    // с часто используемыми тайлами
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'isnull(k.common_size,v.tile_size) as tile_size';
    if ((AOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      VSQLParts.SelectSQL := VSQLParts.SelectSQL + ',isnull(k.common_body,v.tile_body) as tile_body';
    end;

    VSQLParts.FromSQL := VSQLParts.FromSQL + ' left outer join  u_' + InternalGetServiceNameByDB + ' k on v.tile_size<0 and v.tile_size=-k.id_common_tile and v.id_contenttype=k.id_common_type';
  end;

  // забацаем FROM, WHERE и ORDER BY

  // определим запрошенную версию
  if ((AOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // как Ansi
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AVersionIn),
      @VReqVersion
    );
  end else begin
    // как Wide
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(AVersionIn),
      @VReqVersion
    );
  end;

  // если не смогли определить версию - вернём ошибку
  // всё равно ничего хорошего в этом случае из БД не вытащить
  if (not VSQLParts.RequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  VShowPrevVersion := ((AOptionsIn and ETS_ROI_SHOW_PREV_VERSION) <> 0);

  // если версия была найдена (в том числе зарезервированный идентификатор для пустой версии!)
  if (VReqVersion.id_ver=FVersionList.EmptyVersionIdVer) then begin
    // запрос без версии
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_LAST_VERSION) <> 0) or VShowPrevVersion then begin
      // берём последнюю версию (добавляем в OrderBySQL кусок)
      AddVersionOrderBy(ATilesConnection, @VSQLParts, @VReqVersion, FALSE);
    end else begin
      // берём только пустую версию (так как она одна - обойдёмся без ORDER BY)
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
    end;
  end else begin
    // запрос с непустой версией
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_PREV_VERSION) <> 0) or VShowPrevVersion then begin
      // разрешена предыдущая версия
      AddVersionOrderBy(ATilesConnection, @VSQLParts, @VReqVersion, TRUE);
      if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) = 0) then begin
        // но не разрешено без версии!
        VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver!=' + IntToStr(FVersionList.EmptyVersionIdVer);
      end;
    end else if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) <> 0) then begin
      // разрешено вернуть только запрошенную версию или совсем без версии
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver in (' + IntToStr(VReqVersion.id_ver) + ',' + IntToStr(FVersionList.EmptyVersionIdVer) + ')';
    end else begin
      // разрешено вернуть только запрошенную версию
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
    end;
  end;

  // обработка WHERE:
  // а) если начинается с ' and ' - удалим начало;
  // б) если вообще нет условий - не будем писать и WHERE
  if (0<Length(VSQLParts.WhereSQL)) then begin
    if SameText(System.Copy(VSQLParts.WhereSQL, 1, 5),' and ') then begin
      System.Delete(VSQLParts.WhereSQL, 1, 5);
    end;

    VSQLParts.WhereSQL := ' WHERE ' + VSQLParts.WhereSQL;
  end;

  if (not AGetManyTilesWithXY) then begin
    // тащим только один тайл - добавим TOP 1 или LIMIT 1 или ещё что (в зависимости от СУБД)
    case ATilesConnection.GetSelectRowCount1Mode of
      rc1m_Top1: begin
        VSQLParts.SelectSQL := 'TOP 1 ' + VSQLParts.SelectSQL;
      end;
      rc1m_First1: begin
        VSQLParts.SelectSQL := 'FIRST 1 ' + VSQLParts.SelectSQL;
      end;
      rc1m_Limit1: begin
        VSQLParts.OrderBySQL := VSQLParts.OrderBySQL + ' LIMIT 1';
      end;
      rc1m_Fetch1Only: begin
        VSQLParts.OrderBySQL := VSQLParts.OrderBySQL + ' FETCH FIRST 1 ROW ONLY';
      end;
      rc1m_Rows1: begin
        VSQLParts.OrderBySQL := VSQLParts.OrderBySQL + ' ROWS 1';
      end;
    end;
  end;

  // собираем всё вместе
  ASQLTextResult := 'SELECT ' + VSQLParts.SelectSQL +
                     ' FROM ' + VSQLParts.FromSQL +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetVersionAnsiPointer(
  const AGuideConnection: IDBMS_Connection;
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(AGuideConnection, Aid_ver, AExclusively, @Result, VDummy) then
      Exit;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetVersionAnsiPointer(AGuideConnection, Aid_ver, TRUE);
  end;
end;

function TDBMS_Provider.GetVersionWideString(
  const AGuideConnection: IDBMS_Connection;
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VVerValueAnsiStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(AGuideConnection, Aid_ver, AExclusively, nil, VVerValueAnsiStr) then begin
      // found
      Result := VVerValueAnsiStr;
      Exit;
    end;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetVersionWideString(AGuideConnection, Aid_ver, TRUE);
  end;
end;

procedure TDBMS_Provider.GuidesBeginWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FGuidesSync.BeginWrite
  else
    FGuidesSync.BeginRead;
end;

procedure TDBMS_Provider.GuidesEndWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FGuidesSync.EndWrite
  else
    FGuidesSync.EndRead;
end;

function TDBMS_Provider.HasUnknownExceptions: Boolean;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    Result := (nil<>FUnknownExceptions) and (0<FUnknownExceptions.Count);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

function TDBMS_Provider.InternalCalcSQLTile(
  const AXYZ: PTILE_ID_XYZ;
  const ASQLTile: PSQLTile;
  const AAllowNewObjects: Boolean;
  out AResultConnection: IDBMS_Connection
): Byte;
begin
  if (nil=ASQLTile) or (nil=AXYZ) then begin
    AResultConnection := GetGuidesConnection;
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // если секционирование по тайловым координатам - определяем секцию
  if UseSectionByTileXY then begin
    AResultConnection := ChooseConnection(AXYZ^.z, @(AXYZ^.xy), AAllowNewObjects);
  end;

  // сохраняем зум (от 1 до 24)
  ASQLTile^.Zoom := AXYZ^.z;

  // делим XY на "верхнюю" и "нижнюю" части
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  // строим имя таблицы для тайлов
  FillTableNamesForTiles(ASQLTile, AAllowNewObjects, AResultConnection);

  Result := ETS_RESULT_OK;
end;

procedure TDBMS_Provider.InternalDivideXY(
  const AXY: TPoint;
  const ASQLTile: PSQLTile
);
var
  VMask: LongInt;
  VXYMaskWidth: Byte;
begin
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  if (0=VXYMaskWidth) then begin
    // do not divide
    ASQLTile^.XYUpperToTable.X := 0;
    ASQLTile^.XYUpperToTable.Y := 0;
    ASQLTile^.XYLowerToID := AXY;
  end else begin
    // divide
    VMask := (1 shl VXYMaskWidth)-1;
    ASQLTile^.XYUpperToTable.X := AXY.X shr VXYMaskWidth;
    ASQLTile^.XYUpperToTable.Y := AXY.Y shr VXYMaskWidth;
    ASQLTile^.XYLowerToID.X := AXY.X and VMask;
    ASQLTile^.XYLowerToID.Y := AXY.Y and VMask;
  end;
end;

function TDBMS_Provider.InternalGetContentTypeAnsiValues(
  const AGuideConnection: IDBMS_Connection;
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean;
  const AContentTypeTextPtr: PPAnsiChar;
  out AContentTypeTextStr: AnsiString
): Boolean;
begin
  // find
  Result := FContentTypeList.FindItemByIdContentType(
    Aid_contenttype,
    AContentTypeTextPtr,
    AContentTypeTextStr
  );

  if (not Result) then begin
    // not found
    if not AExclusively then
      Exit;
      
    // read from DB
    ReadContentTypesFromDB(AGuideConnection, AExclusively);

    // again
    Result := FContentTypeList.FindItemByIdContentType(
      Aid_contenttype,
      AContentTypeTextPtr,
      AContentTypeTextStr
    );
  end;
end;

function TDBMS_Provider.InternalGetServiceNameByDB: TDBMS_String;
begin
  Result := FDBMS_Service_Code;
end;

function TDBMS_Provider.InternalGetServiceNameByHost: TDBMS_String;
begin
  Result := FPath.Path_Items[2];
end;

function TDBMS_Provider.InternalGetVersionAnsiValues(
  const AGuideConnection: IDBMS_Connection;
  const Aid_ver: SmallInt;
  const AExclusively: Boolean;
  const AVerValuePtr: PPAnsiChar;
  out AVerValueStr: AnsiString
): Boolean;
begin
  // find
  Result := FVersionList.FindItemByIdVer(Aid_ver, AVerValuePtr, AVerValueStr);
  if (not Result) then begin
    // not found
    if not AExclusively then
      Exit;
      
    // read from DB
    ReadVersionsFromDB(AGuideConnection, AExclusively);

    Result := FVersionList.FindItemByIdVer(Aid_ver, AVerValuePtr, AVerValueStr);
  end;
end;

procedure TDBMS_Provider.InternalProv_Cleanup;
begin
  FillChar(FHostCallbacks, sizeof(FHostCallbacks), 0);
  FPath.Clear;
  InternalProv_ClearServiceInfo;
end;

procedure TDBMS_Provider.InternalProv_ClearGuides;
begin
  FVersionList.Clear;
  FContentTypeList.Clear;
end;

procedure TDBMS_Provider.InternalProv_ClearServiceInfo;
begin
  FDBMS_Service_OK := FALSE;
  FDBMS_Service_Code := '';
  with FDBMS_Service_Info do begin
    id_service := 0;
    id_contenttype := 0;
    id_ver_comp := TILE_VERSION_COMPARE_NONE;
    id_div_mode := TILE_DIV_ERROR;
    work_mode := ETS_SWM_DEFAULT;
    use_common_tiles := ETS_UCT_NO;
    // вторая версия полей
    tile_load_mode    := 0;
    tile_save_mode    := 0;
    tile_hash_mode    := 0;
    new_ver_by_tile   := 0;
  end;
end;

function TDBMS_Provider.InternalProv_Connect(
  const AExclusively: Boolean;
  const AXYZ: PTILE_ID_XYZ;
  const AAllowNewObjects: Boolean;
  ASQLTilePtr: PSQLTile;
  out ATilesConnection: IDBMS_Connection
): Byte;
begin
  if (not FCompleted) then begin
    Result := ETS_RESULT_INCOMPLETE;

    // пропихнём признак в хост
    if (FStatusBuffer<>nil) then
    with (FStatusBuffer^) do begin
      if wSize>=SizeOf(FStatusBuffer^) then
        malfunction_mode := ETS_PMM_NOT_COMPLETED;
    end;
    
    Exit;
  end;

  // при необходимости создаём первичное подключение
  // вторичные создадутся автоматически при натягивании параметров
  if (nil=FPrimaryConnnection) then begin
    // check exclusive mode
    if AExclusively then begin
      // make connection
      FPrimaryConnnection := GetConnectionByPath(@FPath);
      if (nil=FPrimaryConnnection) then begin
        Result := ETS_RESULT_CANNOT_CONNECT;
        Exit;
      end;
      CheckSecondaryConnections;
    end else begin
      // request exclusive access
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
  end;

  // если ещё не читали настройки - берём подключение для справочников и подключаемся
  if (not FDBMS_Service_OK) then begin
    // пробуем подключиться
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;

    // требование переподключения после разрыва соединения будем проверять внутри
    Result := GetGuidesConnection.EnsureConnected(AExclusively, FStatusBuffer);

    // при ошибке валим
    if (ETS_RESULT_OK<>Result) then
      Exit;

    // читаем параметры сервиса после подключения
    Result := InternalProv_ReadServiceInfo(GetGuidesConnection, AExclusively);
    if (ETS_RESULT_OK<>Result) then
      Exit;

    // читаем типы тайлов
    if (0=FContentTypeList.Count) then begin
      ReadContentTypesFromDB(GetGuidesConnection, AExclusively);
    end;

    // если сервис нашёлся - вытащим из базы его версии
    ReadVersionsFromDB(GetGuidesConnection, AExclusively);
    // если версий нет вообще - создадим запись для пустой версии (без версии)
    try
      if (0=FVersionList.Count) then begin
        // создаём только если СУБД допускает пустую версию
        if not c_SQL_Empty_Version_Denied[GetGuidesConnection.GetCheckedEngineType] then begin
          MakeEmptyVersionInDB(GetGuidesConnection, 0, AExclusively);
        end;
        ReadVersionsFromDB(GetGuidesConnection, AExclusively);
      end;
    except
    end;
  end;

  // определяем таблицу (заполняем ASQLTilePtr) и рабочее подключение по XYZ
  Result := InternalCalcSQLTile(
    AXYZ,
    ASQLTilePtr,
    AAllowNewObjects,
    ATilesConnection
  );

  if (Result<>ETS_RESULT_OK) then
    Exit;

  // пробуем подключиться
  // требование переподключения после разрыва соединения будем проверять внутри
  Result := ATilesConnection.EnsureConnected(AExclusively, FStatusBuffer);
end;

procedure TDBMS_Provider.InternalProv_Disconnect;
begin
  // detach connection object from provider
  FGuidesConnnection := nil;
  FUndefinedConnnection := nil;
  FreeDBMSConnection(FPrimaryConnnection);
end;

function TDBMS_Provider.InternalProv_ReadServiceInfo(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean
): Byte;
var
  VOdbcFetchColsEx: TOdbcFetchCols12;
  VSelectCurrentServiceSQL: TDBMS_String;
  VStatementExceptionType: TStatementExceptionType;
begin
  FillChar(FDBMS_Service_Info, SizeOf(FDBMS_Service_Info), 0);

  // тащим инфу о текущем сервисе
  // исходя из указанного при инициализации внешнего уникального кода сервиса
  VSelectCurrentServiceSQL := 'SELECT *' +
                               ' FROM ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
                              ' WHERE service_name='+DBMSStrToDB(InternalGetServiceNameByHost);

  VOdbcFetchColsEx.Init;
  try
    VStatementExceptionType := set_Success;
    try
      AGuideConnection.OpenDirectSQLFetchCols(VSelectCurrentServiceSQL, @(VOdbcFetchColsEx.Base));
    except on E: Exception do
      VStatementExceptionType := GetStatementExceptionType(AGuideConnection, E);
    end;

    if StandardExceptionType(VStatementExceptionType, FALSE, Result) then begin
      // предопределённые известные критичные ошибки
      InternalProv_ClearServiceInfo;
      Exit;
    end;

    case VStatementExceptionType of
      set_Success: begin
        // ok
      end;
      set_TableNotFound: begin
        // нет таблицы с сервисами
        VOdbcFetchColsEx.Base.Close;
        // создаём базовые таблицы из скрипта
        CreateAllBaseTablesFromScript(AGuideConnection);
        // переоткрываемся
        try
          AGuideConnection.OpenDirectSQLFetchCols(VSelectCurrentServiceSQL, @(VOdbcFetchColsEx.Base));
        except
        end;
      end;
      set_PrimaryKeyViolation: begin
        // тут пусто потому что нет смысла повторять обработчик ниже
      end;
    end;

    // а вдруг полный отстой, и нам так и не удалось открыться
    if (not VOdbcFetchColsEx.Base.IsActive) then begin
      // с прискорбием валим
      InternalProv_ClearServiceInfo;
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    // проверка, а есть ли сервис
    if (not VOdbcFetchColsEx.Base.FetchRecord) then begin
      // а сервиса-то такого нет
      VOdbcFetchColsEx.Base.Close;

      // однако попробуем создать его
      Result := AutoCreateServiceRecord(AGuideConnection, AExclusively);

      // проверка чего насоздавали
      if (Result<>ETS_RESULT_OK) then begin
        InternalProv_ClearServiceInfo;
        Exit;
      end;

      // и снова пробуем переоткрыться
      try
        AGuideConnection.OpenDirectSQLFetchCols(VSelectCurrentServiceSQL, @(VOdbcFetchColsEx.Base));
      except
      end;

      // последняя проверка - может так ничего и не забацали
      if (not VOdbcFetchColsEx.Base.FetchRecord) then begin
        // так и нет сервиса
        InternalProv_ClearServiceInfo;
        Result := ETS_RESULT_UNKNOWN_SERVICE;
        Exit;
      end;
    end;
    
    // запрошенный сервис нашёлся
    with VOdbcFetchColsEx.Base do begin
      ColToSmallInt   (ColIndex('id_service'),       FDBMS_Service_Info.id_service);
      ColToAnsiString (ColIndex('service_code'),     FDBMS_Service_Code);
      ColToSmallInt   (ColIndex('id_contenttype'),   FDBMS_Service_Info.id_contenttype);
      ColToAnsiCharDef(ColIndex('id_ver_comp'),      FDBMS_Service_Info.id_ver_comp, TILE_VERSION_COMPARE_NONE);
      ColToAnsiCharDef(ColIndex('id_div_mode'),      FDBMS_Service_Info.id_div_mode, TILE_DIV_ERROR);
      ColToAnsiCharDef(ColIndex('work_mode'),        FDBMS_Service_Info.work_mode, ETS_SWM_DEFAULT);
      ColToAnsiCharDef(ColIndex('use_common_tiles'), FDBMS_Service_Info.use_common_tiles, ETS_UCT_NO);
    end;

    FDBMS_Service_OK := TRUE;

    // следующие поля появились только во второй версии Z_SERVICE, так что их может не быть
    with VOdbcFetchColsEx.Base do begin
      FDBMS_Service_Info.tile_load_mode  := GetOptionalSmallInt('tile_load_mode');
      FDBMS_Service_Info.tile_save_mode  := GetOptionalSmallInt('tile_save_mode');
      FDBMS_Service_Info.tile_hash_mode  := GetOptionalSmallInt('tile_hash_mode');
      FDBMS_Service_Info.new_ver_by_tile := GetOptionalSmallInt('new_ver_by_tile');
    end;

    // копируем параметры в опции хранилища
    if (FStatusBuffer<>nil) then
    with (FStatusBuffer^) do begin
      id_div_mode      := FDBMS_Service_Info.id_div_mode;
      id_ver_comp      := FDBMS_Service_Info.id_ver_comp;
      work_mode        := FDBMS_Service_Info.work_mode;
      use_common_tiles := FDBMS_Service_Info.use_common_tiles;
      // вторая версия полей
      tile_load_mode   := LoByte(FDBMS_Service_Info.tile_load_mode);
      tile_save_mode   := LoByte(FDBMS_Service_Info.tile_save_mode);
      new_ver_by_tile  := FDBMS_Service_Info.new_ver_by_tile;
    end;

    Result := ETS_RESULT_OK;
  finally
    VOdbcFetchColsEx.Base.Close;
  end;
end;

function TDBMS_Provider.InternalProv_SetStorageIdentifier(
  const AInfoSize: LongWord;
  const AInfoData: PETS_SET_IDENTIFIER_INFO;
  const AInfoResult: PLongWord
): Byte;
var
  VGlobalStorageIdentifier, VServiceName: WideString; // keep wide
begin
  // проверим буфер
  if (nil = AInfoData) or (AInfoSize < Sizeof(AInfoData^)) then begin
    Result := ETS_RESULT_INVALID_BUFFER_SIZE;
    Exit;
  end;

  // идентификатор не может быть пустым
  if (nil = AInfoData^.szGlobalStorageIdentifier) then begin
    Result := ETS_RESULT_POINTER1_NIL;
    Exit;
  end;

  // идентификатор не может быть пустым
  if (nil = AInfoData^.szServiceName) then begin
    Result := ETS_RESULT_POINTER2_NIL;
    Exit;
  end;

  // тащим значения из буфера
  if ((AInfoData^.dwOptionsIn and ETS_ROI_ANSI_SET_INFORMATION) <> 0) then begin
    // как AnsiString
    VGlobalStorageIdentifier := AnsiString(PAnsiChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := AnsiString(PAnsiChar(AInfoData^.szServiceName));
  end else begin
    // как WideString
    VGlobalStorageIdentifier := WideString(PWideChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := WideString(PWideChar(AInfoData^.szServiceName));
  end;

  // парсим и получаем полный путь до СУБД и сервиса в ней
  FPath.ApplyFrom(VGlobalStorageIdentifier, VServiceName);

  // проверяем что напарсилось
  if (0<Length(FPath.ServerName)) and (0<Length(FPath.ServiceName)) then begin
    // корректно (с точки зрения формата, не обязательно сервис будет доступен)
    Result := ETS_RESULT_OK;
  end else begin
    // заведомо криво
    Result := ETS_RESULT_INVALID_PATH;
  end;
end;

function TDBMS_Provider.IsUninitialized: Boolean;
begin
  Result := FUninitialized;
end;

function TDBMS_Provider.MakeEmptyVersionInDB(
  const AGuideConnection: IDBMS_Connection;
  const AIdVersion: SmallInt;
  const AExclusively: Boolean
): Boolean;
var
  VNewVersion: TVersionAA;
begin
  Assert(AExclusively);

  // создание записи в БД для пустой версии текущего сервиса
  VNewVersion.id_ver := AIdVersion;
  VNewVersion.ver_value :='';
  VNewVersion.ver_date := c_SQL_DateTimeForEmptyVersion[AGuideConnection.GetCheckedEngineType]; //NowUTC;
  VNewVersion.ver_number := AIdVersion;
  VNewVersion.ver_comment := '';
  Result := MakePtrVersionInDB(AGuideConnection, @VNewVersion, AExclusively);
end;

function TDBMS_Provider.MakePtrVersionInDB(
  const AGuideConnection: IDBMS_Connection;
  const ANewVersionPtr: PVersionAA;
  const AExclusively: Boolean
): Boolean;
var
  VVersionsTableName_UnquotedWithoutPrefix: TDBMS_String;
  VVersionsTableName_QuotedWithPrefix: TDBMS_String;
begin
  Assert(AExclusively);

  VVersionsTableName_UnquotedWithoutPrefix := c_Prefix_Versions + InternalGetServiceNameByDB;
  VVersionsTableName_QuotedWithPrefix := AGuideConnection.ForcedSchemaPrefix + VVersionsTableName_UnquotedWithoutPrefix;

  // проверим, а есть ли табличка с версиями сервиса
  if (not AGuideConnection.TableExistsDirect(VVersionsTableName_QuotedWithPrefix)) then
  try
    // создадим
    CreateTableByTemplate(
      AGuideConnection,
      c_Templated_Versions,
      VVersionsTableName_UnquotedWithoutPrefix,
      VVersionsTableName_QuotedWithPrefix,
      0,
      FALSE
    );
  except
  end;

  // тут проверять бессмысленно, будем считать что таблица создалась

  try
    // выполним SQL для вставки записи о новой версии напрямую
    AGuideConnection.ExecuteDirectSQL(
      'INSERT INTO ' + VVersionsTableName_QuotedWithPrefix +
      '(id_ver,ver_value,ver_date,ver_number,ver_comment) VALUES (' +
      IntToStr(ANewVersionPtr^.id_ver) + ',' +
      DBMSStrToDB(ANewVersionPtr^.ver_value) + ',' +
      SQLDateTimeToDBValue(AGuideConnection, ANewVersionPtr^.ver_date) + ',' +
      IntToStr(ANewVersionPtr^.ver_number) + ',' +
      DBMSStrToDB(ANewVersionPtr^.ver_comment) + ')',

      FALSE
    );
    Result := TRUE;
  except
    Result := FALSE;
  end;
end;

function TDBMS_Provider.MakeVersionByFormParams(
  const AGuideConnection: IDBMS_Connection;
  const AFormParams: TStrings
): Byte;

  function _DecodedValue(const AValueName: String): String;
  begin
    Result := AFormParams.Values[AValueName];
    if System.Pos('%', Result) > 0 then begin
      // декодируем
      Result := HTTPDecode(Result);
    end;
  end;

var
  VFormVersion, VFoundVersion: TVersionAA;
  VExclusivelyLocked: Boolean;
  VUpdateExisting, VSwitchToMaked: Boolean;
  VSQLText: TDBMS_String;
  VVersionsTableName_UnquotedWithoutPrefix: TDBMS_String;
  VVersionsTableName_QuotedWithPrefix: TDBMS_String;
  VStatementExceptionType: TStatementExceptionType;
begin
  VFormVersion.ver_value := _DecodedValue(c_MkVer_Value);

  if (0=Length(VFormVersion.ver_value)) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  if not ParseFullyQualifiedDateTime(_DecodedValue(c_MkVer_Date), VFormVersion.ver_date) then
    VFormVersion.ver_date  := c_ZeroVersionNumber_DateTime;

  VFormVersion.ver_number := StrToIntDef(_DecodedValue(c_MkVer_Number), 0);

  VFormVersion.ver_comment := _DecodedValue(c_MkVer_Comment);

  VUpdateExisting := (AFormParams.Values[c_MkVer_UpdOld] = '1');
  VSwitchToMaked := (AFormParams.Values[c_MkVer_SwitchToVer] = '1');


  DoBeginWork(TRUE, so_ReloadVersions, VExclusivelyLocked);
  try
    ReadVersionsFromDB(AGuideConnection, VExclusivelyLocked);

    if FVersionList.FindItemByAnsiValue(PAnsiChar(VFormVersion.ver_value), @VFoundVersion) then begin
      // надо обновляться
      if (not VUpdateExisting) then begin
        // нельзя обновлять существующую версию
        Result := ETS_RESULT_SKIP_EXISTING;
        Exit;
      end;

      // обновляемся - это проще
      VVersionsTableName_UnquotedWithoutPrefix := c_Prefix_Versions + InternalGetServiceNameByDB;
      VVersionsTableName_QuotedWithPrefix := AGuideConnection.ForcedSchemaPrefix + VVersionsTableName_UnquotedWithoutPrefix;

      VSQLText := 'UPDATE ' + VVersionsTableName_QuotedWithPrefix +
                    ' SET ' + 'ver_date=' + SQLDateTimeToDBValue(AGuideConnection, VFormVersion.ver_date) +
                             ',ver_number=' + IntToStr(VFormVersion.ver_number) +
                             ',ver_comment=' + DBMSStrToDB(VFormVersion.ver_comment) +
                  ' WHERE ver_value=' + DBMSStrToDB(VFormVersion.ver_value);

      VStatementExceptionType := set_Success;
      try
        AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
      except on E: Exception do
        VStatementExceptionType := GetStatementExceptionType(AGuideConnection, E);
      end;

      // хоть успешно обновили, хоть с ошибкой - надо обновить список версий
      ReadVersionsFromDB(AGuideConnection, VExclusivelyLocked);

      if StandardExceptionType(VStatementExceptionType, FALSE, Result) then
        Exit;

      // тут при наличии версии таблица уже точно есть
      // так что тут по идее только успех
      Result := ETS_RESULT_OK;
      Exit;
    end;

    // создаём версию
    Result := AutoCreateServiceVersion(
      AGuideConnection,
      VExclusivelyLocked,
      TRUE, // чтобы только определилось значение id_ver
      nil,  // нет необходимости
      @VFormVersion,
      VUpdateExisting // признак существования версии - неактуален
    );

    // обновление списка версий из БД есть внутри
  finally
    DoEndWork(VExclusivelyLocked);

    // если запрошено переключение и есть версия - переключаемся даже при наличии ошибки
    if VSwitchToMaked then
    if FVersionList.FindItemByAnsiValue(PAnsiChar(VFormVersion.ver_value), @VFoundVersion) then begin
      SwitchHostToVersion(VFormVersion.ver_value);
    end;
  end;
end;

function TDBMS_Provider.ParseMakeVersionSource(
  const AGuideConnection: IDBMS_Connection;
  const AMakeVersionSource: String;
  const AVerFoundInfo, AVerParsedInfo: PVersionAA;
  out AVersionFound: Boolean
): Byte;
var
  VExclusivelyLocked: Boolean;
begin
  Result := ParseVersionSource(AMakeVersionSource, AVerParsedInfo);
  if (Result <> ETS_RESULT_OK) then
    Exit;

  // ищем распарсенное
  AVerFoundInfo^.Clear;
  DoBeginWork(TRUE, so_ReloadVersions, VExclusivelyLocked);
  try
    ReadVersionsFromDB(AGuideConnection, TRUE);
    AVersionFound := FVersionList.FindItemByAnsiValue(PAnsiChar(AVerParsedInfo^.ver_value), AVerFoundInfo);
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.ParseVersionSource(const AVersionSource: String; const AVerParsedInfo: PVersionAA): Byte;
const
  c_BR = '<br>';

  function _AllowSaveQualifierValue(const AQualifier, ATextValue: String): Boolean;
  var VLWC: String;
  begin
    // не сохраняем пустоту
    if (0 = Length(ATextValue)) then begin
      Result := FALSE;
      Exit;
    end;
    // не сохраняем тэги и ссылки
    if (System.Pos('<', ATextValue) > 0) then begin
      Result := FALSE;
      Exit;
    end;
    if (System.Pos('://', ATextValue) > 0) then begin
      Result := FALSE;
      Exit;
    end;

    // не сохраняем устаревшие и линки
    VLWC := LowerCase(AQualifier);
    if (System.Pos('link', VLWC) > 0) then begin
      Result := FALSE;
      Exit;
    end;
    if (System.Pos('legacy', VLWC) > 0) then begin
      Result := FALSE;
      Exit;
    end;
    
    Result := TRUE;
  end;

  procedure _ParseExtractedValue(const AParsedLine: String);
  var
    VPos: Integer;
    VQualifier, VTextValue: String;
  begin
    VPos := System.Pos(':', AParsedLine);
    if (VPos>0) then begin
      // вариант 1
      VQualifier := Trim(System.Copy(AParsedLine, 1, (VPos-1)));
      VTextValue := Trim(System.Copy(AParsedLine, (VPos+1), Length(AParsedLine)));
      if _AllowSaveQualifierValue(VQualifier, VTextValue) then begin
        // URL-ы и прочие тэги пропускаем
        if SameText(VQualifier, 'FeatureId') then begin
          // в ver_value
          AVerParsedInfo^.ver_value := VTextValue;
        end else if SameText(VQualifier, 'Date') then begin
          // в ver_date
          if not ParseFullyQualifiedDateTime(VTextValue, AVerParsedInfo^.ver_date) then begin
            AVerParsedInfo^.ver_date := c_ZeroVersionNumber_DateTime;
          end;
          // в ver_number
          AVerParsedInfo^.ver_number := GetVersionNumberForDateTimeAsZeroDifference(AVerParsedInfo^.ver_date);
        end else begin
          // всё прочее в ver_comment через запятую
          if (0<Length(AVerParsedInfo^.ver_comment)) then
            AVerParsedInfo^.ver_comment := AVerParsedInfo^.ver_comment + ',';
          AVerParsedInfo^.ver_comment := AVerParsedInfo^.ver_comment + VTextValue;
        end;
      end;
    end;
  end;

var
  VStartingPos, VEndOfTagPos: Integer;
  VExtractValue: String;
begin
  Result := ETS_RESULT_OK;

(*
вариант 1:

FeatureId:ae1371a7a7ae56e357643268c9d05f05
<br>
Date:2011-05-13 08:02:41.889
<br>
Color:Panchromatic
<br>
Resolution:0.50
<br>
DataLayer:country_coverage
<br>
Source:WV01
<br>
LegacyId:1020010013D9CA00
<br>
Provider:DigitalGlobe
<br>
PreviewLink:<a href=https://browse.digitalglobe.com/imagefinder/showBrowseImage?catalogId=1020010013D9CA00&imageHeight=1024&imageWidth=1024>https://browse.digitalglobe.com/imagefinder/showBrowseImage?catalogId=1020010013D9CA00&imageHeight=1024&imageWidth=1024</a>
<br>
MetadataLink:<a href=https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?buffer=1.0&catalogId=1020010013D9CA00&imageHeight=natres&imageWidth=natres>https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?buffer=1.0&catalogId=1020010013D9CA00&imageHeight=natres&imageWidth=natres</a>

обработка:
FeatureId в ver_value
Date в ver_date
ver_number считаем как разницу между ver_date и "началом отсчёта"
ver_comment заполняем остальными значениями через запятую (кроме тэгов и УРЛов)
*)

  // парсим
  AVerParsedInfo^.Clear;

  VStartingPos := System.Pos(c_BR, AVersionSource);
  if (VStartingPos>0) then begin
    // определили как HTML
    // парсим первый кусок до переноса строки
    _ParseExtractedValue(System.Copy(AVersionSource, 1, (VStartingPos-1)));
    //  парсим остальное
    while ExtractFromTag(AVersionSource, c_BR, c_BR, VStartingPos, VExtractValue, VEndOfTagPos) do begin
      _ParseExtractedValue(VExtractValue);
      // next
      VStartingPos := VEndOfTagPos - Length(c_BR);
    end;
  end;

  if (0=Length(AVerParsedInfo^.ver_value)) then
    Result := ETS_RESULT_UNKNOWN_VERSION;
end;

function TDBMS_Provider.ParseVerValueToVerNumber(
  const AGivenVersionValue: String;
  out ADoneVerNumber: Boolean;
  out ADateTimeIsDefined: Boolean;
  out ADateTimeValue: TDateTime
): Integer;
var
  p: Integer;

  function _ExtractTailByte: Byte;
  var
    s: String;
    v: Integer;
  begin
    // пропускаем нечисловые
    while (p>0) and (not (AGivenVersionValue[p] in ['0','1'..'9'])) do begin
      Dec(p);
    end;
    // копируем числовые
    s := '';
    while (p>0) and ((AGivenVersionValue[p] in ['0','1'..'9'])) do begin
      s := AGivenVersionValue[p] + s;
      Dec(p);
    end;
    // смотрим чего получилось
    if TryStrToInt(s, v) then
    if (v>=0) and (v<=255) then begin
      Result := LoByte(v);
      Exit;
    end;
    
    Result := 0;
  end;
  
var
  n1,n2,n3,n4: Byte;
begin
  // пробуем распарсить значение типа 2.33.0 и преобразовать в 0*256^0 + 33*256^1 + 2*256^2
  // чтобы впихнуть это в ver_number - для дальнейшей более быстрой сортировки версий
  // в любом случае если ничего не получилось - смело можно вернуть 0
  // здесь строка с версией заведомо не пустая
  //Result := 0;
  ADoneVerNumber := FALSE;
  ADateTimeIsDefined := FALSE;

  // для роскосмоса версия в виде 2011-08-25_18-15-38
  // дату из неё понятно как получаем
  // номер получаем как разницу (в секундах) между датой и фиксированной датой (со знаком)
  if ParseFullyQualifiedDateTime(AGivenVersionValue, ADateTimeValue) then begin
    ADateTimeIsDefined := TRUE;
    ADoneVerNumber := TRUE;
    Result := GetVersionNumberForDateTimeAsZeroDifference(ADateTimeValue);
    Exit;
  end;

  // пробуем разобрать byte.byte.byte.byte (справа налево!)
  p := Length(AGivenVersionValue);
  n4 := _ExtractTailByte;
  n3:= _ExtractTailByte;
  n2 := _ExtractTailByte;
  n1 := _ExtractTailByte;
  Result := (Integer(n1) shl 24) or (Integer(n2) shl 16) or (Integer(n3) shl 8) or Integer(n4);
  ADoneVerNumber := (Result<>0);
end;

function TDBMS_Provider.GetStatementExceptionType(
  const ATilesConnection: IDBMS_Connection;
  const AException: Exception
): TStatementExceptionType;
var
  VMessage: String;
  VEngineType: TEngineType;
begin
  // смотрим по SQLSTATE и родному коду ошибки
  // сразу отсечём лишнее
  VMessage := System.Copy(AException.Message, 1, c_ODBC_SQLSTATE_MAX_LEN);

  if (0=Length(VMessage)) then begin
    // нет кода ошибки
    Result := set_Unknown;
    Exit;
  end;

  VMessage := UpperCase(VMessage);

  if (nil=ATilesConnection) then
    VEngineType := et_Unknown
  else
    VEngineType := ATilesConnection.GetCheckedEngineType;
  
  // проверка нарушения уникальности (не обязательно описано как PRIMARY KEY)
  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_PrimaryKeyViolation[et_Unknown]) then begin
    // залетели по маске - уточним её для определённых СУБД
    if (et_Unknown=VEngineType) then begin
      // неизвестный сервер - нет данных для уточнения
      Result := set_PrimaryKeyViolation;
      Exit;
    end else begin
      // можем уточнить по известному коду ошибки
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_PrimaryKeyViolation[VEngineType]) then begin
        // оно самое
        Result := set_PrimaryKeyViolation;
        Exit;
      end;
      // тут окажемся, если код ошибки похожий, но не такой
    end;
  end;


  // проверка отсутствия отношения (таблицы или вьюхи)
  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_1[et_Unknown]) then begin
    // залетели по маске - уточним её для определённых СУБД
    if (et_Unknown=VEngineType) then begin
      // неизвестный сервер - нет данных для уточнения
      Result := set_TableNotFound;
      Exit;
    end else begin
      // можем уточнить по известному коду ошибки
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_1[VEngineType]) then begin
        Result := set_TableNotFound;
        Exit;
      end;
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_2[VEngineType]) then begin
        Result := set_TableNotFound;
        Exit;
      end;
      // тут окажемся, если код ошибки похожий, но не такой
    end;
  end;

  // может ошибка про то что место кончилось
  if (0<Length(c_ODBC_SQLSTATE_NoSpaceAvailable_1[VEngineType])) then begin
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_NoSpaceAvailable_1[VEngineType]) then begin
      Result := set_NoSpaceAvailable;
      Exit;
    end;
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_NoSpaceAvailable_2[VEngineType]) then begin
      Result := set_NoSpaceAvailable;
      Exit;
    end;
  end;

  // может соединение разорвано
  if (0<Length(c_ODBC_SQLSTATE_ConnectionIsDead_1[VEngineType])) then begin
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_ConnectionIsDead_1[VEngineType]) then begin
      Result := set_ConnectionIsDead;
      DoOnDeadConnection(ATilesConnection);
      Exit;
    end;
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_ConnectionIsDead_2[VEngineType]) then begin
      Result := set_ConnectionIsDead;
      DoOnDeadConnection(ATilesConnection);
      Exit;
    end;
  end;

  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_DataTruncation[VEngineType]) then begin
    Result := set_DataTruncation;
    Exit;
  end;

  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_UnsynchronizedStatements[VEngineType]) then begin
    Result := set_UnsynchronizedStatements;
    Exit;
  end;

  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_ReadOnlyConnection[VEngineType]) then begin
    Result := set_ReadOnlyConnection;
    Exit;
  end;

  // 'HY000:955:[ORACLE][ODBC][ORA]ORA-00955: NAME IS ALREADY USED BY AN EXISTING OBJECT'#$A

  // что-то иное
  Result := set_Unknown;
  SaveUnknownException(AException);
end;

function TDBMS_Provider.GetUndefinedConnection: IDBMS_Connection;
begin
  Result := FUndefinedConnnection
end;

function TDBMS_Provider.GetUnknownExceptions: String;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    if (nil=FUnknownExceptions) then
      Result := ''
    else
      Result := FUnknownExceptions.Text;
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

procedure TDBMS_Provider.ReadContentTypesFromDB(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean
);
var
  VOdbcFetchColsEx: TOdbcFetchCols2;
  VSQLText: TDBMS_String;
  VNewItem: TContentTypeA;
begin
  Assert(AExclusively);
  try
    FContentTypeList.SetCapacity(0);

    VSQLText := 'SELECT id_contenttype,contenttype_text' +
                 ' FROM ' + AGuideConnection.ForcedSchemaPrefix + Z_CONTENTTYPE;

    VOdbcFetchColsEx.Init;
    try
      AGuideConnection.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));

      if not VOdbcFetchColsEx.Base.IsActive then
        Exit;

      // если без датасетов - число записей неизвестно - забацаем 16
      FContentTypeList.SetCapacity(16);

      // перечисляем
      while VOdbcFetchColsEx.Base.FetchRecord do begin
        // добавляем запись в список
        with VOdbcFetchColsEx.Base do begin
          ColToSmallInt(1, VNewItem.id_contenttype);
          ColToAnsiString(2, VNewItem.contenttype_text);
        end;

        FContentTypeList.AddItem(@VNewItem);
      end;
    finally
      VOdbcFetchColsEx.Base.Close;
    end;
  except
  end;
end;

procedure TDBMS_Provider.ReadVersionsFromDB(
  const AGuideConnection: IDBMS_Connection;
  const AExclusively: Boolean
);
var
  VOdbcFetchColsEx: TOdbcFetchCols5;
  VSQLText: TDBMS_String;
  VNewItem: TVersionAA;
begin
  Assert(AExclusively);
  try
    // читаем все версии в почищенный список
    FVersionList.Clear;

    VSQLText := 'SELECT id_ver,ver_value,ver_date,ver_number,ver_comment' +
                 ' FROM ' + AGuideConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;

    VOdbcFetchColsEx.Init;
    try
      AGuideConnection.OpenDirectSQLFetchCols(VSQLText, @(VOdbcFetchColsEx.Base));

      if not VOdbcFetchColsEx.Base.IsActive then
        Exit;

      // перечисляем
      while VOdbcFetchColsEx.Base.FetchRecord do begin
        // добавляем поштучно
        with VOdbcFetchColsEx.Base do begin
          ColToSmallInt(1, VNewItem.id_ver);
          ColToAnsiString(2, VNewItem.ver_value);
          ColToDateTime(3, VNewItem.ver_date);
          ColToLongInt(4, VNewItem.ver_number);
          ColToAnsiString(5, VNewItem.ver_comment);
        end;

        FVersionList.AddItem(@VNewItem);
      end;
    finally
      VOdbcFetchColsEx.Base.Close;
    end;
  except
  end;
end;

procedure TDBMS_Provider.SaveUnknownException(const AException: Exception);
begin
  if (nil=AException) then
    Exit;
  FUnknownExceptionsCS.BeginWrite;
  try
    if (nil=FUnknownExceptions) then begin
      // создаём и добавляем
      FUnknownExceptions := TStringList.Create;
    end else begin
      // разделяем и добавляем
      FUnknownExceptions.Add('<br>');
    end;
    FUnknownExceptions.Add(AException.Message);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

function TDBMS_Provider.SQLDateTimeToDBValue(
  const ATilesConnection: IDBMS_Connection;
  const ADateTime: TDateTime
): TDBMS_String;
var
  VEngineType: TEngineType;
begin
  if (ATilesConnection<>nil) then
    VEngineType := ATilesConnection.GetCheckedEngineType
  else
    VEngineType := et_Unknown;

  if (VEngineType=et_MSSQL) then
    Result := DBMSStrToDB(FormatDateTime(c_DateTimeToDBFormat_MSSQL, ADateTime, FFormatSettings))
  else
    Result := c_SQL_DateTime_Literal_Prefix[VEngineType] +
              DBMSStrToDB(FormatDateTime(c_DateTimeToDBFormat_Common, ADateTime, FFormatSettings));
end;

function TDBMS_Provider.SQLDateTimeToVersionValue(const ADateTime: TDateTime): TDBMS_String;
begin
  Result := FormatDateTime(c_DateTimeToListOfVersions, ADateTime, FFormatSettings);
end;

function TDBMS_Provider.SwitchHostToVersion(const AVersionToSwitch: String): Byte;
var
  VCallback: Pointer;
  VOptions: TETS_SET_VERSION_OPTION;
begin
  VCallback := FHostCallbacks[ETS_INFOCLASS_SetVersion_Notifier];
  if (VCallback<>nil) then begin
    FillChar(VOptions, SizeOf(VOptions), 0);
    VOptions.szVersion := PChar(AVersionToSwitch);
    if (SizeOf(Char)=SizeOf(AnsiChar)) then
      VOptions.dwOptions := VOptions.dwOptions or ETS_SVO_ANSI_VALUES;
    
    Result := TETS_SetVersion_Notifier(VCallback)(
      FHostPointer,
      FHostPointer,
      @VOptions
    );
  end else begin
    Result := ETS_RESULT_NOT_IMPLEMENTED;
  end;
end;

function TDBMS_Provider.TryToObtainVerByTile(
  const AExclusively: Boolean;
  var ARequestedVersionFound: Boolean;
  const AIdContentType: SmallInt;
  var AVersionAutodetected: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  AReqVersionPtr: PVersionAA
): Byte;
var
  VExifAttr: PByte;
  VLen: DWORD;
  VNeedFindVersion: Boolean;
begin
  // смотрим настройки сохранения тайлов
  // при каких условиях (в зависимости от найденной версии)
  // надо или нет парсить тайл
  if (c_Tile_Parser_None=FDBMS_Service_Info.new_ver_by_tile) then begin
    // отключено вообще - ничего не трогаем
    Result := ETS_RESULT_OK;
    Exit;
  end else if (0=Length(AReqVersionPtr^.ver_value)) then begin
    // запрошена пустая версия
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_EMPTY) = 0) then begin
      // для пустой версии парсер тайлов отключен
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end else if ARequestedVersionFound then begin
    // запрошенная версия найдена
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_KNOWN) = 0) then begin
      // для найденных версий парсер тайлов отключен
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end else begin
    // запрошенная версия не найдена
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_UNKNOWN) = 0) then begin
      // для ненайденных версий парсер тайлов отключен
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end;

  VNeedFindVersion := FALSE;
  
  case FDBMS_Service_Info.new_ver_by_tile of
    // парсер как для тайлов GE - тащим дату из тайла
    (*
    c_Tile_Parser_Exif_GE: begin
      // парсим тайл как jpeg и достаём из него гуглодату (больше там ничего нет)
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, TRUE, $0000, VExifAttr, VLen) then begin
        Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      Result := ParseExifForGE(
        VExifAttr,
        VLen,
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
    *)
    
    c_Tile_Parser_Exif_NMC_Unique, c_Tile_Parser_Exif_NMC_Latest: begin
      // парсим тайл как jpeg и достаём из него EXIF ($9286=UserComment)
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE, $9286, VExifAttr, VLen) then begin
        // а тут чтобы можно было генерить зумы наверх, возможно надо сделать поблажку
        if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_ALLOW_NO_EXIF) <> 0) then
          Result := ETS_RESULT_OK
        else
          Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      // здесь типа EXIF достали - определяем из него параметры версии (кроме id_ver)
      Result := ParseExifForNMC(
        VExifAttr,
        VLen,
        // версию фильтруем только если она найдена и не пустая
        ARequestedVersionFound and (0<Length(AReqVersionPtr^.ver_value)),
        AReqVersionPtr^.ver_value,
        // признак что надо брать уникальный идентификатор версии тайла
        (c_Tile_Parser_Exif_NMC_Unique=FDBMS_Service_Info.new_ver_by_tile),
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
      AVersionAutodetected := TRUE;
    end;

    (*
    c_Tile_Parser_Exif_DG_Catalog: begin
      // парсер для каталога DigitalGlobe - очень похоже на NMC
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE, $9286, VExifAttr, VLen) then begin
        Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      // здесь типа EXIF достали - определяем из него параметры версии (кроме id_ver)
      Result := ParseExifUserComment(
        VExifAttr,
        VLen,
        ARequestedVersionFound,
        AReqVersionPtr^.ver_value,
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
    *)

    else begin
      // неизвестный алгоритм - пока что будем ругаться
      Result := ETS_RESULT_UNKNOWN_VERBYTILE;
      Exit;
    end;
  end;

  // если версия поменялась - надо найтись
  if (Result=ETS_RESULT_OK) then
  if VNeedFindVersion then begin
    ARequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AReqVersionPtr^.ver_value),
      AReqVersionPtr
    );
  end;


end;

function TDBMS_Provider.Uninitialize: Byte;
begin
  FUninitialized := True;
  Result := 0;
end;

function TDBMS_Provider.UpdateServiceVerComp(
  const AGuideConnection: IDBMS_Connection;
  const ANewVerCompMode: AnsiChar;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := AGuideConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  VSQLText := 'UPDATE ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET id_ver_comp=' + DBMSStrToDB(ANewVerCompMode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
    // success
    FStatusBuffer^.id_ver_comp := ANewVerCompMode;
    FDBMS_Service_Info.id_ver_comp := ANewVerCompMode;
  except
    on E: Exception do begin
      AErrorText := E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateTileLoadMode(
  const AGuideConnection: IDBMS_Connection;
  const ANewTLMFlag: Byte;
  const AEnabled: Boolean;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := AGuideConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // даже если в БД не обновимся - в памяти всё равно надо менять значения
  if AEnabled then
    FStatusBuffer^.tile_load_mode     := FStatusBuffer^.tile_load_mode or ANewTLMFlag
  else
    FStatusBuffer^.tile_load_mode     := FStatusBuffer^.tile_load_mode and not ANewTLMFlag;

  FDBMS_Service_Info.tile_load_mode := FStatusBuffer^.tile_load_mode;

  // забацаем запрос
  VSQLText := 'UPDATE ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET tile_load_mode='  + IntToStr(FStatusBuffer^.tile_load_mode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
  except
    on E: Exception do begin
      AErrorText := 'Failed to store new value in database' + '<br>' + E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateTileSaveMode(
  const AGuideConnection: IDBMS_Connection;
  const ANewTSMFlag: Byte;
  const AEnabled: Boolean;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := AGuideConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // даже если в БД не обновимся - в памяти всё равно надо менять значения
  if AEnabled then
    FStatusBuffer^.tile_save_mode     := FStatusBuffer^.tile_save_mode or ANewTSMFlag
  else
    FStatusBuffer^.tile_save_mode     := FStatusBuffer^.tile_save_mode and not ANewTSMFlag;

  FDBMS_Service_Info.tile_save_mode := FStatusBuffer^.tile_save_mode;

  // забацаем запрос
  VSQLText := 'UPDATE ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET tile_save_mode='  + IntToStr(FStatusBuffer^.tile_save_mode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
  except
    on E: Exception do begin
      AErrorText := 'Failed to store new value in database' + '<br>' + E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateVerByTileMode(
  const AGuideConnection: IDBMS_Connection;
  const ANewVerByTileMode: SmallInt;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := AGuideConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // забацаем запрос
  VSQLText := 'UPDATE ' + AGuideConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET new_ver_by_tile=' + IntToStr(ANewVerByTileMode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    AGuideConnection.ExecuteDirectSQL(VSQLText, FALSE);
    // это сильно необязательная функциональность
    // для её использования будем требовать соответствия структуры БД второй версии модели
    FStatusBuffer^.new_ver_by_tile := ANewVerByTileMode;
    FDBMS_Service_Info.new_ver_by_tile := ANewVerByTileMode;
  except
    on E: Exception do begin
      AErrorText := E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UseSectionByTableXY: Boolean;
begin
  // сейчас секционирование по табличым координатам используется
  // тогда и только тогда, когда используются удалённые таблицы
  Result := (tssal_Linked = FPrimaryConnnection.FTSS_Primary_Params.Algorithm)
end;

function TDBMS_Provider.UseSectionByTileXY: Boolean;
begin
  Result := (tssal_Linked <> FPrimaryConnnection.FTSS_Primary_Params.Algorithm)
end;

function TDBMS_Provider.VersionExistsInDBWithIdVer(
  const AGuideConnection: IDBMS_Connection;
  const AIdVersion: SmallInt
): Boolean;
var
  VSqlText: TDBMS_String;
begin
  VSqlText := 'SELECT id_ver' +
               ' FROM ' + AGuideConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB +
              ' WHERE id_ver=' + IntToStr(AIdVersion);
  try
    Result := AGuideConnection.CheckDirectSQLSingleNotNull(VSqlText);
  except
    Result := FALSE;
  end;
end;

end.
