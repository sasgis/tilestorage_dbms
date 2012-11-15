unit u_DBMS_Utils;

interface

uses
  Windows,
  SysUtils;

function AnsiStrToDB(const S: AnsiString): AnsiString;
function WideStrToDB(const S: WideString): WideString;

function GetModuleFileNameWithoutExt(const ATailAfterDot: String): String;

function NowUTC: TDateTime;

implementation

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

function GetModuleFileNameWithoutExt(const ATailAfterDot: String): String;
begin
  Result := GetModuleName(HInstance);
  Result := ExtractFileName(Result);
  if (0<Length(ATailAfterDot)) then begin
    Result := Result + '.' + ATailAfterDot;
  end;
end;

function NowUTC: TDateTime;
var st: TSystemTime;
begin
  GetSystemTime(st);
  Result := SystemTimeToDateTime(st);
end;

end.
