unit u_ODBC_STMT;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Windows,
  Classes,
  DB,
  FMTBcd,
  OdbcApi,
  u_ODBC_UTILS;

type
  IODBCStatement = interface(IODBCBasic)
    ['{A7C71A3F-EC6B-41A2-948A-7EDAAF94E0C2}']
    // check specified result on statement handle
    procedure CheckError(const AResult: SQLRETURN);
    // bind params
    procedure BindParams(const AParams: TParams);
    // execute statement
    function Execute(const ARowsAffected: PLongInt = nil): SQLRETURN;
    // get rows affected
    function GetAffectedRows: Longint;
  end;

  TParamBufferItem = packed record
    StrLen_or_IndPtr: SQLLEN;
    ParameterValuePtr: SQLPOINTER;
  end;

  // record to generate actual buffers
  TColumnFlag = packed record
    ColIsPointer: Byte;     // need to getmem/freemem
    ColFldType: TFieldType; // defined field type
    ColSqlType: SmallInt;   // original sql type
  end;

  // format for SQL fetching
  TColumnBufferItem = record
    ColumnFlag: TColumnFlag;
    StrLen_or_IndPtr: SQLLEN; // marker of NULL
    case SmallInt {ColumnFlag.ColSqlType} of
    // fixed length
    SQL_SMALLINT:
      (ColValueSmallInt: SqlSmallint;);
    SQL_INTEGER:
      (ColValueInteger: SqlInteger;);
    SQL_TYPE_TIME:
      (ColValueTime: SQL_TIME_STRUCT;);
    SQL_TYPE_DATE:
      (ColValueDate: SQL_DATE_STRUCT;);
    SQL_TYPE_TIMESTAMP:
      (ColValueTimeStamp: SQL_TIMESTAMP_STRUCT;);
    SQL_NUMERIC:
      (ColValueNumeric: tagSQL_NUMERIC_STRUCT;);
    SQL_INTERVAL:
      (ColValueInterval: TSqlInterval;);
    SQL_BIGINT:
      (ColValueLargeint: SqlBigint;);
    SQL_BIT:
      (ColValueBool: SqlChar;);

    // unknown
    SQL_DOUBLE:
      (ColValueDouble: SqlDouble;);
    SQL_DATETIME:
      (ColValueDateTime: TDateTime;);
    SQL_GUID:
      (ColValueGUID: SqlGuid;);

    // all pointers
    SQL_UNKNOWN_TYPE:
      (ColValuePtr: SQLPOINTER;
       BytesAllocated: Integer;);
  end;

  TColumnBufferItemsList = array [0..0] of TColumnBufferItem;

  TColumnBuffers = record
    // TODO: add bookmark data here
    Cols: TColumnBufferItemsList;
  end;
  PColumnBuffers = ^TColumnBuffers;



  TODBCStatement = class(TInterfacedObject, IODBCStatement, IODBCBasic)
  private
    // stored connection handle
    FDBCHandle: SQLHDBC;
    // statement Handle
    FSTMTHandle: SQLHSTMT;
    // result of handle allocation
    FResult: SQLRETURN;
    // called SQLPrepare
    FPrepared: Boolean;
    // for params binding
    FParamBuffers: array of TParamBufferItem;
  private
    procedure FreeParamBuffers;
  private
    { IODBCBasic }
    function IsAllocated: Boolean;
    function GetLastResult: SQLRETURN;
    function GetODBCType: SQLSMALLINT;
    function GetODBCHandle: SQLHANDLE;
    procedure CheckErrors;
    { IODBCStatement }
    procedure CheckError(const AResult: SQLRETURN);
    procedure BindParams(const AParams: TParams);
    function Execute(const ARowsAffected: PLongInt = nil): SQLRETURN;
    function GetAffectedRows: Longint;
  public
    constructor Create(
      const ADBCHandle: SQLHDBC;
      const AParsedSQLText: WideString
    );
    constructor CreateAndExecDirect(
      const ADBCHandle: SQLHDBC;
      const ADirectSQLText: String
    );
    destructor Destroy; override;
  end;

implementation

{ TODBCStatement }

procedure TODBCStatement.BindParams(const AParams: TParams);
var
  i: Integer;
  VBlobData: TBlobData;
  // to bind
  VInputOutputType: SQLSMALLINT;
  VValueType: SQLSMALLINT;
  VParameterType: SQLSMALLINT;
  VColumnSize: SQLULEN;
  VDecimalDigits: SQLSMALLINT;
  //VParameterValuePtr: SQLPOINTER;
  VBufferLength: SQLLEN;
  //VStrLen_or_IndPtr: SQLLEN;
begin
  if (nil=AParams) or (0=AParams.Count) then
    Exit;

  if (not FPrepared) then begin
    raise EODBCStatementNotPreparedException.Create('BindParams');
  end;

  FreeParamBuffers;

  // initialize ParamBuffers
  SetLength(FParamBuffers, AParams.Count);

  VInputOutputType := SQL_PARAM_INPUT;

  for i:=0 to AParams.Count-1 do begin
    // TODO: because we have single blob only - we don't need to check params order
    // check actually prepared fields to implement full functionality
    // see SQLNumParams
    VBufferLength := 0;
    VColumnSize := 0;
    VDecimalDigits := 0;
    VValueType := SQL_C_LONG;
    VParameterType := SQL_UNKNOWN_TYPE;

    with AParams[i] do
    case DataType of
      ftBlob: begin
        // the only required for us
        VValueType:=SQL_C_BINARY;
        VParameterType:=SQL_LONGVARBINARY;
        if IsNull then begin
          // no data
          FParamBuffers[i].ParameterValuePtr := nil;
          FParamBuffers[i].StrLen_or_IndPtr := SQL_NULL_DATA;
        end else begin
          // has data
          VBlobData := AsBlob;
          FParamBuffers[i].StrLen_or_IndPtr := Length(VBlobData);
          if (0=FParamBuffers[i].StrLen_or_IndPtr) then begin
            // no data indeed
            VBlobData := '';
            FParamBuffers[i].StrLen_or_IndPtr := SQL_NULL_DATA;
            FParamBuffers[i].ParameterValuePtr := nil;
          end else begin
            // has data
            VBufferLength := FParamBuffers[i].StrLen_or_IndPtr;
            VColumnSize := VBufferLength;
            GetMem(FParamBuffers[i].ParameterValuePtr, FParamBuffers[i].StrLen_or_IndPtr);
            CopyMemory(FParamBuffers[i].ParameterValuePtr, @VBlobData[1], FParamBuffers[i].StrLen_or_IndPtr);
          end;
        end;
      end;
      else begin
        // others - just set NULL
        FParamBuffers[i].ParameterValuePtr := nil;
        FParamBuffers[i].StrLen_or_IndPtr := SQL_NULL_DATA;
      end;
    end;

    // bind
    FResult := SQLBindParameter(
      FSTMTHandle,
      i+1, // inc
      VInputOutputType,
      VValueType,
      VParameterType,
      VColumnSize,
      VDecimalDigits,
      FParamBuffers[i].ParameterValuePtr,
      VBufferLength,
      @(FParamBuffers[i].StrLen_or_IndPtr)
    );

    // check result
    if not SQL_SUCCEEDED(FResult) then
      raise EODBCBindParamsError.CreateWithDiag(FResult, SQL_HANDLE_STMT, FSTMTHandle);
  end;
end;

procedure TODBCStatement.CheckError(const AResult: SQLRETURN);
begin
  if not SQL_SUCCEEDED(AResult) then
    raise EODBCStatementError.CreateWithDiag(AResult, SQL_HANDLE_STMT, FSTMTHandle);
end;

procedure TODBCStatement.CheckErrors;
begin
  // check on connection statement
  if (not IsAllocated) then
    raise EODBCNoStatement.CreateWithDiag(FResult, SQL_HANDLE_DBC, FDBCHandle);

  if FPrepared and (not SQL_SUCCEEDED(FResult)) then
    InternalRaiseODBC(Self, EODBCPrepareStatementError);

  if (not FPrepared) and (not SQL_SUCCEEDED(FResult)) then
    InternalRaiseODBC(Self, EODBCDirectExecStatementError);
end;

constructor TODBCStatement.Create(
  const ADBCHandle: SQLHDBC;
  const AParsedSQLText: WideString
);
begin
  inherited Create;

  FDBCHandle := ADBCHandle;
  FParamBuffers := nil;
  FPrepared := FALSE;

  // allocate statement handle
  FResult := SQLAllocHandle(SQL_HANDLE_STMT, ADBCHandle, FSTMTHandle);

  if SQL_SUCCEEDED(FResult) then begin
    // ok - prepare statement
    if (0<Length(AParsedSQLText)) then begin
      FResult := SQLPrepareW(FSTMTHandle, PWideChar(AParsedSQLText), Length(AParsedSQLText));
      FPrepared := TRUE;
    end;
  end else begin
    // fail
    FSTMTHandle := nil;
  end;
end;

constructor TODBCStatement.CreateAndExecDirect(const ADBCHandle: SQLHDBC; const ADirectSQLText: String);
begin
  inherited Create;

  FDBCHandle := ADBCHandle;
  FParamBuffers := nil;
  FPrepared := FALSE;

  // allocate statement handle
  FResult := SQLAllocHandle(SQL_HANDLE_STMT, ADBCHandle, FSTMTHandle);

  if SQL_SUCCEEDED(FResult) then begin
    // direct exec
    FResult := SQLExecDirectA(FSTMTHandle, PAnsiChar(ADirectSQLText), Length(ADirectSQLText));
  end else begin
    // fail
    FSTMTHandle := nil;
  end;
end;

destructor TODBCStatement.Destroy;
begin
  // SQL_NULL_HSTMT = NIL
  if (SQL_NULL_HSTMT<>FSTMTHandle) then begin
    // free statement
    SQLFreeStmt(FSTMTHandle, SQL_RESET_PARAMS);
    // free handle
    SQLFreeHandle(SQL_HANDLE_STMT, FSTMTHandle);
    FSTMTHandle:=SQL_NULL_HSTMT;
  end;
  FreeParamBuffers;
  inherited;
end;

function TODBCStatement.Execute(const ARowsAffected: PLongInt): SQLRETURN;
begin
  if (not FPrepared) then begin
    // ошибка логики вызова
    raise EODBCStatementNotPreparedException.Create('BindParams');
  end;

  // execute statement
  Result := SQLExecute(FSTMTHandle);

  if (SQL_NO_DATA=Result) then begin
    // no rows affected - but success
    if (nil<>ARowsAffected) then
      ARowsAffected^ := 0;
    Exit;
  end;

  // check result
  CheckError(Result);

  // if OK
  if (nil<>ARowsAffected) then begin
    SQLRowCount(FSTMTHandle, ARowsAffected^);
  end;
  (*
  SQL_SUCCESS,
  SQL_SUCCESS_WITH_INFO,
  SQL_NEED_DATA,
  SQL_STILL_EXECUTING,
  SQL_ERROR,
  SQL_NO_DATA,
  SQL_INVALID_HANDLE,
  SQL_PARAM_DATA_AVAILABLE
  *)
end;

procedure TODBCStatement.FreeParamBuffers;
var i,k: Integer;
begin
  if (nil=FParamBuffers) then
    Exit;

  k := High(FParamBuffers);
  if (k>0) then begin
    for i:=0 to k do begin
      FreeMem(FParamBuffers[i].ParameterValuePtr);
    end;
    SetLength(FParamBuffers,0);
  end;

  FParamBuffers:=nil;
end;

function TODBCStatement.GetAffectedRows: Longint;
begin
  CheckErrors;
  Result := 0;
  SQLRowCount(FSTMTHandle, Result);
end;

function TODBCStatement.GetLastResult: SQLRETURN;
begin
  Result := FResult;
end;

function TODBCStatement.GetODBCHandle: SQLHANDLE;
begin
  Result := FSTMTHandle;
end;

function TODBCStatement.GetODBCType: SQLSMALLINT;
begin
  Result := SQL_HANDLE_STMT;
end;

function TODBCStatement.IsAllocated: Boolean;
begin
  Result := (FSTMTHandle<>nil)
end;

end.
