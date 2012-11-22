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

uses
  mExcept;

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
var vRes: SQLRETURN;
begin
  if FHENV <> 0 then
    exit;

  loadODBC;

  if not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, FHENV)) then
    raise Exception.Create( SmAllocateHENVError);

  try
    vRes := SQLSetEnvAttr(
      FHENV,
      SQL_ATTR_ODBC_VERSION,
{$if defined(ODBCVER380)}
      SQLPOINTER(SQL_OV_ODBC3_80),
{$elseif defined(ODBCVER351)}
      SQLPOINTER(SQL_OV_ODBC3_51),
{$elseif defined(ODBCVER350)}
      SQLPOINTER(SQL_OV_ODBC3_50),
{$else}
      SQLPOINTER(SQL_OV_ODBC3),
{$ifend}
      0);
      
      if not SQL_SUCCEEDED(vRes) then
        raise EODBCEnvironmentError.CreateDiag( SQL_HANDLE_ENV, FHENV, vRes );
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
