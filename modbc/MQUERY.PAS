{********************************************}
{                                            }
{     mODBC - ODBC data aware components     }
{     http://www.perio.unlp.edu.ar/modbc/    }
{                                            }
{********************************************}
unit mQuery;

{$I mODBC.INC}

//{$define USE_READONLY_DATASET}
//{$define USE_UNIDIRECTIONAL_DATASET}

interface

uses
  Windows,
  SysUtils,
  Classes,
{$if defined(ALLOW_USES_FORMS)}
  Forms,
{$ifend}
{$if defined(ALLOW_USES_DIALOGS)}
  Dialogs,
{$ifend}
  Db,
  mDataBas,
  odbcsql,
  u_ODBC_BLOB,
  mParams;

{$IFDEF D4UP}
const
   dsMaxBufferCount = MAXINT DIV 8;
type
  PBufferList = ^TBufferList;
  TBufferList = array[0..dsMaxBufferCount - 1] of PChar;
{$ENDIF}
type
  PWord = ^Word;
  PByte     =^Byte;
  TmCustomQuery = class;

{ TBlobStream }

  TmBlobStream = class(TStream)
  private
    FField:    TBlobField;
    FDataSet:  TmCustomQuery;
    FBuffer:   PChar;            // буфер записи в датасете
    FMode:     TBlobStreamMode;
    FFieldNo:  Integer;
    FOpened:   Boolean;
    FModified: Boolean;
    FPosition: Longint;
    function GetBlobSize: Longint;
  public
    constructor Create(Field: TBlobField; Mode: TBlobStreamMode);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    procedure Truncate;
  end;

  TODBCFieldDef = class(TFieldDef)
  private
     FOffset:      integer;
     FSQLDataType: SQLSMALLINT;
     FSQLsize:     SQLUINTEGER;
  public
//   BaseTable,
//   BaseColumn:   String;
     property OffsetInbuf: integer read fOffset write Foffset;
     property SQLDataType: SQLSMALLINT read fSQLDataType write FSQLDataType;
     property SQLsize:     SQLUINTEGER read fSQLsize write FSQLsize;
  end;

  TODBCRecInfo = record
    RecordNumber: SQLINTEGER;
    UpdateStatus: TUpdateStatus;
    BookmarkFlag: TBookmarkFlag;
  end;
  PODBCRecInfo = ^TODBCRecInfo;

  PBookMarkList = ^TBookMarkList;
  TBookMarkList = array[0..dsMaxBufferCount - 1] of Char;
  TmCursorTypes = (ctFwdOnlyCursor,ctStaticCursor,ctKeySetCursor,ctDynamicCursor);
  TmCursorAttributes = record
    Attrib1:           SQLUINTEGER;
    Attrib2:           SQLUINTEGER;
    UseDriverBookMark: Boolean;
    Concurrency:       SQLUINTEGER;
    Sensitivity:       SQLUINTEGER;
    UseInternalInsert,
    UseInternalUpdate,
    UseInternalDelete: boolean;
  end;

  TmQueryStateBit = (mqOpened, mqPrepared, mqInitialized, mqAllFetched);
  TmQueryState = set of TmQueryStateBit;

  { TQueryDataLink }

  TmCustomQueryDataLink = class(TDataLink)
  private
    FQuery: TmCustomQuery;
  protected
    procedure ActiveChanged; override;
    procedure RecordChanged(Field: TField); override;
    procedure CheckBrowseMode; override;
  public
    constructor Create(AQuery: TmCustomQuery);
  end;

  TmCustomQuery = class(TDataSet)
  private
    { Private declarations }
    hstmt:         SQLHSTMT;
    FetchStatus:   TBookMarkFlag;

    FBlobCount:    Integer;
    FCanModify:    boolean;
//    FCacheBlobs:   Boolean;
    FCachedPos:    LongInt;
    FCachedUpdates:Boolean;
    FCursorAttr:   TmCursorAttributes; // ODBC attributes of SQL cursor
    FCursorType:   TmCursorTypes;      // type cursor (static,dynamic)
    FDataBase:     TmDataBase;
    FDeletedCount: Integer;            // count of deleted records
    FDeletedRec:   PBookMarkList;      // bookmarks of deleted records
    FCachedCount:  Integer;            // count of cached records
    FCachedBuffer: PBufferList;        // buffers with cached records
    FParamCheck:   Boolean;
    FParams:       TmParams;
    FRecordSize:   Word;
    FRecBufSize:   Word;
    FRecInfoOfs:   Word;
    FBlobCacheOfs: Word;
    FRequestLive:  boolean;
    FRowsAffected: LongInt;
    FSQL:          TStrings;
    FState:        TmQueryState;
    FUniDirect:    boolean;
    FupdateSQL:    array[TUpdateKind] of TStrings;
    FText:         String;
    FDataLink:     TDataLink;
    FQueries:      array[TUpdateKind] of TmCustomQuery;
    FoldBuffer:    PChar; // buffer for old values of edited record
    FBindBuffer:   PChar; // buffer for SQLbindColumn
    FFilterBuffer: PChar;
    FonFilter:     TFilterRecordEvent;
    FOdbcBlobStream: TOdbcBlobStream;
    procedure AddDeletedToList(Buffer: PChar {Pointer});
    procedure AddToCacheBuffer( uStatus:TUpdateStatus; Buffer: PChar);
    function  CheckDeleted( Buffer: PChar {Pointer}):boolean;
    procedure CheckSQLResult( sqlres:SQLRETURN{;const Message: string = ''});
    procedure CreateParams(List: TmParams; const Value: PChar);
    procedure InitStmt;
    procedure FreeDeletedList;
    procedure FreeModifiedList;
    function  GetActiveRecBuf(var RecBuf: PChar): Boolean;
    function  GetBlobData(Field: TField; Buffer: PChar): TmBlobData;
    function  GetCursorName:String;
//    function  GetRowsAffected: LongInt;
    function  LocateRecord( const KeyFields: string; const KeyValues: Variant;
                      Options: TLocateOptions): Boolean;
    procedure QueryChanged(Sender: TObject);
    procedure RefreshParams;
    procedure SetBlobData(Field: TField; Buffer: PChar; Value: TmBlobData);
    procedure SetDataBase(Value: TmDataBase);
    procedure SetDataSource(Value: TDataSource);
    procedure SetParamsFromCursor;
    procedure SetParamsList(Value: TmParams);
    function  getBookmarkPtr(Buffer: PChar {Pointer}): PChar {Pointer};
    procedure InternalOpenCursor;
    procedure CopyRecordBuffer( BufferSrc, BufferDst:PChar);
    function  GetUpdateSQL(Index: Integer): TStrings;
    function  GetUpdateQuery(UpdateKind: TUpdateKind): TmCustomQuery;
    procedure SQLBindColumns( Buffer: PChar);
    procedure SQLUnBindColumns;
    function  CheckFilter( Buffer: PChar {Pointer}): boolean;
    function  GetPrepared: Boolean;
//    procedure SetPrepared(const Value: Boolean);
    function UseCache:boolean;
    { std }
  protected
    { Protected declarations }
    function  AllocRecordBuffer: PChar; override;
    procedure ClearCalcFields(Buffer: PChar); override;
    procedure FreeRecordBuffer(var Buffer: PChar); override;
    procedure GetBookmarkData(Buffer: PChar; Data: Pointer); override;
    function  GetBookmarkFlag(Buffer: PChar): TBookmarkFlag; override;
    function  GetDataSource: TDataSource; override;
    procedure GetStmtAttributes;
    function  GetRecordSize: Word; override;
    procedure SetBookmarkData(Buffer: PChar; Data: Pointer); override;
    procedure SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag); override;
    procedure SetCachedUpdates(Value: Boolean);
{$IFNDEF D4UP}
    function  GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
{$ENDIF}
    procedure SetFieldData(Field: TField; Buffer: Pointer); override;
    procedure SetCursorType(Value: TmCursorTypes);
    function  GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult; override;
    function  GetRecNo: Integer; override;
    function  GetRecordCount: Integer; override;
    procedure InternalAddRecord(Buffer: Pointer; Append: Boolean); override;
    procedure InternalClose; override;
    procedure InternalDelete; override;
    procedure InternalFirst; override;
    function  InternalGetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult;
    procedure InternalGotoBookmark(Bookmark: Pointer); override;
    procedure InternalHandleException; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalInitRecord(Buffer: PChar); override;
    procedure InternalLast; override;
    procedure InternalOpen; override;
    procedure InternalEdit; override;
    procedure InternalPost; override;
    procedure InternalCancel; override;
    procedure InternalSetToRecord(Buffer: PChar); override;
    procedure InternalRefresh; override;
    function  IsCursorOpen: Boolean; override;
    function  GetCanModify: Boolean; override;
    procedure SetQuery(Value: TStrings); virtual;
    procedure SetUpdateSQL(Index: Integer; Value: TStrings); virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure AddODBCFieldDesc( FFieldNo: Word);
    procedure CheckDataTypeAndSetWhenGet( var Field: TField;
                                          var RecBuf: PChar;
                                          var fd: TODBCFieldDef;
                                          var Buffer: pointer);
    procedure CheckDataTypeAndSetWhenSet( var Field: TField;
                                          var RecBuf: PChar;
                                          var fd: TODBCFieldDef;
                                          var Buffer: pointer);

    property CachedUpdates: Boolean read FCachedUpdates write SetCachedUpdates default False;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure ApplyUpdates;
    procedure CancelUpdates;
    procedure CommitUpdates;
    function CompareBookmarks(Bookmark1, Bookmark2: TBookmark): Integer; override;
    function  CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream; override;
{$IFDEF D4UP}
    function  GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
{$ENDIF}
    function  GetRecordValue(RecBuf:pchar; fdesc: TODBCFieldDef):Variant;
    function  GetFieldValue(RecBuf:pchar; Field: TField):Variant;
    property  CursorAttr: TmCursorAttributes read FCursorAttr;
    property  CursorName:String read GetCursorName;
    procedure ExecSQL;
    procedure FreeStmt;
    procedure PrepareCursor; virtual;
    procedure UnprepareCursor; virtual;
    function  IsSequenced: Boolean; override;
    function  Locate( const KeyFields: string; const KeyValues: Variant;
                      Options: TLocateOptions): Boolean; override;
    function  Lookup( const KeyFields: string; const KeyValues: Variant;
                      const ResultFields: string): Variant; override;
    function  ParamByName(const Value: string): TmParam;
    procedure SetParamsForUpdateSql(UpdateKind: TUpdateKind);
    property  RowsAffected: longint read FRowsAffected;
    property  Text: string read FText;
    property  SQL: TStrings read FSQL write SetQuery;
    property  ModifySQL: TStrings index 0 read GetUpdateSQL write SetUpdateSQL;
    property  InsertSQL: TStrings index 1 read GetUpdateSQL write SetUpdateSQL;
    property  DeleteSQL: TStrings index 2 read GetUpdateSQL write SetUpdateSQL;
    property  DataBase:TmDataBase read FDataBase write SetDataBase;
    property  DataSource: TDataSource read GetDataSource write SetDataSource;
    property  RequestLive:boolean read FRequestLive write FRequestLive default False;
    property  CursorType:TmCursorTypes read FCursorType write SetCursorType default ctFwdOnlyCursor;
    property  ParamCheck: Boolean read FParamCheck write FParamCheck default True;
    property  Params: TmParams read FParams write SetParamsList;
    property  Prepared: Boolean read GetPrepared;
    property  UniDirectional: Boolean read FUniDirect write FUniDirect default False;
    property  OnFilterRecord: TFilterRecordEvent read FOnFilter write FOnFilter;
  published
    { Published declarations }
  end;

  TmQuery = class(TmCustomQuery)
  published
    { Published declarations }
    property Active;
    property AutoCalcFields;
    property SQL;
    property ModifySQL;
    property InsertSQL;
    property DeleteSQL;
    property DataBase;
    property DataSource;
    property RequestLive;
    property CursorType;
    property ParamCheck;
    property Params;
    property BeforeOpen;
    property UniDirectional;
    property AfterOpen;
    property BeforeClose;
    property AfterClose;
    property BeforeInsert;
    property AfterInsert;
    property BeforeEdit;
    property AfterEdit;
    property BeforePost;
    property AfterPost;
    property BeforeCancel;
    property AfterCancel;
    property BeforeDelete;
    property AfterDelete;
    property BeforeScroll;
    property AfterScroll;
    property OnCalcFields;
    property OnDeleteError;
    property OnFilterRecord;
    property OnNewRecord;
    property OnPostError;
  end;


implementation

uses
  DbConsts,
  mConst,
  mExcept,
  Variants;

{$include mQueryHe.pas}

{ TmCustomQuery }

constructor TmCustomQuery.Create(AOwner: TComponent);
var
  UpdateKind: TUpdateKind;
begin
  inherited Create(AOwner);
  FOdbcBlobStream := nil;
  
  FSQL           := TStringList.Create;
  hstmt          := 0;
  FRecBufSize    := 0;
  FDeletedCount  := 0;
  FCanModify     := False;
  FRequestLive   := False;
  ParamCheck     := True;
  FCachedCount   := 0;
  FCachedBuffer  := nil;
  FParams        := TmParams.Create;
  FDataLink      := TmCustomQueryDataLink.Create(Self);
  TStringList(SQL).OnChange := QueryChanged;
  FCursorType    := ctFwdOnlyCursor;
  FState         := [];
  FUniDirect     := False;
  FCachedUpdates := False;
  for UpdateKind := Low(TUpdateKind) to High(TUpdateKind) do
  begin
    FupdateSQL[UpdateKind] := TStringList.Create;
  end;
  FoldBuffer     := nil;
  FBindBuffer    := nil;
end;

destructor TmCustomQuery.Destroy;
var
  UpdateKind: TUpdateKind;
begin
  FreeStmt;
  SQL.Free;
  FParams.Free;
  FDataLink.free;
  FreeDeletedList;
  FreeModifiedList;

  if Assigned(FDataBase) then
    FDataBase.ExcludeDataSet(Self);

  for UpdateKind := Low(TUpdateKind) to High(TUpdateKind) do
    FupdateSQL[UpdateKind].free;

  for UpdateKind := Low(TUpdateKind) to High(TUpdateKind) do
  begin
    if Assigned(FQueries[UpdateKind]) then
      FQueries[UpdateKind].free;
  end;

  FreeAndNil(FOdbcBlobStream);
  inherited Destroy;
end;

function TmCustomQuery.CompareBookmarks(Bookmark1, Bookmark2: TBookmark):Integer;
  function compmem(Buf1,Buf2:PChar;count:Integer):Integer;
  var i:integer;
  begin
   Result := 0;
   for i := 0 to Count-1 do
      if Buf1[i] < Buf2[i] then
       begin
          Result := -1;
          exit;
       end else
      if Buf1[i] > Buf2[i] then
       begin
          Result := 1;
          exit;
       end;
  end;
const
  RetCodes: array[Boolean, Boolean] of ShortInt = ((2,-1),(1,0));
begin
  Result := RetCodes[Bookmark1 = nil, Bookmark2 = nil];
  if Result = 2 then
    Result := compmem(Bookmark1, Bookmark2, Bookmarksize);
end;

function TmCustomQuery.GetBookmarkPtr( Buffer: PChar): PChar;
begin
  if CursorAttr.UseDriverBookMark then
  begin
    Result := Buffer;
  end else
  begin
    Result := @(PODBCRecInfo({PChar(}Buffer{)} + FRecInfoOfs).RecordNumber);
  end;
end;


procedure TmCustomQuery.AddDeletedToList( Buffer: PChar);
var
  NewList: PBookMarkList;
begin
  GetMem(NewList, (FDeletedCount+1) * BookMarkSize);
  if FDeletedCount > 0 then
  begin
    Move( FDeletedRec^, NewList^, FDeletedCount * BookMarkSize);
    FreeMem( FDeletedRec);
  end;
  FDeletedRec := NewList;
  Move( getBookmarkPtr(Buffer)^,
        FDeletedRec^[FDeletedCount*BookMarkSize],
        BookMarkSize);
  inc( FDeletedCount);
end;

procedure TmCustomQuery.AddToCacheBuffer( uStatus:TUpdateStatus; Buffer: PChar);
var
  i:  longint;
  b:  PChar;
begin
  for i := 0 to FCachedCount-1 do
  begin
    if (PODBCRecInfo(FCachedBuffer[i] + FRecInfoOfs)^.UpdateStatus = uStatus)
       and MemCompare( getBookmarkPtr( Buffer), getBookmarkPtr( FCachedBuffer[i]), BookMarkSize) then
    begin
      CopyRecordBuffer( Buffer, FCachedBuffer[i]);
      PODBCRecInfo(FCachedBuffer[i] + FRecInfoOfs)^.UpdateStatus := uStatus;
      exit;
    end;
  end;
  b := AllocRecordBuffer;
  CopyRecordBuffer( Buffer, b);
  PODBCRecInfo( b + FRecInfoOfs)^.UpdateStatus := uStatus;
  ReallocMem( FCachedBuffer, (FCachedCount+1) * sizeof(PChar));
  FCachedBuffer[FCachedCount] := b;
  inc( FCachedCount);
end;

procedure TmCustomQuery.FreeModifiedList;
var
  i: LongInt;
  p: PBufferList;
begin
  // free record buffers
  p := FCachedBuffer;
  FCachedBuffer := nil;
  for i := 0 to FCachedCount-1 do
  begin
    FreeRecordBuffer( p[i]);
  end;
  // free array
  if p <> nil then
  begin
    FreeMem( p, FCachedCount * sizeof(PChar));
  end;
  FCachedCount:=0;
end;

function TmCustomQuery.CheckDeleted( Buffer: PChar):boolean;
var
  i: Integer;
begin
  Result:=False;
//  if (FCursorAttr.Sensitivity and SQL_SS_DELETIONS)=0 then
//  begin
    for i := 0 to FDeletedCount-1 do
      if MemCompare(getBookmarkPtr( Buffer), @(FDeletedRec[i*BookMarkSize]), BookMarkSize) then
        Exit;
//  end;
   Result:=True;
end;

// get and set cursor attributes
procedure TmCustomQuery.GetStmtAttributes;
var
  VActualValue: SQLUINTEGER;
begin
   // get supported cursor types
   if (CursorType=ctDynamicCursor)and((DataBase.SQL_SCROLL_OPTIONS_VALUE and SQL_SO_DYNAMIC)=0)
     then CursorType:=ctKeySetCursor;
   if (CursorType=ctKeySetCursor)and((DataBase.SQL_SCROLL_OPTIONS_VALUE and SQL_SO_KEYSET_DRIVEN)=0)
     then CursorType:=ctStaticCursor;
   if (CursorType=ctStaticCursor)and((DataBase.SQL_SCROLL_OPTIONS_VALUE and SQL_SO_STATIC)=0)
     then CursorType:=ctFwdOnlyCursor;
   if CursorType<>ctFwdOnlyCursor then
   begin
      // set cursor type
      if not(mqOpened in FState) then
      try
         case CursorType of
          ctFwdOnlyCursor: CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CURSOR_TYPE, Pointer(SQL_CURSOR_FORWARD_ONLY), SQL_IS_UINTEGER));
          ctStaticCursor:  CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CURSOR_TYPE, Pointer(SQL_CURSOR_STATIC), SQL_IS_UINTEGER));
          ctKeySetCursor:  CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CURSOR_TYPE, Pointer(SQL_CURSOR_KEYSET_DRIVEN), SQL_IS_UINTEGER));
          ctDynamicCursor: {CheckSQLResult( } SQLSetStmtAttr( hstmt, SQL_ATTR_CURSOR_TYPE, Pointer(SQL_CURSOR_DYNAMIC), SQL_IS_UINTEGER){)};
         end;
      except on E: ESQLerror do
           if (E.SqlState<>'01S02')and(E.SqlState<>'HYC00') then raise;
      end;
      // get real cursor type
      CheckSQLResult( SQLGetStmtAttr( hstmt, SQL_ATTR_CURSOR_TYPE, @VActualValue, sizeof(VActualValue), nil));
      case VActualValue of
         SQL_CURSOR_FORWARD_ONLY:  CursorType:= ctFwdOnlyCursor;
         SQL_CURSOR_STATIC:        CursorType:= ctStaticCursor;
         SQL_CURSOR_KEYSET_DRIVEN: CursorType:= ctKeySetCursor;
         SQL_CURSOR_DYNAMIC:       CursorType:= ctDynamicCursor;
      end;
   end;   
   with FCursorAttr do
   begin // get cursor attributes
      Attrib1 := 0;
      Attrib2 := 0;
      Sensitivity := 0;
      try
      case CursorType of
        ctStaticCursor:
          begin
            DataBase.ODBCDriverInfo( SQL_STATIC_CURSOR_ATTRIBUTES1, SQLPOINTER(@Attrib1), sizeof(SQLUINTEGER), nil);
            DataBase.ODBCDriverInfo( SQL_STATIC_SENSITIVITY, SQLPOINTER(@Sensitivity), sizeof(SQLUINTEGER), nil);
            // DataBase.ODBCDriverInfo( SQL_STATIC_CURSOR_ATTRIBUTES2, SQLPOINTER(@Attrib2), sizeof(SQLUINTEGER), nil);
          end;
        ctKeySetCursor:
          begin
            Attrib1     := DataBase.SQL_KEYSET_CURSOR_ATTRIBUTES1_VALUE;
            Sensitivity := DataBase.SQL_STATIC_SENSITIVITY_VALUE;
            // DataBase.ODBCDriverInfo( SQL_KEYSET_CURSOR_ATTRIBUTES2, SQLPOINTER(@Attrib2), sizeof(SQLUINTEGER), nil);
          end;
        ctDynamicCursor:
          begin
            DataBase.ODBCDriverInfo( SQL_DYNAMIC_CURSOR_ATTRIBUTES1, SQLPOINTER(@Attrib1), sizeof(SQLUINTEGER), nil);
            Sensitivity := SQL_SS_ADDITIONS + SQL_SS_DELETIONS + SQL_SS_UPDATES; // by default
            // DataBase.ODBCDriverInfo( SQL_DYNAMIC_CURSOR_ATTRIBUTES2, SQLPOINTER(@Attrib2), sizeof(SQLUINTEGER), nil);
          end;
      end;
      except; // some drivers not support second attributes
      end;

      if ((Database.SQL_BOOKMARK_PERSISTENCE_VALUE and SQL_BP_UPDATE)=0)
          or(((Database.SQL_BOOKMARK_PERSISTENCE_VALUE and SQL_BP_DELETE)=0)and((Sensitivity and SQL_SS_DELETIONS)=0))
          or (cursorType=ctFwdOnlyCursor)
      then UseDriverBookMark := False
      else UseDriverBookMark := True;

      if UseDriverBookMark
      then CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_USE_BOOKMARKS, Pointer(SQL_UB_ON), 0))
      else SQLSetStmtAttr( hstmt, SQL_ATTR_USE_BOOKMARKS, Pointer(SQL_UB_OFF), 0);

      UseInternalInsert := ((Attrib1 and SQL_CA1_BULK_ADD  )<>0);
      UseInternalUpdate := ((Attrib1 and SQL_CA1_POS_UPDATE)<>0);
      UseInternalDelete := ((Attrib1 and SQL_CA1_POS_DELETE)<>0);
      // using external update SQL statement
      if Length(FUpdateSQL[ukInsert].Text) > 0 then
           UseInternalInsert := False;
      if Length(FUpdateSQL[ukModify].Text) > 0 then
           UseInternalUpdate := False;
      if Length(FUpdateSQL[ukDelete].Text) > 0 then
           UseInternalDelete := False;
      if not UseInternalUpdate then
          Sensitivity := Sensitivity and (not SQL_SS_UPDATES);
      if not UseInternalDelete then
          Sensitivity := Sensitivity and (not SQL_SS_DELETIONS);


      // SQL_SCROLL_CONCURRENCY deprecated in ODBC 3.x

      (*
      if (not(mqOpened in FState)) and
         (CursorType in [ctDynamicCursor,ctKeySetCursor])
      then
      if ((ui and SQL_SCCO_LOCK)<>0) then
      begin
          CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CONCURRENCY, Pointer(SQL_CONCUR_LOCK), SQL_IS_UINTEGER));
      end else
      begin
          if ((ui and SQL_SCCO_OPT_ROWVER) <> 0) then
          begin
            CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CONCURRENCY, Pointer(SQL_CONCUR_ROWVER), SQL_IS_UINTEGER));
          end else
          begin
            if ((ui and SQL_SCCO_OPT_VALUES) <> 0) then
            begin
              CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CONCURRENCY, Pointer(SQL_CONCUR_VALUES), SQL_IS_UINTEGER));
            end else
            begin
              if (ui and SQL_SCCO_READ_ONLY) <> 0 then
              begin
                CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_CONCURRENCY, Pointer(SQL_CONCUR_READ_ONLY), SQL_IS_UINTEGER));
              end;
            end;
          end;
      end;
      *)

      if SQLGetStmtAttr( hstmt, SQL_ATTR_CONCURRENCY, @Concurrency, sizeof(Concurrency), nil)<>0
        then Concurrency:=0;
   end;

end;

procedure TmCustomQuery.InitStmt;
var
  sqlres: SQLRETURN;
begin
  if (mqInitialized in FState) and (hstmt <> 0) then
    Exit;

  if DataBase=nil then
    raise EMODBCNoDataSource.Create( SmNoDataSource);

  if DataBase.hdbc=0 then
    DataBase.Connect;

  sqlres := SQLAllocHandle(SQL_HANDLE_STMT, DataBase.hdbc, hstmt);

  if not SQL_SUCCEEDED(sqlres) then
    raise EMODBCAllocStatement.CreateDiag( SQL_HANDLE_DBC, DataBase.hdbc, sqlres);//ESQLerror.Create( SmAllocateSTMTError);

  Include(FState, mqInitialized);
  GetStmtAttributes;
end;

procedure TmCustomQuery.FreeStmt;
begin
  if hstmt = 0 then
    exit;

  Close;
  SQLFreeHandle(SQL_HANDLE_STMT,hstmt);
  hstmt := 0;
  FState := []; //Exclude(FState, mqInitialized); Exclude(FState, mqPrepared); Exclude(FState, mqOpened);
end;

procedure TmCustomQuery.ExecSQL;

   function GetRowsAffected: LongInt;
   var
     rCount: SQLINTEGER;
   begin
     CheckSQLResult( SQLRowCount( hstmt, rCount));
     Result := rCount;
   end;

begin
  CheckInActive;
  try
    FRowsAffected := 0;
    InternalOpenCursor;
    FRowsAffected := GetRowsAffected;
  finally
    InternalClose;
  end;
end;

procedure TmCustomQuery.SetQuery( Value: TStrings);
begin
  if SQL.Text <> Value.Text then
  begin
//    Disconnect;
    SQL.BeginUpdate;
    try
      SQL.Assign(Value);
    finally
      SQL.EndUpdate;
    end;
  end;
end;

procedure TmCustomQuery.SetUpdateSQL(Index: Integer; Value: TStrings);
begin
  if (State <> dsInActive) and (not (csDesigning in ComponentState)) then
  begin
    if (Length(FUpdateSQL[ukInsert].Text) > 0) <> (Length(Value.Text) > 0) then
      raise Exception.Create('You can''t change Post metod while query is active');
  end;
  FupdateSQL[TUpdateKind(Index)].Assign(Value)
end;

function TmCustomQuery.GetupdateSQL(Index: Integer): TStrings;
begin
  Result := FupdateSQL[TUpdateKind(Index)];
end;

procedure TmCustomQuery.InternalOpen;
begin
  InternalInitFieldDefs;
  if DefaultFields then
    CreateFields;
  BindFields(True);
  FBlobCacheOfs := FRecordSize + CalcFieldsSize;
  FRecInfoOfs := FBlobCacheOfs + FBlobCount * SizeOf(Pointer);
  FRecBufSize := FRecInfoOfs + SizeOf(TODBCRecInfo);
  // а bookmark прячется в нулевой колонке ( если существует )
end;

procedure TmCustomQuery.InternalClose;
begin
  SQLFreeStmt( hstmt, SQL_CLOSE); { SQLCloseCursor( hstmt); }
  Exclude(FState, mqOpened); Exclude(FState, mqAllFetched);
  SQLUnBindColumns;

  BindFields(False);
  if DefaultFields then
    DestroyFields;
  FCanModify := False;
  FreeDeletedList;
  FreeModifiedList;
end;

procedure TmCustomQuery.InternalRefresh;
//Var
//   sqlres: SQLRETURN;
begin
{     SQLCloseCursor( hstmt);
     sqlres:=SQLExecute( hstmt);
     case sqlres of
     SQL_SUCCESS:;
     SQL_SUCCESS_WITH_INFO: raise ESQLerror.CreateDiag(SQL_HANDLE_STMT,hstmt);
     SQL_NEED_DATA:         raise ESQLerror.Create('SQL_NEED_DATA');
     SQL_STILL_EXECUTING:   raise ESQLerror.Create('SQL_STILL_EXECUTING');
     SQL_ERROR:             raise ESQLerror.CreateDiag(SQL_HANDLE_STMT,hstmt);
     SQL_NO_DATA:           raise ESQLerror.Create('SQL_NO_DATA');
     SQL_INVALID_HANDLE:    raise ESQLerror.Create('SQL_INVALID_HANDLE');
     else                   raise ESQLerror.Create('unknown SQL result');
     end;
   if (FCursorAttr.Sensitivity and SQL_SS_DELETIONS)=0
     then FreeDeletedList;
     }
end;

procedure TmCustomQuery.InternalInitFieldDefs;
var
  Colmns: SQLSMALLINT;
  i:      integer;
begin
  if not IsCursorOpen then InternalOpenCursor;
  FieldDefs.Clear;
  CheckSQLResult( SQLNumResultCols(hstmt, Colmns){,'InternalInitFieldDefs'});
  BookmarkSize := sizeof(SQLUINTEGER);
  FRecordSize  := 0;
  FBlobCount   := 0;
  if CursorAttr.UseDriverBookMark then
  begin
    for i := 0 to Colmns do
      AddODBCFieldDesc(i);
  end else
  begin
    for i := 1 to Colmns do
      AddODBCFieldDesc(i);
  end;
  FCanModify := RequestLive;
end;

procedure TmCustomQuery.PrepareCursor;
begin
  if mqPrepared in FState then
    Exit;
  CheckSQLResult( SQLPrepare( hstmt, PCHAR(Text), SQL_NTS));
  Include( FState, mqPrepared);
end;

procedure TmCustomQuery.UnPrepareCursor;
begin
  Exclude(FState, mqPrepared);
end;

function TmCustomQuery.GetPrepared: Boolean;
begin
  Result := mqPrepared in FState;
end;

procedure TmCustomQuery.InternalOpenCursor;
var
  buf,
  bufPos:    Pchar;
  bufLen:    LongInt;
  ValueType,
  ParamType: SQLSMALLINT;
  dsize:     SQLUINTEGER;
  i:         Integer;
  snd:       SQLINTEGER;
  h,m,s,ms:word;
  DecDigits:SMALLINT;
begin
  FetchStatus := bfBof;
  FCanModify := False;

  FieldDefs.Clear;
  FRecordSize:=0;
  InitStmt;
  try
    PrepareCursor;
    // seting MasterSource parameters
    if FDataLink.DataSource <> nil then
      SetParamsFromCursor;

    // calculate buffer length
    bufLen := 0;
    for i := 0 to Params.Count-1 do
    begin
      if not Params[i].isnull then
      begin
        ValueType := Database.BDE2SqlType( Params[i].DataType);
        case ValueType of
          SQL_DATE,
          SQL_TYPE_DATE:      bufLen := bufLen + Sizeof(SQL_DATE_STRUCT);
          SQL_TIMESTAMP,
          SQL_TYPE_TIMESTAMP:
          begin
              DecodeTime(Params[i].AsDateTime,h,m,s,ms);
              if ms <> 0 
                then DecDigits := length(IntToStr(ms))
                else DecDigits := 0;
              if DecDigits=0
                then bufLen := bufLen +  19
                else bufLen := bufLen +  20 + DecDigits;
          end;
         else
          bufLen := bufLen + Params[i].GetDataSize;
        end;
        bufLen := bufLen + sizeof(SQLINTEGER);
      end;
    end;

    if bufLen > 0 then
    begin
      GetMem( buf, bufLen); // buf:=StrAlloc(bufLen)
    end else
    begin
      buf := nil;
    end;

    // bind parameters
    try
      bufPos:=buf;
      for i:=0 to Params.Count-1 do
      begin
        Valuetype := Database.BDE2SqlType( Params[i].DataType);
        ParamType := ValueType;
        DecDigits := 0;
        // for Sybase SQL Anywhere 6.x & Date fields
        // SQL_C_DEFAULT -> dtype
(*      v1.07f
        if not (Paramtype in [SQL_DATE,SQL_TIMESTAMP,SQL_TYPE_DATE,SQL_TYPE_TIMESTAMP])
          else ValueType := SQL_C_DEFAULT; *)
        case ParamType of
          SQL_DATE,
          SQL_TYPE_DATE:      dsize := Sizeof(SQL_DATE_STRUCT);
          SQL_TIMESTAMP,
          SQL_TYPE_TIMESTAMP:
            begin
              // dsize := Sizeof(SQL_TIMESTAMP_STRUCT);
              DecodeTime(Params[i].AsDateTime,h,m,s,ms);
              if ms <> 0 then DecDigits := length(IntToStr(ms));
              if DecDigits=0
                then dsize := 19
                else dsize := 20 + DecDigits;
            end;
          else                dsize := Params[i].GetDataSize;
        end;
        case ParamType of // default datatype conversions
        SQL_CHAR,
        SQL_VARCHAR,
        SQL_LONGVARCHAR:   ValueType := SQL_CHAR;
        SQL_BINARY,
        SQL_VARBINARY,
        SQL_LONGVARBINARY: begin
          ValueType := SQL_BINARY;
          // for postgresql
          if Database.ByteaAsLoOff then
            ParamType := SQL_VARBINARY
          else
            ParamType := SQL_LONGVARBINARY;
        end;
        end;

        if (not Params[i].IsNull) then
        begin
           case Valuetype of
             0: DatabaseErrorFmt( SmFieldUnsupportedType, [Params[i].Name]);
             SQL_DATE,
             SQL_TYPE_DATE:
               begin
                 PSQL_DATE_STRUCT( BufPos)^ :=
                              DateTimeToDateStruct( Params[i].AsDateTime);
               end;
             SQL_TIMESTAMP,
             SQL_TYPE_TIMESTAMP:
               begin
                 DateTime2timeStampStruct( PSQL_TIMESTAMP_STRUCT( bufPos)^,
                                           Params[i].AsDateTime);
               end;
             else
               Params[i].GetData( bufPos);
           end;
           if ValueType=SQL_CHAR then PSQLINTEGER(bufPos + dsize)^ := SQL_NTS
           else PSQLINTEGER(bufPos + dsize)^ := dsize;
           CheckSQLResult( SQLBindParameter( hstmt, i+1, SQL_PARAM_INPUT,
                           ValueType, ParamType, dsize, DecDigits, bufPos, 0, Pointer(bufPos + dsize)));
           bufPos := bufPos + dsize + sizeof(SQLINTEGER);
        end else
        begin
(*         v1.07f
           snd := SQL_NULL_DATA;
           try
             // dsize must be 0, but some drivers do not understand this
             CheckSQLResult( SQLBindParameter( hstmt, i+1, SQL_PARAM_INPUT, ValueType, ParamType, 3{dsize}, 0, bufPos, 3, @snd));
           except
             dsize := 3;
             CheckSQLResult( SQLBindParameter( hstmt, i+1, SQL_PARAM_INPUT, ValueType, ParamType, dsize, 0, nil, 0, @snd));
           end; *)
          (* it's BDE like version *)
          snd := SQL_NULL_DATA;
          CheckSQLResult( SQLBindParameter( hstmt, i+1, SQL_PARAM_INPUT, ValueType,
                                            ParamType, dsize, 0, nil, 0, @snd));
          (* end of BDE ver*)
        end;
      end;

      try
        CheckSQLResult( SQLExecute( hstmt));
      except
        on E: ESQLerror do
          // change cursor type according stmt attributes
          if E.SqlState = '01S02' then
          begin
            Include( FState, mqOpened);
            GetStmtAttributes
          end else raise;
      end;
      Include( FState, mqOpened);
    finally
      if Params.Count > 0 then
        CheckSQLResult( SQLFreeStmt( hstmt, SQL_RESET_PARAMS));
      if Assigned(buf){bufLen > 0} then
        FreeMem( buf);
    end;
  except
    FreeStmt;
    raise;
  end;
end;

function TmCustomQuery.IsCursorOpen: Boolean;
begin
  Result:= (hstmt <> 0) and (mqOpened in FState);
end;

function TmCustomQuery.AllocRecordBuffer: PChar;
begin
  Result := StrAlloc( FRecBufSize);
  if FBlobCount > 0 then
    Initialize( PmBlobDataArray( Result + FBlobCacheOfs)[0], FBlobCount);
end;

procedure TmCustomQuery.FreeRecordBuffer(var Buffer: PChar);
begin
  if FBlobCount > 0 then
    Finalize( PmBlobDataArray( Buffer + FBlobCacheOfs)[0], FBlobCount);
  StrDispose( Buffer);
end;

procedure TmCustomQuery.SQLBindColumns( Buffer: PChar);
var
  i: Integer;
begin
  if FBindBuffer = nil then
    FBindBuffer := AllocRecordBuffer;

  if CursorAttr.UseDriverBookMark then
        CheckSQLResult( SQLBindCol( hstmt, 0, SQL_C_BOOKMARK{SQL_BINARY},
                                    SQLPOINTER(FBindBuffer), BookMarkSize,
                                    PSQLINTEGER(FBindBuffer+BookMarkSize) ));

  for i := 0 to FieldDefs.Count - 1 do
  begin
    with TODBCFieldDef(FieldDefs[I]) do
    begin
      if SQLsize>0{DataType<>SQL_BINARY 05/05/2000} then
      begin
        CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                                    SQLPOINTER(FBindBuffer+OffsetInBuf),SqlSize,
                                    PSQLINTEGER(FBindBuffer+OffsetInBuf+SqlSize)));
      end;
    end;
  end;
end;

procedure TmCustomQuery.SQLUnBindColumns;
var
  i: Integer;
  sqlres: SQLRETURN;
begin
  if FBindBuffer <> nil then
  begin
    sqlres := SQLFreeStmt( hstmt, SQL_UNBIND);
    if (sqlres<>SQL_SUCCESS) and (sqlres<>SQL_INVALID_HANDLE) then
    begin
      if CursorAttr.UseDriverBookMark then
        SQLBindCol( hstmt, 0, SQL_BINARY,
                    nil, BookMarkSize, nil);
      for I := 0 to FieldDefs.Count - 1 do
      begin
        with TODBCFieldDef(FieldDefs[I]) do
          if SQLsize>0{ DataType<>SQL_BINARY 05/05/2000} then
             SQLBindCol( hstmt, FieldNo, SqlDataType,
                                        nil, SQLSize, nil);
      end;
    end;
    FreeRecordBuffer( FBindBuffer);
    FBindBuffer := nil;
  end;
end;

function TmCustomQuery.UseCache:boolean;
begin
  Result := (FUniDirect=False)and(CursorType=ctFwdOnlyCursor);

end;

function TmCustomQuery.GetRecord(Buffer: PChar; GetMode: TGetMode;
  DoCheck: Boolean): TGetResult;
label TryAgain;
begin
TryAgain:
  if not UseCache then
  begin // standart way
    Result:=InternalGetRecord( Buffer, GetMode, DoCheck);
  end else begin
     // use internal cache
     Result:=grOk;
     if FetchStatus=bfEof then
     begin // retrive all data
       FetchStatus := bfCurrent;
       repeat
         Result:=InternalGetRecord( Buffer, gmNext, DoCheck);
         if Result=grOk then
           AddToCacheBuffer(usModified, Buffer);
       until Result<>grOk;
       if Result<>grEof then exit;
       FCachedPos := FCachedCount-1;
       FetchStatus := bfEof;
     end;
     case GetMode of
       gmCurrent:
         case FetchStatus of
           bfBOF: FCachedPos := 0;
           bfEOF: FCachedPos := FCachedCount-1;
           else   ;
         end;
       gmNext:
         case FetchStatus of
           bfBOF: FCachedPos := 0;
           bfEOF: Result:=grError;
           else   inc( FCachedPos);
         end;
       gmPrior:
         case FetchStatus of
           bfBOF: Result:=grError;
           bfEOF: FCachedPos := FCachedCount;
           else   dec( FCachedPos);
         end;
     end;
     FetchStatus := bfCurrent;
     if FCachedPos<0 then
     begin
       FCachedPos := -1;
       Result := grBOF;
       exit;
     end;
     if FCachedPos>=FCachedCount then
     begin // retrive next record into buffer
       FCachedPos := FCachedCount;
       Result:=InternalGetRecord( Buffer, gmNext, DoCheck);
       if Result=grOk then
       begin
         // store new record into buffer
         AddToCacheBuffer(usModified, Buffer);
         FCachedPos := FCachedCount-1;
       end;
     end else
     begin
        CopyRecordBuffer( FCachedBuffer[FCachedPos], Buffer);
     end;
  end;
  if Result<>grOk then exit;
  if not CheckDeleted(Buffer) then
  begin
     if GetMode = gmCurrent then
       GetMode := gmNext;
     goto TryAgain;
  end;
  GetCalcFields(Buffer);
  if (not CheckFilter(Buffer))and (Result=grOk) then
  begin
     if GetMode = gmCurrent then
       GetMode := gmNext;
     goto TryAgain;
  end;
end;

function TmCustomQuery.InternalGetRecord(Buffer: PChar; GetMode: TGetMode;
  DoCheck: Boolean): TGetResult;
var
  sqlres:   SQLRETURN;
  i,
  bind:     SQLINTEGER;
  VBlobAccum: TmBlobData;
  b:        LongInt;
label again;
begin
  if FBindBuffer = nil then
    SQLBindColumns( FBindBuffer);
again:
//  if CursorAttr.UseDriverBookMark then FillChar(FBindBuffer^, BookMarkSize, 0);

  case GetMode of
    gmCurrent:
      case FetchStatus of
        bfBOF: sqlres := SQLFetchScroll( hstmt, SQL_FETCH_FIRST, 0);
        bfEOF: sqlres := SQLFetchScroll( hstmt, SQL_FETCH_LAST, 0);
        else   sqlres := SQLFetchScroll( hstmt, SQL_FETCH_RELATIVE, 0);
      end;
    gmNext:
      if CursorType=ctFwdOnlyCursor then
      begin
         if mqAllFetched in FState then sqlres := 100
         else begin
           sqlres := SQLFetch( hstmt);
           if sqlres=100 then Include( FState,mqAllFetched);
         end;
      end else
      case FetchStatus of
        bfBOF: sqlres := SQLFetchScroll( hstmt, SQL_FETCH_FIRST, 0);
        bfEOF: sqlres := SQL_NO_DATA; //SQL_ERROR;
        else   sqlres := SQLFetchScroll( hstmt, SQL_FETCH_NEXT, 1);
      end;
    gmPrior:
      case FetchStatus of
        bfBOF: sqlres := SQL_NO_DATA; //SQL_ERROR;
        bfEOF: sqlres := SQLFetchScroll( hstmt, SQL_FETCH_LAST, 0);
        else   sqlres := SQLFetchScroll( hstmt, SQL_FETCH_PRIOR, 1);
      end;
  else
    sqlres:= SQL_ERROR;
  end;

  FetchStatus := bfCurrent;

  Result := grOK;
  case sqlres of
    SQL_SUCCESS:;
    SQL_SUCCESS_WITH_INFO:
      try
        checkSQLResult(sqlres);
      except on E: ESQLerror do
        if (E.SqlState<>'01S06')and(GetMode=gmPrior)
          then Result:=grBOF
          else raise;
      end;
     SQL_NEED_DATA,
     SQL_STILL_EXECUTING,
     SQL_ERROR,
     SQL_INVALID_HANDLE:
       begin
         Result := grError;
         try
            checkSQLResult(sqlres);
         except on E: ESQLerror do
            if (E.SqlState = 'HY109') // skip deleted records in MS Access
            then begin
               if GetMode = gmCurrent then GetMode := gmNext;
               Result := grOk;
            end else raise;//ShowMessage('+'+E.SqlState+'+');
         end;
         if Result = grOk then goto again;
       end;
     SQL_NO_DATA:
       begin
         if GetMode=gmNext then
         begin
           Result := grEOF;
         end else
         begin
           if GetMode = gmPrior then
           begin
             Result := grBOF;
           end else
           begin
             Result := grError;{raise ESQLerror.Create('SQL_NO_DATA');}
           end;
         end;
       end;
     else
       Result := grError;
  end;

  if Result <> grOk then
    exit;

  // read bookmark
  if CursorAttr.UseDriverBookMark then
  begin
{    bind := bookmarksize; // SQL server don't understand getdata bookmark
    i:=SQLGetData( hstmt, 0, SQL_C_BOOKMARK,
                                SQLPOINTER(Buffer),
                                BookMarkSize,@bind);
//    checkSQLResult(sqlres); }
    bind := PSQLINTEGER(FBindBuffer+BookMarkSize)^;
    if bind<>BookMarkSize then
    begin
       Result := grError;
       exit;
    end;
    Move( FBindBuffer^, Buffer^, BookMarkSize + Sizeof(SQLINTEGER));
  end;
  with PODBCRecInfo(Buffer + FRecInfoOfs)^ do
  begin
    BookmarkFlag := bfCurrent;
    if UseCache then
    begin
      RecordNumber := FCachedCount;
    end else
    begin
      i:=SQLGetStmtAttr( hstmt, SQL_ATTR_ROW_NUMBER, @RecordNumber, SQL_IS_UINTEGER, nil);
      if  i <> SQL_SUCCESS then
        RecordNumber := -1;
      if RecordNumber = 0 then
        RecordNumber:=-1;
    end;
//       UpdateStatus := TUpdateStatus(FRecProps.iRecStatus);
  end;

  try
    b := -1;
    // check if record cached
    if not UseCache then
    for i := 0 to FCachedCount-1 do
      begin
        if MemCompare( getBookmarkPtr( Buffer),
                       getBookmarkPtr( FCachedBuffer[i]), BookMarkSize) then
        begin
          b := i;
          break;
        end;
      end;

    if b >= 0 then
    begin
       // read fields into buffer from cache
       CopyRecordBuffer( FCachedBuffer[b], Buffer);
    end else
    begin
      // read fields into buffer from driver
//      if CursorAttr.UseDriverBookMark then
//      begin
        // copy only binded fields without blob
//        Move( (FBindBuffer+BookMarkSize)^,
//              (Buffer+BookMarkSize)^,
//               FRecordSize-BookMarkSize);
//      end else
//      begin
        // copy only binded fields without blob
        Move( FBindBuffer^, Buffer^, FRecordSize);
//      end;

      for i := 0 to FieldDefs.Count - 1 do
      begin
        with TODBCFieldDef(FieldDefs[i]) do
          if SQLsize <= 0{DataType=SQL_BINARY 05/05/2000} then {
          CheckSQLResult( SQLGetData( hstmt,FieldNo, SQLDataType,
                                   SQLPOINTER(Buffer+OffsetInBuf),SqlSize,
                                   PSQLINTEGER(Buffer+OffsetInBuf+SqlSize)))
          else }
          begin
            // load blob fields
            if (nil=FOdbcBlobStream) then begin
              FOdbcBlobStream := TOdbcBlobStream.Create;
            end;
            VBlobAccum := FOdbcBlobStream.ReadOdbcFieldAsString(hstmt, FieldNo, SQLDataType, Database.CheckStatementResult);

            {$RANGECHECKS OFF}
            PmBlobDataArray(Buffer + FBlobCacheOfs)[OffsetInBuf] := VBlobAccum;
          end;
      end;
    end;
  except
//    Result:=grError;
    raise;
  end;
end;

procedure TmCustomQuery.InternalSetToRecord(Buffer: PChar);
begin
  InternalGotoBookmark( getBookmarkPtr( Buffer));
end;

function TmCustomQuery.GetFieldData( Field: TField; Buffer: Pointer): Boolean;
var
  RecBuf: PChar;
  fd:     TODBCFieldDef;
begin
  Result := False;
  if not GetActiveRecBuf(RecBuf) then
    Exit;

  if Field.FieldNo > 0 then
  begin
    fd := TODBCFieldDef( FieldDefs.Find( Field.FieldName));

    if PSQLINTEGER( RecBuf + fd.OffsetInBuf + fd.SqlSize)^ = SQL_NULL_DATA then
      Exit;

    if Buffer <> nil then
      CheckDataTypeAndSetWhenGet( Field, RecBuf, fd, Buffer);

    Result := True;
  end else
  begin
    if State in [dsBrowse, dsEdit, dsInsert, dsCalcFields] then
    begin
      Inc(RecBuf, FRecordSize + Field.Offset);
      Result := Boolean( RecBuf[0]);
      if Result and (Buffer <> nil) then
        Move(RecBuf[1], Buffer^, Field.DataSize);
    end;
  end;
end;

procedure TmCustomQuery.SetFieldData( Field: TField; Buffer: Pointer);
var
  RecBuf:     PChar;
  fd:         TODBCFieldDef;
begin
  if not (State in dsWriteModes) then
    DatabaseError( SNotEditing);

  GetActiveRecBuf( RecBuf);

  if Field.FieldNo > 0 then
  begin
    if State = dsCalcFields then
      DatabaseError( SNotEditing);

    if Field.ReadOnly and not (State in [dsSetKey, dsFilter]) then
      DatabaseErrorFmt( SFieldReadOnly, [Field.DisplayName]);

    Field.Validate( Buffer);

    if Field.FieldKind <> fkInternalCalc then
    begin
      // if FConstraintLayer and Field.HasConstraints and (State in [dsEdit, dsInsert]) then
      //   Check(DbiVerifyField(FHandle, FieldNo, Buffer, Blank));
      // Check(DbiPutField(FHandle, FieldNo, RecBuf, Buffer));
      fd := TODBCFieldDef( FieldDefs.Find( Field.FieldName));
      if Buffer = nil
        then PSQLINTEGER(RecBuf + fd.OffsetInBuf + fd.SqlSize)^ := SQL_NULL_DATA // field set to NULL
        else CheckDataTypeAndSetWhenSet( Field, RecBuf, fd, Buffer);
    end;
  end else
  begin
     // fkCalculated, fkLookup
     Inc( RecBuf, FRecordSize + Field.Offset);
     Boolean( RecBuf[0]) := LongBool( Buffer);
     if Boolean(RecBuf[0]) then
       Move( Buffer^, RecBuf[1], Field.DataSize);
  end;

  if not (State in [dsCalcFields, dsFilter, dsNewValue]) then
    DataEvent( deFieldChange, Longint(Field));
end;

function TmCustomQuery.GetActiveRecBuf( var RecBuf: PChar): Boolean;
begin
  case State of
    dsBrowse:
      if IsEmpty then RecBuf := nil
                 else RecBuf := ActiveBuffer;
    dsEdit,
    dsInsert: RecBuf := ActiveBuffer;
//    dsSetKey: RecBuf := PChar(FKeyBuffer) + SizeOf(TKeyBuffer);
    dsCalcFields: RecBuf := CalcBuffer;
    dsFilter: RecBuf := FFilterBuffer;
    dsNewValue: RecBuf := ActiveBuffer;
    dsOldValue: if fOldBuffer <> nil
                  then RecBuf := FOldBuffer
                  else RecBuf := ActiveBuffer;
  else
    RecBuf := nil;
  end;
  Result := RecBuf <> nil;
end;

procedure TmCustomQuery.InternalFirst;
begin
  FetchStatus := bfBOF;
end;

procedure TmCustomQuery.InternalLast;
begin
  FetchStatus := bfEOF;
end;

procedure TmCustomQuery.InternalInitRecord(Buffer: PChar);
var
  i:integer;
begin
  for i := 0 to BlobFieldCount - 1 do
    PmBlobDataArray(Buffer + FBlobCacheOfs)[I] := '';
   // clear indicator var //FillChar( Buffer^, FRecordSize, #0);
  for i := 0 to FieldDefs.Count - 1 do
    with TODBCFieldDef(FieldDefs[I]) do
      PSQLINTEGER(Buffer+OffsetInBuf+SqlSize)^:=SQL_NULL_DATA;

  with PODBCRecInfo(Buffer + FRecInfoOfs)^ do
  begin
    UpdateStatus := TUpdateStatus(usInserted);
    BookMarkFlag := bfInserted;
    RecordNumber := -1;
  end;
end;

procedure TmCustomQuery.InternalAddRecord( Buffer: Pointer; Append: Boolean);
begin
end;

procedure TmCustomQuery.InternalEdit;
begin
  if FoldBuffer <> nil then
    FreeRecordBuffer( FoldBuffer);

  FoldBuffer := AllocRecordBuffer;
  CopyRecordBuffer( ActiveBuffer, FoldBuffer);
end;

procedure TmCustomQuery.InternalPost;
var
{$if defined(ALLOW_USES_DIALOGS)}
  i:     integer;
{$ifend}
  iNull: SQLINTEGER;
  bNull: char;

  procedure BindCurRecord;
  var
    i:        integer;
    FieldDef: TODBCFieldDef;
    b:PChar;
  begin
    SQLUnBindColumns;
    b := ActiveBuffer;
    if CursorAttr.UseDriverBookMark then
      CheckSQLResult( SQLBindCol( hstmt, 0, SQL_C_BOOKMARK{SQL_BINARY},
                                  SQLPOINTER(b),
                                  BookMarkSize,nil));

    for i := 0 to FieldCount - 1 do
    begin
      with TField(Fields[I]) do
      begin
        if (FieldKind <> fkData) or (ReadOnly = True) or (FieldNo <= 0) then
          continue;

        FieldDef := FieldDefs.Find(FieldName) as TODBCFieldDef;

        if FieldDef = nil then
          raise Exception.create('fielddef not found');

        with FieldDef do
        if SQLsize>0{DataType<>SQL_BINARY 05/05/2000} then
        begin
          CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                          SQLPOINTER(b+OffsetInBuf),SqlSize,
                          PSQLINTEGER(b+OffsetInBuf+SqlSize)))
        end else
        begin
          if Length(PmBlobDataArray(b + FBlobCacheOfs)[OffsetInBuf]) > 0 then
          begin
            CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                            SQLPOINTER( PmBlobDataArray( b + FBlobCacheOfs)[OffsetInBuf]),
                            Length(PmBlobDataArray(b + FBlobCacheOfs)[OffsetInBuf]), nil));
          end else
          begin
            CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                                        SQLPOINTER(@bNull),
                                        0, SQLPOINTER(@iNull)));
          end;
        end;
      end;
    end;
  end;

                      {     for I := 0 to FieldDefs.Count - 1 do
                              with TODBCFieldDef(FieldDefs[I]) do
                              if SQLDataType<>SQL_BINARY then
                                CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                                              SQLPOINTER(ActiveBuffer+OffsetInBuf),SqlSize,
                                              PSQLINTEGER(ActiveBuffer+OffsetInBuf+SqlSize)))
                              else
                                if Length(PmBlobDataArray(ActiveBuffer + FBlobCacheOfs)[OffsetInBuf])>0
                                 then CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                                              SQLPOINTER(PmBlobDataArray(ActiveBuffer + FBlobCacheOfs)[OffsetInBuf]),
                                              Length(PmBlobDataArray(ActiveBuffer + FBlobCacheOfs)[OffsetInBuf]),
                                              nil))
                                 else begin
                                      CheckSQLResult( SQLBindCol( hstmt, FieldNo, SQLDataType,
                                              SQLPOINTER(@bNull),
                                              0,
                                              SQLPOINTER(@iNull)));
                                 end;
                      }

  procedure UnBindCurRecord;
  var
   i: Integer;
   sqlres: SQLRETURN;
  begin
    if CursorAttr.UseDriverBookMark then
      SQLBindCol( hstmt, 0, SQL_BINARY, nil, 0, PSQLINTEGER(0));

    sqlres := SQLFreeStmt( hstmt, SQL_UNBIND);

    if (sqlres <> SQL_SUCCESS) and (sqlres<>SQL_INVALID_HANDLE) then
    begin
      for i := 0 to FieldDefs.Count - 1 do
        with TODBCFieldDef(FieldDefs[I]) do
          CheckSQLResult( SQLBindCol( hstmt, FieldNo, SqlDataType,
                                      nil, SQLSize, nil));
    end;
  end;

begin
  iNull := SQL_NULL_DATA;
  bNull := #0;
//  if CachedUpdates then
//  begin
//    AddToCacheBuffer(usModified, ActiveBuffer);
//    Exit;
//  end;

  case State of
    dsInsert:
    begin
      if (Length(FUpdateSQL[ukInsert].Text)=0)
         and(not FCursorAttr.UseInternalInsert)
      then raise Exception.Create( SmInsertNotSupported);

      if not FCursorAttr.UseInternalInsert then
      begin // use insertsql statement
        SetParamsForUpdateSQL(ukInsert);
        FQueries[ukInsert].ExecSql;
{$if defined(ALLOW_USES_DIALOGS)}
        i := FQueries[ukInsert].RowsAffected;
        if i <= 0 then ShowMessage( SmNoRowsAffected);
        if i > 1  then ShowMessage( SmMoreRowsAffected);
{$ifend}
      end else
      begin
         BindCurRecord;
         try
            CheckSQLResult( SQLBulkOperations( hstmt, SQL_ADD));
            // for ODBC 3.0 drivers bookmark setted for new record ... but not work ;)
         finally
            UnBindCurRecord;
         end;
         // if (FCursorAttr.Sensitivity and SQL_SS_ADDITIONS)=0
         //  then AddToCacheBuffer( usInserted, ActiveBuffer); in the future
      end;
    end;

    dsEdit:
    begin
      if (Length(FUpdateSQL[ukModify].Text)=0)
         and(not FCursorAttr.UseInternalUpdate)
      then raise Exception.Create( SmUpdateNotSupported);

      if not FCursorAttr.UseInternalUpdate then
      begin // use updatesql
         SetParamsForUpdateSQL(ukModify);
         FQueries[ukModify].ExecSql;
{$if defined(ALLOW_USES_DIALOGS)}
         i:=FQueries[ukModify].RowsAffected;
         if i<=0 then ShowMessage( SmNoRowsAffected);
         if i>1  then ShowMessage( SmMoreRowsAffected);
{$ifend}
      end else
      begin
         BindCurRecord;
         try
            CheckSQLResult( SQLSetPos( hstmt, 1, SQL_UPDATE, SQL_LOCK_NO_CHANGE ));
            //CheckSQLResult( SQLBulkOperations( hstmt, SQL_UPDATE_BY_BOOKMARK));
         finally
            UnBindCurRecord;
         end;
      end;

      if FoldBuffer <> nil then
        FreeRecordBuffer( FoldBuffer);

      FoldBuffer := nil;

      if (FCursorAttr.Sensitivity and SQL_SS_UPDATES) = 0 then
        AddToCacheBuffer( usModified, ActiveBuffer);
    end;
  end;
end;

procedure TmCustomQuery.InternalCancel;
begin
end;

procedure TmCustomQuery.InternalDelete;
{$if defined(ALLOW_USES_DIALOGS)}
var
  i:  LongInt;
{$ifend}
begin
  if Length(FUpdateSQL[ukDelete].Text) > 0 then
  begin // use updatesql
    SetParamsForUpdateSQL(ukDelete);
    FQueries[ukDelete].ExecSql;
{$if defined(ALLOW_USES_DIALOGS)}
    i:=FQueries[ukDelete].RowsAffected;
    if i <= 0 then ShowMessage( SmNoRowsAffected);
    if i > 1  then ShowMessage( SmMoreRowsAffected);
{$ifend}
    AddDeletedToList( ActiveBuffer);
  end else
  begin
    if (FCursorAttr.Attrib1 and SQL_CA1_POS_DELETE) <> 0 then
    begin
      CheckSQLResult( SQLSetPos( hstmt, 1, SQL_DELETE, SQL_LOCK_NO_CHANGE));
      if (FCursorAttr.Sensitivity and SQL_SS_DELETIONS) = 0 then
        AddDeletedToList( ActiveBuffer);
    end else
    begin
      raise Exception.Create( SmDeleteNotSupported);
    end;
  end;

end;

// BookMarks
procedure TmCustomQuery.GetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  Move( GetBookmarkPtr( Buffer)^, Data^, BookmarkSize);
end;

procedure TmCustomQuery.SetBookmarkData(Buffer: PChar; Data: Pointer);
begin
{   if CursorAttr.UseDriverBookMark
   then Move( Data^, getBookmarkPtr( Buffer)^, BookmarkSize)
   else} Move( Data^, getBookmarkPtr( Buffer)^, BookmarkSize);
end;

function TmCustomQuery.GetBookmarkFlag(Buffer: PChar): TBookmarkFlag;
begin
  Result := PODBCRecInfo(Buffer + FRecInfoOfs).BookmarkFlag;
end;

procedure TmCustomQuery.SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag);
begin
  PODBCRecInfo(Buffer + FRecInfoOfs).BookmarkFlag := Value;
end;

procedure TmCustomQuery.InternalGotoBookmark(Bookmark: Pointer);
var
  i: SQLINTEGER;
begin
  if UseCache then
  begin
    FCachedPos := PSQLINTEGER(BookMark)^;
    exit;
  end;
//  SQLUnBindColumns;
  if CursorAttr.UseDriverBookMark then
  begin
    CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_FETCH_BOOKMARK_PTR, SQLPOINTER(BookMark), SQL_IS_POINTER));
    try
       CheckSQLResult( SQLFetchScroll( hstmt, SQL_FETCH_BOOKMARK, 0));
    finally
       CheckSQLResult( SQLSetStmtAttr( hstmt, SQL_ATTR_FETCH_BOOKMARK_PTR, nil, SQL_IS_POINTER));
    end;
    exit;
  end;

  if not ((CursorAttr.Attrib1 and SQL_CA1_ABSOLUTE) > 0) then
    raise Exception.Create( SmErrAbsSetToRec);

  i := PSQLINTEGER(BookMark)^;
  if i < 0 then
    raise Exception.Create( SmUndefinedRecNo);

  CheckSQLResult( SQLFetchScroll( hstmt, SQL_FETCH_ABSOLUTE, i));
end;

procedure TmCustomQuery.QueryChanged(Sender: TObject);
var
  List: TmParams;
begin
  FText := SQL.Text;

  if (csLoading in ComponentState) then
  begin
    CreateParams( nil, PChar(Text));
    exit
  end;

  Close;
  UnPrepareCursor;
  //  StrDispose(SQLBinary);
  //  SQLBinary := nil;

  if ParamCheck or (csDesigning in ComponentState) then
  begin
    List := TmParams.Create;
    try
      CreateParams(List, PChar(Text));
(*
      // try to figure out if some of the params might be fields
      // in the datasource , in that case we can figure the datatype out !
      if assigned(datasource) then
      begin
        for i:=0 to list.Count-1 do 
        begin
           Fi:=datasource.DataSet.FindField(list.Items[i].name);
           // we get an exeption if there is no field by that name
           if Assigned(Fi) then 
               list.Items[i].DataType:=fi.DataType;
        end;
      end; 
*)
      List.AssignValues(FParams);
      FParams.Free;
      FParams := List;
    except
      List.Free;
    end;
  end;

  DataEvent(dePropertyChange, 0);
end;

procedure TmCustomQuery.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FDataBase) then
    FDataBase := nil;
{  if (Operation = opRemove) and (AComponent = FUpdateObject) then
    FUpdateObject := nil; }
end;

function TmCustomQuery.GetCursorName:String;
var
  curName: array [0..30] of Char;
  nl:      SQLSMALLINT;
begin
  CheckSQLResult( SQLGetCursorName( hstmt, curName, 30, @nl));
  Result:=StrPas( curNAme);
end;
{
function TmCustomQuery.GetRowsAffected: LongInt;
var
  rCount: SQLINTEGER;
begin
  CheckSQLResult( SQLRowCount( hstmt, rCount));
  Result:= rCount;
end;
}

function TmCustomQuery.GetRecNo: Integer;
var
  BufPtr: PChar;
begin
  CheckActive;
  if State = dsCalcFields
    then BufPtr := CalcBuffer
    else BufPtr := ActiveBuffer;

  Result := PODBCRecInfo(BufPtr + FRecInfoOfs).RecordNumber;
end;

procedure TmCustomQuery.RefreshParams;
var
  DataSet: TDataSet;
begin
  DisableControls;
  try
    if (FDataLink.DataSource <> nil)
       and(not (csDesigning in ComponentState)) then
    begin
      DataSet := FDataLink.DataSource.DataSet;
      if DataSet <> nil then
        if DataSet.Active and (DataSet.State <> dsSetKey) then
        begin
          Close;
          Open;
        end;
    end;
  finally
    EnableControls;
  end;
end;

procedure TmCustomQuery.SetParamsFromCursor;
var
  I: Integer;
  DataSet: TDataSet;
begin
  if FDataLink.DataSource <> nil then
  begin
    DataSet := FDataLink.DataSource.DataSet;
    if DataSet <> nil then
    begin
      DataSet.FieldDefs.Update;
      for I := 0 to FParams.Count - 1 do
      begin
        with FParams[I] do
          if not Bound then
          begin
            if DataSet.Active
              then AssignField(DataSet.FieldByName(Name))
              else DataType:=DataSet.FieldDefs.Find(Name).DataType;
            Bound := False;
          end;
      end;
    end;
  end;
end;

procedure TmCustomQuery.SetCachedUpdates(Value: Boolean);
begin
  if (State = dsInActive) or (csDesigning in ComponentState) then
    FCachedUpdates := Value
  else
    raise Exception.Create('Can''t change CachedUpdates property' );
end;

procedure TmCustomQuery.ApplyUpdates;
begin
end;

procedure TmCustomQuery.CommitUpdates;
begin
end;

procedure TmCustomQuery.CancelUpdates;
begin
end;

procedure TmCustomQuery.SetCursorType(Value: TmCursorTypes);
begin
  if Value <> FCursorType then
  begin
    CheckInactive;
    FCursorType:=Value;
  end;
end;

function TmCustomQuery.ParamByName(const Value: string): TmParam;
begin
  Result := FParams.ParamByName(Value);
end;

// Blobs

function TmCustomQuery.GetBlobData(Field: TField; Buffer: PChar): TmBlobData;
begin
  Result := PmBlobDataArray(Buffer + FBlobCacheOfs)[Field.Offset];
end;

procedure TmCustomQuery.SetBlobData(Field: TField; Buffer: PChar; Value: TmBlobData);
begin
  if Buffer = ActiveBuffer then
    PmBlobDataArray(Buffer + FBlobCacheOfs)[Field.Offset] := Value;
end;

function TmCustomQuery.CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream;
begin
  Result := TmBlobStream.Create(Field as TBlobField, Mode);
end;

function TmCustomQuery.LocateRecord(const KeyFields: string;
           const KeyValues:Variant; Options: TLocateOptions): Boolean;
var
  SearchFields: TList;
  I: Integer;
  Match: boolean;

  function MatchVariants( FieldType:TFieldType; fieldvalue,keyvalue:Variant;
        CaseInSensitive:boolean; PartialKey:boolean):boolean;
  var
    s1,s2:string;
  begin
    if fieldType=ftString then
    begin
      if VarIsNull(fieldvalue) then S1:='' else S1:=fieldvalue;
      if VarIsNull(keyvalue) then S2:='' else S2:=keyvalue;
      if CaseInSensitive then
      begin
        S1 := AnsiUpperCase( S1);
        S2 := AnsiUpperCase( S2);
      end;
      if PartialKey
        then result := AnsiCompareStr(Copy(S1,1,length(S2)),S2) = 0
        else result := AnsiCompareStr(S1, S2) = 0;
    end else
    begin
       result := (fieldvalue=keyvalue);
    end;
  end;

begin
  CheckBrowseMode;
  CursorPosChanged;

  Result := False;
  SearchFields := TList.Create;
  try
    GetFieldList(SearchFields, KeyFields);
    InternalFirst;
    while (GetRecord( TempBuffer, gmNext, True) = grOK) do
    begin
      if Searchfields.Count=1 then
      begin
        match := MatchVariants(
                   TField(SearchFields[0]).DataType,
                   GetFieldValue( TempBuffer, FieldByName(TField(SearchFields[0]).FieldName)),
                   KeyValues,
                   (loCaseInsensitive in Options),
                   (loPartialKey in Options));
      end else
      begin
        match := true;
        for i := 0 to Searchfields.Count-1 do
        begin
          match := match and
                   MatchVariants(
                     TField(SearchFields[i]).DataType,
                     GetFieldValue( TempBuffer, FieldByName(TField(SearchFields[i]).FieldName)),
                     KeyValues[i],
                     (loCaseInsensitive in Options),
                     (loPartialKey in Options));
        end;
      end;

      if match then
      begin
        Result:=True;
        break;
      end;
    end;
  finally
    SearchFields.Free;
  end;
end;

function TmCustomQuery.Locate(const KeyFields: string;
           const KeyValues:Variant; Options: TLocateOptions): Boolean;
begin
   DoBeforeScroll;
   Result := LocateRecord(KeyFields, KeyValues,Options);
   if Result then
   begin
      Resync([rmExact, rmCenter]);
      DoAfterScroll;
   end;
end;


function TmCustomQuery.Lookup(const KeyFields: string; const KeyValues: Variant;
      const ResultFields: string): Variant;
begin
  Result := Null;
  if LocateRecord(KeyFields, KeyValues, []) then
  begin
    SetTempState(dsCalcFields);
    try
      CalculateFields(TempBuffer);
      Result := FieldValues[ResultFields];
    finally
      RestoreState(dsBrowse);
    end;
  end;
end;

function TmCustomQuery.CheckFilter( Buffer: PChar):boolean;
var
  SaveState: TDataSetState;
begin
  Result:=True;
  if not Assigned( FonFilter) then
    exit;
  SaveState := SetTempState(dsFilter);
  try
    FFilterBuffer := Buffer;
    FonFilter( Self, Result);
  finally
    RestoreState(SaveState);
  end;
end;

{ TmBlobStream }

constructor TmBlobStream.Create(Field: TBlobField; Mode: TBlobStreamMode);
begin
  FMode    := Mode;
  FField   := Field;
  FDataSet := FField.DataSet as TmCustomQuery;
  FFieldNo := FField.FieldNo;
  if not FDataSet.GetActiveRecBuf(FBuffer) then
    Exit;
{  if not FField.Modified then
  begin
    if Mode = bmRead then
    begin
      FCached := FDataSet.FCacheBlobs and (FBuffer = FDataSet.ActiveBuffer) and
        (FField.IsNull or (FDataSet.GetBlobData(FField, FBuffer) <> ''));
    end else
    begin
      FDataSet.SetBlobData(FField, FBuffer, '');
      if FField.ReadOnly then DatabaseErrorFmt(SFieldReadOnly, [FField.DisplayName]);
      if not (FDataSet.State in [dsEdit, dsInsert]) then DatabaseError(SNotEditing);
    end;
  end;  }
  FOpened := True;
  if Mode = bmWrite then Truncate;
end;

destructor TmBlobStream.Destroy;
begin
  if FOpened then
  begin
    if FModified then FField.Modified := True;
  end;
  if FModified then
  try
    FDataSet.DataEvent(deFieldChange, Longint(FField));
  except
{$if defined(ALLOW_USES_FORMS)}
    Application.HandleException(Self);
{$ifend}
  end;
end;

function TmBlobStream.Read(var Buffer; Count: Longint): Longint;
Var BlobSize: LongInt;
begin
  Result := 0;
  if FOpened then
  begin
    BlobSize := Length(FDataSet.GetBlobData(FField, FBuffer));//Size;
    if Count > BlobSize - FPosition
      then Result := BlobSize - FPosition
      else Result := Count;

    if Result > 0 then
    begin
      Move(PChar(FDataSet.GetBlobData(FField, FBuffer))[FPosition], Buffer, Result);
      Inc(FPosition, Result);
    end;
  end;
end;

function TmBlobStream.Write(const Buffer; Count: Longint): Longint;
var
//  Temp: Pointer;
  c:    AnsiString;
begin
  Result := 0;
  if FOpened then
  begin
{    if FField.Transliterate then
    begin
      GetMem(Temp, Count);
      c:= FDataSet.GetBlobData(FField, FBuffer);
      FDataSet.SetBlobData(FField, FBuffer, '');
      try
         SetLength( c, FPosition+Count);
         Move( Buffer, PChar(c)[FPosition], Count);
         FDataSet.SetBlobData(FField, FBuffer, c);

//         SetLength( PmBlobDataArray( FBuffer + DataSet.FBlobCacheOfs)[FField.Offset], FPosition+Count);
//         Move( Buffer, PChar(PmBlobDataArray( FBuffer + FBlobCacheOfs)[FField.Offset])[FPosition], Count);
//        AnsiToNativeBuf(FDataSet.Locale, @Buffer, Temp, Count);
//        Check(DbiPutBlob(FDataSet.Handle, FBuffer, FFieldNo, FPosition,
//          Count, Temp));
      finally
        FreeMem(Temp, Count);
      end;
    end else
//      Check(DbiPutBlob(FDataSet.Handle, FBuffer, FFieldNo, FPosition,
//        Count, @Buffer)); }
     c := FDataSet.GetBlobData(FField, FBuffer);
//      FDataSet.SetBlobData(FField, FBuffer, '');
     SetLength( c, FPosition+Count);
     Move( Buffer, c[FPosition+1], Count);
     FDataSet.SetBlobData(FField, FBuffer, c);

     Inc(FPosition, Count);
     Result := Count;
     FModified := True;
//    FDataSet.SetBlobData(FField, FBuffer, '');
  end;
end;

function TmBlobStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  case Origin of
    0: FPosition := Offset;
    1: Inc(FPosition, Offset);
    2: FPosition := GetBlobSize + Offset;
  end;
  Result := FPosition;
end;

procedure TmBlobStream.Truncate;
begin
  if FOpened then
  begin
    FModified := True;
    FDataSet.SetBlobData(FField, FBuffer, '');
  end;
end;

function TmBlobStream.GetBlobSize: Longint;
begin
   Result := 0;
   if FOpened then
   begin
      Result := Length(FDataSet.GetBlobData(FField, FBuffer));
   end;
end;

end.
