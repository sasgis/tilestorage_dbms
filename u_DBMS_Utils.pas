unit u_DBMS_Utils;

interface

uses
  SysUtils;

function AnsiStrToDB(const S: AnsiString): AnsiString;
function WideStrToDB(const S: WideString): WideString;

function GetModuleFileNameWithoutExt: String;

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

function GetModuleFileNameWithoutExt: String;
begin
  Result := GetModuleName(HInstance);
  Result := ExtractFileName(Result);
end;

end.
