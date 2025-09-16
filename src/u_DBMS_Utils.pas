unit u_DBMS_Utils;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils;

function DBMSStrToDB(const S: String): String; inline;

function GetModuleFileNameWithoutExt(
  const AInSqlSubFolder: Boolean;
  const AKeepFullPath: Boolean;
  const APrefixBefore: String;
  const ATailAfterDot: String
): String;

function NowUTC: TDateTime;

implementation

uses
  t_DBMS_Template;

function DBMSStrToDB(const S: String): String; inline;
begin
  Result := QuotedStr(S);
end;

function GetModuleFileNameWithoutExt(
  const AInSqlSubFolder: Boolean;
  const AKeepFullPath: Boolean;
  const APrefixBefore: String;
  const ATailAfterDot: String
): String;
begin
  Result := GetModuleName(HInstance);

  if (not AKeepFullPath) then begin
    Result := ExtractFileName(Result);
  end;

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
