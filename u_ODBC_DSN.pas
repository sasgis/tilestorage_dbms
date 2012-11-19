unit u_ODBC_DSN;

{$include i_DBMS.inc}

interface

uses
  OdbcApi,
  Windows,
  SysUtils;

function Load_DSN_Params_from_ODBC(
  const AServerName: WideString;
  out ADescription: WideString
): Boolean;

implementation

function Load_DSN_Params_from_ODBC(
  const AServerName: WideString;
  out ADescription: WideString
): Boolean;
var
  VResult: SqlReturn;
  VODBC32Handle: HMODULE;
  VSQLAllocHandle: Pointer;
  VSQLFreeHandle: Pointer;
  VSQLSetEnvAttr: Pointer;
  VSQLDataSources: Pointer;
  VEnvHandle: SqlHEnv;
  VServerName: array [0..SQL_MAX_DSN_LENGTH] of Byte;
  VDescription: array [0..SQL_MAX_OPTION_STRING_LENGTH] of Byte;
  VSize1, VSize2: SQLSmallint;
  VDirection: SQLUSMALLINT;
  VServerNameStr, VDescriptionStr: AnsiString;
begin
  Result := FALSE;
  ADescription := '';

  if (0=Length(AServerName)) then
    Exit;

  VODBC32Handle:=LoadLibrary(PAnsiChar(sysodbclib));
  if (0<>VODBC32Handle) then
  try
    // get function for 3.0 version
    VSQLAllocHandle := GetProcAddress(VODBC32Handle, 'SQLAllocHandle');
    if (nil=VSQLAllocHandle) then
      Exit;
    VSQLFreeHandle := GetProcAddress(VODBC32Handle, 'SQLFreeHandle');
    if (nil=VSQLFreeHandle) then
      Exit;
    VSQLSetEnvAttr := GetProcAddress(VODBC32Handle, 'SQLSetEnvAttr');
    if (nil=VSQLSetEnvAttr) then
      Exit;
    VSQLDataSources := GetProcAddress(VODBC32Handle, 'SQLDataSources');
    if (nil=VSQLDataSources) then
      Exit;

    // allocate environment
    VResult := TSQLAllocHandle(VSQLAllocHandle)(SQL_HANDLE_ENV, nil, VEnvHandle);
    if not SQL_SUCCEEDED(VResult) then
      Exit;

    // environment is allocated successfully
    try
      // set ODBC version (c_ODBC_VERSION)
      {VResult :=} TSQLSetEnvAttr(VSQLSetEnvAttr)(VEnvHandle, SQL_ATTR_ODBC_VERSION, Pointer(SQL_OV_ODBC3), 0);

      VDirection := SQL_FETCH_FIRST_SYSTEM; // SQL_FETCH_FIRST;
      repeat
        // enumerate
        VResult := TSQLDataSources(VSQLDataSources)(
          VEnvHandle,
          VDirection,
          VServerName[0],
          SQL_MAX_DSN_LENGTH,
          VSize1,
          VDescription[0],
          SQL_MAX_OPTION_STRING_LENGTH,
          VSize2
        );

        if SQL_SUCCEEDED(VResult) then begin
          // ok
          SetString(VServerNameStr, PAnsiChar(@(VServerName[0])), VSize1);
          SetString(VDescriptionStr, PAnsiChar(@(VDescription[0])), VSize2);
          // check servername
          if WideSameText(VServerNameStr, AServerName) then begin
            // found
            ADescription := VDescriptionStr;
            // get all params
            // SQLGetPrivateProfileStringW
            // done
            Result := TRUE;
            break;
          end;
        end else begin
          // error or SQL_NO_DATA
          break;
        end;

        VDirection := SQL_FETCH_NEXT;
      until FALSE;
    finally
      // free env handle
      TSQLFreeHandle(VSQLFreeHandle)(SQL_HANDLE_ENV, VEnvHandle);
    end;
  finally
    FreeLibrary(VODBC32Handle);
  end;
end;

end.
