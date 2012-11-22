unit u_ODBC_UTILS;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  OdbcApi;

type
  EODBCException = class(Exception);
  EODBCUnavailableException = class(EODBCException);
  EODBCCallException = class(EODBCException);
  EODBCNotImplementedYetException = class(EODBCException);
  EODBCNoStatementException = class(EODBCException);
  EODBCStatementNotPreparedException = class(EODBCException);
  EODBCStatementDirectExecException = class(EODBCException);
  EODBCUnknownFieldTypeException = class(EODBCException);

  IODBCBasic = interface
    ['{7EEE1FA1-B87C-40F2-8B0C-2DD1871FDCF3}']
    // check errors
    function IsAllocated: Boolean;
    procedure CheckErrors;
  end;


procedure CheckODBCError(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
);
  
implementation

procedure CheckODBCError(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
);
var
  VFullMessage: String;
begin
  // assuming FENVHandle is ok

  if SQL_SUCCEEDED(AErrorCode) then
    Exit;

  // TODO: get text via SQLGetDiagRec
  VFullMessage := IntToStr(AErrorCode);
  raise EODBCCallException.Create(VFullMessage);
end;

end.
