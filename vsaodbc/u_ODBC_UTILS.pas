unit u_ODBC_UTILS;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  OdbcApi;

type
  IODBCBasic = interface
    ['{7EEE1FA1-B87C-40F2-8B0C-2DD1871FDCF3}']
    // check errors
    function IsAllocated: Boolean;
    function GetLastResult: SQLRETURN;
    function GetODBCType: SQLSMALLINT;
    function GetODBCHandle: SQLHANDLE;
    procedure CheckErrors;
  end;

  EODBCException = class(Exception)
  public
    constructor CreateWithDiag(
      const AErrorCode: SQLRETURN;
      const AHandleType: SQLSMALLINT;
      const AHandleValue: SQLHANDLE
    );
  end;

  TODBCExceptionClass  = class of EODBCException;

  EODBCNoEnvironment      = class(EODBCException);
  EODBCEnvironmentError   = class(EODBCException);

  EODBCNoConnection      = class(EODBCException);
  EODBCConnectionError   = class(EODBCException);

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



procedure InternalRaiseODBC(
  const AODBCBasic: IODBCBasic;
  const AODBCExceptionClass: TODBCExceptionClass
);

function InternalMakeODBCMessage(
  const AErrorCode: SQLRETURN;
  const AHandleType: SQLSMALLINT;
  const AHandleValue: SQLHANDLE
): String;
  
implementation

procedure InternalRaiseODBC(
  const AODBCBasic: IODBCBasic;
  const AODBCExceptionClass: TODBCExceptionClass
);
var
  VErrorCode: SQLRETURN;
  VHandleType: SQLSMALLINT;
  VHandleValue: SQLHANDLE;
begin
  // если сюда попали - ошибка точно есть
  
  VErrorCode   := AODBCBasic.GetLastResult;
  VHandleType  := AODBCBasic.GetODBCType;
  VHandleValue := AODBCBasic.GetODBCHandle;

  raise AODBCExceptionClass.CreateWithDiag(VErrorCode, VHandleType, VHandleValue);
end;

function InternalMakeODBCMessage(
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
  VSqlState:    String;
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
      sqlres := SQLGetDiagRec( AHandleType, AHandleValue, i, psqlstate,
                               VNativeError, pmessage, c_message_buffer_len-1, textlength);

      if (sqlres = SQL_SUCCESS) or (sqlres = SQL_SUCCESS_WITH_INFO) then begin
        VSqlState := StrPas(pSqlState);
        Result := Result + VSqlState + ':' + StrPas(pmessage);
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
  inherited Create(InternalMakeODBCMessage(AErrorCode, AHandleType, AHandleValue));
end;

end.
