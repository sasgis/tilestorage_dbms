unit u_ODBC_ENV;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  OdbcApi,
  u_ODBC_UTILS;

type
  IODBCEnvironment = interface(IODBCBasic)
    ['{825AAF47-C2BC-4498-8F6D-221FF8DCC45D}']
    // return environment handle
    function GetEnvHandle: SQLHENV;
    property ENVHandle: SQLHENV read GetEnvHandle;
  end;

  TODBCEnvironment = class(TInterfacedObject, IODBCEnvironment)
  private
    // Environment Handle
    FENVHandle: SQLHENV;
    // result of handle allocation
    FResult: SQLRETURN;
  private
    { IODBCBasic }
    function IsAllocated: Boolean;
    procedure CheckErrors;
    { IODBCEnvironment }
    function GetEnvHandle: SQLHENV;
  public
    constructor Create;
    destructor Destroy; override;
    property ENVHandle: SQLHENV read FENVHandle;
  end;

var
  g_ODBCEnvironment: IODBCEnvironment;

implementation

{ TODBCEnvironment }

procedure TODBCEnvironment.CheckErrors;
begin
  if (not IsAllocated) then
    raise EODBCUnavailableException.Create(IntToStr(FResult));
end;

constructor TODBCEnvironment.Create;
begin
  inherited Create;
  
  // allocate environment handle
  FResult := SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, FENVHandle);

  if SQL_SUCCEEDED(FResult) then begin
    // set version
    SQLSetEnvAttr(FENVHandle, SQL_ATTR_ODBC_VERSION, SQLPOINTER(SQL_OV_ODBC3), 0);
  end else begin
    // failed
    FENVHandle := nil;
  end;
end;

destructor TODBCEnvironment.Destroy;
begin
  if (FENVHandle<>nil) then begin
    SQLFreeHandle(SQL_HANDLE_ENV, FENVHandle);
    FENVHandle := nil;
  end;
  inherited;
end;

function TODBCEnvironment.GetEnvHandle: SQLHENV;
begin
  Result := FENVHandle
end;

function TODBCEnvironment.IsAllocated: Boolean;
begin
  Result := (FENVHandle<>nil)
end;

initialization
  g_ODBCEnvironment := nil;
finalization
  g_ODBCEnvironment := nil;
end.
