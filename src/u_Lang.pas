unit u_Lang;

interface

uses
  Windows;

{$if CompilerVersion<=18.5}
//http://stackoverflow.com/questions/7630781/delphi-2007-and-xe2-using-nativeint
type
  NativeInt = Integer;
  NativeUInt = Cardinal;
{$ifend}
(*
function GetContentLanguage(const ALanguage: LANGID): AnsiString;
function GetCharsetFromCodepage(const ACodePage: Word): AnsiString;

function ALMimeBase64EncodeStringNoCRLF(const S: AnsiString): AnsiString;
function ALMimeBase64EncodedSizeNoCRLF(const InputSize: NativeInt): NativeInt;
procedure ALMimeBase64EncodeNoCRLF(const InputBuffer; const InputByteCount: NativeInt; out OutputBuffer);

function ALDateTimeToRfc822Str_Now: AnsiString;
*)
function HTTPDecode(const AStr: String): String;

implementation

uses
  SysUtils;
(*
function GetContentLanguage(const ALanguage: LANGID): AnsiString;
var VPrimLang: Word;
begin
  VPrimLang := (ALanguage and 1023);
  case VPrimLang of
    LANG_AFRIKAANS: begin
      Result := 'af';
    end;
    LANG_ALBANIAN: begin
      Result := 'sq';
    end;
    LANG_ARABIC: begin
      Result := 'ar';
    end;
    LANG_BASQUE: begin
      Result := 'eu';
    end;
    LANG_BELARUSIAN: begin
      Result := 'be';
    end;
    LANG_BULGARIAN: begin
      Result := 'bg';
    end;
    LANG_CATALAN: begin
      Result := 'ca';
    end;
    LANG_CHINESE: begin
      Result := 'zh';
    end;
    LANG_CROATIAN: begin
      // LANG_BOSNIAN
      // 0x781a Bosnian (bs)
      // 0x201a Bosnian (bs)
      // 0x141a
      
      // LANG_CROATIAN
      // 0x041a Croatian (hr)  
      // 0x101a Croatian (hr)
      // 0x041a

      // LANG_SERBIAN
      // 0x7c1a Serbian (sr)
      // 0x181a
      // 0x0c1a
      // 0x081a
      Result := 'sr, hr, bs';
    end;
    LANG_CZECH: begin
      Result := 'cs';
    end;
    LANG_DANISH: begin
      Result := 'da';
    end;
    LANG_DUTCH: begin
      Result := 'nl';
    end;
    LANG_ENGLISH: begin
      Result := 'en';
    end;
    LANG_ESTONIAN: begin
      Result := 'et';
    end;
    LANG_FAEROESE: begin
      Result := 'fo';
    end;
    LANG_FARSI: begin
      Result := 'fa';
    end;
    LANG_FINNISH: begin
      Result := 'fi';
    end;
    LANG_FRENCH: begin
      Result := 'fr';
    end;
    LANG_GERMAN: begin
      Result := 'de';
    end;
    LANG_GREEK: begin
      Result := 'el';
    end;
    LANG_HEBREW: begin
      Result := 'he';
    end;
    LANG_HUNGARIAN: begin
      Result := 'hu';
    end;
    LANG_ICELANDIC: begin
      Result := 'is';
    end;
    LANG_INDONESIAN: begin
      Result := 'id';
    end;
    LANG_ITALIAN: begin
      Result := 'it';
    end;
    LANG_JAPANESE: begin
      Result := 'ja';
    end;
    LANG_KOREAN: begin
      Result := 'ko';
    end;
    LANG_LATVIAN: begin
      Result := 'lv';
    end;
    LANG_LITHUANIAN: begin
      Result := 'lt';
    end;
    LANG_NORWEGIAN: begin
      Result := 'no';
    end;
    LANG_POLISH: begin
      Result := 'pl';
    end;
    LANG_PORTUGUESE: begin
      Result := 'pt';
    end;
    LANG_ROMANIAN: begin
      Result := 'ro';
    end;
    LANG_RUSSIAN: begin
      Result := 'ru';
    end;
    LANG_SLOVAK: begin
      Result := 'sk';
    end;
    LANG_SLOVENIAN: begin
      Result := 'sl';
    end;
    LANG_SPANISH: begin
      Result := 'es';
    end;
    LANG_SWEDISH: begin
      Result := 'sv';
    end;
    LANG_THAI: begin
      Result := 'th';
    end;
    LANG_TURKISH: begin
      Result := 'tr';
    end;
    LANG_UKRAINIAN: begin
      Result := 'uk';
    end;
    LANG_VIETNAMESE: begin
      Result := 'vi';
    end;
    else begin
      // not defined in windows
      case ALanguage of
        $0843: begin
          Result := 'uz'; // Uzbek
        end;
        $0485: begin
          Result := 'sah'; // Yakut
        end;
        $0452: begin
          Result := 'cy'; // Welsh
        end;
        $0442: begin
          Result := 'tk'; // Turkmen
        end;
        $0444: begin
          Result := 'tt'; // Tatar
        end;
        $0428: begin
          Result := 'tg'; // Tajik
        end;
        $045a: begin
          Result := 'syr'; // Syriac
        end;
        $0441: begin
          Result := 'sw'; // Swahili
        end;
        $0450: begin
          Result := 'mn'; // Mongolian
        end;
        $0454: begin
          Result := 'lo'; // Lao
        end;
        $0440: begin
          Result := 'ky'; // Kyrgyz
        end;
        $043f: begin
          Result := 'kk'; // Kazakh
        end;
        $0437: begin
          Result := 'ka'; // Georgian
        end;
        $046d: begin
          Result := 'ba'; // Bashkir
        end;
        $082c: begin
          Result := 'az'; // Azeri
        end;
        $042b: begin
          Result := 'hy'; // Armenian
        end;
        $045e: begin
          Result := 'am'; // Amharic
        end;
        $0445: begin
          Result := 'bn'; // Bengali
        end;
        else begin
          Result := '';
        end;
      end;
    end;
  end;
end;

function GetCharsetFromCodepage(const ACodePage: Word): AnsiString;
begin
  case ACodePage of
    874,1250..1258: begin
      Result := 'windows-' + IntToStr(ACodePage);
    end;
    65000: begin
      Result := 'utf-7';
    end;
    65001: begin
      Result := 'utf-8';
    end;
    65005: begin
      Result := 'utf-32';
    end;
    65006: begin
      Result := 'utf-32be';
    end;
    28591..28605: begin
      Result := 'iso-8859-' + IntToStr(ACodePage-28590);
    end;
    37,1047,1140..1149: begin
      Result := 'ibm0' + IntToStr(ACodePage);
    end;
    858: begin
      Result := 'ibm00858';
    end;
    437,500,737,775,850,852,855,857,860,861,863,864,865,869,870,1026: begin
      Result := 'ibm' + IntToStr(ACodePage);
    end;
    708: begin
      Result := 'asmo-' + IntToStr(ACodePage);
    end;
    720,862: begin
      Result := 'dos-' + IntToStr(ACodePage);
    end;
    866,875: begin
      Result := 'cp' + IntToStr(ACodePage);
    end;
    932: begin
      Result := 'shift_jis';
    end;
    936: begin
      Result := 'gb2312';
    end;
    949: begin
      Result := 'ks_c_5601-1987';
    end;
    950: begin
      Result := 'big5';
    end;
    1200: begin
      Result := 'utf-16';
    end;
    1201: begin
      Result := 'unicodefffe';
    end;
    1361: begin
      Result := 'johab';
    end;
    20273..20424,20871,20880,20905: begin
      Result := 'ibm' + IntToStr(ACodePage-20000);
    end;
    20866: begin
      Result := 'koi8-r';
    end;
    21866: begin
      Result := 'koi8-u';
    end;
    21025: begin
      Result := 'cp1025';
    end;
    20001,20003,20004,20005,20261,20269,20936,20949,50227: begin
      Result := 'x-cp' + IntToStr(ACodePage);
    end;
    20924: begin
      Result := 'ibm00924';
    end;
    20932: begin
      Result := 'euc-jp';
    end;
    29001: begin
      Result := 'x-europa';
    end;
    38598: begin
      Result := 'iso-8859-8-i';
    end;
    50220: begin
      Result := 'iso-2022-jp';
    end;
    50221: begin
      Result := 'csiso2022jp';
    end;
    50222: begin
      Result := 'iso-2022-jp';
    end;
    50225: begin
      Result := 'iso-2022-kr';
    end;
    20127: begin
      Result := 'us-ascii';
    end;
    20833: begin
      Result := 'x-ebcdic-koreanextended';
    end;
    20838: begin
      Result := 'ibm-thai';
    end;
    20105: begin
      Result := 'x-ia5';
    end;
    20106: begin
      Result := 'x-ia5-german';
    end;
    20107: begin
      Result := 'x-ia5-swedish';
    end;
    20108: begin
      Result := 'x-ia5-norwegian';
    end;
    51932: begin
      Result := 'euc-jp';
    end;
    51936: begin
      Result := 'euc-cn';
    end;
    51949: begin
      Result := 'euc-kr';
    end;
    52936: begin
      Result := 'hz-gb-2312';
    end;
    54936: begin
      Result := 'gb18030';
    end;
    20000: begin
      Result := 'x-chinese-cns';
    end;
    20002: begin
      Result := 'x-chinese-eten';
    end;
    57002: begin
      Result := 'x-iscii-de';
    end;
    57003: begin
      Result := 'x-iscii-be';
    end;
    57004: begin
      Result := 'x-iscii-ta';
    end;
    57005: begin
      Result := 'x-iscii-te';
    end;
    57006: begin
      Result := 'x-iscii-as';
    end;
    57007: begin
      Result := 'x-iscii-or';
    end;
    57008: begin
      Result := 'x-iscii-ka';
    end;
    57009: begin
      Result := 'x-iscii-ma';
    end;
    57010: begin
      Result := 'x-iscii-gu';
    end;
    57011: begin
      Result := 'x-iscii-pa';
    end;
    10000: begin
      Result := 'macintosh';
    end;
    10001: begin
      Result := 'x-mac-japanese';
    end;
    10002: begin
      Result := 'x-mac-chinesetrad';
    end;
    10003: begin
      Result := 'x-mac-korean';
    end;
    10004: begin
      Result := 'x-mac-arabic';
    end;
    10005: begin
      Result := 'x-mac-hebrew';
    end;
    10006: begin
      Result := 'x-mac-greek';
    end;
    10007: begin
      Result := 'x-mac-cyrillic';
    end;
    10008: begin
      Result := 'x-mac-chinesesimp';
    end;
    10010: begin
      Result := 'x-mac-romanian';
    end;
    10017: begin
      Result := 'x-mac-ukrainian';
    end;
    10021: begin
      Result := 'x-mac-thai';
    end;
    10029: begin
      Result := 'x-mac-ce';
    end;
    10079: begin
      Result := 'x-mac-icelandic';
    end;
    10081: begin
      Result := 'x-mac-turkish';
    end;
    10082: begin
      Result := 'x-mac-croatian';
    end;
    else begin
      Result := '';
    end;
  end;
end;

function ALMimeBase64EncodeStringNoCRLF(const S: AnsiString): AnsiString;
var
  L: NativeInt;
begin
  if S <> '' then
  begin
    L := Length(S);
    SetLength(Result, ALMimeBase64EncodedSizeNoCRLF(L));
    ALMimeBase64EncodeNoCRLF(PAnsiChar(S)^, L, PAnsiChar(Result)^);
  end
  else
    Result := '';
end;

function ALMimeBase64EncodedSizeNoCRLF(const InputSize: NativeInt): NativeInt;
begin
  Result := (InputSize + 2) div 3 * 4;
end;

type
  PByte4 = ^TByte4;
  TByte4 = packed record
    B1: Byte;
    B2: Byte;
    B3: Byte;
    B4: Byte;
  end;

  PByte3 = ^TByte3;
  TByte3 = packed record
    B1: Byte;
    B2: Byte;
    B3: Byte;
  end;

const
  { The mime encoding table. Do not alter. }
  cALMimeBase64_ENCODE_TABLE: array [0..63] of Byte = (
    065, 066, 067, 068, 069, 070, 071, 072, //  00 - 07
    073, 074, 075, 076, 077, 078, 079, 080, //  08 - 15
    081, 082, 083, 084, 085, 086, 087, 088, //  16 - 23
    089, 090, 097, 098, 099, 100, 101, 102, //  24 - 31
    103, 104, 105, 106, 107, 108, 109, 110, //  32 - 39
    111, 112, 113, 114, 115, 116, 117, 118, //  40 - 47
    119, 120, 121, 122, 048, 049, 050, 051, //  48 - 55
    052, 053, 054, 055, 056, 057, 043, 047); // 56 - 63

  cALMimeBase64_PAD_CHAR = Byte('=');

  cALMimeBase64_DECODE_TABLE: array [Byte] of Byte = (
    255, 255, 255, 255, 255, 255, 255, 255, //   0 -   7
    255, 255, 255, 255, 255, 255, 255, 255, //   8 -  15
    255, 255, 255, 255, 255, 255, 255, 255, //  16 -  23
    255, 255, 255, 255, 255, 255, 255, 255, //  24 -  31
    255, 255, 255, 255, 255, 255, 255, 255, //  32 -  39
    255, 255, 255, 062, 255, 255, 255, 063, //  40 -  47
    052, 053, 054, 055, 056, 057, 058, 059, //  48 -  55
    060, 061, 255, 255, 255, 255, 255, 255, //  56 -  63
    255, 000, 001, 002, 003, 004, 005, 006, //  64 -  71
    007, 008, 009, 010, 011, 012, 013, 014, //  72 -  79
    015, 016, 017, 018, 019, 020, 021, 022, //  80 -  87
    023, 024, 025, 255, 255, 255, 255, 255, //  88 -  95
    255, 026, 027, 028, 029, 030, 031, 032, //  96 - 103
    033, 034, 035, 036, 037, 038, 039, 040, // 104 - 111
    041, 042, 043, 044, 045, 046, 047, 048, // 112 - 119
    049, 050, 051, 255, 255, 255, 255, 255, // 120 - 127
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255);

procedure ALMimeBase64EncodeNoCRLF(const InputBuffer; const InputByteCount: NativeInt; out OutputBuffer);
var
  B: Cardinal;
  InnerLimit, OuterLimit: NativeInt;
  InPtr: PByte3;
  OutPtr: PByte4;
begin
  if InputByteCount = 0 then
    Exit;

  InPtr := @InputBuffer;
  OutPtr := @OutputBuffer;

  OuterLimit := InputByteCount div 3 * 3;

  InnerLimit := NativeUint(InPtr);
  Inc(InnerLimit, OuterLimit);

  { Last line loop. }
  while NativeUint(InPtr) < NativeUint(InnerLimit) do
  begin
    { Read 3 bytes from InputBuffer. }
    B := InPtr^.B1;
    B := B shl 8;
    B := B or InPtr^.B2;
    B := B shl 8;
    B := B or InPtr^.B3;
    Inc(InPtr);
    { Write 4 bytes to OutputBuffer (in reverse order). }
    OutPtr^.B4 := cALMimeBase64_ENCODE_TABLE[B and $3F];
    B := B shr 6;
    OutPtr^.B3 := cALMimeBase64_ENCODE_TABLE[B and $3F];
    B := B shr 6;
    OutPtr^.B2 := cALMimeBase64_ENCODE_TABLE[B and $3F];
    B := B shr 6;
    OutPtr^.B1 := cALMimeBase64_ENCODE_TABLE[B];
    Inc(OutPtr);
  end;

  { End of data & padding. }
  case InputByteCount - OuterLimit of
    1:
      begin
        B := InPtr^.B1;
        B := B shl 4;
        OutPtr.B2 := cALMimeBase64_ENCODE_TABLE[B and $3F];
        B := B shr 6;
        OutPtr.B1 := cALMimeBase64_ENCODE_TABLE[B];
        OutPtr.B3 := cALMimeBase64_PAD_CHAR; { Pad remaining 2 bytes. }
        OutPtr.B4 := cALMimeBase64_PAD_CHAR;
      end;
    2:
      begin
        B := InPtr^.B1;
        B := B shl 8;
        B := B or InPtr^.B2;
        B := B shl 2;
        OutPtr.B3 := cALMimeBase64_ENCODE_TABLE[B and $3F];
        B := B shr 6;
        OutPtr.B2 := cALMimeBase64_ENCODE_TABLE[B and $3F];
        B := B shr 6;
        OutPtr.B1 := cALMimeBase64_ENCODE_TABLE[B];
        OutPtr.B4 := cALMimeBase64_PAD_CHAR; { Pad remaining byte. }
      end;
  end;
end;

const
  CAlRfc822DaysOfWeek: array[0..6] of AnsiString = ('Sun',
                                                    'Mon',
                                                    'Tue',
                                                    'Wed',
                                                    'Thu',
                                                    'Fri',
                                                    'Sat');

  CALRfc822MonthNames: array[1..12] of AnsiString = ('Jan',
                                                     'Feb',
                                                     'Mar',
                                                     'Apr',
                                                     'May',
                                                     'Jun',
                                                     'Jul',
                                                     'Aug',
                                                     'Sep',
                                                     'Oct',
                                                     'Nov',
                                                     'Dec');

function WordToStrLen(const AValue: Word; const ALen: SmallInt): AnsiString;
begin
  Result := IntToStr(AValue);
  while (Length(Result)<ALen) do begin
    Result := '0'+Result;
  end;
end;

function ALDateTimeToRfc822Str_Now: AnsiString;
var
  VSystemTime: TSystemTime;
begin
  GetSystemTime(VSystemTime);
  {aValue is a GMT TDateTime - result is "Sun, 06 Nov 1994 08:49:37 GMT"}
  Result := CAlRfc822DaysOfWeek[VSystemTime.wDayOfWeek] + ', ' +
            WordToStrLen(VSystemTime.wDay, 2) + ' ' +
            CAlRfc822MonthNames[VSystemTime.wMonth] + ' ' +
            WordToStrLen(VSystemTime.wYear, 4) + ' ' +
            WordToStrLen(VSystemTime.wHour, 2) + ':' +
            WordToStrLen(VSystemTime.wMinute, 2) + ':' +
            WordToStrLen(VSystemTime.wSecond, 2) + ' ' +
            'GMT';
end;
*)
resourcestring
  sErrorDecodingURLText = 'Error decoding URL style (%%XX) encoded string at position %d';
  sInvalidURLEncodedChar = 'Invalid URL encoded character (%s) at position %d';

function HTTPDecode(const AStr: String): String;
var
  Sp, Rp, Cp: PChar;
  S: String;
begin
  SetLength(Result, Length(AStr));
  Sp := PChar(AStr);
  Rp := PChar(Result);
  Cp := Sp;
  try
    while Sp^ <> #0 do
    begin
      case Sp^ of
        '+': Rp^ := ' ';
        '%': begin
               // Look for an escaped % (%%) or %<hex> encoded character
               Inc(Sp);
               if Sp^ = '%' then
                 Rp^ := '%'
               else
               begin
                 Cp := Sp;
                 Inc(Sp);
                 if (Cp^ <> #0) and (Sp^ <> #0) then
                 begin
                   S := '$' + Cp^ + Sp^;
                   Rp^ := Chr(StrToInt(S));
                 end
                 else
                   raise Exception.CreateFmt(sErrorDecodingURLText, [Cp - PChar(AStr)]);
               end;
             end;
      else
        Rp^ := Sp^;
      end;
      Inc(Rp);
      Inc(Sp);
    end;
  except
    on E:EConvertError do
      raise EConvertError.CreateFmt(sInvalidURLEncodedChar,
        ['%' + Cp^ + Sp^, Cp - PChar(AStr)])
  end;
  SetLength(Result, Rp - PChar(Result));
end;

end.
