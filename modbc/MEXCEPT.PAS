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

uses
  Windows,
  SysUtils,
  Classes,
  Db,
  odbcsql;

type
  ESQLerror = class(Exception)
  public
    MessageList: TStringList;
    SqlState:    String;
    NativeError: SQLINTEGER;
    constructor CreateDiag(HandleType:SQLSMALLINT; Handle:SQLHANDLE; nError:SQLINTEGER);
    destructor Destroy; override;
  end;

  // ODBC environment errors
  EODBCEnvironmentError    = class(ESQLerror);

  // common ODBC errors
  EODBCCommonError         = class(ESQLerror);
  EODBCErrorWithInfo       = class(EODBCCommonError);
  EODBCErrorNeedData       = class(EODBCCommonError);
  EODBCErrorStillExecuting = class(EODBCCommonError);
  EODBCErrorSQLError       = class(EODBCCommonError);
  EODBCErrorNoData         = class(EODBCCommonError);
  EODBCErrorInvalidHandle  = class(EODBCCommonError);
  EODBCErrorUnknown        = class(EODBCCommonError);

  // library errors
  EMODBCCommonError         = class(ESQLerror);
  EMODBCNoDataSource        = class(EMODBCCommonError);
  EMODBCAllocStatement      = class(EMODBCCommonError);
  EMODBCCommonDatabaseError = class(EMODBCCommonError);
  EMODBCStrictDatabaseError = class(EMODBCCommonError);
  EMODBCExecStatementError  = class(EMODBCCommonError);

implementation

{ ESQLError }

constructor ESQLError.CreateDiag(HandleType:SQLSMALLINT; Handle:SQLHANDLE; nError:SQLINTEGER);
const
  c_message_buffer_len = 512;
var
  psqlstate: array [0..6] of Char;
  pmessage: array [0..c_message_buffer_len-1] of Char;
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
                             NativeError, pmessage, c_message_buffer_len-1, textlength);
    if i = 1 then
      if (sqlres = SQL_SUCCESS) or (sqlres = SQL_SUCCESS_WITH_INFO) then
      begin
        SqlState := StrPas(pSqlState);
        Message := StrPas(psqlstate) + ':' + IntToStr(NativeError) + ':' + StrPas(pmessage);
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

end.
