unit t_TSS;

interface

uses
  Windows,
  SysUtils,
  i_ZoomList,
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

  // общий алгоритм секционирования
  TTSS_Algorithm = (tssal_None, tssal_Linked, tssal_Manual);

  // настройка использования конкретной секции
  // здесь по умолчанию самым первым должно быть Primary
  TTSS_Link_Type = (tsslt_Primary, tsslt_Secondary, tsslt_Destination);
  PTSS_Link_Type = ^TTSS_Link_Type;

  PTSS_Primary_Params = ^TTSS_Primary_Params;
  TTSS_Primary_Params = record
    // обший тип секционирования
    Algorithm: TTSS_Algorithm;
    // секция для справочников
    Guides_Link: TTSS_Link_Type;
    // секция для тайловых таблиц, которые не попали ни в одну из секций
    Undefined_Link: TTSS_Link_Type;
    // секция для исполнения процедуры при создании новой таблицы
    NewTileTable_Link: TTSS_Link_Type;
    NewTileTable_Proc: String;
    // есть хотя бы одна секция без кода (вспомогательное поле)
    HasSectionWithoutCode: Boolean;
  public
    // Если TRUE - используется только одна секция
    function UseSingleConn(const AAllowNewObjects: Boolean): Boolean;
    // устанавливает значение алгоритма
    procedure ApplyAlgorithmValue(const AParamValue: String);
    // устанавливает значение настройки секции
    procedure ApplyLinkValue(const AParamValue: String; const AValuePtr: PTSS_Link_Type);
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

{ TTSS_Primary_Params }

procedure TTSS_Primary_Params.ApplyAlgorithmValue(const AParamValue: String);
begin
  if SameText(AParamValue, 'Linked') then
    Algorithm := tssal_Linked
  else if SameText(AParamValue, 'Manual') then
    Algorithm := tssal_Manual
  else
    Algorithm := tssal_None;
end;

procedure TTSS_Primary_Params.ApplyLinkValue(const AParamValue: String; const AValuePtr: PTSS_Link_Type);
begin
  if SameText(AParamValue, 'Primary') then
    AValuePtr^ := tsslt_Primary
  else if SameText(AParamValue, 'Secondary') then
    AValuePtr^ := tsslt_Secondary
  else if (AValuePtr = @NewTileTable_Link) and SameText(AParamValue, 'Destination') then
    AValuePtr^ := tsslt_Destination
  else
    AValuePtr^ := tsslt_Primary;
end;

function TTSS_Primary_Params.UseSingleConn(const AAllowNewObjects: Boolean): Boolean;
begin
  Result := 
  // либо вообще не должно быть секционирования
  (tssal_None = Algorithm)
  OR
  // либо это только встроенное секционирование и нет секций без кодов
  // и не создаём новые таблицы
  ((tssal_Linked = Algorithm) and (not HasSectionWithoutCode) and (not AAllowNewObjects));
end;

end.
