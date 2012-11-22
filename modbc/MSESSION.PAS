unit mSession;

{$I mODBC.INC}

interface

uses
  SysUtils, Classes, Forms,
  odbcsql, mconst;

type
  TmSession = class(TComponent)
    private
	    FHENV:    SQLHANDLE;
      procedure InitHENV;
	    procedure FreeHENV;
      function GetHENV:SQLHANDLE;
    public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      function ODBCLoaded:boolean;
      property HENV:SQLHANDLE read GetHENV;
   end;

var
  GlobalSession: TmSession;

implementation

constructor TmSession.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHENV := 0;
end;

destructor TmSession.Destroy;
begin
  FreeHENV;
  inherited Destroy;
end;

function TmSession.GetHENV:SQLHANDLE;
begin
  InitHENV;
  Result := FHENV;
end;

function TmSession.ODBCLoaded:boolean;
begin
  Result := (FHENV <> 0);
end;

procedure TmSession.FreeHENV;
begin
  if FHENV = 0 then
    exit;
  SQLFreeHandle(SQL_HANDLE_ENV, FHENV);
  FHENV:=0;
end;

procedure TmSession.InitHENV;
begin
  if FHENV <> 0 then
    exit;

  loadODBC;

  if SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, FHENV) <> SQL_SUCCESS then
    raise Exception.Create( SmAllocateHENVError);

  try
    if not(SQLSetEnvAttr(FHENV,SQL_ATTR_ODBC_VERSION, SQLPOINTER( SQL_OV_ODBC3), 0)
           in [SQL_SUCCESS,SQL_SUCCESS_WITH_INFO]) then
      raise Exception.Create( SmSetEnvAttrError);
  except
    FreeHENV;
    raise;
  end;
end;

initialization
begin
  GlobalSession := TmSession.Create( nil);
end;

finalization
begin
  GlobalSession.free;
end;

end.
