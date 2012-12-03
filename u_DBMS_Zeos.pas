unit u_DBMS_Zeos;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  t_types,
  ZConnection;

type
  TZeosDatabase = class(TZConnection)
  public
    function TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
  end;

implementation

{ TZeosDatabase }

function TZeosDatabase.TableExistsDirect(const AFullyQualifiedQuotedTableName: String): Boolean;
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
