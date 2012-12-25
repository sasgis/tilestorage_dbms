unit t_TSS;

interface

uses
  Windows,
  SysUtils,
  t_ETS_Tiles,
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
    // ETS_INTERNAL_TSS_CODE
    CodeSource: String;
  end;

  TTSSMode = (tssm_Off, tssm_On, tssm_Inversion);

  PTSS_Info = ^TTSS_Info;
  TTSS_Info = record
    // ETS_INTERNAL_TSS_DEST
    DestValue: String;
    // ETS_INTERNAL_TSS_AREA
    // ETS_INTERNAL_TSS_ZOOM
    AreaValue: ITileArea;
    // ETS_INTERNAL_TSS_FULL
    FullValue: IZoomList;
    // ETS_INTERNAL_TSS_MODE
    ModeValue: TTSSMode;
    // ETS_INTERNAL_TSS_CODE
    CodeValue: LongInt;
  public
    procedure Clear;
    function ApplyDefinition(const ADefinition: TTSS_Definition): Boolean;
    function TileInSection(
      const AZoom: Byte;
      const AXYPtr: PPoint
    ): Boolean;
  end;

  PTSS_Primary_Params = ^TTSS_Primary_Params;
  TTSS_Primary_Params = record
    HasWithoutCode: Boolean;
    ProcedureNew: String;
  end;

const
  c_TSSMode_Default = tssm_On;

implementation

{ TTSS_Info }

function TTSS_Info.ApplyDefinition(const ADefinition: TTSS_Definition): Boolean;
var VPos: Integer;
begin
  // ETS_INTERNAL_TSS_DEST
  DestValue := ADefinition.DestSource;

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

  // ETS_INTERNAL_TSS_CODE
  if not TryStrToInt(ADefinition.CodeSource, CodeValue) then
    CodeValue := 0;

  // некий результат (поправить чтобы был смысл его возвращать)
  Result := (AreaValue<>nil) or (FullValue<>nil);
end;

procedure TTSS_Info.Clear;
begin
  AreaValue := nil;
  FullValue := nil;
end;

function TTSS_Info.TileInSection(
  const AZoom: Byte;
  const AXYPtr: PPoint
): Boolean;
begin
  Result := FALSE;
  
  // может секция отключена
  if (tssm_Off=ModeValue) then
    Exit;

  if (FullValue<>nil) then begin
    // некоторые зумы залетают целиком
    if FullValue.ZoomInList(AZoom) then begin
      // подходит - значит TRUE (если инверсия - FALSE)
      Result := (tssm_Inversion<>ModeValue);
      Exit;
    end;
  end;

  if (AreaValue<>nil) then begin
    // может быть попали в область секции
    if AreaValue.TileInArea(AZoom, AXYPtr) then begin
      // подходит - значит TRUE (если инверсия - FALSE)
      Result := (tssm_Inversion<>ModeValue);
      Exit;
    end;
  end;

  // никуда не попали
  Result := (tssm_Inversion=ModeValue);
end;

end.
