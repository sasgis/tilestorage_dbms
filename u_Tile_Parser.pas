unit u_Tile_Parser;

interface

{$include i_DBMS.inc}

uses
  Windows,
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_DBMS_version;

const
  // дата "большого взрыва" - для определения номера по дате версии и для версий без даты (кроме пустой версии!)
  c_ZeroVersionNumber_DateTime: TDateTime = 36526; // 36526 = '2000-01-01 00:00:00.00000'

  c_Tile_Parser_None            = 0;
  c_Tile_Parser_Exif_NMC_Unique = 1;
  c_Tile_Parser_Exif_NMC_Latest = 2;
  //c_Tile_Parser_Exif_GE         = 10;
  //c_Tile_Parser_Exif_DG_Catalog = 20;

function ParseFullyQualifiedDateTime(const ADateTimeValue: String; out AResult: TDateTime): Boolean;

function GetVersionNumberForDateTimeAsZeroDifference(const ADateTime: TDateTime): Integer;

function ParseExifForGE(
  const AExifBuffer: PByte;
  const AExifLength: LongWord;
  var ANeedFindVersion: Boolean;
  AParsedVersionPtr: PVersionAA
): Byte;

function ParseExifForNMC(
  const AExifBuffer: PByte;
  const AExifLength: LongWord;
  const ALookupSpecifiedVersion: Boolean;
  const AVersionForLookup: String;
  const AUseUniqueTileIdentifier: Boolean;
  var ANeedFindVersion: Boolean;
  AParsedVersionPtr: PVersionAA
): Byte;

function ExtractFromTag(
  const ASource, ATagBegin, ATagEnd: String;
  const AStartingPos: Integer;
  out AValue: String;
  out AEndOfTagPos: Integer
): Boolean;

implementation

uses
  StrUtils;

const
  c_digitalglobe_tileIdentifier_b = '<digitalglobe:tileIdentifier>';
  c_digitalglobe_tileIdentifier_e = '</digitalglobe:tileIdentifier>';

  c_digitalglobe_featureId_b = '<digitalglobe:featureId>';

  c_digitalglobe_FinishedFeature_e = '</digitalglobe:FinishedFeature>';

function ExtractFromTag(
  const ASource, ATagBegin, ATagEnd: String;
  const AStartingPos: Integer;
  out AValue: String;
  out AEndOfTagPos: Integer
): Boolean;
var
  VPos, VEnd: Integer;
begin
  VPos := PosEx(ATagBegin, ASource, AStartingPos);
  Result := (VPos>0);
  if Result then begin
    VEnd := PosEx(ATagEnd, ASource, VPos+Length(ATagBegin));
    Result := (VEnd>0);
    if Result then begin
      // extract
      AValue := System.Copy(ASource, VPos+Length(ATagBegin), VEnd-VPos-Length(ATagBegin));
      // set end of tag
      AEndOfTagPos := VEnd + (Length(ATagEnd));
    end;
  end;
end;

function GetVersionNumberForDateTimeAsZeroDifference(const ADateTime: TDateTime): Integer;
begin
  Result := Round((ADateTime-c_ZeroVersionNumber_DateTime)*86400);
end;

function IsFullyQualifiedDateTimeDelimiter(const ADelim: Char): Boolean; inline;
begin
  Result := (ADelim in ['-','_',' ',':']);
end;

function ParseFullyQualifiedDateTime(const ADateTimeValue: String; out AResult: TDateTime): Boolean;
var
  st: TSystemTime;
  p: Integer;
begin
  // значение типа 2011-05-25 08:09:57.696 для NMC
  // или типа 2011-08-25_18-15-38 для роскосмоса
  // доли секунд просто отбрасываем, не округляем

  // проверка формата
  Result := (19<=Length(ADateTimeValue));
  if Result then begin
    Result := IsFullyQualifiedDateTimeDelimiter(ADateTimeValue[5]) and
              IsFullyQualifiedDateTimeDelimiter(ADateTimeValue[8]) and
              IsFullyQualifiedDateTimeDelimiter(ADateTimeValue[11]) and
              IsFullyQualifiedDateTimeDelimiter(ADateTimeValue[14]) and
              IsFullyQualifiedDateTimeDelimiter(ADateTimeValue[17]);
  end;

  // парсим по очереди

  // year
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,1,4), p);
    if Result then
      st.wYear := p;
  end;
  // month
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,6,2), p);
    if Result then
      st.wMonth := p;
  end;
  // day
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,9,2), p);
    if Result then
      st.wDay := p;
  end;

  // hour
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,12,2), p);
    if Result then
      st.wHour := p;
  end;
  // minute
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,15,2), p);
    if Result then
      st.wMinute := p;
  end;
  // second
  if Result then begin
    Result := TryStrToInt(System.Copy(ADateTimeValue,18,2), p);
    if Result then
      st.wSecond := p;
  end;

  // окончаловка
  if Result then begin
    // others
    st.wMilliseconds := 0;
    // convert
    try
      AResult := SystemTimeToDateTime(st);
      // ok
    except
      Result := FALSE;
    end;
  end;
end;

procedure ParseLatestXMLtoVersion(
  const ASource: String;
  const ALookupSpecifiedVersion: Boolean;
  const AVersionForLookup: String;
  AFeatureVersionPtr: PVersionAA
);
var
  VLatestDate, VSingleDate: TDateTime;
  VExtractedValue: String;
  VEndOfTagPos: Integer;
  VComment: String;
begin
  (*
  даты берём из
  <digitalglobe:acquisitionDate>2011-05-25 08:09:57.696</digitalglobe:acquisitionDate>
  <digitalglobe:earliestAcquisitionDate>2011-05-25 08:09:55.0</digitalglobe:earliestAcquisitionDate>
  <digitalglobe:latestAcquisitionDate>2011-05-25 08:09:57.0</digitalglobe:latestAcquisitionDate>
  *)
  if ExtractFromTag(ASource, '<digitalglobe:latestAcquisitionDate>', '</digitalglobe:latestAcquisitionDate>', 1, VExtractedValue, VEndOfTagPos) then begin
    // есть latestAcquisitionDate
    if not ParseFullyQualifiedDateTime(VExtractedValue, VLatestDate) then
      VLatestDate := 0;
  end else begin
    VLatestDate := 0;
  end;

  if ExtractFromTag(ASource, '<digitalglobe:acquisitionDate>', '</digitalglobe:acquisitionDate>', 1, VExtractedValue, VEndOfTagPos) then begin
    // есть acquisitionDate
    if not ParseFullyQualifiedDateTime(VExtractedValue, VSingleDate) then
      VSingleDate := 0;
  end else begin
    VSingleDate := 0;
  end;

  // в VLatestDate сложим максимум
  if (VLatestDate<VSingleDate) then
    VLatestDate:=VSingleDate;
  
  if (VLatestDate>AFeatureVersionPtr^.ver_date) then begin
    // надо обновлять данные о версии, так как нашли более новую
    // featureId у нас тут с самого начала строки до первого тэга - его сунем в значение версии
    VEndOfTagPos := Pos('</digitalglobe:featureId>', ASource);
    if (VEndOfTagPos>0) then begin
      // ok
      VComment := System.Copy(ASource, 1, (VEndOfTagPos-1));
      // обрабатываем feature только если либо затребованная версия совпала, либо версии не было
      if (not ALookupSpecifiedVersion) or SameText(AVersionForLookup, VComment) then begin
        AFeatureVersionPtr^.ver_value  := VComment;
        AFeatureVersionPtr^.ver_date   := VLatestDate;
        AFeatureVersionPtr^.ver_number := GetVersionNumberForDateTimeAsZeroDifference(VLatestDate);

        // соберём комментарий к версии
        // что-то типа "Strip WV02 Pan Sharpened Natural Color 0.50 Meter country_coverage"
        VComment := '';
        // Strip
        // Mosaic Product
        if ExtractFromTag(ASource, '<digitalglobe:sourceUnit>', '</digitalglobe:sourceUnit>', 1, VExtractedValue, VEndOfTagPos) then
          VComment := VComment + ',' + VExtractedValue;
        // WV01
        // WV02
        if ExtractFromTag(ASource, '<digitalglobe:source>', '</digitalglobe:source>', 1, VExtractedValue, VEndOfTagPos) then
          VComment := VComment + ',' + VExtractedValue;
        // Pan Sharpened Natural Color
        // Panchromatic
        if ExtractFromTag(ASource, '<digitalglobe:productType>', '</digitalglobe:productType>', 1, VExtractedValue, VEndOfTagPos) then
          VComment := VComment + ',' + VExtractedValue;
        // 0.50 Meter
        if ExtractFromTag(ASource, '<digitalglobe:groundSampleDistance>', '</digitalglobe:groundSampleDistance>', 1, VExtractedValue, VEndOfTagPos) then begin
          VComment := VComment + ',' + VExtractedValue;
          if ExtractFromTag(ASource, '<digitalglobe:groundSampleDistanceUnit>', '</digitalglobe:groundSampleDistanceUnit>', 1, VExtractedValue, VEndOfTagPos) then
            VComment := VComment + ' ' + VExtractedValue;
        end;
        // country_coverage
        // metro
        if ExtractFromTag(ASource, '<digitalglobe:dataLayer>', '</digitalglobe:dataLayer>', 1, VExtractedValue, VEndOfTagPos) then
          VComment := VComment + ',' + VExtractedValue;
        // готово - удалим первую запятую
        System.Delete(VComment, 1, 1);
        AFeatureVersionPtr^.ver_comment := Trim(VComment);
      end;
    end;
  end;
end;

function ParseExifForGE(
  const AExifBuffer: PByte;
  const AExifLength: LongWord;
  var ANeedFindVersion: Boolean;
  AParsedVersionPtr: PVersionAA
): Byte;
var
  VText: String;
begin
  SetString(VText, PChar(AExifBuffer), AExifLength);
  if (0=Length(VText)) then begin
    Result := ETS_RESULT_INVALID_EXIF;
    Exit;
  end;

  Result := ETS_RESULT_OK;
end;

function ParseExifForNMC(
  const AExifBuffer: PByte;
  const AExifLength: LongWord;
  const ALookupSpecifiedVersion: Boolean;
  const AVersionForLookup: String;
  const AUseUniqueTileIdentifier: Boolean;
  var ANeedFindVersion: Boolean;
  AParsedVersionPtr: PVersionAA
): Byte;
var
  VXML, VUniqueTileIdentifier: String;
  VPos, VEndOfTagPos: Integer;
  VTagValue: String;
  VFeatureVersion: TVersionAA;
begin
  SetString(VXML, PChar(AExifBuffer), AExifLength);
  if (0=Length(VXML)) then begin
    Result := ETS_RESULT_INVALID_EXIF;
    Exit;
  end;

  // текст до digitalglobe:tileIdentifier нас не интересует в принципе
  VPos := System.Pos(c_digitalglobe_tileIdentifier_b, VXML);
  if (VPos>0) then begin
    System.Delete(VXML, 1, (VPos-1));
  end;

  VUniqueTileIdentifier := '';

  if AUseUniqueTileIdentifier then begin
    // уникальный идентификатор версии тайла сидит внутри
    // <digitalglobe:tileIdentifier>f3c948fe359237bfa0c0801f0aa91c8f</digitalglobe:tileIdentifier>
    // причём он может как совпадать с идентификатором feature, так и отличаться от них всех
    if not ExtractFromTag(VXML, c_digitalglobe_tileIdentifier_b, c_digitalglobe_tileIdentifier_e, 1, VTagValue, VEndOfTagPos) then begin
      // не смогли определить tileIdentifier
      Result := ETS_RESULT_INVALID_EXIF;
      Exit;
    end;
    // успешно определили tileIdentifier
    VUniqueTileIdentifier := VTagValue;
  end;


  // а теперь работаем по списку features
  // ищем самое последнее значение AcquisitionDate
  // если снаружи фильтруемся по конкретной версии - значит смотрим только её
  VFeatureVersion.Clear;
  VPos := 1;
  while ExtractFromTag(VXML, c_digitalglobe_featureId_b, c_digitalglobe_FinishedFeature_e, VPos, VTagValue, VEndOfTagPos) do begin
    // парсим кусок XML в версию
    // сразу же проверяем что дата более новая
    ParseLatestXMLtoVersion(
      VTagValue,
      ALookupSpecifiedVersion,
      AVersionForLookup,
      @VFeatureVersion
    );
    // next
    VPos := VEndOfTagPos;
  end;

  if (0=Length(VFeatureVersion.ver_value)) then begin
    // версии не нашлись вообще
    Result := ETS_RESULT_UNKNOWN_EXIF_VERSION;
    Exit;
  end;

  // если работаем по уникальному идентификатору версии тайла - пропихнём её
  if AUseUniqueTileIdentifier then begin
    VFeatureVersion.ver_value := VUniqueTileIdentifier;
  end;

  // если версия сменилась - надо искаться
  ANeedFindVersion := (not SameText(VFeatureVersion.ver_value, AParsedVersionPtr^.ver_value));
  // копируемся в выходную версию
  AParsedVersionPtr^ := VFeatureVersion;
  
  Result := ETS_RESULT_OK;
end;

end.
