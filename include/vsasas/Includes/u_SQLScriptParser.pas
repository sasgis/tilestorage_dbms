unit u_SQLScriptParser;

interface

uses
  SysUtils,
  Classes;

type
  TSQLScriptParserFoundProc = procedure (
    const ASender: TObject;
    const ACommandIndex: Integer;
    const ACommandText, AErrors: TStrings
  ) of object;

  // ����� ��� �������� � ����������� �������� SQL
  // ����� ������ �� ��������� ������� � ����� �� ��� ����������
  TSQLScriptParser = class(TStringList)
  private
    // ����������� ������ - ������������ �� ��������� �������� ������
    function GetSQLDivider: String;
    // ���� � ���������� ����� SQL
    function GetNextDivLineIndex(
      const AStartLine: Integer;
      const ADivider: String;
      const ALines: TStrings
    ): Integer;
  public
    // ��������� ������ � ������
    class procedure AddExceptionToErrors(
      const AList: TStrings;
      const E: Exception
    );
    // ������ �����
    function ParseSQL(
      const AProc: TSQLScriptParserFoundProc;
      const AErrors: TStrings
    ): Integer;
  end;

implementation

{ TSQLScriptParser }

class procedure TSQLScriptParser.AddExceptionToErrors(
  const AList: TStrings;
  const E: Exception
);
begin
  if AList.Count>0 then
    AList.Add('');
  AList.Add(E.ClassName);
  AList.Add(E.Message);
end;

function TSQLScriptParser.GetNextDivLineIndex(
  const AStartLine: Integer;
  const ADivider: String;
  const ALines: TStrings
): Integer;
var
  VLine: String;
begin
  // ����� ������ �������� � ���� ��������� ������
  ALines.Clear;

  if (AStartLine>=Self.Count) then begin
    Result := -1;
    Exit;
  end;

  VLine := Trim(Self[AStartLine]);
  if (not SameText(VLine, ADivider)) then
    ALines.Add(VLine);

  // ���� �� �����������
  Result := AStartLine+1;
  while (Result<Self.Count) do begin
    VLine := Trim(Self[Result]);
    if SameText(VLine, ADivider) then
      break
    else
      ALines.Add(VLine);
    Inc(Result);
  end;

  // � ������ � ������ � � ����� ����� ������� ��������

  while ALines.Count>0 do begin
    VLine := Trim(ALines[0]);
    if (0=Length(VLine)) then
      ALines.Delete(0)
    else
      break;
  end;

  while ALines.Count>0 do begin
    VLine := Trim(ALines[ALines.Count-1]);
    if (0=Length(VLine)) then
      ALines.Delete(ALines.Count-1)
    else
      break;
  end;

  // ��� ������ ������� ����� ���������  
end;

function TSQLScriptParser.GetSQLDivider: String;
var
  i: Integer;
begin
  i := Self.Count;

  // ���� �����
  if (0=i) then begin
    Result := 'go';
    Exit;
  end;

  Dec(i);

  while (i>=0) do begin
    Result := Trim(Self[i]);
    // ������� ������� ������ �� ����� ���� �������������
    if (Length(Result)>0) then
    if (Length(Result)<4) then
      Exit;
    Dec(i);
  end;

  Result := 'go';
end;

function TSQLScriptParser.ParseSQL(
  const AProc: TSQLScriptParserFoundProc;
  const AErrors: TStrings
): Integer;
var
  VDivider: String;
  VLines: TStrings;
  VStartLine, VNewDivLine: Integer;
begin
  Result := 0;

  if (0=Self.Count) then
    Exit;

  VDivider := GetSQLDivider;

  VLines := TStringList.Create;
  try
    VStartLine := 0;

    repeat
      Inc(Result);

      // ������� ����� �����
      VNewDivLine := GetNextDivLineIndex(VStartLine, VDivider, VLines);

      if (VLines.Count>0) then begin
        // ���� ����� SQL ��� ����������
        AProc(Self, Result, VLines, AErrors);
      end;

      // �������� �� �����
      if (VNewDivLine<0) or (VNewDivLine>=Self.Count) then
        break;

      VStartLine := VNewDivLine + 1;
    until FALSE;

  finally
    VLines.Free;
  end;
end;

end.