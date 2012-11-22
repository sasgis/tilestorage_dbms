unit mParams;

interface

uses
  Windows,
  Classes,
  Db,
  odbcsql,
  mdatabas,
  mconst;

{ TmParam }
type
  TmBlobData = AnsiString;
  TmBlobDataArray = array[0..0] of TmBlobData;
  PmBlobDataArray = ^TmBlobDataArray;

  BlobParamDesc = Integer;
  TmParams = class;

  TParamType = (ptUnknown, ptInput, ptOutput, ptInputOutput, ptResult);

  TmParam = class(TPersistent)
  private
    FParamList: TmParams;
    FData: Variant;
    FName: string;
    FSQLDataType:SQLSMALLINT;
    FNull: Boolean;
    FBound: Boolean;
//    FParamType: TParamType;
    FSQLParamType: SQLSMALLINT;
    procedure InitValue;
    function GetParamType: TParamType;
    procedure SetParamType(const Value: TParamType);
  protected
    procedure AssignParam(Param: TmParam);
    procedure AssignTo(Dest: TPersistent); override;
    function GetAsBCD: Currency;
    function GetAsBoolean: Boolean;
    function GetAsDateTime: TDateTime;
    function GetAsFloat: Double;
    function GetAsInteger: Longint;
    function GetAsMemo: string;
    function GetAsString: string;
    function GetAsVariant: Variant;
    function GetDataType: TFieldType;
    function IsEqual(Value: TmParam): Boolean;
    function RecBufDataSize: Integer;
    procedure SetAsBCD(Value: Currency);
    procedure SetAsBlob(Value: TmBlobData);
    procedure SetAsBoolean(Value: Boolean);
    procedure SetAsCurrency(Value: Double);
    procedure SetAsDate(Value: TDateTime);
    procedure SetAsDateTime(Value: TDateTime);
    procedure SetAsFloat(Value: Double);
    procedure SetAsInteger(Value: Longint);
    procedure SetAsMemo(const Value: string);
    procedure SetAsString(const Value: string);
    procedure SetAsSmallInt(Value: LongInt);
    procedure SetAsTime(Value: TDateTime);
    procedure SetAsVariant(Value: Variant);
    procedure SetAsWord(Value: LongInt);
    procedure SetDataType(Value: TFieldType);
    procedure SetText(const Value: string);
  public
    constructor Create(AParamList: TmParams; AParamType: TParamType);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignField(Field: TField);
    procedure AssignFieldValue(Field: TField; const Value: Variant);
    procedure Clear;
    procedure GetData(Buffer: Pointer);
    function GetDataSize: Integer;
    procedure LoadFromFile(const FileName: string; BlobType: TBlobType);
    procedure LoadFromStream(Stream: TStream; BlobType: TBlobType);
    procedure SetBlobData(Buffer: Pointer; Size: Integer);
    procedure SetData(Buffer: Pointer);
    property AsBCD: Currency read GetAsBCD write SetAsBCD;
    property AsBlob: TmBlobData read GetAsString write SetAsBlob;
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsCurrency: Double read GetAsFloat write SetAsCurrency;
    property AsDate: TDateTime read GetAsDateTime write SetAsDate;
    property AsDateTime: TDateTime read GetAsDateTime write SetAsDateTime;
    property AsFloat: Double read GetAsFloat write SetAsFloat;
    property AsInteger: LongInt read GetAsInteger write SetAsInteger;
    property AsSmallInt: LongInt read GetAsInteger write SetAsSmallInt;
    property AsMemo: string read GetAsMemo write SetAsMemo;
    property AsString: string read GetAsString write SetAsString;
    property AsTime: TDateTime read GetAsDateTime write SetAsTime;
    property AsWord: LongInt read GetAsInteger write SetAsWord;
    property Bound: Boolean read FBound write FBound;
    property DataType: TFieldType read GetDataType write SetDataType;
    property SQLDataType: SQLSMALLINT read FSQLDataType write FSQLDataType;
    property IsNull: Boolean read FNull;
    property Name: string read FName write FName;
    property SQLParamType: SQLSMALLINT read FSQLParamType write FSQLParamType;
    property ParamType: TParamType read GetParamType write SetParamType;
    property Text: string read GetAsString write SetText;
    property Value: Variant read GetAsVariant write SetAsVariant;
  end;

{ TmParams }

  TmParams = class(TPersistent)
  private
    FItems: TList;
    function GetParam(Index: Word): TmParam;
    function GetParamValue(const ParamName: string): Variant;
    function GetVersion: Word;
    procedure ReadBinaryData(Stream: TStream);
    procedure SetParamValue(const ParamName: string;
      const Value: Variant);
    procedure WriteBinaryData(Stream: TStream);
  protected
    procedure AssignTo(Dest: TPersistent); override;
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignValues(Value: TmParams);
    procedure AddParam(Value: TmParam);
    procedure RemoveParam(Value: TmParam);
    function CreateParam(FldType: TFieldType; const ParamName: string;
      ParamType: TParamType): TmParam;
    function CreateSQLParam(SQLFldType: SQLSMALLINT; const ParamName: string;
      SQLParamType: SQLSMALLINT): TmParam;
    function Count: Integer;
    procedure Clear;
    procedure GetParamList(List: TList; const ParamNames: string);
    function IsEqual(Value: TmParams): Boolean;
    function ParamByName(const Value: string): TmParam;
    property Items[Index: Word]: TmParam read GetParam; default;
    property ParamValues[const ParamName: string]: Variant read GetParamValue write SetParamValue;
  end;
  function Sql2BDEType( aSQLType: SQLSMALLINT): TFieldType;
  function BDE2SqlType( aFieldType: TFieldType): SQLSMALLINT;

implementation
uses
  SysUtils,
  dbconsts,
  graphics,
  variants;

function Sql2BDEType( aSQLType: SQLSMALLINT): TFieldType;
begin
  case aSQLType of
    SQL_CHAR,
    SQL_WCHAR,
    SQL_VARCHAR,
    SQL_WVARCHAR: Result := ftString;
    SQL_TINYINT,
    SQL_SMALLINT: Result := ftSmallint;
    SQL_INTEGER:  Result := ftInteger;
    SQL_DECIMAL,
    SQL_NUMERIC,
    SQL_REAL,
    SQL_FLOAT,
    SQL_DOUBLE:    Result := ftFloat;
    SQL_DATE,
    SQL_TYPE_DATE: Result := ftDate;
    SQL_TIME,
    SQL_TYPE_TIME: Result := ftTime;
    SQL_TYPE_TIMESTAMP,
    SQL_TIMESTAMP: Result := ftDateTime;
    SQL_BIT:       Result := ftBoolean;
    SQL_BIGINT:    Result := ftFloat;
    SQL_BINARY,
    SQL_VARBINARY,
    SQL_LONGVARBINARY:Result := ftBlob;
    SQL_LONGVARCHAR,
    SQL_WLONGVARCHAR: Result := ftMemo;
    else              Result := ftUnknown;
  end;
end;

function BDE2SqlType( aFieldType: TFieldType): SQLSMALLINT;
begin
  case aFieldType of
    ftString:   result := SQL_CHAR;
    ftWord:     result := SQL_SMALLINT;
    ftSmallint: result := SQL_SMALLINT;
    ftInteger,
    ftAutoInc:  result := SQL_INTEGER;
    ftTime:     result := SQL_TIME;
    ftDate:     result := SQL_DATE;
    ftDateTime: result := SQL_TIMESTAMP;
    ftBCD,
    ftCurrency,
    ftFloat:    result := SQL_DOUBLE;
    ftBoolean:  result := SQL_BIT;
    ftMemo:     result := SQL_LONGVARCHAR;
    ftBlob:     result := SQL_LONGVARBINARY;
    else        result := SQL_UNKNOWN_TYPE;
  end;
end;

{ TmParam }

constructor TmParam.Create(AParamList: TmParams; AParamType: TParamType);
begin
  if AParamList <> nil then AParamList.AddParam(Self);
  ParamType := AParamType;
  FSQLDataType := SQL_UNKNOWN_TYPE;
  FBound := False;
end;

destructor TmParam.Destroy;
begin
  if FParamList <> nil then FParamList.RemoveParam(Self);
end;

function TmParam.IsEqual(Value: TmParam): Boolean;
begin
  Result := (VarType(FData) = VarType(Value.FData)) and
    (FData = Value.FData) and (Name = Value.Name) and
    (DataType = Value.DataType) and (IsNull = Value.IsNull) and
    (Bound = Value.Bound) and (ParamType = Value.ParamType);
end;

function TmParam.GetDataSize: Integer;
var i:integer;
begin
  case DataType of
    ftString, ftMemo: Result := Length(FData) + 1;
    ftBoolean: Result := SizeOf(WordBool);
//    ftBCD: Result := SizeOf(FMTBcd);
    ftDateTime,
    ftCurrency,
    ftFloat: Result := SizeOf(Double);
    ftTime,
    ftDate,
    ftAutoInc,
    ftInteger: Result := SizeOf(Integer);
    ftSmallint: Result := SizeOf(SmallInt);
    ftWord: Result := SizeOf(Word);
    ftBlob, ftGraphic..ftDBaseOLE: begin
    i:= Length(FData);
    Result := i;
    end;
    ftCursor: Result := 0;
  else
    if DataType = ftUnknown then
      DatabaseErrorFmt( SmFieldUndefinedType, [Name]) else
      DatabaseErrorFmt( SmFieldUnsupportedType, [Name]);
    Result := 0;
  end;
end;

function TmParam.RecBufDataSize: Integer;
begin
  if ((DataType = ftString) and (Length(FData) > 255)) or
     (DataType in [ftBlob..ftDBaseOLE]) then
    Result := SizeOf(BlobParamDesc) else
    Result := GetDataSize;
end;
{
procedure TmParam.RecBufGetData(Buffer: Pointer; Locale: TLocale);

  function GetNativeStr: string;
  begin
    if Locale <> nil then
    begin
      SetLength(FNativeStr, Length(FData));
      AnsiToNativeBuf(Locale, PChar(string(FData)),
        PChar(string(FNativeStr)), Length(FData));
      Result := FNativeStr;
    end else
      Result := FData;
  end;

begin
  if (DataType = ftString) or (DataType = ftMemo)  then
  begin
    if (Length(FData) > 255) or (DataType = ftMemo) then
    begin
      BlobParamDesc(Buffer^).ulBlobLen := Length(FData);
      BlobParamDesc(Buffer^).pBlobBuffer := PChar(GetNativeStr);
    end else
    begin
      if (Locale <> nil) then
        AnsiToNativeBuf(Locale, PChar(string(FData)), Buffer, Length(FData) + 1) else
        GetData(Buffer);
    end;
  end
  else if (DataType in [ftBlob..ftDBaseOLE]) then
  begin
    with BlobParamDesc(Buffer^) do
    begin
      ulBlobLen := Length(FData);
      pBlobBuffer := PChar(string(FData));
    end;
  end else
    GetData(Buffer);
end;
}
procedure TmParam.GetData(Buffer: Pointer);
begin
  case DataType of
    ftUnknown: DatabaseErrorFmt( SmFieldUndefinedType, [Name]);
    ftString, ftMemo: StrMove(Buffer, PChar(string(FData)), Length(FData) + 1);
    ftSmallint: SmallInt(Buffer^) := FData;
    ftWord: Word(Buffer^) := FData;
    ftAutoInc,
    ftInteger: Integer(Buffer^) := FData;
    ftTime: Integer(Buffer^) := DateTimeToTimeStamp(AsDateTime).Time;
    ftDate: Integer(Buffer^) := DateTimeToTimeStamp(AsDateTime).Date;
    ftDateTime:  Double(Buffer^) := TimeStampToMSecs(DateTimeToTimeStamp(AsDateTime));
//    ftBCD: CurrToFMTBCD(AsBCD, FMTBcd(Buffer^), 32, 4);
    ftCurrency,
    ftFloat: Double(Buffer^) := FData;
    ftBoolean: WordBool(Buffer^) := FData;
    ftBlob, ftGraphic..ftTypedBinary:
            Move(AnsiString(FData)[1], Buffer^, Length(AnsiString(FData)));
    ftCursor: {Nothing};
  else
    DatabaseErrorFmt( SmFieldUnsupportedType, [Name]);
  end;
end;

procedure TmParam.SetBlobData(Buffer: Pointer; Size: Integer);
var
  DataStr: AnsiString;
begin
  SetLength(DataStr, Size);
  Move(Buffer^, DataStr[1], Size);
  AsBlob := DataStr;
end;

procedure TmParam.SetData(Buffer: Pointer);
var
//  Value: Currency;
  TimeStamp: TTimeStamp;
begin
  case DataType of
    ftUnknown: DatabaseErrorFmt( SmFieldUndefinedType, [Name]);
    ftString: AsString := StrPas(Buffer);
    ftWord: AsWord := Word(Buffer^);
    ftSmallint: AsSmallInt := Smallint(Buffer^);
    ftInteger, ftAutoInc: AsInteger := Integer(Buffer^);
    ftTime:
      begin
        TimeStamp.Time := LongInt(Buffer^);
        TimeStamp.Date := DateDelta;
        AsTime := TimeStampToDateTime(TimeStamp);
      end;
    ftDate:
      begin
        TimeStamp.Time := 0;
        TimeStamp.Date := Integer(Buffer^);
        AsDate := TimeStampToDateTime(TimeStamp);
      end;
    ftDateTime:
      begin
        TimeStamp.Time := 0;
        TimeStamp.Date := Integer(Buffer^);
        AsDateTime := TimeStampToDateTime(MSecsToTimeStamp(Double(Buffer^)));
      end;
{    ftBCD:
      begin
        FMTBCDToCurr(FMTBcd(Buffer^), Value);
        AsBCD := Value;
      end;}
    ftCurrency: AsCurrency := Double(Buffer^);
    ftFloat: AsFloat := Double(Buffer^);
    ftBoolean: AsBoolean := WordBool(Buffer^);
    ftMemo: AsMemo := StrPas(Buffer);
    ftCursor: FData := 0;
  else
    DatabaseErrorFmt( SmFieldUnsupportedType, [Name]);
  end;
end;

procedure TmParam.SetText(const Value: string);
begin
  InitValue;
  if DataType = ftUnknown then DataType := ftString;
  FData := Value;
  case DataType of
    ftDateTime, ftTime, ftDate: FData := VarToDateTime(FData);
    ftBCD: FData := Currency(FData);
    ftCurrency, ftFloat: FData := Single(FData);
    ftInteger, ftSmallInt, ftWord: FData := Integer(FData);
    ftBoolean: FData := Boolean(FData);
  end;
end;

procedure TmParam.Assign(Source: TPersistent);

  procedure LoadFromBitmap(Bitmap: TBitmap);
  var
    MS: TMemoryStream;
  begin
    MS := TMemoryStream.Create;
    try
      Bitmap.SaveToStream(MS);
      LoadFromStream(MS, ftGraphic);
    finally
      MS.Free;
    end;
  end;

  procedure LoadFromStrings(Source: TSTrings);
  begin
    AsMemo := Source.Text;
  end;

begin
  if Source is TmParam then
    AssignParam(TmParam(Source))
  else if Source is TField then
    AssignField(TField(Source))
  else if Source is TStrings then
    LoadFromStrings(TStrings(Source))
  else if Source is TBitmap then
    LoadFromBitmap(TBitmap(Source))
  else if (Source is TPicture) and (TPicture(Source).Graphic is TBitmap) then
    LoadFromBitmap(TBitmap(TPicture(Source).Graphic))
  else
    inherited Assign(Source);
end;

procedure TmParam.AssignTo(Dest: TPersistent);
begin
  if Dest is TField then
    TField(Dest).Value := FData
  else
    inherited AssignTo(Dest);
end;

procedure TmParam.AssignParam(Param: TmParam);
begin
  if Param <> nil then
  begin
    DataType := Param.DataType;
    if Param.IsNull then Clear
    else begin
      InitValue;
      FData := Param.FData;
    end;
    FBound := Param.Bound;
    Name := Param.Name;
    if ParamType = ptUnknown then ParamType := Param.ParamType;
  end;
end;

procedure TmParam.AssignFieldValue(Field: TField; const Value: Variant);
begin
  if Field <> nil then
  begin
    if (Field.DataType = ftMemo) and (Field.Size > 255) then
      DataType := ftString else
      DataType := Field.DataType;
    if VarIsNull(Value) then Clear
    else begin
      InitValue;
      FData := Value;
    end;
    FBound := True;
  end;
end;

procedure TmParam.AssignField(Field: TField);
begin
  if Field <> nil then
  begin
    if (Field.DataType = ftMemo) and (Field.Size > 255) then
      DataType := ftString else
      DataType := Field.DataType;
    if Field.IsNull then Clear
    else begin
      InitValue;
      FData := Field.Value;
    end;
    FBound := True;
    Name := Field.FieldName;
  end;
end;

procedure TmParam.Clear;
begin
  FNull := True;
  FData := 0;
//  FNativeStr := '';
end;

procedure TmParam.InitValue;
begin
  FBound := True;
  FNull := False;
end;

procedure TmParam.SetAsBoolean(Value: Boolean);
begin
  InitValue;
  DataType := ftBoolean;
  FData := Value;
end;

function TmParam.GetAsBoolean: Boolean;
begin
  Result := FData;
end;

procedure TmParam.SetAsFloat(Value: Double);
begin
  InitValue;
  DataType := ftFloat;
  FData := Value;
end;

function TmParam.GetAsFloat: Double;
begin
  Result := FData;
end;

procedure TmParam.SetAsCurrency(Value: Double);
begin
  SetAsFloat(Value);
  FSQLDataType := SQL_DOUBLE;//ftCurrency;
end;

procedure TmParam.SetAsBCD(Value: Currency);
begin
  InitValue;
  FData := Value;
  FSQLDataType := SQL_DOUBLE;//ftBCD;
end;

function TmParam.GetAsBCD: Currency;
begin
  Result := FData;
end;

procedure TmParam.SetAsInteger(Value: Longint);
begin
  InitValue;
  DataType := ftInteger;
  FData := Value;
end;

function TmParam.GetAsInteger: Longint;
begin
  Result := FData;
end;

procedure TmParam.SetAsWord(Value: LongInt);
begin
  SetAsInteger(Value);
  FSQLDataType := SQL_SMALLINT;//ftWord;
end;

procedure TmParam.SetAsSmallInt(Value: LongInt);
begin
  SetAsInteger(Value);
  FSQLDataType := SQL_SMALLINT;//ftSmallint;
end;

procedure TmParam.SetAsString(const Value: string);
begin
  InitValue;
  FSQLDataType := SQL_CHAR;//ftString;
  FData := Value;
end;

function TmParam.GetAsString: string;
begin
  if not IsNull then
    case DataType of
      ftBoolean:
        if FData then Result := STextTrue
        else Result := STextFalse;
      ftDateTime, ftDate, ftTime: Result := VarFromDateTime(FData)
      else Result := FData;
    end
  else Result := ''
end;

procedure TmParam.SetAsDate(Value: TDateTime);
begin
  InitValue;
  DataType := ftDate;
  FData := VarFromDateTime(Value);
end;

procedure TmParam.SetAsTime(Value: TDateTime);
begin
  SetAsDate(Value);
  DataType := ftTime;
end;

procedure TmParam.SetAsDateTime(Value: TDateTime);
begin
  SetAsDate(Value);
  FSQLDataType := SQL_TIMESTAMP;
end;

function TmParam.GetAsDateTime: TDateTime;
begin
  if IsNull then
    Result := 0 else
    Result := VarToDateTime(FData);
end;

procedure TmParam.SetAsVariant(Value: Variant);
begin
  InitValue;
  case VarType(Value) of
    varSmallint: DataType := ftSmallInt;
    varInteger: DataType := ftInteger;
    varCurrency: DataType := ftBCD;
    varSingle,
    varDouble: DataType := ftFloat;
    varDate: DataType := ftDateTime;
    varBoolean: DataType := ftBoolean;
    varString, varOleStr: DataType := ftString;
    else DataType := ftUnknown;
  end;
  FData := Value;
end;

function TmParam.GetAsVariant: Variant;
begin
  Result := FData;
end;

procedure TmParam.SetAsMemo(const Value: string);
begin
  InitValue;
  DataType := ftMemo;
  FData := Value;
end;

function TmParam.GetAsMemo: string;
begin
  Result := FData;
end;

procedure TmParam.SetAsBlob(Value: TmBlobData);
begin
  InitValue;
  DataType := ftBlob;
  FData := Value;
end;

procedure TmParam.LoadFromFile(const FileName: string; BlobType: TBlobType);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(Stream, BlobType);
  finally
    Stream.Free;
  end;
end;

procedure TmParam.LoadFromStream(Stream: TStream; BlobType: TBlobType);
var
  DataStr: string;
  Len: Integer;
begin
  with Stream do
  begin
    InitValue;
    DataType := BlobType;
    Position := 0;
    Len := Size;
    SetLength(DataStr, Len);
    ReadBuffer(Pointer(DataStr)^, Len);
    FData := DataStr;
  end;
end;

function TmParam.GetDataType: TFieldType;
begin
   Result := Sql2BDEType( FSQLDataType);
end;

procedure TmParam.SetDataType(Value: TFieldType);
begin
  FData := 0;
  FSQLDataType := BDE2Sqltype(Value);
end;

function TmParam.GetParamType: TParamType;
begin
  case FSQLParamType of
    SQL_PARAM_INPUT         :Result:=ptInput;
    SQL_PARAM_INPUT_OUTPUT  :Result:=ptInputOutput;
    SQL_PARAM_OUTPUT        :Result:=ptOutput;
    SQL_RETURN_VALUE        :Result:=ptResult;
    else                     Result:=ptUnknown;
  end;
end;

procedure TmParam.SetParamType(const Value: TParamType);
begin
  case Value of
    ptInput       :FSQLParamType:=SQL_PARAM_INPUT;
    ptOutput      :FSQLParamType:=SQL_PARAM_OUTPUT;
    ptInputOutput :FSQLParamType:=SQL_PARAM_INPUT_OUTPUT;
    ptResult      :FSQLParamType:=SQL_PARAM_OUTPUT;// SQL_RETURN_VALUE;// is not liked by ODBC ???
    else           FSQLParamType:=SQL_PARAM_INPUT;
  end;
end;

{ TmParams }

constructor TmParams.Create;
begin
  FItems := TList.Create;
end;

destructor TmParams.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

procedure TmParams.Assign(Source: TPersistent);
var
  I: Integer;
begin
  if Source is TmParams then
  begin
    Clear;
    for I := 0 to TmParams(Source).Count - 1 do
      with TmParam.Create(Self, ptUnknown) do
        Assign(TmParams(Source)[I]);
  end
  else inherited Assign(Source);
end;

procedure TmParams.AssignTo(Dest: TPersistent);
begin
  if Dest is TmParams then TmParams(Dest).Assign(Self)
  else inherited AssignTo(Dest);
end;

procedure TmParams.AssignValues(Value: TmParams);
var
  I, J: Integer;
begin
  for I := 0 to Count - 1 do
    for J := 0 to Value.Count - 1 do
      if Items[I].Name = Value[J].Name then
      begin
        Items[I].Assign(Value[J]);
        Break;
      end;
end;

procedure TmParams.AddParam(Value: TmParam);
begin
  FItems.Add(Value);
  Value.FParamList := Self;
end;

procedure TmParams.RemoveParam(Value: TmParam);
begin
  FItems.Remove(Value);
  Value.FParamList := nil;
end;

function TmParams.CreateSQLParam(SQLFldType: SQLSMALLINT;
  const ParamName: string; SQLParamType: SQLSMALLINT): TmParam;
begin
  Result := TmParam.Create(Self, ptInput);
  with Result do
  begin
    Name := ParamName;
    SQLDataType :=  SQLFldType;
  end;
end;

function TmParams.CreateParam(FldType: TFieldType; const ParamName: string;
  ParamType: TParamType): TmParam;
begin
  Result := TmParam.Create(Self, ParamType);
  with Result do
  begin
    Name := ParamName;
    DataType :=  FldType;
  end;
end;

function TmParams.Count: Integer;
begin
  Result := FItems.Count;
end;

function TmParams.IsEqual(Value: TmParams): Boolean;
var
  I: Integer;
begin
  Result := Count = Value.Count;
  if Result then
    for I := 0 to Count - 1 do
    begin
      Result := Items[I].IsEqual(Value.Items[I]);
      if not Result then Break;
    end
end;

procedure TmParams.Clear;
begin
  while FItems.Count > 0
    do TmParam(FItems.Last).Free;
end;

function TmParams.GetParam(Index: Word): TmParam;
begin
  Result := ParamByName(TmParam(FItems[Index]).Name);
end;

function TmParams.ParamByName(const Value: string): TmParam;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := FItems[I];
    if AnsiCompareText(Result.Name, Value) = 0 then Exit;
  end;
  DatabaseErrorFmt( SmParameterNotFound, [Value]);
  Result := nil;
end;

procedure TmParams.DefineProperties(Filer: TFiler);

  function WriteData: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := not IsEqual(TmParams(Filer.Ancestor)) else
      Result := Count > 0;
  end;

begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadBinaryData, WriteBinaryData,
    WriteData);
end;

procedure TmParams.ReadBinaryData(Stream: TStream);
var
  I, Temp, NumItems: Integer;
  Buffer: array[0..2047] of Char;
  TempStr: string;
  Version: Word;
  pType:   TParamType;
  dType:   TFieldType;
begin
  Clear;
  with Stream do
  begin
    ReadBuffer(Version, SizeOf(Version));
    if Version > 2 then DatabaseError( SmInvalidVersion);
    NumItems := 0;
    if Version = 2 then
      ReadBuffer(NumItems, SizeOf(NumItems)) else
      ReadBuffer(NumItems, 2);
    for I := 0 to NumItems - 1 do
      with TmParam.Create(Self, ptUnknown) do
      begin
        Temp := 0;
        if Version = 2 then
          ReadBuffer(Temp, SizeOf(Temp)) else
          ReadBuffer(Temp, 1);
        SetLength(TempStr, Temp);
        ReadBuffer(PChar(TempStr)^, Temp);
        Name := TempStr;
        ReadBuffer(pType, SizeOf(pType)); ParamType:=pType;
        ReadBuffer(dType, SizeOf(dType)); DataType:=dType;
        if DataType <> ftUnknown then
        begin
          Temp := 0;
          if Version = 2 then
            ReadBuffer(Temp, SizeOf(Temp)) else
            ReadBuffer(Temp, 2);
          ReadBuffer(Buffer, Temp);
{          if DataType in [ftBlob, ftGraphic..ftDBaseOLE] then
            SetBlobData(@Buffer, Temp) else }
            SetData(@Buffer);
        end;
        ReadBuffer(FNull, SizeOf(FNull));
        ReadBuffer(FBound, SizeOf(FBound));
      end;
  end;
end;

procedure TmParams.WriteBinaryData(Stream: TStream);
var
  I: Integer;
  Temp: SmallInt;
  Version: Word;
  Buffer: array[0..2047] of Char;
  pType:   TParamType;
  dType:   TFieldType;
begin
  with Stream do
  begin
    Version := GetVersion;
    WriteBuffer(Version, SizeOf(Version));
    Temp := Count;
    WriteBuffer(Temp, SizeOf(Temp));
    for I := 0 to Count - 1 do
      with Items[I] do
      begin
        Temp := Length(FName);
        WriteBuffer(Temp, 1);
        WriteBuffer(PChar(FName)^, Length(FName));
        pType:=ParamType;WriteBuffer(pType, SizeOf(pType));
        dType:=DataType; WriteBuffer(dType, SizeOf(dType));
        if (DataType <> ftUnknown) then
        begin
          if GetDataSize > SizeOf(Buffer) then
            DatabaseErrorFmt(SmParamTooBig, [Name, SizeOf(Buffer)]);
          Temp := GetDataSize;
          GetData(@Buffer);
          WriteBuffer(Temp, SizeOf(Temp));
          WriteBuffer(Buffer, Temp);
        end;
        WriteBuffer(FNull, SizeOf(FNull));
        WriteBuffer(FBound, SizeOf(FBound));
      end;
  end;
end;

function TmParams.GetVersion: Word;
begin
  Result := 1;
end;

function TmParams.GetParamValue(const ParamName: string): Variant;
var
  I: Integer;
  Params: TList;
begin
  if Pos(';', ParamName) <> 0 then
  begin
    Params := TList.Create;
    try
      GetParamList(Params, ParamName);
      Result := VarArrayCreate([0, Params.Count - 1], varVariant);
      for I := 0 to Params.Count - 1 do
        Result[I] := TmParam(Params[I]).Value;
    finally
      Params.Free;
    end;
  end else
    Result := ParamByName(ParamName).Value
end;

procedure TmParams.SetParamValue(const ParamName: string;
  const Value: Variant);
var
  I: Integer;
  Params: TList;
begin
  if Pos(';', ParamName) <> 0 then
  begin
    Params := TList.Create;
    try
      GetParamList(Params, ParamName);
      for I := 0 to Params.Count - 1 do
        TmParam(Params[I]).Value := Value[I];
    finally
      Params.Free;
    end;
  end else
    ParamByName(ParamName).Value := Value;
end;

procedure TmParams.GetParamList(List: TList; const ParamNames: string);
var
  Pos: Integer;
begin
  Pos := 1;
  while Pos <= Length(ParamNames) do
    List.Add(ParamByName(ExtractFieldName(ParamNames, Pos)));
end;

end.
