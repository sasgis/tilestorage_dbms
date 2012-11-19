unit u_DBMS_Utils;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  t_types;

function AnsiStrToDB(const S: AnsiString): AnsiString;
function WideStrToDB(const S: WideString): WideString;

function DBMSStrToDB(const S: TDBMS_String): TDBMS_String; inline;

function GetModuleFileNameWithoutExt(
  const AInSqlSubFolder: Boolean;
  const APrefixBefore: String;
  const ATailAfterDot: String
): String;

function NowUTC: TDateTime;

implementation

uses
  t_DBMS_Template;

function AnsiStrToDB(const S: AnsiString): AnsiString;
begin
  Result := QuotedStr(S);
end;

function WideStrToDB(const S: WideString): WideString;
var
  I: Integer;
begin
  Result := S;
  for I := Length(Result) downto 1 do
    if Result[I] = '''' then Insert('''', Result, I);
  Result := '''' + Result + '''';
end;

function DBMSStrToDB(const S: TDBMS_String): TDBMS_String; inline;
begin
{$if defined(ETS_USE_ZEOS)}
  Result := QuotedStr(S);
{$else}
  Result := WideStrToDB(S);
{$ifend}
end;

function GetModuleFileNameWithoutExt(
  const AInSqlSubFolder: Boolean;
  const APrefixBefore: String;
  const ATailAfterDot: String
): String;
begin
  Result := GetModuleName(HInstance);
  Result := ExtractFileName(Result);
  Result := ChangeFileExt(Result,'');
  if (0<Length(ATailAfterDot)) then begin
    Result := Result + '.' + ATailAfterDot;
  end;
  if (0<Length(APrefixBefore)) then begin
    Result := APrefixBefore + Result;
  end;
  if AInSqlSubFolder then begin
    Result := c_SQL_SubFolder + Result;
  end;
end;

function NowUTC: TDateTime;
var st: TSystemTime;
begin
  GetSystemTime(st);
  Result := SystemTimeToDateTime(st);
end;

end.
