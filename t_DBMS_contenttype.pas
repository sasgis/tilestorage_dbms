unit t_DBMS_contenttype;

{$include i_DBMS.inc}

interface

uses
  SysUtils;

type
  TContentTypeA = record
    id_contenttype: SmallInt;
    contenttype_text: AnsiString;
  end;
  PContentTypeA = ^TContentTypeA;

  TContentTypeFlag = (
    ctf_EmptyContentType
  );
  TContentTypeFlags = set of TContentTypeFlag;

  TContentTypeList = class(TObject)
  private
    FContentTypeFlags: TContentTypeFlags;
    FEmptyContentTypeIdContentType: SmallInt;
    FCount: SmallInt;
    FItemsA: array of TContentTypeA;

  public
    constructor Create;
    destructor Destroy; override;

    // set count of versions
    procedure SetCapacity(const ACapacity: LongInt);

    // clear all info
    procedure Clear;

    // add item from DB
    procedure AddItem(const ANewRec: PContentTypeA);

    // find item by id_contenttype
    function FindItemByIdContentType(
      const Aid_contenttype: SmallInt;
      const AContentTypeTextPtr: PPAnsiChar;
      out AContentTypeTextStr: AnsiString
    ): Boolean;

    // find item by contenttype_text as AnsiString
    function FindItemByAnsiContentTypeText(
      const AContentTypeTextAnsiPtr: PAnsiChar;
      out Aid_contenttype: SmallInt
    ): Boolean;

    // find item by contenttype_text as WideString
    function FindItemByWideContentTypeText(
      const AContentTypeTextWidePtr: PWideChar;
      out Aid_contenttype: SmallInt
    ): Boolean;

    function FindItemByAnsiValueInternal(
      const ASrcName: AnsiString;
      out Aid_contenttype: SmallInt
    ): Boolean;
    
    property ContentTypeFlags: TContentTypeFlags read FContentTypeFlags;
    property EmptyContentTypeIdContentType: SmallInt read FEmptyContentTypeIdContentType;
    property Count: SmallInt read FCount;
  end;


implementation

{ TContentTypeList }

procedure TContentTypeList.AddItem(const ANewRec: PContentTypeA);
var
  VCapacity: SmallInt;
begin
  // get capacity
  VCapacity := Length(FItemsA);

  // check if need to grow
  if (FCount>=VCapacity) then begin
    SetLength(FItemsA, (VCapacity+1));
  end;

  // save item to array
  FItemsA[FCount] := ANewRec^;
  Inc(FCount);
  
  // check flags
  with ANewRec^ do begin
    if (0=Length(contenttype_text)) then begin
      // has empty contenttype
      Include(FContentTypeFlags, ctf_EmptyContentType);
      FEmptyContentTypeIdContentType := id_contenttype;
    end;
  end;
end;

procedure TContentTypeList.Clear;
begin
  FContentTypeFlags := [];
  FEmptyContentTypeIdContentType := 0;
  FCount := 0;
  SetLength(FItemsA, 0);
end;

constructor TContentTypeList.Create;
begin
  Clear;
end;

destructor TContentTypeList.Destroy;
begin
  Clear;
  inherited;
end;

function TContentTypeList.FindItemByAnsiContentTypeText(
  const AContentTypeTextAnsiPtr: PAnsiChar;
  out Aid_contenttype: SmallInt
): Boolean;
var
  VValueA: AnsiString;
begin
  // check for empty version
  if (ctf_EmptyContentType in FContentTypeFlags) and ((AContentTypeTextAnsiPtr=nil) or (AContentTypeTextAnsiPtr^=#0)) then begin
    Aid_contenttype := FEmptyContentTypeIdContentType;
    Result := TRUE;
    Exit;
  end;

  VValueA := AnsiString(AContentTypeTextAnsiPtr);
  Result := FindItemByAnsiValueInternal(VValueA, Aid_contenttype);
end;

function TContentTypeList.FindItemByAnsiValueInternal(
  const ASrcName: AnsiString;
  out Aid_contenttype: SmallInt
): Boolean;
var
  i: SmallInt;
begin
  if (FCount>0) then
  for i := 0 to FCount-1 do
  if SameText(ASrcName, FItemsA[i].contenttype_text) then begin
    // found
    Result := TRUE;
    Aid_contenttype := FItemsA[i].id_contenttype;
    Exit;
  end;

  // not found
  Result := FALSE;
end;

function TContentTypeList.FindItemByIdContentType(
  const Aid_contenttype: SmallInt;
  const AContentTypeTextPtr: PPAnsiChar;
  out AContentTypeTextStr: AnsiString
): Boolean;
var
  i: SmallInt;
begin
  // check for empty contenttype
  if (ctf_EmptyContentType in FContentTypeFlags) and (Aid_contenttype=FEmptyContentTypeIdContentType) then begin
    Result := TRUE;
    AContentTypeTextStr := '';
    if (nil<>AContentTypeTextPtr) then
      AContentTypeTextPtr^ := nil;
    Exit;
  end;

  if (FCount>0) then
  for i := 0 to FCount-1 do
  if (Aid_contenttype=FItemsA[i].id_contenttype) then begin
    // found
    Result := TRUE;
    AContentTypeTextStr := FItemsA[i].contenttype_text;
    if (nil<>AContentTypeTextPtr) then
      AContentTypeTextPtr^ := PAnsiChar(FItemsA[i].contenttype_text);
    Exit;
  end;

  // not found
  Result := FALSE;
  AContentTypeTextStr := '';
  if (nil<>AContentTypeTextPtr) then
    AContentTypeTextPtr^ := nil;
end;

function TContentTypeList.FindItemByWideContentTypeText(
  const AContentTypeTextWidePtr: PWideChar;
  out Aid_contenttype: SmallInt
): Boolean;
var
  VValueA: AnsiString;
  VValueW: WideString;
begin
  // check for empty version
  if (ctf_EmptyContentType in FContentTypeFlags) and ((AContentTypeTextWidePtr=nil) or (AContentTypeTextWidePtr^=#0)) then begin
    Aid_contenttype := FEmptyContentTypeIdContentType;
    Result := TRUE;
    Exit;
  end;

  // version with value
  VValueW := WideString(AContentTypeTextWidePtr);
  VValueA := VValueW;
  Result := FindItemByAnsiValueInternal(VValueA, Aid_contenttype);
end;

procedure TContentTypeList.SetCapacity(const ACapacity: Integer);
begin
  if (ACapacity<FCount) then begin
    // truncate array
    FCount := ACapacity;
  end;

  SetLength(FItemsA, ACapacity);
end;

end.
