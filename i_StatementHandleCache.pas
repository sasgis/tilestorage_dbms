unit i_StatementHandleCache;

interface

uses
  odbcsql;

type
  IStatementHandleCache = interface
    ['{AE10AA72-A057-4285-90B8-3D7839D4654E}']
    procedure FreeStatement(const AStatementHandle: SQLHANDLE);
    function GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN;
    procedure SyncStatements;
  end;

implementation

end.
