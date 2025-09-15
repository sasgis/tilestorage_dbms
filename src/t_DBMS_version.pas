unit t_DBMS_version;

{$include i_DBMS.inc}

interface

uses
  SysUtils;

type
  // base type
  TVersionAA = record
    id_ver: SmallInt;
    ver_value: AnsiString;
    ver_date: TDateTime;
    ver_number: LongInt;
    ver_comment: AnsiString;
  public
    procedure Clear;
  end;
  PVersionAA = ^TVersionAA;

  TVersionFlag = (
    vf_EmptyVersion,
    vf_VerValue_Is_IdVer,
    vf_VerValue_IsNot_IdVer,
    vf_VerValue_Is_VerNumber,
    vf_VerValue_IsNot_VerNumber
  );
  TVersionFlags = set of TVersionFlag;

  TVersionList = class(TObject)
  private
    FVersionFlags: TVersionFlags;
    FEmptyVersionIdVer: SmallInt;
    FCount: SmallInt;
    FItemsAA: array of TVersionAA;

  private
    function FindItemByAnsiValueInternal(
      const ASrcName: AnsiString;
      const AVerInfo: PVersionAA
    ): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    // set count of versions
    procedure SetCapacity(const ACapacity: LongInt);

    // clear all info
    procedure Clear;

    // add item from DB
    procedure AddItem(const ANewRec: PVersionAA);

    // find item by id_ver
    function FindItemByIdVer(
      const Aid_ver: SmallInt;
      const AVerValuePtr: PPAnsiChar;
      out AVerValueStr: AnsiString
    ): Boolean;

    function FindItemByAnsiValue(
      const ASrcName: PAnsiChar;
      const AVerInfo: PVersionAA
    ): Boolean;

    function FindItemByWideValue(
      const ASrcName: PWideChar;
      const AVerInfo: PVersionAA
    ): Boolean;

    function FindItemByIdVerInternal(
      const Aid_ver: SmallInt;
      const AVerInfo: PVersionAA
    ): Boolean;

    function FindItemByVersion(
      const ASrcName: String;
      const AVerInfo: PVersionAA
    ): Boolean;

    function GetItemByIndex(const AIndex: SmallInt): PVersionAA;

    property VersionFlags: TVersionFlags read FVersionFlags;
    property EmptyVersionIdVer: SmallInt read FEmptyVersionIdVer;
    property Count: SmallInt read FCount;
  end;

implementation

{ TVersionList }

procedure TVersionList.AddItem(const ANewRec: PVersionAA);
var
  VCapacity: SmallInt;
begin
  // get capacity
  VCapacity := Length(FItemsAA);

  // check if need to grow
  if (FCount>=VCapacity) then begin
    SetLength(FItemsAA, (VCapacity+1));
  end;

  // save item to array
  FItemsAA[FCount] := ANewRec^;
  Inc(FCount);
  
  // check flags
  with ANewRec^ do begin
    if (0=Length(ver_value)) then begin
      // has empty version
      Include(FVersionFlags, vf_EmptyVersion);
      FEmptyVersionIdVer := id_ver;
      // do not check int=str here!
    end else begin
      // check if id_ver=ver_value
      if (IntToStr(id_ver)=ver_value) then
        Include(FVersionFlags, vf_VerValue_Is_IdVer)
      else
        Include(FVersionFlags, vf_VerValue_IsNot_IdVer);
      // check if ver_number=ver_value
      if (IntToStr(ver_number)=ver_value) then
        Include(FVersionFlags, vf_VerValue_Is_VerNumber)
      else
        Include(FVersionFlags, vf_VerValue_IsNot_VerNumber);
    end;
  end;
end;

procedure TVersionList.Clear;
begin
  FVersionFlags := [];
  FEmptyVersionIdVer := 0;
  FCount := 0;
  SetLength(FItemsAA, 0);
end;

constructor TVersionList.Create;
begin
  inherited Create;
  Clear;
end;

destructor TVersionList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TVersionList.FindItemByAnsiValue(
  const ASrcName: PAnsiChar;
  const AVerInfo: PVersionAA
): Boolean;
var
  VValueA: AnsiString;
begin
  // check for empty version
  if (vf_EmptyVersion in FVersionFlags) and ((ASrcName=nil) or (ASrcName^=#0)) then begin
    Result := FindItemByIdVerInternal(FEmptyVersionIdVer, AVerInfo);
    Exit;
  end;

  // version with value
  VValueA := AnsiString(ASrcName);
  Result := FindItemByAnsiValueInternal(VValueA, AVerInfo);
end;

function TVersionList.FindItemByAnsiValueInternal(
  const ASrcName: AnsiString;
  const AVerInfo: PVersionAA
): Boolean;
var
  i: SmallInt;
begin
  if (FCount>0) then
  for i := 0 to FCount-1 do
  if SameText(ASrcName, FItemsAA[i].ver_value) then begin
    // found
    Result := TRUE;
    AVerInfo^ := FItemsAA[i];
    Exit;
  end;

  // not found
  Result := FALSE;
end;

function TVersionList.FindItemByIdVer(
  const Aid_ver: SmallInt;
  const AVerValuePtr: PPAnsiChar;
  out AVerValueStr: AnsiString
): Boolean;
var
  i: SmallInt;
begin
  // check for empty version
  if (vf_EmptyVersion in FVersionFlags) and (Aid_ver=FEmptyVersionIdVer) then begin
    Result := TRUE;
    AVerValueStr := '';
    if (nil<>AVerValuePtr) then
      AVerValuePtr^ := nil;
    Exit;
  end;

  if (FCount>0) then
  for i := 0 to FCount-1 do
  if (Aid_ver=FItemsAA[i].id_ver) then begin
    // found
    Result := TRUE;
    AVerValueStr := FItemsAA[i].ver_value;
    if (nil<>AVerValuePtr) then
      AVerValuePtr^ := PAnsiChar(FItemsAA[i].ver_value);
    Exit;
  end;

  // not found
  Result := FALSE;
  AVerValueStr := '';
  if (nil<>AVerValuePtr) then
    AVerValuePtr^ := nil;
end;

function TVersionList.FindItemByIdVerInternal(
  const Aid_ver: SmallInt;
  const AVerInfo: PVersionAA
): Boolean;
var
  i: SmallInt;
begin
  if (FCount>0) then
  for i := 0 to FCount-1 do
  if Aid_ver = FItemsAA[i].id_ver then begin
    // found
    Result := TRUE;
    AVerInfo^ := FItemsAA[i];
    Exit;
  end;

  // not found
  Result := FALSE;
end;

function TVersionList.FindItemByVersion(const ASrcName: String; const AVerInfo: PVersionAA): Boolean;
var
  i: SmallInt;
begin
  if (FCount>0) then
  for i := 0 to FCount-1 do
  if SameText(ASrcName, FItemsAA[i].ver_value) then begin
    // found
    Result := TRUE;
    if (AVerInfo<>nil) then begin
      AVerInfo^ := FItemsAA[i];
    end;
    Exit;
  end;

  // not found
  Result := FALSE;
end;

function TVersionList.FindItemByWideValue(
  const ASrcName: PWideChar;
  const AVerInfo: PVersionAA
): Boolean;
var
  VValueA: AnsiString;
  VValueW: WideString;
begin
  // check for empty version
  if (vf_EmptyVersion in FVersionFlags) and ((ASrcName=nil) or (ASrcName^=#0)) then begin
    Result := FindItemByIdVerInternal(FEmptyVersionIdVer, AVerInfo);
    Exit;
  end;

  // version with value
  VValueW := WideString(ASrcName);
  VValueA := VValueW;
  Result := FindItemByAnsiValueInternal(VValueA, AVerInfo);
end;

function TVersionList.GetItemByIndex(const AIndex: SmallInt): PVersionAA;
begin
  if (FCount>0) then
  if (AIndex>=0) then
  if (AIndex<FCount) then begin
    Result := @(FItemsAA[AIndex]);
    Exit;
  end;
  Result := nil;
end;

procedure TVersionList.SetCapacity(const ACapacity: Integer);
begin
  if (ACapacity<FCount) then begin
    // truncate array
    FCount := ACapacity;
  end;

  SetLength(FItemsAA, ACapacity);
end;

{ TVersionAA }

procedure TVersionAA.Clear;
begin
  id_ver:=0;
  ver_value:='';
  ver_date:=0;
  ver_number:=0;
  ver_comment:='';
end;

end.
