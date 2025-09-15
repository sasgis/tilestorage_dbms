unit t_ODBC_Exception;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  odbcsql;

type
  EODBCException = class(Exception)
  public
    constructor CreateWithDiag(
      const AErrorCode: SQLRETURN;
      const AHandleType: SQLSMALLINT;
      const AHandleValue: SQLHANDLE
    );
  end;

  TODBCExceptionClass       = class of EODBCException;

  // исключения для подключения
  EODBCConnectionError           = class(EODBCException);
  EODBCDriverInfoErrorWithInfo   = EODBCConnectionError;
  EODBCDriverInfoNeedDataError   = EODBCConnectionError;
  EODBCDriverInfoStillExecuting  = EODBCConnectionError;
  EODBCDriverInfoError           = EODBCConnectionError;
  EODBCDriverInfoNoData          = EODBCConnectionError;
  EODBCDriverInfoInvalidHandle   = EODBCConnectionError;
  EODBCDriverInfoUnknown         = EODBCConnectionError;

  EODBCEnvironmentError          = class(EODBCException);

  // исключения всяких разных запросов
  EODBCStatementError       = class(EODBCException);
  EODBCOpenFetchError       = class(EODBCStatementError);
  EODBCFetchStmtError       = class(EODBCStatementError);
  EODBCDirectExecError      = class(EODBCStatementError);
  EODBCDirectExecBlobError  = class(EODBCStatementError);
  EODBCNumResultColsError   = class(EODBCStatementError);
  EODBCDescribeColError     = class(EODBCStatementError);
  EODBCBindColError         = class(EODBCStatementError);
  EODBCGetDataLOBError      = class(EODBCStatementError);

  // простые обычные исключения
  EODBCSimpleError               = class(Exception);

  // обычные исключения конвертации
  EODBCConvertError              = class(EODBCSimpleError);
  EODBCConvertFromDateError      = class(EODBCConvertError);
  EODBCConvertFromTimeError      = class(EODBCConvertError);
  EODBCConvertFromTimeStampError = class(EODBCConvertError);
  EODBCConvertDateTimeError      = class(EODBCConvertError);
  EODBCConvertLongintError       = class(EODBCConvertError);
  EODBCConvertSmallintError      = class(EODBCConvertError);
  EODBCConvertLOBError           = class(EODBCConvertError);
  
  // прочие обычные исключения
  EODBCUnknownDataTypeError      = class(EODBCSimpleError);
  EODBCAllocateEnvironment       = class(EODBCSimpleError);

(*
  EODBCNoEnvironment      = class(EODBCException);
  EODBCEnvironmentError   = class(EODBCException);

  EODBCNoConnection      = class(EODBCException);

  EODBCNoStatement               = class(EODBCException);
  EODBCStatementError            = class(EODBCException);
  EODBCBindParamsError           = class(EODBCException);
  EODBCPrepareStatementError     = class(EODBCException);
  EODBCDirectExecStatementError  = class(EODBCException);
  EODBCSQLNumResultColsError     = class(EODBCException);
  EODBCSQLDescribeColError       = class(EODBCException);
  EODBCUnknownFieldType          = class(EODBCException);


  EODBCCallException = class(EODBCException);
  EODBCNotImplementedYetException = class(EODBCException);
  EODBCNoStatementException = class(EODBCException);
  EODBCStatementNotPreparedException = class(EODBCException);
  EODBCStatementDirectExecException = class(EODBCException);
*)

function MakeODBCInfoMessage(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
): String;

procedure CheckStatementResult(
  const AStmtHandle: SqlHStmt;
  const ASqlRes: SQLRETURN;
  const AODBCExceptionClass: TODBCExceptionClass
); //inline;
  
implementation

procedure CheckStatementResult(
  const AStmtHandle: SqlHStmt;
  const ASqlRes: SQLRETURN;
  const AODBCExceptionClass: TODBCExceptionClass
);
begin
  if not SQL_SUCCEEDED(ASqlRes) then
    raise AODBCExceptionClass.CreateWithDiag(ASqlRes, SQL_HANDLE_STMT, AStmtHandle);
end;

function MakeODBCInfoMessage(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
): String;
const
  c_message_buffer_len = 512;
var
  psqlstate: array [0..6] of Char;
  pmessage: array [0..c_message_buffer_len-1] of Char;
  textLength: SQLSMALLINT;
  sqlres:     SQLRETURN;
  i:          SmallInt;
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

var
  VList: TStringList;
  VSqlState: String;
  VNativeError: SQLINTEGER;
begin
  if (AErrorCode <> SQL_SUCCESS_WITH_INFO) and (AErrorCode <> SQL_ERROR) then begin
    // simple
    Result := tError(AErrorCode);
    Exit;
  end;

  VList := TStringList.Create;
  try
    VNativeError := AErrorCode;
    VSqlState := '';
    i := 1;

    Result := '';

    repeat
      sqlres := SQLGetDiagRec(AHandleType, AHandleValue, i, psqlstate,
                               VNativeError, pmessage, c_message_buffer_len-1, textlength);

      if (sqlres = SQL_SUCCESS) or (sqlres = SQL_SUCCESS_WITH_INFO) then begin
        VSqlState := StrPas(pSqlState);
        Result := Result + VSqlState + ':' + IntToStr(VNativeError) + ':' + StrPas(pmessage);
      end else begin
        Result := Result + tError(AErrorCode);
        //Message :='SQL ERROR '+IntToStr(AErrorCode);
      end;

      inc( i);
    until (sqlres <> SQL_SUCCESS) and (sqlres <> SQL_SUCCESS_WITH_INFO);
  finally
    VList.Free;
  end;
end;

{ EODBCException }

constructor EODBCException.CreateWithDiag(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
);
begin
  inherited Create(MakeODBCInfoMessage(AErrorCode, AHandleType, AHandleValue));
end;

end.
