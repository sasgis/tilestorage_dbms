unit u_ODBC_DSN;

{$include i_DBMS.inc}

interface

uses
  Windows,
  odbcsql,
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

    // allocate environment
    VResult := SQLAllocHandle(SQL_HANDLE_ENV, nil, VEnvHandle);
    if not SQL_SUCCEEDED(VResult) then
      Exit;

    // environment is allocated successfully
    try
      // set ODBC version (c_ODBC_VERSION)
      {VResult :=}
      SQLSetEnvAttr(VEnvHandle, SQL_ATTR_ODBC_VERSION, Pointer(SQL_OV_ODBC3), 0);

      VDirection := SQL_FETCH_FIRST_SYSTEM; // SQL_FETCH_FIRST;
      repeat
        // enumerate
        VResult := SQLDataSourcesA(VEnvHandle,
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
      {$if defined(USE_STATIC_LINK_ODBC)}
      SQLFreeHandle
      {$else}
      TSQLFreeHandle(VSQLFreeHandle)
      {$ifend}
      (SQL_HANDLE_ENV, VEnvHandle);
    end;
{$if not defined(USE_STATIC_LINK_ODBC)}
  finally
    FreeLibrary(VODBC32Handle);
  end;
{$ifend}
end;

end.
