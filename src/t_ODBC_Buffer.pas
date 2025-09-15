unit t_ODBC_Buffer;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  odbcsql,
  i_StatementHandleCache,
  t_ODBC_Exception;

{$IF CompilerVersion < 19}
type
  NativeInt = Integer;
  NativeUInt = Cardinal;
{$IFEND}

type
  SIZE_T = NativeUInt;
  TOdbcColBuffer = PAnsiChar;

  PDescribeColData = ^TDescribeColData;
  TDescribeColData = packed record
    NameLen: SQLSMALLINT;
    DataType: SQLSMALLINT;
    ColumnSize: SQLULEN; // size (in characters)
    DecimalDigits: SQLSMALLINT;
    Nullable: SQLSMALLINT;
  public
    function IsLOB(const AWorkFlags: Byte): Boolean;
    function LOBDataType: SQLSMALLINT;
  end;

  POdbcColItem = ^TOdbcColItem;
  TOdbcColItem = packed record
    // параметры описания возвращённого поля
    DescribeColData: TDescribeColData;
    DescribeColName: PAnsiChar;

    // фактический размер поля для текущей записи (в описании может быть 0 для фиксированных полей)
    // так как LOB-ы не приBINDиваются - здесь лежит фактически выделенный размер
    Bind_BufferLength: SQLLEN;
    Bind_StrLen_or_Ind: SQLLEN;

    case Boolean of
      FALSE: (
        ColOffset: SQLULEN;     // смещение в общем буфере (не для LOB)
      );
      TRUE: (
        LOBPtr: TOdbcColBuffer; // собственный буфер для LOB
      );
  end;

  POdbcFetchCols = ^TOdbcFetchCols;
  TOdbcFetchCols = packed record
    Stmt: SqlHStmt;
    // флаги и опции
    WorkFlags: Byte;
    // число полей - выделено памяти (по плану, больше чем 255 у нас нет)
    ColumnsAllocated: Byte;
    // число полей - фактически по данным ODBC
    ColumnCount: SQLSMALLINT;
    // общий буфер для регулярных полей (у каждого large objects свой)
    ColBufLen: SQLLEN;
    ColBufPtr: TOdbcColBuffer;
    // статический буфер для LOB-ов (всегда фиксированной длины - длину можно задать параметром)
    LOBStatic: TOdbcColBuffer;
    // кэш для statement handle
    StatementHandleCache: IStatementHandleCache;
    // поля - нумерация с 1 (как принято в ODBC)
    Cols: array [1..1] of TOdbcColItem;
  private
    function InternalColData(const AItem: POdbcColItem): Pointer;
    procedure InternalFreeLOBs;
    procedure InternalFreeColNames;
  public
    function FetchRecord: Boolean; //inline;
    function IsActive: Boolean; inline;
    function WithColNames: Boolean; inline;
    function WithLOBs: Boolean; inline;
    function IsNull(const AColNumber: Byte): Boolean;
    procedure Close;
    function DescribeAndBind: Boolean;
    function ColIndex(const AExpectedColName: AnsiString): SmallInt;
    function GetLOBBuffer(const AColNumber: Byte): Pointer;
    function GetOptionalSmallInt(const AExpectedColName: AnsiString): SmallInt;
    function GetOptionalLongInt(const AExpectedColName: AnsiString): LongInt;
    function GetOptionalAnsiChar(const AExpectedColName: AnsiString; const ADefaultValue: AnsiChar): AnsiChar;
  public
    procedure Init;
    procedure FetchLOBs;
    procedure EnableCLOBChecking; inline;
    procedure DisableCLOBChecking; inline;
    procedure ColToAnsiChar(const AColNumber: Byte; out AValue: AnsiChar); //inline;
    procedure ColToAnsiCharDef(const AColNumber: Byte; out AValue: AnsiChar; const AValIfNull: AnsiChar);
    procedure ColToAnsiString(const AColNumber: Byte; out AValue: AnsiString);
    procedure ColToSmallInt(const AColNumber: Byte; out AValue: SmallInt);
    procedure ColToLongInt(const AColNumber: Byte; out AValue: LongInt);
    procedure ColToDateTime(const AColNumber: Byte; out AValue: TDateTime);
  public
    function GetAsLongInt(const AColNumber: Byte): LongInt; inline;
  end;

  TOdbcFetchCols2 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..2] of TOdbcColItem;
  public
    procedure Init;
  end;

  TOdbcFetchCols3 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..3] of TOdbcColItem;
  public
    procedure Init;
  end;

  TOdbcFetchCols5 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..5] of TOdbcColItem;
  public
    procedure Init;
  end;

  TOdbcFetchCols7 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..7] of TOdbcColItem;
  public
    procedure Init;
  end;

  TOdbcFetchCols10 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..10] of TOdbcColItem;
  public
    procedure Init;
  end;

  TOdbcFetchCols12 = packed record
    Base: TOdbcFetchCols;
    ExtCols: array [2..12] of TOdbcColItem;
  public
    procedure Init;
  end;

const
  // for WorkFlags
  WF_ACTIVE  = $01; // Statement is active - allow to fetch
  WF_STATIC  = $02; // Buffer is static - do not reallocate it!
  WF_COLNAME = $04; // надо тащить имена полей - будет доступ по имени
  WF_CLOBCHK = $08; // varchar(255) как CLOB (если длиннее - всегда как CLOB)
  WF_HAS_LOB = $20; // Есть хотя бы одно поле LOB (устанавливается автоматически)

function OdbcFetchStmt(const AStmt: SQLHANDLE; var AWorkFlags: Byte): Boolean;
  
implementation

function OdbcAlloc(const ASize: SIZE_T): TOdbcColBuffer; //inline;
begin
  Result := HeapAlloc(GetProcessHeap, 0, ASize);
end;

function OdbcRealloc(const ABuffer: TOdbcColBuffer; const ASize: SIZE_T): TOdbcColBuffer; //inline;
begin
  if (nil=ABuffer) then
    Result := OdbcAlloc(ASize)
  else
    Result := HeapReAlloc(GetProcessHeap, 0, ABuffer, ASize);
end;

procedure OdbcFreeBuffer(var ABufPtr: TOdbcColBuffer);
begin
  if (ABufPtr <> nil) then begin
    HeapFree(GetProcessHeap, 0, ABufPtr);
    ABufPtr := nil;
  end;
end;

procedure OdbcFreeColBuffer(var AColBufPtr: TOdbcColBuffer; var AColBufLen: SQLLEN; const AWorkFlags: Byte);
begin
  // статический буфер не освобождаем
  if ((AWorkFlags and WF_STATIC) <> 0) then
    Exit;

  if (AColBufPtr <> nil) and (AColBufLen > 0) then begin
    HeapFree(GetProcessHeap, 0, AColBufPtr);
  end;
  AColBufPtr := nil;
  AColBufLen := 0;
end;

function OdbcFetchStmt(const AStmt: SQLHANDLE; var AWorkFlags: Byte): Boolean;
var
  VResult: SQLRETURN;
begin
  // может уже закрыты
  if ((AWorkFlags and WF_ACTIVE) = 0) then begin
    Result := FALSE;
    Exit;
  end;

  // тащим строку с сервера
  VResult := SQLFetch(AStmt);
  Result := SQL_SUCCEEDED(VResult);
  
  // проверяем результат
  if (not Result) then begin
    // деактивируемся, так как больше данных нет
    AWorkFlags := AWorkFlags and (not WF_ACTIVE);
    SQLCloseCursor(AStmt);

    // если SQL_NO_DATA - просто всё вытащили
    // иначе проверяем результат
    if (SQL_NO_DATA <> VResult) then begin
      CheckStatementResult(AStmt, VResult, EODBCFetchStmtError);
    end;
  end;
end;

function OdbcNumericToInt(const ANumericPtr: PSQL_NUMERIC_STRUCT): LongInt;
var
  i: Byte;
  VCur, VL, VM: Byte;
  VLast: LongInt;
begin
  Result := 0;
  VLast := 1;

  for i := 0 to SQL_MAX_NUMERIC_LEN-1 do begin
    // стащим значение из структуры
    VCur := ANumericPtr^.Val[i];
    VL := VCur mod 16;
    VM := VCur div 16;
    // итерация для результата
    Result := Result + VLast * VL;
    VLast := VLast * 16;
    Result := Result + VLast * VM;
    VLast := VLast * 16;
  end;

  if ANumericPtr^.Sign=0 then begin
    Result := -Result;
  end;
end;

function OdbcTryEncodeTimeStamp(const ATimeStampPtr: PSQL_TIMESTAMP_STRUCT; out AValue: TDateTime): Boolean;
var VInDay: TDateTime;
begin
  with ATimeStampPtr^ do begin
    // год-месяц-день
    Result := TryEncodeDate(Year, Month, Day, AValue);
    if (not Result) then
      Exit;
    // внутри дня
    Result := TryEncodeTime(Hour, Minute, Second, (Fraction div 1000000), VInDay);
    if (not Result) then
      Exit;
    // всё вместе
    if (AValue<0) then
      AValue := AValue - VInDay
    else
      AValue := AValue + VInDay;
  end;
end;

{ TOdbcFetchCols }

procedure TOdbcFetchCols.Close;
begin
  // free statement handle
  if (Stmt <> SQL_NULL_HANDLE) then begin
    Assert(StatementHandleCache<>nil);
    StatementHandleCache.FreeStatement(Stmt);
    Stmt := SQL_NULL_HANDLE;
  end;
  StatementHandleCache := nil;
  // free buffers
  OdbcFreeColBuffer(ColBufPtr, ColBufLen, WorkFlags);
  OdbcFreeBuffer(LOBStatic);
  InternalFreeLOBs;
  InternalFreeColNames;
end;

procedure TOdbcFetchCols.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  ColumnsAllocated := 1;
end;

function TOdbcFetchCols.InternalColData(const AItem: POdbcColItem): Pointer;
begin
  if AItem^.DescribeColData.IsLOB(WorkFlags) then begin
    // свой буфер
    Result := AItem^.LOBPtr;
  end else begin
    // общий буфер
    Result := ColBufPtr + AItem^.ColOffset;
  end;
end;

procedure TOdbcFetchCols.InternalFreeColNames;
var
  i: SQLUSMALLINT;
  VItem: POdbcColItem;
begin
  // грохнем буфера для имён полей
  if ((WorkFlags and WF_COLNAME) <> 0) then
  for i := 1 to ColumnCount do begin
    VItem := @(Cols[i]);
    OdbcFreeBuffer(VItem^.DescribeColName);
  end;
end;

procedure TOdbcFetchCols.InternalFreeLOBs;
var
  i: SQLUSMALLINT;
  VItem: POdbcColItem;
begin
  // грохнем буфера LOB-ов
  if WithLOBs then
  for i := 1 to ColumnCount do begin
    VItem := @(Cols[i]);
    if VItem^.DescribeColData.IsLOB(WorkFlags) then begin
      OdbcFreeColBuffer(VItem^.LOBPtr, VItem^.Bind_BufferLength, 0);
    end;
  end;
end;

function TOdbcFetchCols.ColIndex(const AExpectedColName: AnsiString): SmallInt;
var
  i: SQLUSMALLINT;
  VItem: POdbcColItem;
begin
  if ((WorkFlags and WF_COLNAME) <> 0) then
  if (ColumnCount>0) then
  for i := 1 to ColumnCount do begin
    VItem := @(Cols[i]);
    if (Length(AExpectedColName) = VItem^.DescribeColData.NameLen) then
    if (0 = StrLIComp(VItem^.DescribeColName, @AExpectedColName[1], Length(AExpectedColName))) then begin
      Result := i;
      Exit;
    end;
  end;

  // не нашлось
  Result := -1;
end;

procedure TOdbcFetchCols.ColToAnsiChar(const AColNumber: Byte; out AValue: AnsiChar);
begin
  ColToAnsiCharDef(AColNumber, AValue, #0);
end;

procedure TOdbcFetchCols.ColToAnsiCharDef(const AColNumber: Byte; out AValue: AnsiChar; const AValIfNull: AnsiChar);
var
  VItem: POdbcColItem;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  VItem := @(Cols[AColNumber]);

  AValue := AValIfNull;

  // если NULL - вернём значение по умолчанию
  if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then
    Exit;

  AValue := PAnsiChar(InternalColData(VItem))^;
end;

procedure TOdbcFetchCols.ColToAnsiString(const AColNumber: Byte; out AValue: AnsiString);
var
  VItem: POdbcColItem;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  VItem := @(Cols[AColNumber]);

  AValue := '';

  // если NULL - вернём пустую строку
  if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then
    Exit;

  if (VItem^.Bind_StrLen_or_Ind>0) then begin
    SetString(AValue, PAnsiChar(InternalColData(VItem)), VItem^.Bind_StrLen_or_Ind);
    AValue := TrimRight(AValue);
  end;
end;

procedure TOdbcFetchCols.ColToDateTime(const AColNumber: Byte; out AValue: TDateTime);
var
  VItem: POdbcColItem;
  VFull: PSQL_TIMESTAMP_STRUCT;
  //VInt: LongInt;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  VItem := @(Cols[AColNumber]);

  AValue := 0;
  
  // если NULL - вернём 0
  if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then
    Exit;
    
  // обрабатываем разные типы
  case VItem^.DescribeColData.DataType of
    SQL_TYPE_DATE: begin
      // SQL_DATE_STRUCT
      with PSQL_DATE_STRUCT(InternalColData(VItem))^ do begin
        if not TryEncodeDate(Year, Month, Day, AValue) then
          raise EODBCConvertFromDateError.Create(
            IntToStr(AColNumber) + ':' +
            IntToStr(Year) + '_' +
            IntToStr(Month) + '_' +
            IntToStr(Day)
          );
      end;
    end;
    SQL_TYPE_TIME: begin
      // SQL_TIME_STRUCT
      with PSQL_TIME_STRUCT(InternalColData(VItem))^ do begin
        if not TryEncodeTime(Hour, Minute, Second, 0, AValue) then
          raise EODBCConvertFromTimeError.Create(
            IntToStr(AColNumber) + ':' +
            IntToStr(Hour) + '_' +
            IntToStr(Minute) + '_' +
            IntToStr(Second)
          );
      end;
    end;
    SQL_TYPE_TIMESTAMP: begin
      // SQL_TIMESTAMP_STRUCT
      VFull := PSQL_TIMESTAMP_STRUCT(InternalColData(VItem));
      with VFull^ do begin
        if not OdbcTryEncodeTimeStamp(VFull, AValue) then
          raise EODBCConvertFromTimeStampError.Create(
            IntToStr(AColNumber) + ':' +
            IntToStr(Year) + '_' +
            IntToStr(Month) + '_' +
            IntToStr(Day) + '_' +
            IntToStr(Hour) + '_' +
            IntToStr(Minute) + '_' +
            IntToStr(Second) + '_' +
            IntToStr(Fraction)
          );
      end;
    end;
    else begin
      // сюда по идее не должны попадать
      raise EODBCConvertDateTimeError.Create(
        IntToStr(AColNumber) + ':' +
        IntToStr(VItem^.DescribeColData.DataType)
      );
    end;
  end;
end;

procedure TOdbcFetchCols.ColToLongInt(const AColNumber: Byte; out AValue: LongInt);
var
  VItem: POdbcColItem;
  VInt: LongInt;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  VItem := @(Cols[AColNumber]);

  AValue := 0;

  // если NULL - вернём 0
  if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then
    Exit;

  // обрабатываем разные типы
  case VItem^.DescribeColData.DataType of
    SQL_SMALLINT: begin
      AValue := PSmallInt(InternalColData(VItem))^;
    end;
    SQL_INTEGER: begin
      AValue := PLongInt(InternalColData(VItem))^;
    end;
    SQL_TINYINT: begin
      AValue := PByte(InternalColData(VItem))^;
    end;
    SQL_BIGINT: begin
      AValue := PSQLBIGINT(InternalColData(VItem))^;
    end;
    SQL_NUMERIC: begin
      // SQL_NUMERIC_STRUCT
      VInt := OdbcNumericToInt(PSQL_NUMERIC_STRUCT(InternalColData(VItem)));
      if (VItem^.DescribeColData.DecimalDigits<>0) then begin
        // TODO: тут надо делиться или умножаться на степень 10
        AValue := VInt;
      end else begin
        // не надо делить или умножать
        AValue := VInt;
      end;
    end;
    SQL_DOUBLE: begin
      // SQLDOUBLE
      // TODO: необходима корректная проверка округления
      //if (0=VItem^.DescribeColData.DecimalDigits) then begin
        AValue := Round(PSQLDOUBLE(InternalColData(VItem))^);
      //end;
    end;
    else begin
      // сюда по идее не должны попадать
      raise EODBCConvertLongintError.Create(IntToStr(AColNumber) + ':' + IntToStr(VItem^.DescribeColData.DataType));
    end;
  end;
end;

procedure TOdbcFetchCols.ColToSmallInt(const AColNumber: Byte; out AValue: SmallInt);
var
  VItem: POdbcColItem;
  VInt: LongInt;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  VItem := @(Cols[AColNumber]);

  AValue := 0;

  // если NULL - вернём 0
  if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then
    Exit;

  // обрабатываем разные типы
  case VItem^.DescribeColData.DataType of
    SQL_SMALLINT: begin
      AValue := PSmallInt(InternalColData(VItem))^;
    end;
    SQL_INTEGER: begin
      AValue := PLongInt(InternalColData(VItem))^;
    end;
    SQL_TINYINT: begin
      AValue := PByte(InternalColData(VItem))^;
    end;
    SQL_BIGINT: begin
      AValue := PSQLBIGINT(InternalColData(VItem))^;
    end;
    SQL_NUMERIC: begin
      // SQL_NUMERIC_STRUCT
      VInt := OdbcNumericToInt(PSQL_NUMERIC_STRUCT(InternalColData(VItem)));
      if (VItem^.DescribeColData.DecimalDigits<>0) then begin
        // TODO: тут надо делиться или умножаться на степень 10
        AValue := VInt;
      end else begin
        // не надо делить или умножать
        AValue := VInt;
      end;
    end;
    SQL_DOUBLE: begin
      // SQLDOUBLE
      // TODO: необходима корректная проверка округления
      //if (0=VItem^.DescribeColData.DecimalDigits) then begin
        AValue := Round(PSQLDOUBLE(InternalColData(VItem))^);
      //end;
    end;
    else begin
      // сюда по идее не должны попадать
      raise EODBCConvertSmallintError.Create(IntToStr(AColNumber) + ':' + IntToStr(VItem^.DescribeColData.DataType));
    end;
  end;
end;

function TOdbcFetchCols.DescribeAndBind: Boolean;
const
  c_max_colname_len = 255;
var
  VRes: SQLRETURN;
  i: SQLUSMALLINT;
  VItem: POdbcColItem;
  VDesc: PDescribeColData;
  VColNameBufLen: SQLUSMALLINT;
begin
  Result := FALSE;
  
  // определим фактическое число полей
  VRes := SQLNumResultCols(Stmt, ColumnCount);
  CheckStatementResult(Stmt, VRes, EODBCNumResultColsError);

  // вообще нет полей
  if (0=ColumnCount) then
    Exit;
  
  // проверка что выделили достаточно памяти под поля
  Assert(Abs(ColumnCount)<=ColumnsAllocated);

  // сбросим общий буфер
  OdbcFreeColBuffer(ColBufPtr, ColBufLen, WorkFlags);

  // если сказано сформировать имена для полей - будем его временно использовать
  if (WithColNames) then begin
    VColNameBufLen := c_max_colname_len;
    ColBufPtr := OdbcAlloc(VColNameBufLen);
  end else begin
    // без имён полей
    VColNameBufLen := 0;
  end;

  // определим типы полей и создадим буфер
  for i := 1 to ColumnCount do begin
    // тащим описание поля
    VItem := @(Cols[i]);
    VDesc := @(VItem^.DescribeColData);
    VRes := SQLDescribeColA(   // ToDo: use SQLDescribeCol
      Stmt,
      i,
      ColBufPtr,
      VColNameBufLen,
      VDesc^.NameLen,
      VDesc^.DataType,
      VDesc^.ColumnSize,
      VDesc^.DecimalDigits,
      VDesc^.Nullable
    );
    CheckStatementResult(Stmt, VRes, EODBCDescribeColError);

    // обработка потенциального глюка
    if VDesc^.NameLen>c_max_colname_len then
      VDesc^.NameLen:=c_max_colname_len;

    // сохраним имя поля - сразу в нижнем регистре
    if (WithColNames) then begin
      VItem^.DescribeColName := OdbcAlloc(VDesc^.NameLen+1);
      CopyMemory(VItem^.DescribeColName, ColBufPtr, VDesc^.NameLen);
      VItem^.DescribeColName[VDesc^.NameLen] := #0;
    end;

    // если не LOB - подсчитаем размер для буфера
    if VDesc^.IsLOB(WorkFlags) then begin
      // LOB
      WorkFlags := WorkFlags or WF_HAS_LOB;
      // конец для LOB
    end else begin
      // регулярное поле
      VItem^.ColOffset := ColBufLen;

      // рассчитаем размер под поле
      case VDesc^.DataType of
        SQL_CHAR: begin
          // выделим на байт больше
          VItem^.Bind_BufferLength := VDesc^.ColumnSize + 1;
        end;
        SQL_WCHAR,
        SQL_VARCHAR,
        SQL_WVARCHAR,
        SQL_LONGVARCHAR,
        SQL_WLONGVARCHAR: begin
          // заменяем на CHAR
          VDesc^.DataType := SQL_CHAR;
          // (wide)(var)char(n) - выделим на 2 байта больше
          VItem^.Bind_BufferLength := VDesc^.ColumnSize + 2;
        end;
        SQL_DECIMAL: begin
          // заменяем на NUMERIC
          VDesc^.DataType := SQL_NUMERIC;
          VItem^.Bind_BufferLength := sizeof(SQL_NUMERIC_STRUCT);
        end;
        SQL_NUMERIC: begin
          VItem^.Bind_BufferLength := sizeof(SQL_NUMERIC_STRUCT);
        end;
        SQL_SMALLINT: begin
          VItem^.Bind_BufferLength := sizeof(SQLSMALLINT);
        end;
        SQL_INTEGER: begin
          VItem^.Bind_BufferLength := sizeof(SQLINTEGER);
        end;
        SQL_REAL,
        SQL_FLOAT: begin
          // заменяем на DOUBLE
          VDesc^.DataType := SQL_DOUBLE;
          VItem^.Bind_BufferLength := sizeof(SQLDOUBLE);
        end;
        SQL_DOUBLE: begin
          VItem^.Bind_BufferLength := sizeof(SQLDOUBLE);
        end;
        SQL_BIT: begin
          VItem^.Bind_BufferLength := sizeof(SQLCHAR);
        end;
        SQL_TINYINT: begin
          VItem^.Bind_BufferLength := sizeof(Byte);
        end;
        SQL_BIGINT: begin
          VItem^.Bind_BufferLength := sizeof(SQLBIGINT);
        end;
        // SQL_BINARY - как BLOB
        // SQL_VARBINARY - как BLOB
        // SQL_LONGVARBINARY - как BLOB
        SQL_TYPE_DATE: begin
          VItem^.Bind_BufferLength := sizeof(SQL_DATE_STRUCT);
        end;
        SQL_TYPE_TIME: begin
          VItem^.Bind_BufferLength := sizeof(SQL_TIME_STRUCT);
        end;
        SQL_TYPE_TIMESTAMP: begin
          VItem^.Bind_BufferLength := sizeof(SQL_TIMESTAMP_STRUCT);
        end;
        // SQL_TYPE_UTCDATETIME
        // SQL_TYPE_UTCTIME
        SQL_INTERVAL_MONTH,
        SQL_INTERVAL_YEAR,
        SQL_INTERVAL_YEAR_TO_MONTH,
        SQL_INTERVAL_DAY,
        SQL_INTERVAL_HOUR,
        SQL_INTERVAL_MINUTE,
        SQL_INTERVAL_SECOND,
        SQL_INTERVAL_DAY_TO_HOUR,
        SQL_INTERVAL_DAY_TO_MINUTE,
        SQL_INTERVAL_DAY_TO_SECOND,
        SQL_INTERVAL_HOUR_TO_MINUTE,
        SQL_INTERVAL_HOUR_TO_SECOND,
        SQL_INTERVAL_MINUTE_TO_SECOND: begin
          // заменяем на TIMESTAMP
          VDesc^.DataType := SQL_TYPE_TIMESTAMP;
          VItem^.Bind_BufferLength := sizeof(SQL_TIMESTAMP_STRUCT);
        end;
        SQL_GUID: begin
          if (VDesc^.ColumnSize in [36,38]) or (VDesc^.ColumnSize > 38) then
            VItem^.Bind_BufferLength := VDesc^.ColumnSize
          else
            VItem^.Bind_BufferLength := 38;
        end;

        // SQL_DB2_BLOB - как BLOB
        // SQL_DB2_CLOB - как BLOB

        else begin
          // неизвестный тип поля
          raise EODBCUnknownDataTypeError.Create(IntToStr(i)+': '+IntToStr(VDesc^.DataType)+'['+IntToStr(VDesc^.ColumnSize)+']');
        end;
      end;

      // добавим размерчика общему буферу
      ColBufLen := ColBufLen + VItem^.Bind_BufferLength;
    end;
  end;

  // забацаем общий буфер
  if (ColBufLen>0) then begin
    // возможно он создавался и его размера хватит
    if WithColNames then begin
      // создавался
      if (VColNameBufLen<ColBufLen) then begin
        // размера недостаточно - пересоздаём
        ColBufPtr := OdbcRealloc(ColBufPtr, ColBufLen);
      end else begin
        // размера достаточно - ничего не делаем с буфером
        // только запомним сколько реально выделено
        ColBufLen := VColNameBufLen;
      end;
    end else begin
      // не создавался
      ColBufPtr := OdbcAlloc(ColBufLen);
    end;
  end else begin
    // буфер не нужен
    if WithColNames then begin
      // создавался - убьём его
      OdbcFreeColBuffer(ColBufPtr, ColBufLen, WorkFlags);
    end;
  end;

  // приBINDим поля (кроме LOB)
  for i := 1 to ColumnCount do begin
    VItem := @(Cols[i]);
    if (not VItem^.DescribeColData.IsLOB(WorkFlags)) then begin
      VRes := SQLBindCol(
        Stmt,
        i,
        VItem^.DescribeColData.DataType,
        InternalColData(VItem), // тут для LOB указатель на его личный буфер
        VItem^.Bind_BufferLength,
        @(VItem^.Bind_StrLen_or_Ind)
      );
      CheckStatementResult(Stmt, VRes, EODBCBindColError);
    end;
  end;

  // всё успешно
  Result := TRUE;
  WorkFlags := WorkFlags or WF_ACTIVE;
end;

procedure TOdbcFetchCols.DisableCLOBChecking;
begin
  WorkFlags := (WorkFlags and (not WF_CLOBCHK))
end;

procedure TOdbcFetchCols.EnableCLOBChecking;
begin
  WorkFlags := (WorkFlags or WF_CLOBCHK)
end;

procedure TOdbcFetchCols.FetchLOBs;
const
  c_LOB_Static_Size = 64*1024; // 64k
  c_LOB_Huge_Size = 1024*1024; // 1MB
var
  i: SQLUSMALLINT;
  VItem: POdbcColItem;
  VRes: SQLRETURN;
  VLOBDataType: SQLSMALLINT;
  VSecondPtr: TOdbcColBuffer;
  VSecondInd: SQLLEN;
begin
  // сюда попадаем только если есть LOB-ы

  // создадим статический буфер для LOB
  // статический потому что размер фиксирован
  // а не потому что один на всех или на стеке
  if (nil=LOBStatic) then begin
    LOBStatic := OdbcAlloc(c_LOB_Static_Size);
  end;

  // цикл по непустым LOB-полям
  for i := 1 to ColumnCount do begin
    VItem := @(Cols[i]);
    // если NULL - пропускаем
    // if (SQL_NULL_DATA <> VItem^.Bind_StrLen_or_Ind) then
    if VItem^.DescribeColData.IsLOB(WorkFlags) then begin
      // тащим LOB
      VLOBDataType := VItem^.DescribeColData.LOBDataType;

      // первый вызов - в статический буфер
      // заодно получаем общий размер LOB-а
      VRes := SQLGetData(
        Stmt,
        i,
        VLOBDataType,
        LOBStatic,
        c_LOB_Static_Size,
        @(VItem^.Bind_StrLen_or_Ind)
      );

      CheckStatementResult(Stmt, VRes, EODBCGetDataLOBError);

(*
SQLGetData can return the following values in the length/indicator buffer:
The length of the data available to return
SQL_NO_TOTAL
SQL_NULL_DATA
*)
      // по этому адресу будем писать при втором вызове
      // если указателя не будет - значит и писать второй раз не будем
      VSecondPtr := nil;
      
      if (SQL_NULL_DATA = VItem^.Bind_StrLen_or_Ind) then begin
        // NULL - пустое значение
        // буфер можно грохнуть
        // хотя в принципе можно и не грохать
        OdbcFreeColBuffer(VItem^.LOBPtr, VItem^.Bind_BufferLength, 0);
      end else begin
        // по идее какие-то данные есть
        if (SQL_NO_TOTAL = VItem^.Bind_StrLen_or_Ind) then begin
          // драйвер не знает сколько надо выделить
          // фигово, но (пере)выделим большой буфер
          if (VItem^.Bind_BufferLength < c_LOB_Huge_Size) then begin
            VItem^.LOBPtr := OdbcRealloc(VItem^.LOBPtr, c_LOB_Huge_Size);
            VItem^.Bind_BufferLength := c_LOB_Huge_Size;
          end;
          // запишем в буфер кусок из статического буфера, и будем писать дальше
          CopyMemory(VItem^.LOBPtr, LOBStatic, c_LOB_Static_Size);
          VSecondPtr := VItem^.LOBPtr + c_LOB_Static_Size;
        end else begin
          // драйвер вернул размер поля - проверяем надо ли писать второй раз
          if (VItem^.Bind_StrLen_or_Ind <= c_LOB_Static_Size) then begin
            // уложились в один вызов
            if (VItem^.Bind_BufferLength < VItem^.Bind_StrLen_or_Ind) then begin
              VItem^.LOBPtr := OdbcRealloc(VItem^.LOBPtr, SQLUINTEGER(VItem^.Bind_StrLen_or_Ind));
              VItem^.Bind_BufferLength := VItem^.Bind_StrLen_or_Ind;
            end;
            CopyMemory(VItem^.LOBPtr, LOBStatic, VItem^.Bind_StrLen_or_Ind);
          end else begin
            // не уложились в один вызов
            if (VItem^.Bind_BufferLength < VItem^.Bind_StrLen_or_Ind) then begin
              VItem^.LOBPtr := OdbcRealloc(VItem^.LOBPtr, SQLUINTEGER(VItem^.Bind_StrLen_or_Ind));
              VItem^.Bind_BufferLength := VItem^.Bind_StrLen_or_Ind;
            end;
            CopyMemory(VItem^.LOBPtr, LOBStatic, c_LOB_Static_Size);
            VSecondPtr := VItem^.LOBPtr + c_LOB_Static_Size;
          end;
        end;
      end;

      if (VSecondPtr<>nil) then begin
        // дописываем остаток
        VRes := SQLGetData(
          Stmt,
          i,
          VLOBDataType,
          VSecondPtr,
          (VItem^.Bind_BufferLength-c_LOB_Static_Size),
          @VSecondInd
        );
        
        CheckStatementResult(Stmt, VRes, EODBCGetDataLOBError);

        // если был неизвестный размер - сейчас он известен
        if (SQL_NO_TOTAL = VItem^.Bind_StrLen_or_Ind) then begin
          VItem^.Bind_StrLen_or_Ind := VSecondInd + c_LOB_Static_Size;
        end;
      end;

      (*
      // убьём буфер, если он есть
      OdbcFreeColBuffer(VItem^.LOBPtr, VItem^.Bind_BufferLength, 0);

      // если требуется больше размер чем уже есть - перевыделяем
      if SQLUINTEGER(VItem^.Bind_StrLen_or_Ind) > VItem^.Bind_BufferLength then begin
        VItem^.LOBPtr := OdbcRealloc(VItem^.LOBPtr, SQLUINTEGER(VItem^.Bind_StrLen_or_Ind));
        VItem^.Bind_BufferLength := SQLUINTEGER(VItem^.Bind_StrLen_or_Ind);
      end;
      *)


(*
If the driver does not support extensions to SQLGetData, the function can return data only
for unbound columns with a number greater than that of the last bound column.

Furthermore, within a row of data, the value of the ColumnNumber argument in each call to SQLGetData
must be greater than or equal to the value of ColumnNumber in the previous call;
that is, data must be retrieved in increasing column number order.
Finally, if no extensions are supported, SQLGetData cannot be called if the rowset size is greater than 1.

Drivers can relax any of these restrictions. To determine what restrictions a driver relaxes,
an application calls SQLGetInfo with any of the following SQL_GETDATA_EXTENSIONS options: 

SQL_GD_ANY_COLUMN. If this option is returned, SQLGetData can be called for any unbound column,
including those before the last bound column.

SQL_GD_ANY_ORDER. If this option is returned, SQLGetData can be called for unbound columns in any order.

SQL_GD_BLOCK. If this option is returned by SQLGetInfo for the SQL_GETDATA_EXTENSIONS InfoType,
the driver supports calls to SQLGetData when the rowset size is greater than 1
and the application can call SQLSetPos with the SQL_POSITION option to position the cursor
on the correct row before calling SQLGetData.

SQL_GD_BOUND. If this option is returned, SQLGetData can be called for bound columns
as well as unbound columns.
*)
    end;
  end;
end;

function TOdbcFetchCols.FetchRecord: Boolean;
begin
  Result := OdbcFetchStmt(Stmt, WorkFlags);
  if Result and WithLOBs then begin
    FetchLOBs;
  end;
end;

function TOdbcFetchCols.GetAsLongInt(const AColNumber: Byte): LongInt;
begin
  ColToLongInt(AColNumber, Result)
end;

function TOdbcFetchCols.GetLOBBuffer(const AColNumber: Byte): Pointer;
var
  VItem: POdbcColItem;
begin
  // проверки номера поля есть уже внутри
  if IsNull(AColNumber) then begin
    Result := nil;
    Exit;
  end;

  VItem := @(Cols[AColNumber]);
  if VItem^.DescribeColData.IsLOB(WorkFlags) then
    Result := VItem^.LOBPtr
  else with VItem^.DescribeColData do
    raise EODBCConvertLOBError.Create(IntToStr(AColNumber)+': '+IntToStr(DataType)+'['+IntToStr(ColumnSize)+']');
end;

function TOdbcFetchCols.GetOptionalAnsiChar(const AExpectedColName: AnsiString; const ADefaultValue: AnsiChar): AnsiChar;
var
  VIndex: SmallInt;
begin
  VIndex := ColIndex(AExpectedColName);
  if (VIndex<0) then
    Result := ADefaultValue
  else
    ColToAnsiCharDef(VIndex, Result, ADefaultValue);
end;

function TOdbcFetchCols.GetOptionalLongInt(const AExpectedColName: AnsiString): LongInt;
var
  VIndex: SmallInt;
begin
  VIndex := ColIndex(AExpectedColName);
  if (VIndex<0) then
    Result := 0
  else
    ColToLongInt(VIndex, Result);
end;

function TOdbcFetchCols.GetOptionalSmallInt(const AExpectedColName: AnsiString): SmallInt;
var
  VIndex: SmallInt;
begin
  VIndex := ColIndex(AExpectedColName);
  if (VIndex<0) then
    Result := 0
  else
    ColToSmallInt(VIndex, Result);
end;

function TOdbcFetchCols.IsActive: Boolean;
begin
  Result := ((WorkFlags and WF_ACTIVE) <> 0)
end;

function TOdbcFetchCols.IsNull(const AColNumber: Byte): Boolean;
begin
  Assert(AColNumber>0);
  Assert(AColNumber<=ColumnCount);
  Result := (SQL_NULL_DATA = Cols[AColNumber].Bind_StrLen_or_Ind);
end;

function TOdbcFetchCols.WithColNames: Boolean;
begin
  Result := ((WorkFlags and WF_COLNAME) <> 0)
end;

function TOdbcFetchCols.WithLOBs: Boolean;
begin
  Result := ((WorkFlags and WF_HAS_LOB) <> 0)
end;

{ TDescribeColData }

function TDescribeColData.IsLOB(const AWorkFlags: Byte): Boolean;
begin
  case DataType of
    SQL_BINARY,
    SQL_VARBINARY,
    SQL_LONGVARBINARY,
    SQL_DB2_BLOB,
    SQL_DB2_CLOB: begin
      // всегда в отдельный буфер
      Result := TRUE;
    end;

    SQL_CHAR,
    SQL_WCHAR,
    SQL_VARCHAR,
    SQL_WVARCHAR,
    SQL_LONGVARCHAR,
    SQL_WLONGVARCHAR: begin
      // если больше 255 или неизвестно - тоже утащим в отдельный буфер
      // если 255 и признак трактовать это как CLOB (TEXT) - тоже
      Result := (
        (ColumnSize=0) or
        (ColumnSize>255) or
        ((ColumnSize=255) and ((AWorkFlags and WF_CLOBCHK)<>0))
      );
    end;

    else begin
      // в общий буфер
      Result := FALSE;
    end;
  end;
end;

function TDescribeColData.LOBDataType: SQLSMALLINT;
begin
  case DataType of
    SQL_BINARY,
    SQL_VARBINARY,
    SQL_LONGVARBINARY,
    SQL_DB2_BLOB: begin
      Result := SQL_C_BINARY;
    end;
    else begin
      Result := SQL_C_CHAR;
    end;
  end;
end;

{ TOdbcFetchCols10 }

procedure TOdbcFetchCols10.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  with Base do begin
    ColumnsAllocated := 10;
    WorkFlags := WorkFlags or WF_COLNAME;
  end;
end;

{ TOdbcFetchCols12 }

procedure TOdbcFetchCols12.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  with Base do begin
    ColumnsAllocated := 12;
    WorkFlags := WorkFlags or WF_COLNAME;
  end;
end;

{ TOdbcFetchCols5 }

procedure TOdbcFetchCols5.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  Self.Base.ColumnsAllocated := 5;
end;

{ TOdbcFetchCols3 }

procedure TOdbcFetchCols3.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  Self.Base.ColumnsAllocated := 3;
end;

{ TOdbcFetchCols2 }

procedure TOdbcFetchCols2.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  Self.Base.ColumnsAllocated := 2;
end;

{ TOdbcFetchCols7 }

procedure TOdbcFetchCols7.Init;
begin
  FillChar(Self, SizeOf(Self), 0);
  Self.Base.ColumnsAllocated := 7;
end;

end.
