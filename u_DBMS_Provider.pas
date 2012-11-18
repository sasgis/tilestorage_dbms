unit u_DBMS_Provider;

interface

uses
  Types,
  Windows,
  SysUtils,
  Classes,
  DB,
  WideStrings,
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
    procedure DoBeginWork(const AExclusively: Boolean);
    procedure DoEndWork(const AExclusively: Boolean);
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
    function InternalGetServiceNameByDB: WideString;
    // возвращает имя сервиса, используемое в хосте (внешнее)
    function InternalGetServiceNameByHost: WideString;

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
    ): PAnsiChar;
    function GetVersionWideString(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): WideString;

    // for cached contenttype
    function GetContentTypeAnsiPointer(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;
    function GetContentTypeWideString(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): WideString;

  private
    function SQLDateTimeToDBValue(const ADateTime: TDateTime): WideString;

    function GetSQLIntName_Div(const AXYMaskWidth, AZoom: Byte): String;

    function PrimaryConstraintViolation(const AException: Exception): Boolean;
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

    // check if table exists
    function TableExists(const ATableName: WideString): Boolean;

    // create table using SQL commands from special table
    function CreateTableByTemplate(
      const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: WideString;
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

  private
    procedure AddVersionOrderBy(
      const ASQLParts: PSQLParts;
      const AVerInfoPtr: PVersionAA;
      const ACutOnVersion: Boolean
    );

    // формирование текста SQL для получения (SELECT) тайла или маркера TNE
    function GetSQL_SelectTile(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;

    // формирование текста SQL для вставки (INSERT) и обновления (UPDATE) тайла или маркера TNE
    // в тексте SQL возможны только параметр c_RTL_Tile_Body_Paramname, остальное подставляется сразу
    function GetSQL_InsertUpdateTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult: WideString;
      out AInsertUpdateSubType: TInsertUpdateSubType;
      out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: WideString
    ): Byte;

    // формирование текста SQL для удаления (DELETE) тайла или маркера TNE
    function GetSQL_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      out ADeleteSQLResult: WideString
    ): Byte;

    // формирование текста SQL для получения (SELECT) списка существующих версий тайла (XYZ)
    function GetSQL_EnumTileVersions(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;


    // формирует SQL для получения списка версий для текущего сервиса
    function GetSQL_SelectVersions: WideString;

    // формирует SQL для получения списка типов тайлов
    function GetSQL_SelectContentTypes: WideString;

    // формирует SQL для чтения параметров сервиса по его внешнему коду
    // этот уникальный внешний код передаётся при инициализации с хоста
    function GetSQL_SelectService_ByHost: WideString;

    // формирует SQL для чтения параметров сервиса по его внутреннему коду (код в БД)
    function GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): WideString;

    function GetSQL_InsertIntoService(
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;
    
  private
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

  procedure _AddWithoutFieldValue(const AFieldName: WideString);
  begin
    ASQLParts^.SelectSQL := ASQLParts^.SelectSQL + ',w.' + AFieldName;

    ASQLParts^.OrderBySQL := ' order by ' + AFieldName + ' desc';
  
    // добавляем таблицу с версиями
    ASQLParts^.FromSQL := ASQLParts^.FromSQL + ', ' + c_Prefix_Versions + InternalGetServiceNameByDB + ' w';

    ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=w.id_ver';
  end;

  procedure _AddWithFieldValue(const AFieldName, AGreatestValueForDB: WideString);
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
        _AddWithFieldValue('ver_value', WideStrToDB(AVerInfoPtr^.ver_value))
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
  VDataset: TDBMS_Dataset;
  VSQLText: WideString;
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

  VDataset := FConnection.MakePoolDataset;
  try
    // исполняем INSERT (вставляем запись о сервисе)
    try
      VDataset.SQL.Text := VSQLText;
      VDataset.ExecSQL(TRUE);
      Result := ETS_RESULT_OK;
    except
      // обломались
      Result := ETS_RESULT_INVALID_STRUCTURE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
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

  // TODO:  make it more correctly!!!
  // use Versions flags

  // check ver_comp
  case FDBMS_Service_Info.id_ver_comp of
    TILE_VERSION_COMPARE_ID, TILE_VERSION_COMPARE_NUMBER: begin
      // id_ver=ver_value OR ver_number=ver_value
      VKeepVerNumber := TRUE;
      if VVerIsInt then begin
        // check if allow to treat ver_value as SmallInt
        if (AReqVersionPtr^.ver_number<$8000) and (AReqVersionPtr^.ver_number>=0) then begin
          // allow treat ver_value as SmallInt
          AReqVersionPtr^.id_ver := AReqVersionPtr^.ver_number;
        end else begin
          // cannot treat ver_value as SmallInt
          // TODO: get max+1 for id_ver and reset TILE_VERSION_COMPARE_ID to TILE_VERSION_COMPARE_NUMBER
          GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
        end;
      end else begin
        // ver_value is not INT
        // TODO: get max+1 for id_ver and max+1 for ver_number
        // and reset TILE_VERSION_COMPARE_ID or TILE_VERSION_COMPARE_NUMBER to TILE_VERSION_COMPARE_DATE
        GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
      end;
    end;
    TILE_VERSION_COMPARE_VALUE, TILE_VERSION_COMPARE_DATE: begin
      // TODO: get max+1 for id_ver and max+1 for ver_number
      GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
    end;
    else {TILE_VERSION_COMPARE_NONE:} begin
      // TODO: get max+1 for id_ver and max+1 for ver_number
      GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
    end;
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
  VDataset: TDBMS_Dataset;
begin
  // получим уникальный код типа СУБД
  VUniqueEngineType := c_SQL_Engine_Name[FConnection.GetCheckedEngineType];
  // если пусто - значит неизвестный типа СУБД, и ловить тут нечего
  if (0=Length(VUniqueEngineType)) then begin
    Result := ETS_RESULT_UNKNOWN_DBMS;
    Exit;
  end;

  // создадим объект для генерации структуры для конкретного типа БД
  VDataset := nil;
  VSQLTemplates := TDBMS_SQLTemplates_File.Create(
    VUniqueEngineType,
    FConnection.ForcedSchemaPrefix,
    FConnection.GetInternalParameter(ETS_INTERNAL_SCRIPT_APPENDER)
  );
  try
    // исполним всё что есть
    VDataset := FConnection.MakePoolDataset;
    Result := VSQLTemplates.ExecuteAllSQLs(VDataset);
  finally
    FConnection.KillPoolDataset(VDataset);
    VSQLTemplates.Free;
  end;
end;

function TDBMS_Provider.CreateTableByTemplate(
  const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: WideString;
  const AZoom: Byte;
  const ASubstSQLTypes: Boolean
): Byte;
var
  VDataset, VExecSQL: TDBMS_Dataset;
  VSqlTextField: TField;
  VSQLText: WideString;
  //VSQLAnsi: AnsiString;
  Vignore_errors: AnsiChar;
  //VStream: TStream;
  //VMemStream: TMemoryStream;
  VReplaceNumeric: String;
begin
  // а вдруг нет базовой таблицы с шаблонами
  if (not TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
    // создадим базовые таблицы
    CreateAllBaseTablesFromScript;
    // а вдруг обломались?
    if (not TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
      // полный отстой и нам тут делать нечего
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // если запрошенная таблица уже есть - валим
  if (TableExists(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // вытащим все запросы SQL для CREATE (операция "C") для запрошенного шаблона
  VDataset := FConnection.MakePoolDataset;
  VExecSQL := FConnection.MakePoolDataset;
  try
    VSQLText := 'select * from ' + FConnection.ForcedSchemaPrefix + Z_ALL_SQL+
                ' where object_name=' + WideStrToDB(ATemplateName) +
                  ' and object_oper=''C'' and skip_sql=''0'' order by index_sql';
    VDataset.OpenSQL(VSQLText);

    if VDataset.IsEmpty then begin
      // ничего не прочиталось - значит нет шаблона
      Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
      Exit;
    end;

    VDataset.First;
    while (not VDataset.Eof) do begin
      // тащим текст SQL для исполнения в порядке очерёдности
      Vignore_errors := VDataset.GetAnsiCharFlag('ignore_errors', ETS_UCT_YES);
      VSqlTextField := VDataset.FieldByName('object_sql');
      if (not VSqlTextField.IsNull) then
      try
        (*
        if VSqlTextField.IsBlob then begin
          // CLOB
          VMemStream:=TMemoryStream.Create;
          try
            (VSqlTextField as TBlobField).SaveToStream(VMemStream);
            if (VMemStream.Size=(VSqlTextField as TBlobField).BlobSize) then begin
              SetString(VSQLAnsi, PAnsiChar(VMemStream.Memory), VMemStream.Size);
              VSQLText := VSQLAnsi;
            end else begin
              SetString(VSQLText, PWideChar(VMemStream.Memory), VMemStream.Size);
            end;
          finally
            FreeAndNil(VMemStream);
          end;
        end else begin
          // varchar
          VSQLText := VSqlTextField.AsWideString;
        end;
        *)

        // работает и по-тупому
        VSQLText := VSqlTextField.AsWideString;

        // а тут надо подменить имя таблицы
        VSQLText := StringReplace(VSQLText, ATemplateName, AUnquotedTableNameWithoutPrefix, [rfReplaceAll,rfIgnoreCase]);

        if ASubstSQLTypes then begin
          // также необходимо подставить нуные типы полей для оптимального хранения XY
          // а именно - заменить numeric на INT нужной ширины
          VReplaceNumeric := GetSQLIntName_Div(FDBMS_Service_Info.XYMaskWidth, AZoom);
          VSQLText := StringReplace(VSQLText, c_RTL_Numeric, VReplaceNumeric, [rfReplaceAll,rfIgnoreCase]);
        end;

        // готово
        VExecSQL.SQL.Text := VSQLText;

        // исполняем (напрямую)
        VExecSQL.ExecSQL(FALSE);

        //(VDataset.FieldByName('object_sql') as TBlobField).BlobSize;

        (*
        VStream := VDataset.CreateBlobStream(VDataset.FieldByName('object_sql'), bmRead);
        try
          VExecSQL.SQL.LoadFromStream(VStream);
          VSQLText := VExecSQL.SQL.Text;
          // а тут надо подменить имя таблицы
          // TODO: также необходимо подставить нуные типы полей для оптимального хранения XY
          VSQLText := StringReplace(VSQLText, ATemplateName, ATableName, [rfReplaceAll,rfIgnoreCase]);
          // готово
          VExecSQL.SQL.Text := VSQLText;
          // исполняем (напрямую)
          VExecSQL.ExecSQL(TRUE);
        finally
          FreeAndNil(VStream);
        end;
        *)
      except
        if (Vignore_errors=ETS_UCT_NO) then
          raise;
      end;
      // - Следующий!
      VDataset.Next;
    end;

    // проверяем что табла успешно создалась
    if (TableExists(AQuotedTableNameWithPrefix)) then begin
      Result := ETS_RESULT_OK;
      Exit;
    end;
  finally
    FConnection.KillPoolDataset(VExecSQL);
    FConnection.KillPoolDataset(VDataset);
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
  VDataset: TDBMS_Dataset;
  VDeleteSQL: WideString;
begin
  VExclusive := ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - DELETE tile from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // make DELETE statements
      Result := GetSQL_DeleteTile(
        ADeleteBuffer,
        VDeleteSQL
      );
      
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // execute INSERT statement
      try
        VDataset.SQL.Text := VDeleteSQL;
        // exec (do not prepare statement)
        VDataset.ExecSQL(TRUE);
        // done (successfully INSERTed)
        Result := ETS_RESULT_OK;
      except
        // no table - no tile - OK
        Result := ETS_RESULT_OK;
      end;

    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
  VSQLText: WideString;
  VVersionValueW, VVersionCommentW: WideString;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
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
        // failed to select - no table - no versions
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
        VEnumOut.ResponseCount := VDataset.RecordCount;
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
    DoEndWork(VExclusive);
  end;
end;

function TDBMS_Provider.DBMS_GetTileRectInfo(
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte;
(*
var
  VExclusive, VVersionFound: Boolean;
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_GET_TILE_RECT_OUT;
  VETS_VERSION_W: TETS_VERSION_W;
  VETS_VERSION_A: TETS_VERSION_A;
  VVersionAA: TVersionAA;
  VSQLText: WideString;
  VVersionValueW, VVersionCommentW: WideString;
  *)
begin
  Result := ETS_RESULT_NOT_IMPLEMENTED;
(*
  VExclusive := ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT id_ver from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_GetTileRectInfo(ATileRectInfoIn, VExclusive, VSQLText);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      FillChar(VEnumOut, SizeOf(VEnumOut), 0);
      
      if ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
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
        // failed to select - no table - no versions
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
        VEnumOut.ResponseCount := VDataset.RecordCount;
        VDataset.First;
        while (not VDataset.Eof) do begin
          // find selected version
          VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);

          if (not VVersionFound) then begin
            // try to refresh versions
            ReadVersionsFromDB;
            VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);
          end;

          if (not VVersionFound) then begin
            // OMG WTF
            VVersionAA.id_ver := VDataset.FieldByName('id_ver').AsInteger;
            VVersionAA.ver_value := '';
            VVersionAA.ver_comment := '';
          end;

          // make params for callback
          if ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
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
          Result := TETS_GetTileRectInfo_Callback(FHostCallbacks[ETS_INFOCLASS_GetTileRectInfo_Callback])(
            FHostPointer,
            ACallbackPointer,
            ATileRectInfoIn,
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
    DoEndWork(VExclusive);
  end;
*)
end;

function TDBMS_Provider.DBMS_InsertTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean
): Byte;
var
  VExclusive: Boolean;
  VInsertDataset, VUpdateDataset: TDBMS_Dataset;
  VInsertSQL, VUpdateSQL: WideString;
  VUnquotedTableNameWithoutPrefix: WideString;
  VQuotedTableNameWithPrefix: WideString;
  VParam: TParam;
  VNeedUpdate: Boolean;
  VInsertUpdateSubType: TInsertUpdateSubType;
  VCastBodyAsHexLiteral: Boolean;
  VExecDirect: Boolean;
  VBodyAsLiteralValue: WideString;
begin
  VExclusive := ((AInsertBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - INSERT tile to DB
    // VInsertDataset := FConnection.MakePoolDataset;
    VInsertDataset := FConnection.MakeNonPooledDataset;
    // VUpdateDataset := FConnection.MakePoolDataset;
    VUpdateDataset := FConnection.MakeNonPooledDataset;
    try
      VNeedUpdate := FALSE;
      
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

      // запрос напрямую или нет
      VExecDirect := VCastBodyAsHexLiteral or (iust_TILE<>VInsertUpdateSubType);
      //VExecDirect := TRUE;

      // выполним INSERT
      try
        // может BLOB надо писать как 16-ричный литерал
        if VCastBodyAsHexLiteral then begin
          VInsertSQL := StringReplace(VInsertSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
        end;

        VInsertDataset.SQL.Text := VInsertSQL;
        if (iust_TILE=VInsertUpdateSubType) and (not VCastBodyAsHexLiteral) then begin
          // добавим параметр (как BLOB)
          VParam := VInsertDataset.Params.FindParam(c_RTL_Tile_Body_Paramsrc);
          if (VParam<>nil) then begin
            //VParam.ParamType := ptInput;
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;

        // исполняем INSERT
        //VInsertDataset.PrepareStatement;
        VInsertDataset.ExecSQL(VExecDirect);
        
        // готово (вставлено!)
        Result := ETS_RESULT_OK;
      except
        // обломались со вставкой новой записи
        on E: Exception do begin
          // если есть слова про уникальность - уходим на update
          if PrimaryConstraintViolation(E) then begin
            // нарушение уникальности - надо обновляться
            VNeedUpdate := TRUE;
          end else begin
            // проверяем, может не было таблицы
            if (not TableExists(VQuotedTableNameWithPrefix)) then begin
              // пробуем создать таблицу по шаблону
              CreateTableByTemplate(
                c_Templated_RealTiles,
                VUnquotedTableNameWithoutPrefix,
                VQuotedTableNameWithPrefix,
                AInsertBuffer^.XYZ.z,
                TRUE
              );
              // проверяем существование таблицы
              if (not TableExists(VQuotedTableNameWithPrefix)) then begin
                // не удалось даже создать - валим
                Result := ETS_RESULT_TILE_TABLE_NOT_FOUND;
                Exit;
              end;
            end;
            // повторяем INSERT
            try
              VInsertDataset.ExecSQL(VExecDirect);
              Result := ETS_RESULT_OK;
            except
              VNeedUpdate := TRUE;
            end;
          end;
        end;
      end;

      if VNeedUpdate then begin
        // пробуем выполнить UPDATE
        if VCastBodyAsHexLiteral then begin
          VUpdateSQL := StringReplace(VUpdateSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
        end;
        
        VUpdateDataset.SQL.Text := VUpdateSQL;
        if (iust_TILE=VInsertUpdateSubType) and (not VCastBodyAsHexLiteral) then begin
          // добавим параметр (как BLOB)
          VParam := VUpdateDataset.Params.FindParam(c_RTL_Tile_Body_Paramsrc);
          if (VParam<>nil) then begin
            VParam.ParamType := ptInput;
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;
        // исполняем UPDATE
        try
          // испускаем запрос
          VUpdateDataset.ExecSQL(VExecDirect);
          // готово (обновлено!)
          Result := ETS_RESULT_OK;
        except
          // общая ошибка структуры, тут уже автоматически не разобраться
          Result := ETS_RESULT_INVALID_STRUCTURE;
        end;
      end;
    finally
      // FConnection.KillPoolDataset(VInsertDataset);
      FreeAndNil(VInsertDataset);
      // FConnection.KillPoolDataset(VUpdateDataset);
      FreeAndNil(VUpdateDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
  VSQLText, VVersionW, VContentTypeW: WideString;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
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
        // failed to select - no table - tile not found
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
          VStream := VDataset.CreateBlobStream(VDataset.FieldByName('tile_body'), bmRead);
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
      VStream.Free;
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
begin
  VExclusively := ((AFlags and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusively);
  try
    if (nil<>FConnection) then begin
      FConnection.CompactPool;
    end;
  finally
    DoEndWork(VExclusively);
  end;

  Result := ETS_RESULT_OK;
end;

destructor TDBMS_Provider.Destroy;
begin
  DoBeginWork(TRUE);
  try
    InternalProv_Disconnect;
  finally
    DoEndWork(TRUE);
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
  
  inherited;
end;

procedure TDBMS_Provider.DoBeginWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FProvSync.BeginWrite
  else
    FProvSync.BeginRead;
end;

procedure TDBMS_Provider.DoEndWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FProvSync.EndWrite
  else
    FProvSync.EndRead;
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
  VSQLText: WideString;
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

function TDBMS_Provider.GetSQL_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  out ADeleteSQLResult: WideString
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
  out ASQLTextResult: WideString
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

function TDBMS_Provider.GetSQL_InsertIntoService(
  const AExclusively: Boolean;
  out ASQLTextResult: WideString
): Byte;
var
  VDataset: TDBMS_Dataset;
  VNewIdService: SmallInt;
  VNewIdContentType: SmallInt;
  VNewServiceCode: AnsiString;
  VSQLText: WideString;
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
                            WideStrToDB(VNewServiceCode) + ',' +
                            WideStrToDB(InternalGetServiceNameByHost) + ',' +
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
  out AInsertSQLResult, AUpdateSQLResult: WideString;
  out AInsertUpdateSubType: TInsertUpdateSubType;
  out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: WideString
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound, VRequestedContentTypeFound: Boolean;
  VIdContentType: SmallInt;
  VReqVersion: TVersionAA;
  VUseCommonTiles: Boolean;
  VNewTileSize: LongInt;
  VNewTileBody: WideString;
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

function TDBMS_Provider.GetSQL_SelectContentTypes: WideString;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_CONTENTTYPE;
end;

function TDBMS_Provider.GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): WideString;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_code='+WideStrToDB(AServiceCode);
end;

function TDBMS_Provider.GetSQL_SelectService_ByHost: WideString;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_name='+WideStrToDB(InternalGetServiceNameByHost);
end;

function TDBMS_Provider.GetSQL_SelectTile(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: WideString
): Byte;
var
  VSQLTile: TSQLTile;
  VSQLParts: TSQLParts;
  VReqVersion: TVersionAA;
begin
  // заполняем VSQLTile по переданным значениям
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  (*
  // если таблицы ещё нет - НЕ пробуем её создать, а вернём ошибку (всё равно тайла нет)
  // только в эксклюзивном режиме
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := ETS_RESULT_UNKNOWN_TILE_TABLE;
      Exit;
      {
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // проверка результата создания новой таблицы
      if (Result<>ETS_RESULT_OK) then
        Exit;
      }
    end;
  end;
  *)

  // заготовки
  VSQLParts.SelectSQL := 'SELECT v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := VSQLTile.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // забацаем SELECT

  // надо ли учитывать часто используемые тайлы
  if (ETS_UCT_NO=FDBMS_Service_Info.use_common_tiles) then begin
    // нет
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.tile_size,v.tile_body';
  end else begin
    // да
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'isnull(k.common_size,v.tile_size) as tile_size,isnull(k.common_body,v.tile_body) as tile_body';
    VSQLParts.FromSQL := VSQLParts.FromSQL + ' left outer join  u_' + InternalGetServiceNameByDB + ' k on v.tile_size<0 and v.tile_size=-k.id_common_tile and v.id_contenttype=k.id_common_type';
  end;

  // забацаем FROM, WHERE и ORDER BY

  // определим запрошенную версию
  if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // как Ansi
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ASelectBufferIn^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // как Wide
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ASelectBufferIn^.szVersionIn),
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

  // собираем всё вместе
  ASQLTextResult := VSQLParts.SelectSQL +
                  ' FROM ' + VSQLParts.FromSQL +
                 ' WHERE v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                   ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetSQL_SelectVersions: WideString;
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
var
  VXYMaskWidth: Byte;
  VNeedToQuote: Boolean;
  VEngineType: TEngineType;
begin
  // сохраняем зум (от 1 до 24)
  ASQLTile^.Zoom := AXYZ^.z;
  
  // делим XY на "верхнюю" и "нижнюю" части
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;
  
  // строим имя таблицы для тайлов
  ASQLTile^.UnquotedTileTableName := ASQLTile^.ZoomToTableNameChar(VNeedToQuote) +
                                     ASQLTile^.HXToTableNameChar(VXYMaskWidth) +
                                     FDBMS_Service_Info.id_div_mode +
                                     ASQLTile^.HYToTableNameChar(VXYMaskWidth) +
                                     '_' +
                                     InternalGetServiceNameByDB;

  VEngineType := FConnection.GetCheckedEngineType;

  if VNeedToQuote or c_SQL_QuotedIdentifierForcedForTiles[VEngineType] then begin
    ASQLTile^.QuotedTileTableName := c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] + ASQLTile^.UnquotedTileTableName + c_SQL_QuotedIdentifierValue[VEngineType, qp_After];
  end else begin
    ASQLTile^.QuotedTileTableName := ASQLTile^.UnquotedTileTableName;
  end;

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

function TDBMS_Provider.InternalGetServiceNameByDB: WideString;
begin
  Result := FDBMS_Service_Code;
end;

function TDBMS_Provider.InternalGetServiceNameByHost: WideString;
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
  Result := FConnection.EnsureConnected(AExclusively);

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
  VSelectCurrentServiceSQL: WideString;
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
    except
      // обломались при открытии датасета - значит нет таблицы
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
  VGlobalStorageIdentifier, VServiceName: WideString;
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
  VDataset: TDBMS_Dataset;
  VVersionsTableName_UnquotedWithoutPrefix: String;
  VVersionsTableName_QuotedWithPrefix: String;
begin
  Assert(AExclusively);

  VDataset := FConnection.MakePoolDataset;
  try
    VVersionsTableName_UnquotedWithoutPrefix := c_Prefix_Versions + InternalGetServiceNameByDB;
    VVersionsTableName_QuotedWithPrefix := FConnection.ForcedSchemaPrefix + VVersionsTableName_UnquotedWithoutPrefix;

    // проверим, а есть ли табличка с версиями сервиса
    if (not TableExists(VVersionsTableName_QuotedWithPrefix)) then
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

    // забацаем SQL для вставки записи о новой версии
    VDataset.SQL.Text := 'INSERT INTO ' + VVersionsTableName_QuotedWithPrefix +
              '(id_ver,ver_value,ver_date,ver_number) VALUES (' +
              IntToStr(ANewVersionPtr^.id_ver) + ',' +
              WideStrToDB(ANewVersionPtr^.ver_value) + ',' +
              SQLDateTimeToDBValue(ANewVersionPtr^.ver_date) + ',' +
              IntToStr(ANewVersionPtr^.ver_number) + ')';
    try
      // выполним (напрямую)
      VDataset.ExecSQL(TRUE);
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.PrimaryConstraintViolation(const AException: Exception): Boolean;
var VMessage: String;
begin
  VMessage := LowerCase(AException.Message);
  Result := (System.Pos('violation', VMessage)>0) and (System.Pos('constraint', VMessage)>0);
  // FB: 'violation of PRIMARY or UNIQUE KEY constraint "PK_C2I1_NMC_RECENCY" on table "C2I1_nmc_recency"'
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

function TDBMS_Provider.SQLDateTimeToDBValue(const ADateTime: TDateTime): WideString;
begin
  Result := c_SQL_DateTime_Literal_Prefix[FConnection.GetCheckedEngineType] +
            WideStrToDB(FormatDateTime(c_DateTimeToDBFormat, ADateTime, FFormatSettings));
end;

function TDBMS_Provider.TableExists(const ATableName: WideString): Boolean;
var
  VDataset: TDBMS_Dataset;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      // простая универсальная проверка существования и доступности таблицы
      VDataset.OpenSQL('select 1 as a from ' + ATableName + ' where 0=1');
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
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
