unit u_DBMS_TileEnum;

{$include i_DBMS.inc}

interface

uses
  Types,
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_ETS_Path,
  t_ETS_Provider,
  t_ODBC_Buffer,
  t_DBMS_version,
  t_DBMS_service,
  t_DBMS_contenttype,
  i_DBMS_Provider,
  u_DBMS_Connect;

type
  TTileEnumState = (
    tes_Start,
    tes_Error,
    tes_Fetched
  );

  TDBMS_TileEnum = class(TInterfacedObject, IDBMS_TileEnum)
  private
    FDBMS_Worker: IDBMS_Worker;
    FDBMS_Service_Info: PDBMS_Service_Info;
    FVersionList: TVersionList;
    FContentTypeList: TContentTypeList;
    FStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
    FFlags: LongWord;
    FHostPointer: Pointer;
    FCallbackProc: Pointer;
    FConnectionForEnum: IDBMS_Connection;
    FUseSingleSection: Boolean;
    FScanMaxRows: AnsiString;
  private
    FState: TTileEnumState;
    FLastError: Byte;
    FListOfTables: TStringList;
    FNextTableIndex: Integer;
    FENUM_Prefix: String;
    FENUM_Select: String;
    FFetchTilesCols: TOdbcFetchCols7;
  private
    FNextBufferOut: TETS_NEXT_TILE_ENUM_OUT;
    FTileXYZ: TTILE_ID_XYZ;
    FXYUpperToTable: TPoint;
    // кэш версии тайла
    FTileVersionId: SmallInt;
    FTileVersionA: AnsiString;
    FTileVersionW: WideString;
    // кэш типа тайла
    FTileContentTypeId: SmallInt;
    FTileContentTypeA: AnsiString;
    FTileContentTypeW: WideString;
  private
    procedure ConnChanged;
    procedure InitTileCache;
  private
    function SetError(const AErrorCode: Byte): Byte;
    function CallHostForCurrentRecord(
      const ACallbackPointer: Pointer;
      const ANextBufferIn: PETS_GET_TILE_RECT_IN
    ): Byte;
    function ReadListOfTables: Boolean;
    function GetTablesWithTilesBySelect: Boolean;
    function CannotSwitchToNextSection(var AResult: Byte): Boolean;
    function OpenNextTableAndFetch(const ANextBufferIn: PETS_GET_TILE_RECT_IN): Boolean;
    procedure GetZoomAndHighXYFromCurrentTable;
  private
    function InternalFetch: Boolean; inline;
    procedure InternalClose; inline;
  private
    { IDBMS_TileEnum }
    function GetNextTile(
      const ACallbackPointer: Pointer;
      const ANextBufferIn: PETS_GET_TILE_RECT_IN
    ): Byte;
  public
    constructor Create(
      const ADBMS_Worker: IDBMS_Worker;
      const ADBMS_Service_Info: PDBMS_Service_Info;
      const AVersionList: TVersionList;
      const AContentTypeList: TContentTypeList;
      const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
      const AFlags: LongWord;
      const AHostPointer: Pointer;
      const ACallbackProc: Pointer;
      const AConnectionForEnum: IDBMS_Connection;
      const AUseSingleSection: Boolean
    );
    destructor Destroy; override;
  end;


implementation

uses
  t_SQL_types,
  t_DBMS_Connect,
  t_DBMS_Template;

{ TDBMS_TileEnum }

function TDBMS_TileEnum.CallHostForCurrentRecord(
  const ACallbackPointer: Pointer;
  const ANextBufferIn: PETS_GET_TILE_RECT_IN
): Byte;
var
  VNewIdVer, VNewIdContentType: SmallInt;
  VFoundValue: AnsiString;
begin
  // запуливаем текущую запись в резалтсете на хост
  FNextBufferOut.TileInfo.dwOptionsOut := 0;

  // координата Z уже заполнена из имени таблицы

  // берём координаты XY ("младшая" часть)
  // и присовокупляем "верхние" значения из имени таблицы
  FDBMS_Service_Info.CalcBackToTilePos(
    FFetchTilesCols.Base.GetAsLongInt(1),
    FFetchTilesCols.Base.GetAsLongInt(2),
    FXYUpperToTable,
    @(FTileXYZ.xy)
  );
  
  // версия тайла
  FFetchTilesCols.Base.ColToSmallInt(3, VNewIdVer);

  // если версия сменилась -  сменим ссылку на значение версии
  // если не изменилась - в буфере ничего не меняем
  if (VNewIdVer <> FTileVersionId) then begin
    // версия сменилась - берём версию по идентификатору
    if FVersionList.FindItemByIdVer(VNewIdVer, nil, VFoundValue) then begin
      // значение найдено
      FTileVersionId := VNewIdVer;
      if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
        // как Ansi
        FTileVersionA := VFoundValue;
        FNextBufferOut.TileInfo.szVersionOut := PAnsiChar(@FTileVersionA[1]);
      end else begin
        // как Wide
        FTileVersionW := VFoundValue;
        FNextBufferOut.TileInfo.szVersionOut := PWideChar(@FTileVersionW[1]);
      end;
    end else begin
      // версия не найдена
      Result := ETS_RESULT_ENUM_UNKNOWN_VERSION;
      Exit;
    end;
  end;

  // размер тайла
  FFetchTilesCols.Base.ColToLongInt(4, FNextBufferOut.TileInfo.dwTileSize);

  // проверка на корректность
  // Assert(FFetchTilesCols.Base.IsNull(7) = (FNextBufferOut.TileInfo.dwTileSize=0));

  // если TNE - значит тело и тип можно не тащить
  // TODO: скорректировать при реализации реестра часто используемых тайлов
  if (FNextBufferOut.TileInfo.dwTileSize <= 0) or FFetchTilesCols.Base.IsNull(7) then begin
    // TNE
    with FNextBufferOut.TileInfo do begin
      ptTileBuffer := nil;
      szContentTypeOut := nil;
      dwOptionsOut := dwOptionsOut or ETS_ROO_TNE_EXISTS;
    end;
  end else begin
    // TILE
    with FNextBufferOut.TileInfo do begin
      dwOptionsOut := dwOptionsOut or ETS_ROO_TILE_EXISTS;
      // тело тайла
      ptTileBuffer := FFetchTilesCols.Base.GetLOBBuffer(7);
    end;

    // тип тайла
    FFetchTilesCols.Base.ColToSmallInt(5, VNewIdContentType);

    // если тип тайла сменился -  сменим ссылку на значение
    if (VNewIdContentType <> FTileContentTypeId) then begin
      // смотрим тип тайла по идентификатору
      if FContentTypeList.FindItemByIdContentType(VNewIdContentType, nil, VFoundValue) then begin
        // новое значение нашлось
        FTileContentTypeId := VNewIdContentType;
        if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_OUT) <> 0) then begin
          // как Ansi
          FTileContentTypeA := VFoundValue;
          FNextBufferOut.TileInfo.szContentTypeOut := PAnsiChar(@FTileContentTypeA[1]);
        end else begin
          // как Wide
          FTileContentTypeW := VFoundValue;
          FNextBufferOut.TileInfo.szContentTypeOut := PWideChar(@FTileContentTypeW[1]);
        end;
      end else begin
        // тип тайла не найден - полный бред
        Result := ETS_RESULT_ENUM_UNKNOWN_CONTENTTYPE;
        Exit;
      end;
    end;
  end;

  // дата
  FFetchTilesCols.Base.ColToDateTime(6, FNextBufferOut.TileInfo.dtLoadedUTC);

  // пуляем всё это в функцию обратного вызова
  Result := TETS_NextTileEnum_Callback(FCallbackProc)(
    FHostPointer,
    ACallbackPointer,
    ANextBufferIn,
    @FNextBufferOut
  );
end;

function TDBMS_TileEnum.CannotSwitchToNextSection(var AResult: Byte): Boolean;
begin
  // если работа ограничена одной секцией - дальше не идём
  // если больше нет секций - тоже
  Result := FUseSingleSection or (nil = FConnectionForEnum.FNextSectionConn);

  // старую секцию отключим
  FConnectionForEnum.FODBCConnectionHolder.DisConnect;

  if Result then begin
    // успешный конец (код ошибки, что всё закончено)
    SetError(ETS_RESULT_COMPLETED_SUCCESSFULLY);
    AResult := ETS_RESULT_OK;
  end else begin
    // переходим к следующей секции
    FConnectionForEnum := FConnectionForEnum.FNextSectionConn;
    // обработаем смену секции
    ConnChanged;
  end;
end;

procedure TDBMS_TileEnum.ConnChanged;
begin
  FLastError := FConnectionForEnum.EnsureConnected(TRUE, FStatusBuffer);
  if (ETS_RESULT_OK <> FLastError) then begin
    FState := tes_Error;
    Exit;
  end;

  FENUM_Prefix := FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_ENUM_PREFIX);
  FENUM_Select := FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_ENUM_SELECT);

  // если не указан запрос - берём запрос по умолчанию для текущего сервера БД (если он указан)
  if (0 = Length(FENUM_Select)) then begin
    FENUM_Select := c_SQL_ENUM_SVC_Tables[FConnectionForEnum.GetCheckedEngineType];
  end;

  // подменим в запросе %SVC% на реальное имя сервиса
  if (0 < Length(FENUM_Select)) then begin
    FENUM_Select := StringReplace(
      FENUM_Select,
      c_Templated_SVC,
      FConnectionForEnum.FPathDiv.ServiceName,
      [rfReplaceAll, rfIgnoreCase]
    );
  end;
end;

constructor TDBMS_TileEnum.Create(
  const ADBMS_Worker: IDBMS_Worker;
  const ADBMS_Service_Info: PDBMS_Service_Info;
  const AVersionList: TVersionList;
  const AContentTypeList: TContentTypeList;
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
  const AFlags: LongWord;
  const AHostPointer: Pointer;
  const ACallbackProc: Pointer;
  const AConnectionForEnum: IDBMS_Connection;
  const AUseSingleSection: Boolean
);
begin
  inherited Create;
  // поля снаружи
  FDBMS_Worker := ADBMS_Worker;
  FDBMS_Service_Info :=  ADBMS_Service_Info;
  FVersionList := AVersionList;
  FContentTypeList := AContentTypeList;
  FStatusBuffer := AStatusBuffer;
  FFlags := AFlags;
  FHostPointer := AHostPointer;
  FCallbackProc := ACallbackProc;
  FConnectionForEnum := AConnectionForEnum;
  FUseSingleSection := AUseSingleSection;
  // свои местные поля
  FState := tes_Start;
  FLastError := ETS_RESULT_OK;
  FListOfTables := nil;
  if TryStrToInt(FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_SCAN_MaxRows), FNextTableIndex) then begin
    FScanMaxRows := IntToStr(FNextTableIndex);
  end else begin
    FScanMaxRows := '';
  end;
  FNextTableIndex := 0;
  // для хоста
  FillChar(FNextBufferOut, SizeOf(FNextBufferOut), 0);
  FNextBufferOut.TileFull := @FTileXYZ;
  // установлена секция для подключения
  FFetchTilesCols.Init;
  InitTileCache;
  ConnChanged;
end;

destructor TDBMS_TileEnum.Destroy;
begin
  InternalClose;
  FreeAndNil(FListOfTables);
  FConnectionForEnum := nil;
  FDBMS_Worker := nil;
  inherited Destroy;
end;

function TDBMS_TileEnum.GetNextTile(
  const ACallbackPointer: Pointer;
  const ANextBufferIn: PETS_GET_TILE_RECT_IN
): Byte;
begin
  if (tes_Error = FState) then begin
    // ошибка или всё кончилось
    Result := FLastError;
    Exit;
  end;

  if FDBMS_Worker.IsUninitialized then begin
    Result := ETS_RESULT_OK;
    FLastError := ETS_RESULT_OK;
    Exit;
  end;

  // ссылка уже должна быть в FConnectionForEnum
  if (nil=FConnectionForEnum) then begin
    // нет секции
    Result := SetError(ETS_RESULT_CANNOT_CONNECT);
    Exit;
  end;

  repeat
    // закрыли
    if FDBMS_Worker.IsUninitialized then begin
      Result := ETS_RESULT_OK;
      FLastError := ETS_RESULT_OK;
      Exit;
    end;

    // режим запуска новой секции (подключения)
    while (tes_Start = FState) do begin
      // проверяемся
      if FDBMS_Worker.IsUninitialized then begin
        Result := ETS_RESULT_OK;
        FLastError := ETS_RESULT_OK;
        Exit;
      end;

      // подключаем подключение (если ешё не подключено)
      Result := FConnectionForEnum.EnsureConnected(TRUE, FStatusBuffer);
      if (ETS_RESULT_OK <> Result) then begin
        FLastError := Result;
        FState := tes_Error;
        Exit;
      end;

      // получаем список тайловых таблиц нашего сервиса
      // счётчик следующей таблицы сбрасывается на 0
      if not ReadListOfTables then begin
        // не смогли получить (даже пустой) список таблиц
        Result := SetError(ETS_RESULT_INVALID_STRUCTURE);
        Exit;
      end;

      // список таблиц получили
      if (0=FListOfTables.Count) then begin
        // но он пустой - переходим к следующему подключению, иначе всё закончили
        if CannotSwitchToNextSection(Result) then
          Exit;
      end;

      // список таблиц не пустой - читаем из первой подходящей таблицы
      if OpenNextTableAndFetch(ANextBufferIn) then begin
        // успешно открыли таблицу и зафетчили хотя бы одну запись
        FState := tes_Fetched;
        break;
      end else begin
        // не смогли открыть таблицу:
        // либо таблицы кончились (пустые таблицы пропускали)
        // либо ошибка
        if (ETS_RESULT_OK = FLastError) then begin
          // успешно но безрезультатно пролистали таблицы - идём к следующей секции
          if CannotSwitchToNextSection(Result) then
            Exit;
        end else begin
          // ошибка
          Result := FLastError;
          FState := tes_Error;
          Exit;
        end;
      end;
    end;

    if (tes_Fetched = FState) then begin
      // запись получена - позовём callback
      // чтобы отправить её на хост
      Result := CallHostForCurrentRecord(ACallbackPointer, ANextBufferIn);

      // проверим результат
      if (ETS_RESULT_OK <> Result) then begin
        // какой-то облом
        FLastError := Result;
        FState := tes_Error;
        Exit;
      end;

      // дёрнем следующую запись
      if InternalFetch then begin
        // всё в порядке - на следующей итерации цикла прилетевшую запись подберём
        //Exit;
      end else begin
        // не всё в порядке:
        // таблица кончилась - надо тащить следующую
        // или просто ошибка
        if (ETS_RESULT_OK = FLastError) then begin
          // кончилась таблица - берём следующую
          // пробуем переключаться на следующую и следующую таблицу
          // покуда не попрут данные или таблицы не кончатся
          if OpenNextTableAndFetch(ANextBufferIn) then begin
            // успешно открыли таблицу и зафетчили хотя бы одну запись
            // всё в порядке - на следующей итерации цикла прилетевшую запись подберём
            //Exit;
          end else begin
            // таблицы кончились или ошибка
            if (ETS_RESULT_OK = FLastError) then begin
              // это была последняя таблица - надо менять подключение
              if CannotSwitchToNextSection(Result) then
                Exit;
              FState := tes_Start;
              //Exit;
            end else begin
              // это была ошибка
              Result := FLastError;
              FState := tes_Error;
              //Exit;
            end;
          end;
        end else begin
          // ошибка
          FLastError := Result;
          FState := tes_Error;
          //Exit;
        end;
      end;

      // так как успешно отправили запись на хост - тут в любом случае надо свалить
      Exit;
    end;

  until FALSE;
end;

function TDBMS_TileEnum.GetTablesWithTilesBySelect: Boolean;
var
  VFetchTablesCols: TOdbcFetchCols3;
  VTableName: AnsiString;
begin
  Result := FALSE;
  try
    VFetchTablesCols.Init;
    try
      Result := FConnectionForEnum.FODBCConnectionHolder.OpenDirectSQLFetchCols(
        FENUM_Select,
        @(VFetchTablesCols.Base)
      );

      if Result then
      while VFetchTablesCols.Base.FetchRecord do begin
        VFetchTablesCols.Base.ColToAnsiString(1, VTableName);
        FListOfTables.Add(VTableName);
      end;
    finally
      VFetchTablesCols.Base.Close;
    end;
  except
  end;
end;

procedure TDBMS_TileEnum.GetZoomAndHighXYFromCurrentTable;
var
  VTablename: String;
  VFirst: Char;
  VPos: Integer;
begin
  // таблица имеет имя вроде такого: I54I24_bingsat
  VTablename := FListOfTables[FNextTableIndex];

  // возьмём зум - это первый символ (в примере - 'I')
  VFirst := VTablename[1];
  if (VFirst in ['1'..'9']) then begin
    // зумы от 1 до 9
    FTileXYZ.z := Ord(VFirst) - Ord('1') + 1;
  end else if (VFirst in ['A'..'W']) then begin
    // зумы от 10
    FTileXYZ.z := Ord(VFirst) - Ord('A') + 10;
  end else if (VFirst in ['a'..'w']) then begin
    // зумы от 10
    FTileXYZ.z := Ord(VFirst) - Ord('a') + 10;
  end else begin
    // в реальности это ошибка
    FTileXYZ.z := 0;
    FXYUpperToTable.X := 0;
    FXYUpperToTable.Y := 0;
    Exit;
  end;

  // берём старшие значения XY из имени таблицы
  // для этого откусываем все что от подчёркивания
  // и собственно первый символ
  VPos := System.Pos('_', VTablename);
  VTablename := System.Copy(VTablename, 2, (VPos-2));

  // ищем разделитель координат - это символ деления по таблицам
  // на самом деле он может быть в любом регистре
  VTablename := UpperCase(VTablename);
  VPos := System.Pos(FDBMS_Service_Info^.id_div_mode, VTablename);

  if (VPos>0) then begin
    // есть разделитель - перед ним X, а после него Y (как HEX)
    FXYUpperToTable.X := StrToIntDef('$'+System.Copy(VTablename, 1, (VPos-1)), 0);
    FXYUpperToTable.Y := StrToIntDef('$'+System.Copy(VTablename, (VPos+1), Length(VTablename)), 0);
  end else begin
    // в реальности это ошибка
    FTileXYZ.z := 0;
    FXYUpperToTable.X := 0;
    FXYUpperToTable.Y := 0;
  end;
end;

procedure TDBMS_TileEnum.InitTileCache;
begin
  FTileVersionId := 0;
  FTileVersionA := '';
  FTileVersionW := '';
  FTileContentTypeId := 0;
  FTileContentTypeA := '';
  FTileContentTypeW := '';
end;

procedure TDBMS_TileEnum.InternalClose;
begin
  FFetchTilesCols.Base.Close;
end;

function TDBMS_TileEnum.InternalFetch: Boolean;
begin
  // тащим следующую запись из существующего открытого запроса
  Result := FFetchTilesCols.Base.FetchRecord;
end;

function TDBMS_TileEnum.OpenNextTableAndFetch(const ANextBufferIn: PETS_GET_TILE_RECT_IN): Boolean;
var
  VSQLText: AnsiString;
  VEngineType: TEngineType;
begin
  Result := FALSE;

  repeat
    if (FNextTableIndex >= FListOfTables.Count) then begin
      // прошли все таблицы в подключении
      Exit;
    end;

    VEngineType := FConnectionForEnum.GetCheckedEngineType;

    // пробуем открыть таблицу с этим номером
    VSQLText := 'v.x,v.y,v.id_ver,v.tile_size,v.id_contenttype,v.load_date,v.tile_body' +
                 ' FROM ' + FENUM_Prefix +
                 c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] +
                 FListOfTables[FNextTableIndex] +
                 c_SQL_QuotedIdentifierValue[VEngineType, qp_After] +
                 ' v';

    // возможно надо пропустить TNE
    if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      // тащим только реально существующие тайлы
      VSQLText := VSQLText + ' WHERE v.tile_size>0';
    end;

    // возможно надо ограничить аппетиты
    // добавим TOP N или LIMIT N или ещё что (в зависимости от СУБД)
    if (0<Length(FScanMaxRows)) then
    // тащим только один тайл -
    case c_SQL_RowCount1_Mode[VEngineType] of
      rc1m_Top1: begin
        VSQLText := 'TOP '+FScanMaxRows+' ' + VSQLText;
      end;
      rc1m_First1: begin
        VSQLText := 'FIRST '+FScanMaxRows+' ' + VSQLText;
      end;
      rc1m_Limit1: begin
        VSQLText := VSQLText + ' LIMIT '+FScanMaxRows;
      end;
      rc1m_Fetch1Only: begin
        VSQLText := VSQLText + ' FETCH FIRST '+FScanMaxRows+' ROW ONLY';
      end;
      rc1m_Rows1: begin
        VSQLText := VSQLText + ' ROWS '+FScanMaxRows;
      end;
    end;

    VSQLText := 'SELECT ' + VSQLText;

    try
      InternalClose;
      if FConnectionForEnum.FODBCConnectionHolder.OpenDirectSQLFetchCols(VSQLText, @(FFetchTilesCols.Base)) then begin
        // смогли открыть
        if InternalFetch then begin
          // зафетчили запись - валим с успехом
          Result := TRUE;
          // только напоследок возьмём всё что нам надо из имени таблицы
          GetZoomAndHighXYFromCurrentTable;
          // и инкрементируем счётчик на будущее
          Inc(FNextTableIndex);
          Exit;
        end;
        // тут если открыли, но записей нет
        // перейдём к следующей таблице
        Inc(FNextTableIndex);
      end else begin
        // не смогли даже открыть - значит ошибка
        FLastError := ETS_RESULT_ENUM_TABLE_STRUCT;
        Exit;
      end;
    except
      FLastError := ETS_RESULT_ENUM_TABLE_STRUCT;
      Exit;
    end;

  until FALSE;
end;

function TDBMS_TileEnum.ReadListOfTables: Boolean;
begin
  // функция читает список таблиц в текущем подключении
  // интересуют только тайловые таблицы текущего сервиса
  FreeAndNil(FListOfTables);
  FNextTableIndex := 0;

  if (nil=FListOfTables) then
    FListOfTables := TStringList.Create
  else
    FListOfTables.Clear;

  // если указан префикс для таблиц, он он может быть совершенно произольный
  // поэтому надо уметь брать запрос из INI
  if (0 < Length(FENUM_Select)) then begin
    // будем выполнять указанный запрос
    Result := GetTablesWithTilesBySelect;
  end else begin
    // если префикс не используется - это должно сработать
    Result := FALSE;
    FLastError := ETS_RESULT_ENUM_NOT_SUPPORTED;
    (*
    Result := FConnectionForEnum.FODBCConnectionHolder.GetTablesWithTiles(
      FConnectionForEnum.FPathDiv.ServiceName,
      FListOfTables
    );
    *)
  end;
end;

function TDBMS_TileEnum.SetError(const AErrorCode: Byte): Byte;
begin
  FState := tes_Error;
  FLastError := AErrorCode;
  Result := AErrorCode;
end;

end.
