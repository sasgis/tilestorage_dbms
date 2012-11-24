unit u_ExecuteSQLArray;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs;

type
  TExecuteSQLItem = class(TStringList)
  private
    FSkipErrorsOnExec: Boolean;
  public
    property SkipErrorsOnExec: Boolean read FSkipErrorsOnExec;
  end;

  // owns objects by default
  TExecuteSQLArray = class(TObjectList)
  public
    procedure AddSQLItem(
      const ASQLText: String;
      const ASkipErrorsOnExec: Boolean
    );
    function GetSQLItem(const AIndex: Integer): TExecuteSQLItem;
  end;

implementation

{ TExecuteSQLArray }

procedure TExecuteSQLArray.AddSQLItem(
  const ASQLText: String;
  const ASkipErrorsOnExec: Boolean
);
var
  VItem: TExecuteSQLItem;
begin
  VItem := TExecuteSQLItem.Create;
  VItem.Text := ASQLText;
  VItem.FSkipErrorsOnExec := ASkipErrorsOnExec;
  Self.Add(VItem);
end;

function TExecuteSQLArray.GetSQLItem(const AIndex: Integer): TExecuteSQLItem;
begin
  Result := (Items[AIndex] as TExecuteSQLItem);
end;

end.
