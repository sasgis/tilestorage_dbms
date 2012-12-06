unit u_DBMS_DBX;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  t_types,
  DBXCommon,
  DBXDynaLink,
  SQLExpr;

type
  TDBXDatabase = class(TSQLConnection)
  public
    function TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
  end;

implementation

{ TZeosDatabase }

function TDBXDatabase.TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
var
  VFullSQL: String;
begin
  VFullSQL := 'select 1 as a from ' + AFullyQualifiedQuotedTableName + ' where 0=1';
  try
    Self.ExecuteDirect(VFullSQL);
    Result := TRUE;
  except
    Result := FALSE;
  end;
end;

end.
