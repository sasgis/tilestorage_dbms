unit t_TSS;

interface

uses
  Windows,
  SysUtils,
  u_ZoomList,
  u_TileArea;

type
  TTSS_Definition = record
    // ETS_INTERNAL_TSS_DEST
    DestSource: String;
    // ETS_INTERNAL_TSS_AREA
    AreaSource: String;
    // ETS_INTERNAL_TSS_ZOOM
    ZoomSource: String;
    // ETS_INTERNAL_TSS_FULL
    FullSource: String;
    // ETS_INTERNAL_TSS_MODE
    ModeSource: String;
    // ETS_INTERNAL_TSS_SYNC
    SyncSource: String;
  end;

  TTSSType = (tsst_Off, tsst_Section, tsst_DSN, tsst_Prefix);
  TTSSMode = (tssm_Off, tssm_On, tssm_Inversion);
  TTSSSync = (tsss_Off, tsss_On);

  PTSS_Info = ^TTSS_Info;
  TTSS_Info = record
    // ETS_INTERNAL_TSS_DEST
    DestType: TTSSType;
    DestValue: String;
    // ETS_INTERNAL_TSS_AREA
    // ETS_INTERNAL_TSS_ZOOM
    AreaValue: ITileArea;
    // ETS_INTERNAL_TSS_FULL
    FullValue: IZoomList;
    // ETS_INTERNAL_TSS_MODE
    ModeValue: TTSSMode;
    // ETS_INTERNAL_TSS_SYNC
    SyncValue: TTSSSync;
  public
    procedure Clear;
    function ApplyDefinition(const ADefinition: TTSS_Definition): Boolean;
  end;

const
  c_TSSMode_Default = tssm_On;
  c_TSSSync_Default = tsss_Off;

implementation

const
  c_TSSType_Section = 'Section';
  c_TSSType_DSN     = 'DSN';
  c_TSSType_Prefix  = 'Prefix';

function StringToTSSType(const ASource: String): TTSSType;
begin
  if SameText(ASource, c_TSSType_Section) then
    Result := tsst_Section
  else if SameText(ASource, c_TSSType_DSN) then
    Result := tsst_DSN
  else if SameText(ASource, c_TSSType_Prefix) then
    Result := tsst_Prefix
  else
    Result := tsst_Off;
end;

{ TTSS_Info }

function TTSS_Info.ApplyDefinition(const ADefinition: TTSS_Definition): Boolean;
var VPos: Integer;
begin
  Result := FALSE;
  
  // ETS_INTERNAL_TSS_DEST
  VPos := System.Pos(':', ADefinition.DestSource);
  if (VPos>0) then begin
    // есть префикс - делим
    DestType  := StringToTSSType(System.Copy(ADefinition.DestSource, 1, (VPos-1)));
    if (tsst_Off=DestType) then
      Exit;
    DestValue := System.Copy(ADefinition.DestSource, (VPos+1), Length(ADefinition.DestSource));
  end else begin
    // префикс не указан
    Exit;
  end;

  // ETS_INTERNAL_TSS_AREA
  // ETS_INTERNAL_TSS_ZOOM
  AreaValue := TTileArea.Create(ADefinition.AreaSource, ADefinition.ZoomSource);
  if not AreaValue.Available then
    AreaValue := nil;

  // ETS_INTERNAL_TSS_FULL
  FullValue := TZoomList.Create(ADefinition.FullSource);
  if not FullValue.Available then
    FullValue := nil;

  // ETS_INTERNAL_TSS_MODE
  if TryStrToInt(ADefinition.ModeSource, VPos) and (VPos >= 0) and (VPos <= Ord(High(TTSSMode))) then
    ModeValue := TTSSMode(Ord(LoByte(VPos)))
  else
    ModeValue := c_TSSMode_Default;

  // ETS_INTERNAL_TSS_SYNC
  if TryStrToInt(ADefinition.SyncSource, VPos) and (VPos >= 0) and (VPos <= Ord(High(TTSSSync))) then
    SyncValue := TTSSSync(Ord(LoByte(VPos)))
  else
    SyncValue := c_TSSSync_Default;

  // некий результат (поправить чтобы был смысл его возвращать)
  Result := (AreaValue<>nil) or (FullValue<>nil);
end;

procedure TTSS_Info.Clear;
begin
  AreaValue := nil;
  FullValue := nil;
end;

end.
