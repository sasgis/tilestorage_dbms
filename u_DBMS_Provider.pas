unit u_DBMS_Provider;

{$include i_DBMS.inc}

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
  u_ExecuteSQLArray,
  u_DBMS_Utils;

type
  TDBMS_Provider = class(TInterfacedObject, IDBMS_Provider)
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

    // признак необходимости переподключиться
    // поднимается при разрыве соединения сервером
    FReconnectPending: Boolean;

    // callbacks
    FHostCallbacks: TDBMS_INFOCLASS_Callbacks;
    
    // GlobalStorageIdentifier and ServiceName
    FPath: TETS_Path_Divided_W;

    // connection objects
    FConnection: IDBMS_Connection;

    // guides
    FVersionList: TVersionList;
    FContentTypeList: TContentTypeList;
    // primary ContentTpye from Host (from Map params)
    FPrimaryContentType: AnsiString;

    // flag (read successfully)
    FDBMS_Service_OK: Boolean;
    // service and global server params
    FDBMS_Service_Info: TDBMS_Service_Info;
    // service code (in DB only)
    FDBMS_Service_Code: AnsiString;

    // настройки формата для дат и чисел
    FFormatSettings: TFormatSettings;

    // препарированные датасеты для вставки и обновления
    (*
    FInsertDS: array [TInsertUpdateSubType] of TDBMS_Dataset;
    FUpdateDS: array [TInsertUpdateSubType] of TDBMS_Dataset;
    *)
  private
    // common work
    procedure DoBeginWork(
      const AExclusively: Boolean;
      const AOperation: TSqlOperation;
      out AExclusivelyLocked: Boolean
    );
    procedure DoEndWork(const AExclusivelyLocked: Boolean);
    // work with guides
    procedure GuidesBeginWork(const AExclusively: Boolean);
    procedure GuidesEndWork(const AExclusively: Boolean);

    procedure ReadVersionsFromDB(const AExclusively: Boolean);
    procedure ReadContentTypesFromDB(const AExclusively: Boolean);
  private
    procedure InternalProv_Cleanup;

    function InternalProv_SetStorageIdentifier(
      const AInfoSize: LongWord;
      const AInfoData: PETS_SET_IDENTIFIER_INFO;
      const AInfoResult: PLongWord
    ): Byte;

    function InternalProv_Connect(const AExclusively: Boolean): Byte;
    function InternalProv_ReadServiceInfo(const AExclusively: Boolean): Byte;
    procedure InternalProv_ClearServiceInfo;
    procedure InternalProv_Disconnect;
    procedure InternalProv_ClearGuides;

    // возвращает имя сервиса, используемое в БД (внутреннее)
    function InternalGetServiceNameByDB: TDBMS_String;
    // возвращает имя сервиса, используемое в хосте (внешнее)
    function InternalGetServiceNameByHost: TDBMS_String;

    // get version from cache (if not found - read from server)
    function InternalGetVersionAnsiValues(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean;
      const AVerValuePtr: PPAnsiChar;
      out AVerValueStr: AnsiString
    ): Boolean;

    // get contenttype from cache (if not found - read from server)
    function InternalGetContentTypeAnsiValues(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean;
      const AContentTypeTextPtr: PPAnsiChar;
      out AContentTypeTextStr: AnsiString
    ): Boolean;

  private
    // for cached version
    function GetVersionAnsiPointer(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetVersionWideString(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

    // for cached contenttype
    function GetContentTypeAnsiPointer(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetContentTypeWideString(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

  private
    function SQLDateTimeToDBValue(const ADateTime: TDateTime): TDBMS_String;

    function GetSQLIntName_Div(const AXYMaskWidth, AZoom: Byte): String;

    function GetStatementExceptionType(const AException: Exception): TStatementExceptionType;
  private
    function CreateAllBaseTablesFromScript: Byte;
    
    // автоматическое создание записи о текущем сервисе (регистрация сервиса в БД)
    function AutoCreateServiceRecord(const AExclusively: Boolean): Byte;

    // автоматическое создание версии для сервиса
    function AutoCreateServiceVersion(
      const AExclusively: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AReqVersionPtr: PVersionAA;
      out ARequestedVersionFound: Boolean
    ): Byte;

    function GetMaxNextVersionInts(const ANewVersionPtr: PVersionAA; const AKeepVerNumber: Boolean): Boolean;

    // функция для разбора строкового значения версии в целое число для нецелочисленных версий
    function ParseVerValueToVerNumber(
      const AGivenVersionValue: String;
      out ADoneVerNumber: Boolean
    ): Integer;

    function MakePtrVersionInDB(
      const ANewVersionPtr: PVersionAA;
      const AExclusively: Boolean
    ): Boolean;
    
    function MakeEmptyVersionInDB(
      const AIdVersion: SmallInt;
      const AExclusively: Boolean
    ): Boolean;
    
    function VersionExistsInDBWithIdVer(const AIdVersion: SmallInt): Boolean;

    // check if tile is in common tiles
    function CheckTileInCommonTiles(
      const ATileBuffer: Pointer;
      const ATileSize: LongInt;
      out AUseAsTileSize: LongInt
    ): Boolean;

    // create table using SQL commands from special table
    function CreateTableByTemplate(
      const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
      const AZoom: Byte;
      const ASubstSQLTypes: Boolean
    ): Byte;

    // divide XY into parts (upper - to tablename, lower - to identifiers)
    procedure InternalDivideXY(
      const AXY: TPoint;
      const ASQLTile: PSQLTile
    );

    function InternalCalcSQLTile(
      const AXYZ: PTILE_ID_XYZ;
      const ASQLTile: PSQLTile
    ): Byte;

    function FillTableNamesForTiles(
      ASQLTile: PSQLTile
    ): Boolean;

    function CalcBackToTilePos(
      XInTable, YInTable: Integer;
      const AXYUpperToTable: TPoint; //ASelectInRectItem: PSelectInRectItem;
      AXYResult: PPoint
    ): Boolean;

    function GetSQL_AddIntWhereClause(
      var AWhereClause: TDBMS_String;
      const AFieldName: TDBMS_String;
      const AWithMinBound, AWithMaxBound: Boolean;
      const AMinBoundValue, AMaxBoundValue: Integer
    ): Boolean;

  private
    procedure AddVersionOrderBy(
      const ASQLParts: PSQLParts;
      const AVerInfoPtr: PVersionAA;
      const ACutOnVersion: Boolean
    );

    // формирование текста SQL для чтения тайлов из разных режимов
    function GetSQL_SelectTilesInternal(
      const ASQLTile: PSQLTile;
      const AVersionIn: Pointer;
      const AOptionsIn: LongWord;
      const AInitialWhere: TDBMS_String;
      const ASelectXY: Boolean;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
    // формирование текста SQL для получения (SELECT) тайла или маркера TNE
    function GetSQL_SelectTile(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // формирование текста SQL для вставки (INSERT) и обновления (UPDATE) тайла или маркера TNE
    // в тексте SQL возможны только параметр c_RTL_Tile_Body_Paramname, остальное подставляется сразу
    function GetSQL_InsertUpdateTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
      out AInsertUpdateSubType: TInsertUpdateSubType;
      out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
    ): Byte;

    // формирование текста SQL для удаления (DELETE) тайла или маркера TNE
    function GetSQL_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      out ADeleteSQLResult: TDBMS_String
    ): Byte;

    // формирование текста SQL для получения (SELECT) списка существующих версий тайла (XYZ)
    function GetSQL_EnumTileVersions(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // формирует список команд SQL для получения карты заполнения по нескольким таблица
    function GetSQL_GetTileRectInfo(
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN;
      const AExclusively: Boolean;
      ASelectInRectList: TSelectInRectList
    ): Byte;

    // формирует SQL для получения списка версий для текущего сервиса
    function GetSQL_SelectVersions: TDBMS_String;

    // формирует SQL для получения списка типов тайлов
    function GetSQL_SelectContentTypes: TDBMS_String;

    // формирует SQL для чтения параметров сервиса по его внешнему коду
    // этот уникальный внешний код передаётся при инициализации с хоста
    function GetSQL_SelectService_ByHost: TDBMS_String;

    // формирует SQL для чтения параметров сервиса по его внутреннему коду (код в БД)
    function GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): TDBMS_String;

    function GetSQL_InsertIntoService(
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
  private
    function DBMS_HandleGlobalException(const E: Exception): Byte;

    function DBMS_Complete(const AFlags: LongWord): Byte;

    // sync provider
    function DBMS_Sync(const AFlags: LongWord): Byte;

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
  u_DBMS_Template;

{ TDBMS_Provider }

procedure TDBMS_Provider.AddVersionOrderBy(
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
      // order by ver_value
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_date', SQLDateTimeToDBValue(AVerInfoPtr^.ver_date))
      else
        _AddWithoutFieldValue('ver_date');
    end;
    TILE_VERSION_COMPARE_NUMBER: begin
      // order by ver_value
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

function TDBMS_Provider.AutoCreateServiceRecord(const AExclusively: Boolean): Byte;
var
  VSQLText: TDBMS_String;
begin
  // регистрация картосервиса в БД выполняется только в эксклюзивном режиме
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  // сформируем текст SQL для создания записи
  Result := GetSQL_InsertIntoService(AExclusively, VSQLText);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // исполняем INSERT (вставляем запись о сервисе)
  try
    if FConnection.ExecuteDirectSQL(VSQLText) then
      Result := ETS_RESULT_OK
    else
      Result := ETS_RESULT_INVALID_STRUCTURE;
  except
    // обломались
    Result := ETS_RESULT_INVALID_STRUCTURE;
  end;
end;

function TDBMS_Provider.AutoCreateServiceVersion(
  const AExclusively: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AReqVersionPtr: PVersionAA;
  out ARequestedVersionFound: Boolean
): Byte;
var
  VVerIsInt: Boolean;
  VKeepVerNumber: Boolean;
  VGenerateNewIdVer: Boolean;
  VFoundAnotherVersionAA: TVersionAA;
begin
  // запрошенные версии создаются только в эксклюзивном режиме
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  // получим запрошенную версию
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
    // TODO: try to use 0 as id_ver
    if (not VersionExistsInDBWithIdVer(0)) then begin
      MakeEmptyVersionInDB(0, AExclusively);
      ReadVersionsFromDB(AExclusively);
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(0, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;

    // TODO: failed - use min(min-1,-1) as id_ver
    (*
    if (not VersionExistsInDBWithIdVer(-1)) then begin
      MakeEmptyVersionInDB(-1);
      ReadVersionsFromDB;
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(-1, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;
    *)

    // TODO: make correct loop
    ARequestedVersionFound := FALSE;
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  AReqVersionPtr^.ver_date := NowUTC;
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

  if VVerIsInt and (Abs(AReqVersionPtr^.ver_number)<=32767) then begin
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
    AReqVersionPtr^.ver_number := ParseVerValueToVerNumber(AReqVersionPtr^.ver_value, VKeepVerNumber);
  end;

  if VGenerateNewIdVer then begin
    // генерим новый id_ver (и возможно ver_number)
    GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
  end;

  repeat
    if MakePtrVersionInDB(AReqVersionPtr, AExclusively) then begin
      ReadVersionsFromDB(AExclusively);
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

function TDBMS_Provider.CalcBackToTilePos(
  XInTable, YInTable: Integer;
  const AXYUpperToTable: TPoint;
  AXYResult: PPoint
): Boolean;
var
  VXYMaskWidth: Byte;
begin
  // рассчитываем обратным расчётом тайловые координаты
  // исходя из параметров деления по таблицам и координат (идентификатора) внутри таблицы
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  // общая часть
  AXYResult^.X := XInTable;
  AXYResult^.Y := YInTable;

  // если делились по таблицам - добавим "верхнюю" часть
  if (0<VXYMaskWidth) then begin
    AXYResult^.X := AXYResult^.X or (AXYUpperToTable.X shl VXYMaskWidth);
    AXYResult^.Y := AXYResult^.Y or (AXYUpperToTable.Y shl VXYMaskWidth);
  end;

  Result := TRUE;

{
  // прямой расчёт:
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
}
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
  FReconnectPending := FALSE;
  
  // initialization
  FStatusBuffer := AStatusBuffer;
  FInitFlags := AFlags;
  FHostPointer := AHostPointer;

  FPrimaryContentType := '';

  // sync objects
  FProvSync := MakeSyncRW_Std(Self);
  FGuidesSync := MakeSyncRW_Std(Self);

  FConnection := nil;

  FVersionList := TVersionList.Create;
  FContentTypeList := TContentTypeList.Create;

  InternalProv_Cleanup;
end;

function TDBMS_Provider.CreateAllBaseTablesFromScript: Byte;
var
  VUniqueEngineType: String;
  VSQLTemplates: TDBMS_SQLTemplates_File;
begin
  // получим уникальный код типа СУБД
  VUniqueEngineType := c_SQL_Engine_Name[FConnection.GetCheckedEngineType];
  // если пусто - значит неизвестный типа СУБД, и ловить тут нечего
  if (0=Length(VUniqueEngineType)) then begin
    Result := ETS_RESULT_UNKNOWN_DBMS;
    Exit;
  end;

  // создадим объект для генерации структуры для конкретного типа БД
  VSQLTemplates := TDBMS_SQLTemplates_File.Create(
    VUniqueEngineType,
    FConnection.ForcedSchemaPrefix,
    FConnection.GetInternalParameter(ETS_INTERNAL_SCRIPT_APPENDER)
  );
  try
    // исполним всё что есть
    Result := VSQLTemplates.ExecuteAllSQLs(FConnection);
  finally
    VSQLTemplates.Free;
  end;
end;

function TDBMS_Provider.CreateTableByTemplate(
  const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
  const AZoom: Byte;
  const ASubstSQLTypes: Boolean
): Byte;
var
  VDataset: TDBMS_Dataset;
  VExecuteSQLArray: TExecuteSQLArray;
  VSQLText: TDBMS_String;
  //VSQLAnsi: AnsiString;
  Vignore_errors: AnsiChar;
  //VStream: TStream;
  //VMemStream: TMemoryStream;
  VReplaceNumeric: String;
  i: Integer;
begin
  // а вдруг нет базовой таблицы с шаблонами
  if (not FConnection.TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
    // создадим базовые таблицы
    CreateAllBaseTablesFromScript;
    // а вдруг обломались?
    if (not FConnection.TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
      // полный отстой и нам тут делать нечего
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // если запрошенная таблица уже есть - валим
  if (FConnection.TableExists(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // вытащим все запросы SQL для CREATE (операция "C") для запрошенного шаблона
  VExecuteSQLArray := nil;
  try
    VDataset := FConnection.MakePoolDataset;
    try
      VSQLText := 'select index_sql,ignore_errors,object_sql from ' + FConnection.ForcedSchemaPrefix + Z_ALL_SQL+
                  ' where object_name=' + DBMSStrToDB(ATemplateName) +
                    ' and object_oper=''C'' and skip_sql=''0'' order by index_sql';
      VDataset.OpenSQL(VSQLText);

      if VDataset.IsEmpty then begin
        // ничего не прочиталось - значит нет шаблона
        Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
        Exit;
      end;

      // что-то в датасете есть
      VExecuteSQLArray := TExecuteSQLArray.Create;

      VDataset.First;
      while (not VDataset.Eof) do begin
        // тащим текст SQL для исполнения в порядке очерёдности
        Vignore_errors := VDataset.GetAnsiCharFlag('ignore_errors', ETS_UCT_YES);

        // если есть текст - добавляем его в список
        if VDataset.ClobAsWideString('object_sql', VSQLText) then begin
          // а тут надо подменить имя таблицы
          VSQLText := StringReplace(VSQLText, ATemplateName, AUnquotedTableNameWithoutPrefix, [rfReplaceAll,rfIgnoreCase]);

          if ASubstSQLTypes then begin
            // также необходимо подставить нуные типы полей для оптимального хранения XY
            // а именно - заменить numeric на INT нужной ширины
            VReplaceNumeric := GetSQLIntName_Div(FDBMS_Service_Info.XYMaskWidth, AZoom);
            VSQLText := StringReplace(VSQLText, c_RTL_Numeric, VReplaceNumeric, [rfReplaceAll,rfIgnoreCase]);
          end;

          VExecuteSQLArray.AddSQLItem(
            VSQLText,
            (Vignore_errors<>ETS_UCT_NO)
          );
        end;

        // - Следующий!
        VDataset.Next;
      end;

    finally
      FConnection.KillPoolDataset(VDataset);
    end;

    // а теперь если чего залетело в список - выполним
    if (VExecuteSQLArray<>nil) then
    if (VExecuteSQLArray.Count>0) then
    for i := 0 to VExecuteSQLArray.Count-1 do
    try
      // выполняем напрямую
      // TODO: после тестирования заменить FALSE на VExecuteSQLArray.GetSQLItem(i).SkipErrorsOnExec
      FConnection.ExecuteDirectSQL(VExecuteSQLArray.GetSQLItem(i).Text, FALSE);
    except
      // SilentMode in ExecuteDirectSQL may be a fake
      if (not VExecuteSQLArray.GetSQLItem(i).SkipErrorsOnExec) then
        raise;
    end;
  finally
    FreeAndNil(VExecuteSQLArray);
  end;

  // проверяем что табла успешно создалась
  if (FConnection.TableExists(AQuotedTableNameWithPrefix)) then begin
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
end;

function TDBMS_Provider.DBMS_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN
): Byte;
var
  VExclusive: Boolean;
  VDeleteSQL: TDBMS_String;
  VExclusivelyLocked: Boolean;
begin
  VExclusive := ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Delete, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // make DELETE statements
    Result := GetSQL_DeleteTile(
      ADeleteBuffer,
      VDeleteSQL
    );
      
    if (ETS_RESULT_OK<>Result) then
      Exit;

    try
      // execute DELETE statement
      if FConnection.ExecuteDirectSQL(VDeleteSQL, TRUE) then begin
        // done (successfully DELETEed)
        Result := ETS_RESULT_OK;
      end else begin
        // not deleted - may be:
        // no tile to delete from existing table
        // no table at all
        // disconnected
        // etc....
        Result := ETS_RESULT_OK;
      end;
    except
      on E: Exception do begin
        // проверка разрыва соединения
        Result := DBMS_HandleGlobalException(E);
        if FReconnectPending then
          Exit;
        // нет таблицы - нет и тайлов
        Result := ETS_RESULT_OK;
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
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_ENUM_TILE_VERSION_OUT;
  VETS_VERSION_W: TETS_VERSION_W;
  VETS_VERSION_A: TETS_VERSION_A;
  VVersionAA: TVersionAA;
  VSQLText: TDBMS_String;
  VVersionValueW, VVersionCommentW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_EnumVersions, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT id_ver from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_EnumTileVersions(ASelectBufferIn, VExclusive, VSQLText);
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

      // open sql
      try
        VDataset.OpenSQL(VSQLText);
      except
        on E: Exception do begin
          // проверка разрыва соединения
          Result := DBMS_HandleGlobalException(E);
          if FReconnectPending then
            Exit;
        end;
      end;

      // get values
      if (not VDataset.Active) then begin
        // table not found
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else if VDataset.IsEmpty then begin
        // nothing
        Result := ETS_RESULT_OK;
      end else begin
        // enum all items
        if (not VDataset.IsUniDirectional) then begin
          VEnumOut.ResponseCount := VDataset.RecordCount;
        end else begin
          VEnumOut.ResponseCount := -1; // unknown count
        end;
        VDataset.First;
        while (not VDataset.Eof) do begin
          // find selected version
          VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);

          if (not VVersionFound) then begin
            // необходимо обновление версии, так как вытащили из БД неизвестную ранее версию
            // очевидно она залетела в другом коннекте
            if (not VExclusive) then begin
              Result := ETS_RESULT_NEED_EXCLUSIVE;
              Exit;
            end;
            ReadVersionsFromDB(VExclusive);
            VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);
          end;

          if (not VVersionFound) then begin
            // OMG WTF
            VVersionAA.id_ver := VDataset.FieldByName('id_ver').AsInteger;
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
          VDataset.Next;
        end;

      end;
      
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_GetTileRectInfo(
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte;
var
  VExclusive: Boolean;
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_GET_TILE_RECT_OUT;
  VExclusivelyLocked: Boolean;
  VSelectInRectList: TSelectInRectList;
  VSelectInRectItem: PSelectInRectItem;
  i: Integer;
begin
  VExclusive := ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_SelectInRect, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

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
        VDataset := FConnection.MakePoolDataset;
        try
          // для каждой интересующей нас таблички
          for i := 0 to VSelectInRectList.Count-1 do begin
            // рабочая структура
            VSelectInRectItem := VSelectInRectList.SelectInRectItems[i];

            // для выхода из обоих циклов по ошибке из хоста инициализируем результат
            Result:=ETS_RESULT_OK;

            // открываемся
            try
              VDataset.OpenSQL(VSelectInRectItem^.FullSqlText);
            except
              // нет таблицы - нет данных - молча пропускаем
            end;

            if (VDataset.Active) and (not VDataset.IsEmpty) then begin
              // что-то открылось - перечислим это в хост
              VDataset.First;
              while (not VDataset.Eof) do begin
                // заполняем параметры
                VEnumOut.TileInfo.dwOptionsOut := ETS_ROO_SAME_VERSION;

                // заполняем TilePos тайловыми координатами тайла
                CalcBackToTilePos(
                  VDataset.FieldByName('x').AsInteger,
                  VDataset.FieldByName('y').AsInteger,
                  VSelectInRectItem.TabSQLTile.XYUpperToTable,
                  @(VEnumOut.TilePos)
                );

                // заполняем данные о тайле
                VEnumOut.TileInfo.dtLoadedUTC := VDataset.FieldByName('load_date').AsDateTime;
                VEnumOut.TileInfo.dwTileSize := VDataset.FieldByName('tile_size').AsInteger;
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

                // - Следующий!
                VDataset.Next;
              end;

            end;

            // тут должны выйти из обоих циклов: и из while, и из for
            if (Result<>ETS_RESULT_OK) then
              break;
          end; // for

        finally
          FConnection.KillPoolDataset(VDataset);
        end;
      end;

    finally
      FreeAndNil(VSelectInRectList);
    end;

  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_HandleGlobalException(const E: Exception): Byte;
begin
{$if defined(ETS_USE_ZEOS)}
  // обрабатываем разрыв соединения сервером
  if (E<>nil) and (System.Pos('ServerDisconnected', E.Classname)>0) then begin
    // разорвалось соединение
    Result := ETS_RESULT_DISCONNECTED;
    // взводим признак необходимости RECONNECT-а в эксклюзивном режиме
    FReconnectPending := TRUE;
  end else begin
    // все прочие глобальные ошибки
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
{$else}
  // для DBX и ODBC не обрабатываем разрыв соединения сервером
  Result := ETS_RESULT_PROVIDER_EXCEPTION;
{$ifend}
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
  VCastBodyAsHexLiteral: Boolean;
  VExecuteWithBlob: Boolean;
  VBodyAsLiteralValue: TDBMS_String;
  VExclusivelyLocked: Boolean;
begin
  VExclusive := ((AInsertBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Insert, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - INSERT tile to DB
      VStatementRepeatType := srt_None;
      
      // получим выражения INSERT и UPDATE
      Result := GetSQL_InsertUpdateTile(
        AInsertBuffer,
        AForceTNE,
        VExclusive,
        VInsertSQL,
        VUpdateSQL,
        VInsertUpdateSubType,
        VUnquotedTableNameWithoutPrefix,
        VQuotedTableNameWithPrefix
      );
      if (ETS_RESULT_OK<>Result) then
        Exit;

      if (iust_TILE=VInsertUpdateSubType) then begin
        // тело тайла есть в запросе
        VCastBodyAsHexLiteral := c_DBX_CastBlobToHexLiteral[FConnection.GetCheckedEngineType];
        if VCastBodyAsHexLiteral then
          VBodyAsLiteralValue := ConvertTileToHexLiteralValue(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize)
        else
          VBodyAsLiteralValue := '';
      end else begin
        // тело тайла вообще отсутствует в запросе
        VCastBodyAsHexLiteral := FALSE;
        VBodyAsLiteralValue := '';
      end;

      // запрос с передачей BLOBа или нет
      VExecuteWithBlob := (iust_TILE=VInsertUpdateSubType) and (not VCastBodyAsHexLiteral);

      // выполним INSERT
      try
        // может BLOB надо писать как 16-ричный литерал
        if VCastBodyAsHexLiteral then begin
          VInsertSQL := StringReplace(VInsertSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
        end;

        if VExecuteWithBlob then begin
          // INSERT with BLOB
          FConnection.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
        end else begin
          // INSERT without BLOB
          FConnection.ExecuteDirectSQL(VInsertSQL);
        end;
        
        // готово (вставлено!)
        Result := ETS_RESULT_OK;
      except on E: Exception do
        // обломались со вставкой новой записи

        // смотрим что за ошибка
        case GetStatementExceptionType(E) of
          set_PrimaryKeyViolation: begin
            // нарушение уникальности по первичному ключу - надо обновляться
            VStatementRepeatType := srt_Update;
          end;
          set_TableNotFound: begin
            // таблицы нет в БД
            if (not VExclusive) then begin
              // таблицы создаём только в эксклюзивном режиме
              Result := ETS_RESULT_NEED_EXCLUSIVE;
              Exit;
            end;

            // пробуем создать таблицу по шаблону
            CreateTableByTemplate(
                c_Templated_RealTiles,
                VUnquotedTableNameWithoutPrefix,
                VQuotedTableNameWithPrefix,
                AInsertBuffer^.XYZ.z,
                TRUE
              );

            // проверяем существование таблицы
            if (not FConnection.TableExists(VQuotedTableNameWithPrefix)) then begin
              // не удалось даже создать - валим
              Result := ETS_RESULT_TILE_TABLE_NOT_FOUND;
              Exit;
            end;

            // повторяем INSERT
            VStatementRepeatType := srt_Insert;
          end;
          else begin
            // неисправляемое исключение при выполнении запроса
            // на всякий случай запросим эксклюзивный режим
            if GetStatementExceptionType(E) <> set_PrimaryKeyViolation then // просто для отладки
            if VExclusive then
              Result := ETS_RESULT_INVALID_STRUCTURE
            else
              Result := ETS_RESULT_NEED_EXCLUSIVE;
            Exit;
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
          if VCastBodyAsHexLiteral then begin
            VUpdateSQL := StringReplace(VUpdateSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
          end;
          VInsertSQL := VUpdateSQL;
        end;

        try
          // здесь в VInsertSQL может быть и текст для UPDATE
          if VExecuteWithBlob then begin
            // UPDATE with BLOB
            FConnection.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end else begin
            // UPDATE without BLOB
            FConnection.ExecuteDirectSQL(VInsertSQL);
          end;

          // однако повторно получилось успешно
          VStatementRepeatType := srt_None;
          Result := ETS_RESULT_OK;
        except on E: Exception do
          // смотрим что за ошибка
          case GetStatementExceptionType(E) of
            set_PrimaryKeyViolation: begin
              // если при INSERT - уйдём на новый виток - на этот раз UPDATE
              // если при UPDATE - уйдём в слезах рекаверить датабазу из обломков былой роскоши
              if (VStatementRepeatType=srt_Update) then begin
                Result := ETS_RESULT_INVALID_STRUCTURE;
                Exit;
              end else
                VStatementRepeatType := srt_Update;
            end;
            set_TableNotFound: begin
              // какая-то бредятина
              Result := ETS_RESULT_INVALID_STRUCTURE;
              Exit;
            end;
            else begin
              // тоже не лучше
              Result := ETS_RESULT_INVALID_STRUCTURE;
              Exit;
            end;
          end;
        end;
      end;
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
  VDataset: TDBMS_Dataset;
  VOut: TETS_SELECT_TILE_OUT;
  VStream: TStream;
  Vid_ver, Vid_contenttype: SmallInt;
  VSQLText: TDBMS_String;
  VVersionW, VContentTypeW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Select, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT tile from DB
    VStream := nil;
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_SelectTile(ASelectBufferIn, VExclusive, VSQLText);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      FillChar(VOut, SizeOf(VOut), 0);

      // open sql
      try
        VDataset.OpenSQL(VSQLText);
      except
        on E: Exception do begin
          // проверка разрыва соединения
          Result := DBMS_HandleGlobalException(E);
          if FReconnectPending then
            Exit;
          // тут могут быть разные ошибки, типа таблица не найдена
        end;
      end;

      // get values
      if (not VDataset.Active) then begin
        // если таблицы с тайлами нет - значит тайлов этого зума нет - обычная ситуация
        Result := ETS_RESULT_OK;
      end else if VDataset.IsEmpty then begin
        // таблица есть, но тайлов нет
        Result := ETS_RESULT_OK;
      end else begin
        // get first item (because of 'order by' clause)
        VOut.dtLoadedUTC := VDataset.FieldByName('load_date').AsDateTime;
        VOut.dwTileSize := VDataset.FieldByName('tile_size').AsInteger;
        // check if tile of tne
        if (VOut.dwTileSize<=0) then begin
          // tne
          VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TNE_EXISTS;
        end else begin
          // tile
          VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TILE_EXISTS;
          // get body
          VStream := VDataset.CreateFieldBlobReadStream('tile_body');
          VOut.ptTileBuffer := (VStream as TCustomMemoryStream).Memory;
        end;

        // version
        Vid_ver := VDataset.FieldByName('id_ver').AsInteger;
        if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
          // as AnsiString
          VOut.szVersionOut := GetVersionAnsiPointer(Vid_ver, VExclusive);
        end else begin
          // as WideString
          VVersionW := GetVersionWideString(Vid_ver, VExclusive);
          VOut.szVersionOut := PWideChar(VVersionW);
        end;

        // contenttype
        Vid_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
        if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_OUT) <> 0) then begin
          // as AnsiString
          VOut.szContentTypeOut := GetContentTypeAnsiPointer(Vid_contenttype, VExclusive);
        end else begin
          // as WideString
          VContentTypeW := GetContentTypeWideString(Vid_contenttype, VExclusive);
          VOut.szContentTypeOut := PWideChar(VContentTypeW);
        end;

        // call host
        Result := TETS_SelectTile_Callback(FHostCallbacks[ETS_INFOCLASS_SelectTile_Callback])(
          FHostPointer,
          ACallbackPointer,
          ASelectBufferIn,
          @VOut
        );
      end;
    finally
      FreeAndNil(VStream);
      FConnection.KillPoolDataset(VDataset);
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

function TDBMS_Provider.DBMS_Sync(const AFlags: LongWord): Byte;
var
  VExclusively: Boolean;
  VExclusivelyLocked: Boolean;
begin
  VExclusively := ((AFlags and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusively, so_Sync, VExclusivelyLocked);
  try
    if (nil<>FConnection) then begin
      FConnection.CompactPool;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;

  Result := ETS_RESULT_OK;
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
  
  inherited Destroy;
end;

procedure TDBMS_Provider.DoBeginWork(
  const AExclusively: Boolean;
  const AOperation: TSqlOperation;
  out AExclusivelyLocked: Boolean
);
begin
  AExclusivelyLocked := AExclusively OR
                        (FConnection=nil) OR
                        (FConnection.FullSyncronizeSQL);

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

function TDBMS_Provider.FillTableNamesForTiles(
  ASQLTile: PSQLTile
): Boolean;
var
  VXYMaskWidth: Byte;
  //VNeedToQuote: Boolean; - use Result instead of
  VEngineType: TEngineType;
begin
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  ASQLTile^.UnquotedTileTableName := ASQLTile^.ZoomToTableNameChar(Result) +
                                     ASQLTile^.HXToTableNameChar(VXYMaskWidth) +
                                     FDBMS_Service_Info.id_div_mode +
                                     ASQLTile^.HYToTableNameChar(VXYMaskWidth) +
                                     '_' +
                                     InternalGetServiceNameByDB;

  VEngineType := FConnection.GetCheckedEngineType;

  // заквотируем или нет
  Result := Result or c_SQL_QuotedIdentifierForcedForTiles[VEngineType];
  if Result then begin
    ASQLTile^.QuotedTileTableName := c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] + ASQLTile^.UnquotedTileTableName + c_SQL_QuotedIdentifierValue[VEngineType, qp_After];
  end else begin
    ASQLTile^.QuotedTileTableName := ASQLTile^.UnquotedTileTableName;
  end;
end;

function TDBMS_Provider.GetContentTypeAnsiPointer(
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(Aid_contenttype, AExclusively, @Result, VDummy) then
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
    Result := GetContentTypeAnsiPointer(Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetContentTypeWideString(
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VContentTypeTextStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(Aid_contenttype, AExclusively, nil, VContentTypeTextStr) then begin
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
    Result := GetContentTypeWideString(Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetMaxNextVersionInts(
  const ANewVersionPtr: PVersionAA;
  const AKeepVerNumber: Boolean
): Boolean;
var
  VDataset: TDBMS_Dataset;
  VSQLText: TDBMS_String;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      VSQLText := 'select max(id_ver) as id_ver';
      if (not AKeepVerNumber) then begin
        // get new value for ver_number too
        VSQLText := VSQLText + ', max(ver_number) as ver_number';
      end;
      VSQLText := VSQLText + ' from ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;
      VDataset.OpenSQL(VSQLText);
      // apply values
      if VDataset.IsEmpty or VDataset.FieldByName('id_ver').IsNull then
        ANewVersionPtr^.id_ver := 0
      else
        ANewVersionPtr^.id_ver := VDataset.FieldByName('id_ver').AsInteger;
      Inc(ANewVersionPtr^.id_ver);
      // may be ver_number too
      if (not AKeepVerNumber) then begin
        if VDataset.IsEmpty or VDataset.FieldByName('ver_number').IsNull then
          ANewVersionPtr^.ver_number := 0
        else
          ANewVersionPtr^.ver_number := VDataset.FieldByName('ver_number').AsInteger;
        Inc(ANewVersionPtr^.ver_number);
      end;
      // done
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.GetSQLIntName_Div(const AXYMaskWidth, AZoom: Byte): String;
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
  VEngineType := FConnection.GetCheckedEngineType;

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

function TDBMS_Provider.GetSQL_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  out ADeleteSQLResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
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

  // заполняем VSQLTile
  Result := InternalCalcSQLTile(ADeleteBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // забацаем DELETE
  ADeleteSQLResult := 'delete from ' + FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName +
                      ' where x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);  
end;

function TDBMS_Provider.GetSQL_EnumTileVersions(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
  VSQLParts: TSQLParts;
begin
  // заполняем VSQLTile по переданным значениям
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  (*
  // check if table exists
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // check if failed
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
  end;
  *)

  // забацаем SELECT
  VSQLParts.SelectSQL := 'select v.id_ver';
  VSQLParts.FromSQL := FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // добавим FROM, WHERE и ORDER BY
  AddVersionOrderBy(@VSQLParts, nil, FALSE);

  // соберём всё вместе
  ASQLTextResult := VSQLParts.SelectSQL +
                  ' from ' + VSQLParts.FromSQL +
                 ' where v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                   ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
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

    // выщитываем координаты в таблицах
    Result := InternalCalcSQLTile(@VTileXYZMin, @VSQLTileMin);
    if (Result<>ETS_RESULT_OK) then
      Exit;
    Result := InternalCalcSQLTile(@VTileXYZMax, @VSQLTileMax);
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
          FillTableNamesForTiles(@(VSelectInRectItem^.TabSQLTile));

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
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VDataset: TDBMS_Dataset;
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

  VDataset := FConnection.MakePoolDataset;
  try
    // а может такой внутренний код сервиса уже есть
    VSQLText := GetSQL_SelectService_ByCode(VNewServiceCode);
    try
      VDataset.OpenSQL(VSQLText);
    except
      // если обломались на простом запросе, значит беда со структурой БД
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    if (not VDataset.IsEmpty) then begin
      // такой сервис уже зарегистрирован в БД (очевидно, с другим внешним уникальным кодом)
      Result := ETS_RESULT_INVALID_SERVICE_CODE;
      Exit;
    end;

    // здесь всегда обновляем список типов тайлов
    ReadContentTypesFromDB(AExclusively);

    // получим первичный тип тайла
    if not FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VNewIdContentType) then begin
      // обломались
      Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
      Exit;
    end;

    // получим новый номер идентификатора
    // TODO: сделать в цикле и обработать облом
    try
      VDataset.OpenSQL('SELECT max(id_service) as id_service FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE);
    except
      // опять обломались на простом запросе
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    // следующий идентификатор
    VNewIdService := VDataset.FieldByName('id_service').AsInteger + 1;

    // выполняем команду INSERT
    // прочие поля (id_ver_comp, id_div_mode, work_mode, use_common_tiles) залетают из DEFAULT-ных значений
    // при необходимости DBA может указать нужные значения в таблице, а также изменить значения для сервиса после его регистрации в БД
    ASQLTextResult := 'INSERT INTO ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' (id_service,service_code,service_name,id_contenttype) VALUES (' +
                            IntToStr(VNewIdService) + ',' +
                            DBMSStrToDB(VNewServiceCode) + ',' +
                            DBMSStrToDB(InternalGetServiceNameByHost) + ',' +
                            IntToStr(VNewIdContentType) + ')';
    Result := ETS_RESULT_OK;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.GetSQL_InsertUpdateTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean;
  const AExclusively: Boolean;
  out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
  out AInsertUpdateSubType: TInsertUpdateSubType;
  out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound, VRequestedContentTypeFound: Boolean;
  VIdContentType: SmallInt;
  VReqVersion: TVersionAA;
  VUseCommonTiles: Boolean;
  VNewTileSize: LongInt;
  VNewTileBody: TDBMS_String;
begin
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

  if (not VRequestedVersionFound) then begin
    // если такой версии нет - пробуем создать её автоматически
    Result := AutoCreateServiceVersion(
      AExclusively,
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

  // если нет начитанных типов тайлов - надо читать
  if (0=FContentTypeList.Count) then begin
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    ReadContentTypesFromDB(AExclusively);
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

  // заполняем VSQLTile
  Result := InternalCalcSQLTile(AInsertBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // отдельно вернём имя таблицы для тайлов (для обработки ошибок)
  AUnquotedTableNameWithoutPrefix := VSQLTile.UnquotedTileTableName;
  // а здесь таблица будет с префиксом схемы
  AQuotedTableNameWithPrefix := FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName;

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

  if AForceTNE then begin
    // маркер TNE - нет тела тайла (поля не указываем вообще)
    // ВНИМАНИЕ! здесь если был TILE и залетает TNE - будет tile_size=0, а тело тайла останется!
    // сделано как реализация раздельного хранения тайла и маркера TNE с приоритетом TNE
    // TODO: учитывать хранимый признак (опцию)
    AUpdateSQLResult := ''; // ', tile_body=null';
    AInsertSQLResult := '';
    VNewTileBody := '';
    AInsertUpdateSubType := iust_TNE;
  end else if VUseCommonTiles then begin
    // часто используемый тайл - сохраним ссылку на него
    AUpdateSQLResult := ', tile_body=null';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',null';
    AInsertUpdateSubType := iust_COMMON;
  end else begin
    // обычный тайл (не маркер TNE и не часто используемый)
    AUpdateSQLResult := ', tile_body=' + c_RTL_Tile_Body_Paramname;
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',' + c_RTL_Tile_Body_Paramname;
    AInsertUpdateSubType := iust_TILE;
  end;

  // соберём выражение INSERT
  AInsertSQLResult := 'INSERT INTO ' + AQuotedTableNameWithPrefix + ' (x,y,id_ver,id_contenttype,load_date,tile_size' + AInsertSQLResult + ') VALUES (' +
                      IntToStr(VSQLTile.XYLowerToID.X) + ',' +
                      IntToStr(VSQLTile.XYLowerToID.Y) + ',' +
                      IntToStr(VReqVersion.id_ver) + ',' +
                      IntToStr(VIdContentType) + ',' +
                      SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) + ',' +
                      IntToStr(VNewTileSize) + VNewTileBody + ')';

  // соберём выражение UPDATE
  AUpdateSQLResult := 'UPDATE ' + AQuotedTableNameWithPrefix + ' SET id_contenttype=' + IntToStr(VIdContentType) +
                           ', load_date=' + SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) +
                           ', tile_size=' + IntToStr(VNewTileSize) +
                           AUpdateSQLResult +
                      ' WHERE x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);
end;

function TDBMS_Provider.GetSQL_SelectContentTypes: TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_CONTENTTYPE;
end;

function TDBMS_Provider.GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_code='+DBMSStrToDB(AServiceCode);
end;

function TDBMS_Provider.GetSQL_SelectService_ByHost: TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_name='+DBMSStrToDB(InternalGetServiceNameByHost);
end;

function TDBMS_Provider.GetSQL_SelectTile(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
begin
  // заполняем VSQLTile по переданным значениям
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // забацаем SELECT
  Result := GetSQL_SelectTilesInternal(
    @VSQLTile,
    ASelectBufferIn^.szVersionIn,
    ASelectBufferIn^.dwOptionsIn,
    // тащим один конкретный тайл
    'v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y),
    FALSE, // тащим один известный тайл - его координаты нам ни к чему
    AExclusively,
    ASQLTextResult
  );
end;

function TDBMS_Provider.GetSQL_SelectTilesInternal(
  const ASQLTile: PSQLTile;
  const AVersionIn: Pointer;
  const AOptionsIn: LongWord;
  const AInitialWhere: TDBMS_String;
  const ASelectXY: Boolean;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLParts: TSQLParts;
  VReqVersion: TVersionAA;
begin
  Result := ETS_RESULT_OK;

  // заготовки
  VSQLParts.SelectSQL := 'SELECT v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := ASQLTile^.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := AInitialWhere;
  VSQLParts.OrderBySQL := '';

  if ASelectXY then begin
    // может быть надо вытащить координаты
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

  // если версия была найдена (в том числе зарезервированный идентификатор для пустой версии!)
  if (VReqVersion.id_ver=FVersionList.EmptyVersionIdVer) then begin
    // запрос без версии
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_LAST_VERSION) <> 0) then begin
      // берём последнюю версию (добавляем в OrderBySQL кусок)
      AddVersionOrderBy(@VSQLParts, @VReqVersion, FALSE);
    end else begin
      // берём только пустую версию (так как она одна - обойдёмся без ORDER BY)
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
    end;
  end else begin
    // запрос с непустой версией
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_PREV_VERSION) <> 0) then begin
      // разрешена предыдущая версия
      AddVersionOrderBy(@VSQLParts, @VReqVersion, TRUE);
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


  // собираем всё вместе
  ASQLTextResult := VSQLParts.SelectSQL + ' FROM ' + VSQLParts.FromSQL +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetSQL_SelectVersions: TDBMS_String;
begin
  // тащим всё из таблицы версий для текущего сервиса
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;
end;

function TDBMS_Provider.GetVersionAnsiPointer(
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(Aid_ver, AExclusively, @Result, VDummy) then
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
    Result := GetVersionAnsiPointer(Aid_ver, TRUE);
  end;
end;

function TDBMS_Provider.GetVersionWideString(
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VVerValueAnsiStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(Aid_ver, AExclusively, nil, VVerValueAnsiStr) then begin
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
    Result := GetVersionWideString(Aid_ver, TRUE);
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

function TDBMS_Provider.InternalCalcSQLTile(
  const AXYZ: PTILE_ID_XYZ;
  const ASQLTile: PSQLTile
): Byte;
begin
  // сохраняем зум (от 1 до 24)
  ASQLTile^.Zoom := AXYZ^.z;
  
  // делим XY на "верхнюю" и "нижнюю" части
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  // строим имя таблицы для тайлов
  FillTableNamesForTiles(ASQLTile);

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
    ReadContentTypesFromDB(AExclusively);

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
    ReadVersionsFromDB(AExclusively);

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
  end;
end;

function TDBMS_Provider.InternalProv_Connect(const AExclusively: Boolean): Byte;
begin
  if (not FCompleted) then begin
    Result := ETS_RESULT_INCOMPLETE;
    Exit;
  end;

  // разрыв соединения
  if (nil<>FConnection) and (FReconnectPending) then begin
    if (not AExclusively) then begin
      // переподключаемся только в эксклюзивном режиме
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    // грохаемся и по новой
    InternalProv_Disconnect;
    FReconnectPending := FALSE;
  end;

  // safe create connection object
  if (nil=FConnection) then begin
    // check exclusive mode
    if AExclusively then begin
      // make connection
      FConnection := GetConnectionByPath(@FPath);
      if (nil=FConnection) then begin
        Result := ETS_RESULT_CANNOT_CONNECT;
        Exit;
      end;
    end else begin
      // request exclusive access
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
  end;

  // пробуем подключиться
  Result := FConnection.EnsureConnected(AExclusively, FStatusBuffer);

  // при ошибке валим
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // читаем параметры сервиса после подключения
  if (not FDBMS_Service_OK) then begin
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    Result := InternalProv_ReadServiceInfo(AExclusively);
    if (ETS_RESULT_OK<>Result) then
      Exit;
    // если сервис нашёлся - вытащим из базы его версии
    ReadVersionsFromDB(AExclusively);
    // если версий нет вообще - создадим запись для пустой версии (без версии)
    try
      if (0=FVersionList.Count) then begin
        MakeEmptyVersionInDB(0, AExclusively);
        ReadVersionsFromDB(AExclusively);
      end;
    except
    end;
  end;
end;

procedure TDBMS_Provider.InternalProv_Disconnect;
begin
  // detach connection object from provider
  FreeDBMSConnection(FConnection);
end;

function TDBMS_Provider.InternalProv_ReadServiceInfo(const AExclusively: Boolean): Byte;
var
  VDataset: TDBMS_Dataset;
  VSelectCurrentServiceSQL: TDBMS_String;
begin
  FillChar(FDBMS_Service_Info, SizeOf(FDBMS_Service_Info), 0);
  VDataset := FConnection.MakePoolDataset;
  try
    // запрос текущего сервиса
    VSelectCurrentServiceSQL := GetSQL_SelectService_ByHost;

    // тащим инфу о текущем сервисе
    // исходя из указанного при инициализации внешнего уникального кода сервиса
    try
      VDataset.OpenSQL(VSelectCurrentServiceSQL);
    except on E: Exception do
      // обломались при открытии датасета - возможно нет таблицы
      case GetStatementExceptionType(E) of
        set_TableNotFound: begin
          // и правда нет таблицы
        end;
        else begin
          // неизвестно что
        end;
      end;
    end;

    if (not VDataset.Active) then begin
      // не открылось - создаём базовые таблицы из скрипта
      CreateAllBaseTablesFromScript;
      // переоткрываемся
      try
        VDataset.OpenSQL(VSelectCurrentServiceSQL);
      except
      end;
    end;

    // а вдруг полный отстой, и нам так и не удалось открыться
    if (not VDataset.Active) then begin
      // с прискорбием валим
      InternalProv_ClearServiceInfo;
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    // проверка, а есть ли сервис
    if VDataset.IsEmpty then begin
      // а сервиса-то такого нет
      // однако попробуем создать его
      Result := AutoCreateServiceRecord(AExclusively);

      // проверка чего насоздавали
      if (Result<>ETS_RESULT_OK) then begin
        InternalProv_ClearServiceInfo;
        Exit;
      end;

      // и снова пробуем переоткрыться
      try
        VDataset.OpenSQL(VSelectCurrentServiceSQL);
      except
      end;
    end;

    // последняя проверка
    if (not VDataset.Active) or VDataset.IsEmpty then begin
      // так и нет сервиса
      InternalProv_ClearServiceInfo;
      Result := ETS_RESULT_UNKNOWN_SERVICE;
      Exit;
    end;

    // запрошенный сервис нашёлся
    FDBMS_Service_Code := VDataset.FieldByName('service_code').AsString;
    FDBMS_Service_Info.id_service := VDataset.FieldByName('id_service').AsInteger;
    FDBMS_Service_Info.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
    FDBMS_Service_Info.id_ver_comp := VDataset.GetAnsiCharFlag('id_ver_comp', TILE_VERSION_COMPARE_NONE);
    FDBMS_Service_Info.id_div_mode := VDataset.GetAnsiCharFlag('id_div_mode', TILE_DIV_ERROR);
    FDBMS_Service_Info.work_mode := VDataset.GetAnsiCharFlag('work_mode', ETS_SWM_DEFAULT);
    FDBMS_Service_Info.use_common_tiles := VDataset.GetAnsiCharFlag('use_common_tiles', ETS_UCT_NO);
    FDBMS_Service_OK := TRUE;

    // копируем параметры в опции хранилища
    if (FStatusBuffer<>nil) then
    with (FStatusBuffer^) do begin
      id_div_mode      := FDBMS_Service_Info.id_div_mode;
      id_ver_comp      := FDBMS_Service_Info.id_ver_comp;
      work_mode        := FDBMS_Service_Info.work_mode;
      use_common_tiles := FDBMS_Service_Info.use_common_tiles;
    end;

    Result := ETS_RESULT_OK;
  finally
    FConnection.KillPoolDataset(VDataset);
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
  if (0<Length(FPath.Path_Items[0])) and (0<Length(FPath.Path_Items[2])) then begin
    // корректно (с точки зрения формата, не обязательно сервис будет доступен)
    Result := ETS_RESULT_OK;
  end else begin
    // заведомо криво
    Result := ETS_RESULT_INVALID_PATH;
  end;
end;

function TDBMS_Provider.MakeEmptyVersionInDB(
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
  VNewVersion.ver_date := 0; //NowUTC;
  VNewVersion.ver_number := AIdVersion;
  VNewVersion.ver_comment := '';
  Result := MakePtrVersionInDB(@VNewVersion, AExclusively);
end;

function TDBMS_Provider.MakePtrVersionInDB(
  const ANewVersionPtr: PVersionAA;
  const AExclusively: Boolean
): Boolean;
var
  VVersionsTableName_UnquotedWithoutPrefix: String;
  VVersionsTableName_QuotedWithPrefix: String;
begin
  Assert(AExclusively);

  VVersionsTableName_UnquotedWithoutPrefix := c_Prefix_Versions + InternalGetServiceNameByDB;
  VVersionsTableName_QuotedWithPrefix := FConnection.ForcedSchemaPrefix + VVersionsTableName_UnquotedWithoutPrefix;

  // проверим, а есть ли табличка с версиями сервиса
  if (not FConnection.TableExists(VVersionsTableName_QuotedWithPrefix)) then
  try
    // создадим
    CreateTableByTemplate(
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
    FConnection.ExecuteDirectSQL(
      'INSERT INTO ' + VVersionsTableName_QuotedWithPrefix +
      '(id_ver,ver_value,ver_date,ver_number) VALUES (' +
      IntToStr(ANewVersionPtr^.id_ver) + ',' +
      DBMSStrToDB(ANewVersionPtr^.ver_value) + ',' +
      SQLDateTimeToDBValue(ANewVersionPtr^.ver_date) + ',' +
      IntToStr(ANewVersionPtr^.ver_number) + ')'
    );
    Result := TRUE;
  except
    Result := FALSE;
  end;
end;

function TDBMS_Provider.ParseVerValueToVerNumber(
  const AGivenVersionValue: String;
  out ADoneVerNumber: Boolean
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

  // для заливки NMC (формально запрос без версии) удобно брать за версию тайла
  // максимальное значение параметра latestAcquisitionDate (строка вида '2012-05-06 09:05:40.278')
  // из его EXIF
  // тогда разные версии тайлов будут разруливаться автоматически
  // надо только:
  // а) изначально не указывать для NMC версию;
  // б) отображать последнюю версию тайла при запросе без версии.
  // в качестве ver_number для сохранения возможности сортировки берём что-то типа yymmddhh
  // p :=

  // пробуем разобрать byte.byte.byte.byte (справа налево!)
  p := Length(AGivenVersionValue);
  n4 := _ExtractTailByte;
  n3:= _ExtractTailByte;
  n2 := _ExtractTailByte;
  n1 := _ExtractTailByte;
  Result := (Integer(n1) shl 24) or (Integer(n2) shl 16) or (Integer(n3) shl 8) or Integer(n4);
  ADoneVerNumber := (Result<>0);

  // TODO: добавить другие возможные парсеры
(*
FeatureId:f09f02e6824eb7f8ba05948aa692ead2
<br>
Date:2012-05-06 09:05:40.278
<br>
Color:Pan Sharpened Natural Color
<br>
Resolution:0.50
<br>
Source:WV02
<br>
LegacyId:1030010017B9D100
<br>
Provider:DigitalGlobe
<br>
PreviewLink:<a href=https://browse.digitalglobe.com/imagefinder/showBrowseImage?catalogId=1030010017B9D100&imageHeight=1024&imageWidth=1024>
https://browse.digitalglobe.com/imagefinder/showBrowseImage?catalogId=1030010017B9D100&imageHeight=1024&imageWidth=1024</a>
<br>MetadataLink:<a href=https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?buffer=1.0&catalogId=1030010017B9D100&imageHeight=natres&imageWidth=natres>https://browse.digitalglobe.com/imagefinder/showBrowseMetadata?buffer=1.0&catalogId=1030010017B9D100&imageHeight=natres&imageWidth=natres</a>

*)
end;

function TDBMS_Provider.GetStatementExceptionType(const AException: Exception): TStatementExceptionType;
var VMessage: String;
begin
  VMessage := UpperCase(AException.Message);
{$if defined(USE_DIRECT_ODBC)}
  // смотрим по SQLSTATE
  VMessage := System.Copy(VMessage, 1, 6);

  if (0=Length(VMessage)) then begin
    Result := set_Unknown;
    Exit;
  end;
  
  if (VMessage = '23000:') or (VMessage = '23505:') then begin
    // это код ODBC для нарушения уникальности
    // '23000:[MICROSOFT][ODBC SQL SERVER DRIVER][SQL SERVER]VIOLATION OF PRIMARY KEY CONSTRAINT 'PK_D2I1_NMC_RECENCY'. CANNOT INSERT DUPLICATE KEY IN OBJECT 'DBO.D2I1_NMC_RECENCY'.'
    // '23000:[MIMER][ODBC MIMER DRIVER][MIMER SQL]PRIMARY KEY CONSTRAINT VIOLATED, ATTEMPT TO INSERT DUPLICATE KEY IN TABLE SYSADM.DZ_NMC_RECENCY'
    // '23505:ОШИБКА: повторяющееся значение ключа нарушает ограничение уникальности "PK_D2I1_NMC_RECENCY"'#$A'Ключ "(X, Y, ID_VER)=(644, 149, 0)" уже существует.;'#$A'ERROR WHILE EXECUTING THE QUERY' // POSTGRESQL
    // '23000:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]ATTEMPT TO INSERT DUPLICATE KEY ROW IN OBJECT 'D2I1_NMC_RECENCY' WITH UNIQUE INDEX 'PK_D2I1_NMC_RECENCY''#$A
    // '23000:[DATADIRECT][ODBC SYBASE WIRE PROTOCOL DRIVER][SQL SERVER]ATTEMPT TO INSERT DUPLICATE KEY ROW IN OBJECT 'D2I1_NMC_RECENCY' WITH UNIQUE INDEX 'PK_D2I1_NMC_RECENCY''#$A
    // '23000:[INFORMIX][INFORMIX ODBC DRIVER][INFORMIX]UNIQUE CONSTRAINT (INFORMIX.PK_H2AI12_NMC_RECENCY) VIOLATED.'
    // '23000:[MYSQL][ODBC 5.2(W) DRIVER][MYSQLD-5.5.28-MARIADB]DUPLICATE ENTRY '0-0-0' FOR KEY 'PRIMARY''
    //
    //
    Result := set_PrimaryKeyViolation;
    Exit;
  end;

  if (VMessage = '42S02:') or (VMessage = '42P01:') or (VMessage = '42000:') then begin
    // это код ODBC для для отсутствия отношения
    // '42S02:[MICROSOFT][ODBC SQL SERVER DRIVER][SQL SERVER]INVALID OBJECT NAME 'C1I0_NMC_RECENCY'.'
    // '42S02:[MIMER][ODBC MIMER DRIVER][MIMER SQL]TABLE 1Z_NMC_RECENCY NOT FOUND, TABLE DOES NOT EXIST OR NO ACCESS PRIVILEGE'
    // '42P01:ОШИБКА: отношение "Z_SERVICE" не существует;'#$A'ERROR WHILE EXECUTING THE QUERY' // POSTGRESQL
    // '42000:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]Z_SERVICE NOT FOUND. SPECIFY OWNER.OBJECTNAME OR USE SP_HELP TO CHECK WHETHER THE OBJECT EXISTS (SP_HELP MAY PRODUCE LOTS OF OUTPUT).'#$A
    // '42S02:[DATADIRECT][ODBC SYBASE WIRE PROTOCOL DRIVER][SQL SERVER]D2I1_NMC_RECENCY NOT FOUND. SPECIFY OWNER.OBJECTNAME OR USE SP_HELP TO CHECK WHETHER THE OBJECT EXISTS (SP_HELP MAY PRODUCE LOTS OF OUTPUT).'#$A
    // '42S02:[Sybase][ODBC Driver][SQL Anywhere]Table 'Z_SERVICE' not found'
    // '42S02:[INFORMIX][INFORMIX ODBC DRIVER][INFORMIX]THE SPECIFIED TABLE (_H2AI12_NMC_RECENCY_) IS NOT IN THE DATABASE.'
    // '42S02:[MYSQL][ODBC 5.2(W) DRIVER][MYSQLD-5.5.28-MARIADB]TABLE 'TEST.Z_SERVICE' DOESN'T EXIST'
    //
    //
    Result := set_TableNotFound;
    Exit;
  end;

  // что-то иное
  Result := set_Unknown;
{$else}
  Result := (System.Pos('VIOLATION', VMessage)>0) and (System.Pos('CONSTRAINT', VMessage)>0);
  // FB: 'violation of PRIMARY or UNIQUE KEY constraint "PK_C2I1_NMC_RECENCY" on table "C2I1_nmc_recency"'
{$ifend}
end;

procedure TDBMS_Provider.ReadContentTypesFromDB(const AExclusively: Boolean);
var
  VDataset: TDBMS_Dataset;
  VNewItem: TContentTypeA;
begin
  Assert(AExclusively);
  try
    FContentTypeList.SetCapacity(0);
    VDataset := FConnection.MakePoolDataset;
    try
      VDataset.OpenSQL(GetSQL_SelectContentTypes);
      if (not VDataset.IsEmpty) then begin
        // set capacity
        if (not VDataset.IsUniDirectional) then begin
          FContentTypeList.SetCapacity(VDataset.RecordCount);
        end;
        // enum
        VDataset.First;
        while (not VDataset.Eof) do begin
          // add record to array
          VNewItem.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
          VNewItem.contenttype_text := Trim(VDataset.FieldByName('contenttype_text').AsString);
          FContentTypeList.AddItem(@VNewItem);
          // next
          VDataset.Next;
        end;
      end;
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  except
  end;
end;

procedure TDBMS_Provider.ReadVersionsFromDB(const AExclusively: Boolean);
var
  VDataset: TDBMS_Dataset;
  VNewItem: TVersionAA;
begin
  Assert(AExclusively);
  try
    // читаем все версии в почищенный список
    FVersionList.Clear;
    VDataset := FConnection.MakePoolDataset;
    try
      VDataset.OpenSQL(GetSQL_SelectVersions);
      if (not VDataset.IsEmpty) then begin
        // сразу установим размер по числу записей в датасете
        if (not VDataset.IsUniDirectional) then begin
          FVersionList.SetCapacity(VDataset.RecordCount);
        end;
        // перечисляем
        VDataset.First;
        while (not VDataset.Eof) do begin
          // добавляем поштучно
          VNewItem.id_ver := VDataset.FieldByName('id_ver').AsInteger;
          VNewItem.ver_value := Trim(VDataset.FieldByName('ver_value').AsString);
          VNewItem.ver_date := VDataset.FieldByName('ver_date').AsDateTime;
          VNewItem.ver_number := VDataset.FieldByName('ver_number').AsInteger;
          VNewItem.ver_comment := Trim(VDataset.FieldByName('ver_comment').AsString);
          FVersionList.AddItem(@VNewItem);
          // - Следующий!
          VDataset.Next;
        end;
      end;
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  except
  end;
end;

function TDBMS_Provider.SQLDateTimeToDBValue(const ADateTime: TDateTime): TDBMS_String;
begin
  Result := c_SQL_DateTime_Literal_Prefix[FConnection.GetCheckedEngineType] +
            DBMSStrToDB(FormatDateTime(c_DateTimeToDBFormat, ADateTime, FFormatSettings));
end;

function TDBMS_Provider.VersionExistsInDBWithIdVer(const AIdVersion: SmallInt): Boolean;
var
  VDataset: TDBMS_Dataset;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      // проверка существования указанной версии (по идентификатору) для текущего сервиса
      VDataset.OpenSQL('SELECT id_ver FROM ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB +
                       ' WHERE id_ver=' + IntToStr(AIdVersion));
      Result := (not VDataset.IsEmpty) and (not VDataset.FieldByName('id_ver').IsNull);
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

end.
