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
  end;

  TODBCEnvironment = class(TInterfacedObject, IODBCEnvironment, IODBCBasic)
  private
    // Environment Handle
    FENVHandle: SQLHENV;
    // result of handle allocation
    FResult: SQLRETURN;
  private
    { IODBCBasic }
    function IsAllocated: Boolean;
    function GetLastResult: SQLRETURN;
    function GetODBCType: SQLSMALLINT;
    function GetODBCHandle: SQLHANDLE;
    procedure CheckErrors;
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
    raise EODBCNoEnvironment.Create(IntToStr(FResult));
  if not SQL_SUCCEEDED(FResult) then
    InternalRaiseODBC(Self, EODBCEnvironmentError);
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

function TODBCEnvironment.GetLastResult: SQLRETURN;
begin
  Result := FResult;
end;

function TODBCEnvironment.GetODBCHandle: SQLHANDLE;
begin
  Result := FENVHandle;
end;

function TODBCEnvironment.GetODBCType: SQLSMALLINT;
begin
  Result := SQL_HANDLE_ENV;
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
