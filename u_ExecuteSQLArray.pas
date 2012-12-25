unit u_ExecuteSQLArray;

{$include i_DBMS.inc}

interface

uses
  Types,
  SysUtils,
  Classes,
  t_types,
  t_DBMS_Template,
  u_DBMS_Connect,
  Contnrs;

type
  TExecuteSQLItem = class(TStringList)
  private
    FSkipErrorsOnExec: Boolean;
    FIndexSQL: SmallInt;
  public
    property SkipErrorsOnExec: Boolean read FSkipErrorsOnExec;
    property IndexSQL: SmallInt read FIndexSQL;
  end;

  // owns objects by default
  TExecuteSQLArray = class(TObjectList)
  public
    procedure AddSQLItem(
      const AIndexSQL: SmallInt;
      const ASQLText: String;
      const ASkipErrorsOnExec: Boolean
    );
    function GetSQLItem(const AIndex: Integer): TExecuteSQLItem;
  end;

  PSelectInRectItem = ^TSelectInRectItem;
  TSelectInRectItem = record
    TabSQLTile: TSQLTile;
    InitialWhereClause: TDBMS_String;
    FullSqlText: TDBMS_String;
    UsedConnection: IDBMS_Connection;
  end;

  TSelectInRectList = class(TList)
  private
    function GetSelectInRectItems(AIndex: Integer): PSelectInRectItem;
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    property SelectInRectItems[AIndex: Integer]: PSelectInRectItem read GetSelectInRectItems;
  end;

implementation

{ TExecuteSQLArray }

procedure TExecuteSQLArray.AddSQLItem(
  const AIndexSQL: SmallInt;
  const ASQLText: String;
  const ASkipErrorsOnExec: Boolean
);
var
  VItem: TExecuteSQLItem;
begin
  VItem := TExecuteSQLItem.Create;
  VItem.FIndexSQL := AIndexSQL;
  VItem.Text := ASQLText;
  VItem.FSkipErrorsOnExec := ASkipErrorsOnExec;
  Self.Add(VItem);
end;

function TExecuteSQLArray.GetSQLItem(const AIndex: Integer): TExecuteSQLItem;
begin
  Result := (Items[AIndex] as TExecuteSQLItem);
end;

{ TSelectInRectList }

function TSelectInRectList.GetSelectInRectItems(AIndex: Integer): PSelectInRectItem;
begin
  Result := PSelectInRectItem(Items[AIndex]);
end;

procedure TSelectInRectList.Notify(Ptr: Pointer; Action: TListNotification);
var VSelectInRectItem: PSelectInRectItem;
begin
  inherited;
  if (Action=lnDeleted) then begin
    VSelectInRectItem := Ptr;
    Dispose(VSelectInRectItem);
  end;
end;

end.
