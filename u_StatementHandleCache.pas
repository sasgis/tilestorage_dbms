unit u_StatementHandleCache;

interface

uses
  Windows,
  SysUtils,
  odbcsql,
  i_StatementHandleCache;

type
  TStatementHandleCache = class(TInterfacedObject, IStatementHandleCache)
  private
    FDBCHandlePtr: PSQLHandle;
  private
    { IStatementHandleCache }
    procedure FreeStatement(const AStatementHandle: SQLHANDLE);
    function GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN;
  public
    constructor Create(
      const ADBCHandlePtr: PSQLHandle
    );
  end;

implementation

{ TStatementHandleCache }

constructor TStatementHandleCache.Create(const ADBCHandlePtr: PSQLHandle);
begin
  inherited Create;
  FDBCHandlePtr := ADBCHandlePtr;
end;

procedure TStatementHandleCache.FreeStatement(const AStatementHandle: SQLHANDLE);
begin
  // free handle
  SQLFreeHandle(SQL_HANDLE_STMT, AStatementHandle);
end;

function TStatementHandleCache.GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN;
begin
  // allocate handle
  Result := SQLAllocHandle(SQL_HANDLE_STMT, FDBCHandlePtr^, AStatementHandle);
end;

end.
