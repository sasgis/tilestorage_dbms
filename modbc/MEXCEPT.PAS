unit mExcept;

{$I mODBC.INC}

{
2000-04-15 Per-Eric Larsson
  changed borderstyle to bssizeable and added a few panels for
  looks !
  if you get the errors I get you'll se why:

"23000:[Microsoft][ODBC SQL Server Driver][SQL Server]
 DELETE statement conflicted with COLUMN REFERENCE
 constraint 'FK_PAS_STATION_PAS_GROUP_HEAD'.
 The conflict occurred in database 'PAS',
 table 'PAS_STATION', column 'GROUP_NAME'."

}
interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Db, odbcsql;

type
  ESQLerror = class(Exception)
  public
    MessageList: TStringList;
    SqlState:    String;
    NativeError: SQLINTEGER;
    constructor CreateDiag(HandleType:SQLSMALLINT; Handle:SQLHANDLE; nError:SQLINTEGER);
    destructor Destroy; override;
  end;

  TmODBCErrorDlg = class(TForm)
    Panel1: TPanel;
    OKBtn: TButton;
    BackBtn: TButton;
    NextBtn: TButton;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    IconImage: TImage;
    ScrollBox1: TScrollBox;
    ErrorLabel: TLabel;
    procedure FormShow(Sender: TObject);
    procedure BackClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FPrevOnException: TExceptionEvent;
    FExceptionAddr: ESQLError;
    procedure HandleException(Sender: TObject; E: Exception);
    procedure ShowError;
  public
    function ShowException(Error: ESQLError): TModalResult;
    property ExceptionAddr: ESQLError read FExceptionAddr write FExceptionAddr;
  end;

var
  mODBCErrorDlg: TmODBCErrorDlg;

implementation

{$R *.DFM}

constructor ESQLError.CreateDiag(HandleType:SQLSMALLINT; Handle:SQLHANDLE; nError:SQLINTEGER);
var
  psqlstate: array [0..6] of Char;
  pmessage: array [0..255] of Char;
  textLength: SQLSMALLINT;
  sqlres:     SQLRETURN;
  i:          integer;
  function tError(nError:SQLINTEGER):String;
  begin
    case nError of
      SQL_SUCCESS:           Result := 'SQL_SUCCESS';
      SQL_SUCCESS_WITH_INFO: Result := 'SQL_SUCCESS_WITH_INFO';
      SQL_NEED_DATA:         Result := 'SQL_NEED_DATA';
      SQL_STILL_EXECUTING:   Result := 'SQL_STILL_EXECUTING';
      SQL_ERROR:             Result := 'SQL_ERROR';
      SQL_NO_DATA:           Result := 'SQL_NO_DATA';
      SQL_INVALID_HANDLE:    Result := 'SQL_INVALID_HANDLE';
      else                   Result := 'unknown SQL result' + IntToStr( nError);
    end;
  end;
begin
  inherited Create('');
  MessageList := TStringList.Create;
  NativeError := nError;
  SqlState := '';
  i := 1;
  if (nError <> SQL_SUCCESS_WITH_INFO) and (nError <> SQL_ERROR) then
  begin
    Message := tError(nError);
  end else
  repeat
    sqlres := SQLGetDiagRec( HandleType, Handle, i, psqlstate,
                             NativeError, pmessage, 254, textlength);
    if i = 1 then
      if (sqlres = SQL_SUCCESS) or (sqlres = SQL_SUCCESS_WITH_INFO) then
      begin
        SqlState := StrPas(pSqlState);
        Message := StrPas(psqlstate) + ':' + StrPas(pmessage);
      end else
      begin
         Message := tError(nError);
         //Message :='SQL ERROR '+IntToStr( nError);
      end;

    if (sqlres = SQL_SUCCESS) or (sqlres = SQL_SUCCESS_WITH_INFO) then
    begin
      MessageList.add( StrPas(psqlstate)+':'+StrPas(pmessage));
    end;

    inc( i);
  until (sqlres <> SQL_SUCCESS) and (sqlres <> SQL_SUCCESS_WITH_INFO);
end;

destructor ESQLError.Destroy;
begin
  if assigned(MessageList) then
    MessageList.Free;

  inherited destroy;
end;

procedure TmODBCErrorDlg.HandleException(Sender: TObject; E: Exception);
begin
  if (E is ESQLError) and (ExceptionAddr = nil) and not Application.Terminated then
  begin
    ShowException(ESQLError(E));
  end else
  begin
    if Assigned(FPrevOnException)
      then FPrevOnException(Sender, E)
      else Application.ShowException(E);
  end;
end;

procedure TmODBCErrorDlg.ShowError;
begin
  BackBtn.Enabled := Tag > 0;
  if Assigned(ExceptionAddr.MessageList) and (ExceptionAddr.MessageList.Count > 0) then
  begin
    NextBtn.Enabled := Tag < ExceptionAddr.MessageList.Count - 1;
    Errorlabel.Caption := ExceptionAddr.MessageList[Tag];
  end else
  begin
    NextBtn.Enabled := False;
    Errorlabel.Caption := ExceptionAddr.Message;
   end;
end;

procedure TmODBCErrorDlg.FormDestroy(Sender: TObject);
begin
  mODBCErrorDlg := nil;
  {if Assigned(FPrevOnException) then }Application.OnException := FPrevOnException;
end;

procedure TmODBCErrorDlg.FormShow(Sender: TObject);
begin
  Tag := 0;
  ShowError;
end;

procedure TmODBCErrorDlg.BackClick(Sender: TObject);
begin
  Tag := Tag - 1;
  ShowError;
end;

procedure TmODBCErrorDlg.NextClick(Sender: TObject);
begin
  Tag := Tag + 1;
  ShowError;
end;

function TmODBCErrorDlg.ShowException(Error: ESQLError): TModalResult;
begin
  ExceptionAddr := Error;
  Result := ShowModal;
  ExceptionAddr := nil;
end;

procedure TmODBCErrorDlg.FormCreate(Sender: TObject);
begin
  FPrevOnException := Application.OnException;
  Application.OnException := HandleException;
end;

initialization
begin
  mODBCErrorDlg:=TmODBCErrorDlg.Create(Application);
end;

finalization
begin
  if Assigned(mODBCErrorDlg) then
    mODBCErrorDlg.free;
end;

end.
