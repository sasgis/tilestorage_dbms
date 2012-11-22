//==============================================================================
//
//    Helper routines for mQuery
//    All code that is obviously correct in mQuery should be here
//    reducing the risks of bugs in mQuery and cleaning it up
//
//------------------------------------------------------------------------------
//
//    mQueryHelper.pas, part of mOdbc, used by mQuery.pas
//
//==============================================================================

//--------------------------------------------------------------------
//    TQueryDataLink
//--------------------------------------------------------------------

constructor TmCustomQueryDataLink.Create(AQuery: TmCustomQuery);
begin
  inherited Create;
  FQuery := AQuery;
end;

procedure TmCustomQueryDataLink.ActiveChanged;
begin
  if FQuery.Active then
    FQuery.RefreshParams;
end;

procedure TmCustomQueryDataLink.RecordChanged(Field: TField);
begin
  if (Field = nil) and FQuery.Active then
    FQuery.RefreshParams;
end;

procedure TmCustomQueryDataLink.CheckBrowseMode;
begin
  if FQuery.Active then
    FQuery.CheckBrowseMode;
end;

//--------------------------------------------------------------------
//     TmCustomQuery
//--------------------------------------------------------------------

procedure TmCustomQuery.CheckSQLResult( sqlres: SQLRETURN{;const Message: string = ''});
begin
  case sqlres of
    SQL_SUCCESS:;
    SQL_SUCCESS_WITH_INFO:;// raise EODBCErrorWithInfo.CreateDiag(SQL_HANDLE_STMT, hstmt, sqlres);
    SQL_NEED_DATA:         raise EODBCErrorNeedData.Create('SQL_NEED_DATA');
    SQL_STILL_EXECUTING:   raise EODBCErrorStillExecuting.Create('SQL_STILL_EXECUTING');
    SQL_ERROR:             raise EODBCErrorSQLError.CreateDiag(SQL_HANDLE_STMT,hstmt, sqlres);
    SQL_NO_DATA:           raise EODBCErrorNoData.Create('SQL_NO_DATA');
    SQL_INVALID_HANDLE:    raise EODBCErrorInvalidHandle.Create({Message+}': SQL_INVALID_HANDLE');
   else                    raise EODBCErrorUnknown.Create('unknown SQL result');
  end;
end;

procedure TmCustomQuery.CopyRecordBuffer( BufferSrc, BufferDst: PChar);
var
  i: LongInt;
begin
  Move( BufferSrc^, BufferDst^, FBlobCacheOfs);
  for i:=0 to FBlobCount-1 do
  begin
    PmBlobDataArray(BufferDst + FBlobCacheOfs)[i]:=
         PmBlobDataArray(BufferSrc + FBlobCacheOfs)[i];
  end;
  Move( (BufferSrc+FRecInfoOfs)^,
        (BufferDst+FRecInfoOfs)^, SizeOf(TODBCRecInfo));
end;

// list of bookmarks deleted records
procedure TmCustomQuery.FreeDeletedList;
begin
  if FDeletedCount > 0 then
    FreeMem( FDeletedRec);

  FDeletedCount := 0;
end;

procedure TmCustomQuery.SetDataBase( Value: TmDataBase);
begin
  if FDataBase <> Value then
  begin
    if Assigned(FDataBase) then
    begin
      FDataBase.ExcludeDataSet(Self);
    end;
    FDataBase := Value;
    if Assigned(FDataBase) then
    begin
      FDataBase.IncludeDataSet(Self);
      FDatabase.FreeNotification(Self);
    end;
  end;
end;

procedure TmCustomQuery.AddODBCFieldDesc(FFieldNo:Word);
var
  FDataType:   TFieldType;
  FSize:       SQLUINTEGER;
  FName:       string;
  pname:       array [0..255] of char;
  nlength:     SQLSMALLINT;
  dtype:       SQLSMALLINT;
  BufDataType: SQLSMALLINT;
  csize:       SQLUINTEGER;
  decdig:      SQLSMALLINT;
  Nullable:    SQLSMALLINT;
  i:           Integer;
{$IFDEF CBUILDER3}
    function AddODBCFieldDef:TODBCFieldDef;
    begin
         Result:=TODBCFieldDef.Create(FieldDefs);
    end;
{$ENDIF}
begin
  CheckSQLResult( SQLDescribeCol( hstmt,
                                  FFieldNo,
                                  pname,
                                  254,
                                  nlength,
                                  dtype,
                                  csize,
                                  decdig,
                                  Nullable));
  if FFieldNo = 0 then
  begin
//    BookmarkType := dtype;
    case dtype of
    SQL_INTEGER: BookmarkSize := sizeof(SQLINTEGER);
    else        BookmarkSize := cSize;
    end;
    FRecordSize  := BookmarkSize + Sizeof(SQLINTEGER);
    exit;
  end;
  i := 0;
  if pname[0] = #0 then
    StrCopy( pname, 'COLUMN');

  FName := StrPas(pname);
  while FieldDefs.IndexOf(FName) >= 0 do
  begin
    Inc( i );
    FName := Format('%s_%d', [StrPas(pname), i]);
  end;

  FSize := cSize;
  BufDataType := dtype;
  case dtype of
    SQL_CHAR,
    SQL_WCHAR,
    SQL_VARCHAR,
    SQL_WVARCHAR,
    SQL_LONGVARCHAR,
    SQL_WLONGVARCHAR:
      begin
        if ((cSize>0)and(cSize<255))
           or(dtype = SQL_CHAR)
           or(dtype = SQL_WCHAR) then
        begin // static buffer
           FDataType := ftString;
           BufDataType := SQL_CHAR;
           inc( cSize); // one more byte for #0 char
        end else
        begin // variable length text
           FDataType := ftMemo;
           BufDataType := SQL_CHAR{SQL_BINARY};
           cSize := 0;
           FSize := 0;
        end;
      end;
    SQL_TINYINT,
    SQL_SMALLINT:
      begin
        FDataType := ftSmallint;
        BufDataType := SQL_SMALLINT;
        FSize := 0;
        cSize := sizeof(SQLSMALLINT);
      end;
    SQL_INTEGER:
      begin
        FDataType := ftInteger;
        FSize := 0;
        cSize := sizeof(SQLINTEGER);
      end;
    SQL_DECIMAL,
    SQL_NUMERIC,
    SQL_REAL,
    SQL_FLOAT,
    SQL_DOUBLE:
      begin
        FDataType := ftFloat;
        FSize := 0;
        BufDataType := SQL_DOUBLE;
        cSize := sizeof(SQLDOUBLE);
      end;
    SQL_DATE,
    SQL_TYPE_DATE:
      begin
        FDataType := ftDate;
        FSize := 0;
        BufDataType := dtype; 
        cSize := sizeof(SQL_DATE_STRUCT);
      end;
    SQL_TIME,
    SQL_TYPE_TIME:
      begin
        FDataType := ftTime;
        FSize := 0;
        BufDataType := dtype; //SQL_TYPE_TIME;
        cSize := sizeof(SQL_TIME_STRUCT);
      end;
    SQL_TYPE_TIMESTAMP,
    SQL_TIMESTAMP:
      begin
        FDataType := ftDateTime;
        FSize := 0;
        BufDataType := dtype; //SQL_TYPE_TIMESTAMP;
        cSize := sizeof(SQL_TIMESTAMP_STRUCT);
      end;
    SQL_BIT:
      begin
        FDataType := ftBoolean;
        FSize := 0;
        cSize := sizeof(SQLCHAR);
      end;
    SQL_BIGINT:
      begin
        FDataType := ftFloat;
        FSize := 0;
        BufDataType := SQL_DOUBLE;
        cSize := sizeof(SQLDOUBLE);
      end;
    SQL_BINARY,
    SQL_VARBINARY,
    SQL_LONGVARBINARY:
      begin
        FDataType := ftBlob;
        BufDataType := SQL_BINARY;
        cSize := 0;
        FSize := 0;
      end;
    else
    begin
      FDataType := ftUnknown;
      FSize := 0;
      cSize := 0;
    end;
  end;
  if FDataType <> ftUnknown then
  begin
{$IFDEF CBUILDER3}
    with FieldDefs, AddODBCFieldDef do
    begin
      BeginUpdate;
      try
          Name     := FName;
          DataType := FDataType;
          Size     := FSize;
          FieldNo  := FFieldNo;
          Required := (Nullable=SQL_NO_NULLS);
{$ELSE}
    with TODBCFieldDef.Create( FieldDefs, FName, FDataType, FSize,
                               (Nullable=SQL_NO_NULLS), FFieldNo) do
    begin
{$ENDIF}
      if cSize>0{BufDataType <> SQL_BINARY 05/05/2000} then
      begin
        OffsetInBuf := FRecordSize;
      end else
      begin
        OffsetInBuf := FBlobCount;
        inc(FblobCount);
      end;
      SQLDataType := BufDataType;
      SQLsize     := cSize;
      FRecordSize := FRecordSize + cSize + sizeof(SQLINTEGER);
      // InternalCalcField := bCalcField;
      if SQLDataType = SQL_DOUBLE then
        Precision := decdig;
{$IFDEF CBUILDER3}
      finally
        EndUpdate;
      end;
{$ENDIF}
    end;
  end;
end;

procedure TmCustomQuery.SetParamsForUpdateSql(UpdateKind: TUpdateKind);
var
  i: Integer;
  Old: Boolean;
  Param: TmParam;
  PName: string;
  Field: TField;
  Value: Variant;
begin
  if Self.FUpdateSQL[UpdateKind].Count = 0 then
    raise Exception.Create( SmStatementUndefined);

  with GetUpdateQuery( UpdateKind) do
  begin
    SQL.Assign(Self.FUpdateSQL[UpdateKind]);
    for I := 0 to Params.Count - 1 do
    begin
      Param := Params[i];
      PName := Param.Name;
      Old := CompareText(Copy(PName, 1, 4), 'OLD_') = 0;
      if Old then
        System.Delete(PName, 1, 4);

      Field := Self.FindField(PName);

      if not Assigned(Field) then
        Continue;

      if Old then
      begin
        Param.AssignFieldValue(Field, Field.OldValue);
      end else
      begin
        Value := Field.NewValue;
        if VarIsEmpty(Value) then
          Value := Field.OldValue;

        Param.AssignFieldValue(Field, Value);
      end;
    end;
  end;
end;

function TmCustomQuery.GetUpdateQuery( UpdateKind: TUpdateKind): TmCustomQuery;
begin
  if not Assigned(FQueries[UpdateKind]) then
  begin
    FQueries[UpdateKind] := TmCustomQuery.Create(Self);
    FQueries[UpdateKind].Database := Self.DataBase;
    FQueries[UpdateKind].CursorType := Self.CursorType;
  end;
  Result := FQueries[UpdateKind];
end;

function TmCustomQuery.GetCanModify: Boolean;
begin
  Result := FCanModify;
end;

// create list of parameters from SQL string
// and replace parameters to "?" char
procedure TmCustomQuery.CreateParams(List: TmParams; const Value: PChar);
var
  CurPos, StartPos: PChar;
  CurChar: Char;
  Literal: Boolean;
  EmbeddedLiteral: Boolean;
  Name: string;

  function NameDelimiter: Boolean;
  begin
    Result := CurChar in [' ', ',', ';', ')', #13, #10];
  end;

  function IsLiteral: Boolean;
  begin
    Result := CurChar in ['''', '"'];
  end;

  function StripLiterals(Buffer: PChar): string;
  var
    Len: Word;
    TempBuf: PChar;

    procedure StripChar(Value: Char);
    var i:LongInt;
    begin
      if TempBuf^ = Value then
        StrMove(TempBuf, TempBuf + 1, Len - 1);
      i := StrLen( PChar( TempBuf));
      if TempBuf[i - 1] = Value then
        TempBuf[i - 1] := #0;
    end;

  begin
    Len := StrLen( PChar( Buffer)) + 1;
    TempBuf := AllocMem(Len);
    Result := '';
    try
      StrCopy(TempBuf, PChar( Buffer));
      StripChar('''');
      StripChar('"');
      Result := StrPas(TempBuf);
    finally
      FreeMem(TempBuf, Len);
    end;
  end;

begin
  CurPos := Value;
  Literal := False;
  EmbeddedLiteral := False;
  repeat
    CurChar := CurPos^;
    if (CurChar = ':') and not Literal and ((CurPos + 1)^ <> ':') then
    begin
      StartPos := CurPos;
      while (CurChar <> #0) and (Literal or not NameDelimiter) do
      begin
        Inc(CurPos);
        CurChar := CurPos^;
        if IsLiteral then
        begin
          Literal := Literal xor True;
          if CurPos = StartPos + 1 then EmbeddedLiteral := True;
        end;
      end;
      CurPos^ := #0;
      if EmbeddedLiteral then
      begin
        Name := StripLiterals(StartPos + 1);
        EmbeddedLiteral := False;
      end
      else Name := StrPas(StartPos + 1);
      if Assigned(List) then
        List.CreateSQLParam(SQL_UNKNOWN_TYPE, Name, SQL_PARAM_INPUT);
      CurPos^ := CurChar;
      StartPos^ := '?';
      Inc(StartPos);
      StrMove(StartPos, CurPos, StrLen(CurPos) + 1);
      CurPos := StartPos;
    end
    else if (CurChar = ':') and not Literal and ((CurPos + 1)^ = ':') then
      StrMove(CurPos, CurPos + 1, StrLen(CurPos) + 1)
    else if IsLiteral then Literal := Literal xor True;
    Inc(CurPos);
  until CurChar = #0;
end;

procedure TmCustomQuery.SetParamsList(Value: TmParams);
begin
  FParams.AssignValues(Value);
end;

// this function could be sloooow,
// try to _not_ use it
function TmCustomQuery.GetRecordCount: Integer;
var
  BM: TBookmark;
  count: integer;
begin
  BM := GetBookmark;
  DisableControls;
  count := 0;
  First;
  while not EOF do
  begin
    count := count + 1;
    Next;
  end;
  GotoBookmark( BM);
  FreeBookMark( BM);
  EnableControls;
  Result := count;
end;

function TmCustomQuery.IsSequenced: Boolean;
begin
  Result := False;
end;

procedure TmCustomQuery.SetDataSource(Value: TDataSource);
begin
  if IsLinkedTo(Value) then
    DatabaseError( SCircularDataLink);
  FDataLink.DataSource := Value;
end;

function TmCustomQuery.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TmCustomQuery.ClearCalcFields(Buffer: PChar);
begin
  FillChar(Buffer[RecordSize], CalcFieldsSize, 0);
end;

function TmCustomQuery.GetRecordSize: Word;
begin
  Result := FRecordSize;
end;

procedure TmCustomQuery.InternalHandleException;
begin
  Application.HandleException(Self)
end;

// move data from record to user's buffer
procedure TmCustomQuery.CheckDataTypeAndSetWhenGet( var Field: TField;
                                                    var RecBuf: PChar;
                                                    var fd: TODBCFieldDef;
                                                    var Buffer: pointer);
var
  i: longint;
  b: ^TDateTimeRec;
begin
  with Field do
  case DataType of
   ftString:
     begin
       Buffer := StrLCopy( PChar( Buffer), RecBuf + fd.OffsetInBuf, Field.Size);
       PChar(Buffer)[Field.Size] := #0;

       i := StrLen( PChar( Buffer)); dec(i);
       while (i >= 0) and (PChar(Buffer)[i] = #32) do
       begin
         PChar(Buffer)[i] := #0;
         dec(i);
       end;
     end;
   ftAutoInc,
   ftSmallint,
   ftInteger,
   ftFloat: Move( (RecBuf + fd.OffsetInbuf)^, Buffer^, fd.SqlSize);
   ftBoolean: PWord( Buffer)^ := PByte( RecBuf + fd.OffsetInbuf)^;
   ftDate:
      begin
        b := Buffer;
        b.Date := DateTimeToTimeStamp(
                    DateStructToDateTime(
                      PSQL_DATE_STRUCT( RecBuf+fd.OffsetInbuf))).Date;
      end;
   ftTime:
      begin
        b := Buffer;
        with PSQL_TIME_STRUCT( RecBuf + fd.OffsetInbuf)^ do
          b.Time := DateTimeToTimeStamp(EncodeTime( Hour, Minute, Second, 0)).Time;
      end;
   ftDateTime:
      with PSQL_TIMESTAMP_STRUCT( RecBuf + fd.OffsetInbuf)^ do
      begin
        b := Buffer;
        b^.DateTime := TimeStampToMSecs(
                         DateTimeToTimeStamp(
                           EncodeDate( Year, Month, Day)+
                             EncodeTime( Hour, Minute, Second, 0)));
      end;
   else
     raise Exception.CreateFmt( SmFieldUnsupportedType,[ FieldName]);
  end;
end;

function TmCustomQuery.GetRecordValue(RecBuf:pchar; fdesc: TODBCFieldDef):Variant;
  function GetAsStr:AnsiString;
  var i:integer;
  begin
     SetLength( Result, fdesc.SQLsize);
     StrLCopy( PChar(Result), RecBuf, fdesc.SQLsize);
     PChar(Result)[fdesc.SQLsize] := #0;

     i := StrLen( PChar(Result));
     while (i >= 1) and (Result[i] = ' ') do dec(i);
     SetLength( Result, i);
  end;
begin
  if fdesc.SQLsize>0{DataType<>SQL_BINARY 05/05/2000} then
  begin
     inc( RecBuf, fdesc.OffsetInbuf);
     if PSQLINTEGER( RecBuf + fdesc.SqlSize)^ = SQL_NULL_DATA then
     begin
        Result := Null;// VarClear( Result);
        Exit;
     end;
  end;
  case fdesc.SQLDataType of
  SQL_CHAR,
  SQL_BINARY:
     begin
       if fdesc.SQLsize > 0 { 05/05/2000 }
         then Result := GetAsStr
         else Result := PmBlobDataArray(RecBuf + FBlobCacheOfs)[fdesc.OffsetInBuf];
     end;
  SQL_TYPE_DATE:
     begin
       TVarData(Result).VType := varDate;
       TVarData(Result).VDate := DateStructToDateTime(
                                 PSQL_DATE_STRUCT( RecBuf));
     end;
  SQL_TYPE_TIME:
     begin
       TVarData(Result).VType := varDate;
        with PSQL_TIME_STRUCT( RecBuf)^ do
          TVarData(Result).VDate := EncodeTime( Hour, Minute, Second, 0);
      end;
  SQL_TYPE_TIMESTAMP:
      with PSQL_TIMESTAMP_STRUCT( RecBuf)^ do
      begin
         TVarData(Result).VType := varDate;
         TVarData(Result).VDate := EncodeDate( Year, Month, Day)+
                                   EncodeTime( Hour, Minute, Second, 0);
      end;
  SQL_BIT:
      begin
         TVarData(Result).VType := varBoolean;
         TVarData(Result).VBoolean := wordbool(PByte( RecBuf)^);
      end;
  SQL_DOUBLE:
      begin
         TVarData(Result).VType := varDouble;
         TVarData(Result).VDouble :=PSQLDOUBLE( RecBuf)^;
      end;
  SQL_SMALLINT:
      begin
         TVarData(Result).VType := varSmallint;
         TVarData(Result).VSmallint := PSQLSMALLINT( RecBuf)^;
      end;
  SQL_INTEGER:
      begin
         TVarData(Result).VType := varInteger;
         TVarData(Result).VInteger := PSQLINTEGER( RecBuf)^;
      end;
  else
     raise Exception.CreateFmt( SmFieldUnsupportedType,[ fdesc.Name]);
  end;
end;

function TmCustomQuery.GetFieldValue(RecBuf:pchar; Field: TField):Variant;
begin
  if Field.FieldNo > 0 then
     Result:=GetRecordValue( RecBuf, TODBCFieldDef( FieldDefs.Find( Field.FieldName)))
  else begin
    if State in [dsBrowse, dsEdit, dsInsert, dsCalcFields] then
    begin
      Inc(RecBuf, FRecordSize + Field.Offset);
      if not Boolean( RecBuf[0]) then
       begin
          VarClear( Result);
          Exit;
       end;
       case Field.DataType of
       ftString:  Result := PString( RecBuf)^;
       ftSmallint:Result := PSQLSmallint( RecBuf)^;
       ftAutoInc,
       ftInteger: Result := PSQLInteger( RecBuf)^;
       ftFloat:   Result := PSQLDouble( RecBuf)^;
       ftBoolean: Result := boolean( pbyte(RecBuf)^);
       ftTime,
       ftDate,
       ftDateTime:Result := PSQLDouble( RecBuf)^;
       else
          raise Exception.CreateFmt( SmFieldUnsupportedType,[ Field.FieldName]);
       end;
    end;
  end;
end;

// set data from user's buffer
procedure TmCustomQuery.CheckDataTypeAndSetWhenSet( var Field: TField;
                                                    var RecBuf: PChar;
                                                    var fd: TODBCFieldDef;
                                                    var Buffer: pointer);
var
  b: ^TDateTimeRec;
  TimeStamp:  TTimeStamp;
begin
  case fd.SQLDataType of
   SQL_CHAR:
     begin
       StrLCopy( RecBuf + fd.OffsetInBuf, PChar( Buffer), fd.SqlSize-1);
       PChar( RecBuf + fd.OffsetInBuf)[fd.SqlSize-1] := #0;
       PSQLINTEGER( RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := StrLen( PChar( Buffer));
     end;
   SQL_SMALLINT:
     begin
       Move( Buffer^, (RecBuf + fd.OffsetInBuf)^, sizeof(SQLSMALLINT));
       PSQLINTEGER( RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQLSMALLINT);
     end;
   SQL_INTEGER:
     begin
       Move( Buffer^, (RecBuf + fd.OffsetInBuf)^, sizeof(SQLINTEGER));
       PSQLINTEGER(RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQLINTEGER);
     end;
   SQL_BIT:
     begin
       PByte(RecBuf + fd.OffsetInbuf)^ := PWord(Buffer)^;
       PSQLINTEGER(RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQLCHAR);
     end;
   SQL_DOUBLE:
     begin
       Move( Buffer^, (RecBuf + fd.OffsetInBuf)^, sizeof(SQLDOUBLE));
       PSQLINTEGER(RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQLINTEGER);
     end;
   SQL_DATE,
   SQL_TYPE_DATE:
     begin
       b := Buffer;
       TimeStamp.Date := b^.Date;
       PSQL_DATE_STRUCT( RecBuf + fd.OffsetInbuf)^ := DateTimeToDateStruct( TimeStampToDateTime( TimeStamp));
       PSQLINTEGER( RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQL_DATE_STRUCT);
     end;
   SQL_TIMESTAMP,
   SQL_TYPE_TIMESTAMP:
     begin
       b := Buffer;
       DateTime2timeStampStruct( PSQL_TIMESTAMP_STRUCT( RecBuf + fd.OffsetInbuf)^,
                                 TimeStampToDateTime( MSecsToTimeStamp( b.DateTime)));
       PSQLINTEGER( RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := sizeof(SQL_TIMESTAMP_STRUCT);
     end;
   else
     raise Exception.CreateFmt( SmFieldUnupdatedType,[ Field.FieldName]);
  end;
end;

//--------------------------------------------------------------------
//    Misc
//--------------------------------------------------------------------

function MemCompare( Buf1, Buf2: PChar; Count: Integer): boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Count-1 do
  begin
    if Buf1[i] <> Buf2[i] then
       exit;
  end;
  Result := True;
end;
