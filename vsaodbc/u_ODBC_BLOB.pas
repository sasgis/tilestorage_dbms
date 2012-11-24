unit u_ODBC_BLOB;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
{$if defined(USE_MODBC)}
  odbcsql,
  mParams,
{$else}

{$ifend}
  Classes;

type
  TCheckStatementResultProc = procedure(stmthandle: SQLHANDLE; sqlres: SQLRETURN) of object;

  TOdbcBlobStream = class(TMemoryStream)
  private
    const OdbcBlobStaticSize = 64*1024; // 64KB
  private
    // static buffer
    FOdbcBlobStaticBuffer: array [0..OdbcBlobStaticSize-1] of AnsiChar;
  public
    function LoadFromOdbcField(
      const AStatementHandle: SQLHANDLE;
      const AColumnNumber: SQLUSMALLINT; // starting from 1
      const ATargetType: SQLSMALLINT;    // allow SQL_C_DEFAULT
      out ATotalActualSize: SQLINTEGER;  // total size of data (in static buffer and in stream)
      out AOdbcResult: SQLRETURN
    ): Boolean;
    function ReadOdbcFieldAsString(
      const AStatementHandle: SQLHANDLE;
      const AColumnNumber: SQLUSMALLINT; // starting from 1
      const ATargetType: SQLSMALLINT;    // allow SQL_C_DEFAULT
      ACheckStatementResultProc: TCheckStatementResultProc
    ): TmBlobData;
  end;

implementation

{ TOdbcBlobStream }

function TOdbcBlobStream.LoadFromOdbcField(
  const AStatementHandle: SQLHANDLE;
  const AColumnNumber: SQLUSMALLINT;
  const ATargetType: SQLSMALLINT;
  out ATotalActualSize: SQLINTEGER;
  out AOdbcResult: SQLRETURN
): Boolean;
const
  c_big_blob_stream_size = 1024*1024; // 1MB
var
  VStreamAllocSize: Integer;
begin
  // read first chunk and get total length
  AOdbcResult := SQLGetData(
    AStatementHandle,
    AColumnNumber,
    ATargetType {PSQL_C_DEFAULT},
    @FOdbcBlobStaticBuffer,
    OdbcBlobStaticSize,
    @ATotalActualSize
  );

  Result := SQL_SUCCEEDED(AOdbcResult);

  if not Result then
    Exit;

(*
SQLGetData can return the following values in the length/indicator buffer:
The length of the data available to return
SQL_NO_TOTAL
SQL_NULL_DATA
*)

  // NULL value - dont care about stream
  if (SQL_NULL_DATA=ATotalActualSize) or (0=ATotalActualSize) then begin
    ATotalActualSize := 0;
    Result := TRUE;
    Exit;
  end;

  if (SQL_NO_TOTAL=ATotalActualSize) then begin
    // driver don't know (SQL_NO_TOTAL)
    // just get big buffer to hold our tiles
    // but fail on panoramio photos
    // TODO: need correct implementation
    VStreamAllocSize := c_big_blob_stream_size;
  end else begin
    // check size of field
    if (ATotalActualSize<=OdbcBlobStaticSize) then begin
      // aclually done - all data in static buffer
      Result := TRUE;
      Exit;
    end;

    // need stream allocation
    VStreamAllocSize := ATotalActualSize-OdbcBlobStaticSize;
  end;

  if (Self.Size<VStreamAllocSize) then begin
    // (re)allocate
    Self.SetSize(VStreamAllocSize);
  end;

  // read secon chunk
  AOdbcResult := SQLGetData(
    AStatementHandle,
    AColumnNumber,
    ATargetType {PSQL_C_DEFAULT},
    Self.Memory,
    Self.Size,
    @VStreamAllocSize
  );
  
  Result := SQL_SUCCEEDED(AOdbcResult);

  if Result then
  if (SQL_NO_TOTAL=ATotalActualSize) then begin
    // return aclual size
    ATotalActualSize := VStreamAllocSize + OdbcBlobStaticSize;
  end;
end;

function TOdbcBlobStream.ReadOdbcFieldAsString(
  const AStatementHandle: SQLHANDLE;
  const AColumnNumber: SQLUSMALLINT;
  const ATargetType: SQLSMALLINT;
  ACheckStatementResultProc: TCheckStatementResultProc
): TmBlobData;
var
  VTotalActualSize: SQLINTEGER;
  VRes: SQLRETURN;
  VAux: TmBlobData;
begin
  if LoadFromOdbcField(AStatementHandle, AColumnNumber, ATargetType, VTotalActualSize, VRes) then begin
    // success
    if (0=VTotalActualSize) then begin
      // NULL
      Result := '';
    end else if (VTotalActualSize <= OdbcBlobStaticSize) then begin
      // small object - read only from static buffer
      SetString(Result, FOdbcBlobStaticBuffer, VTotalActualSize);
    end else begin
      // read from static buffer (first chunk)
      SetString(Result, FOdbcBlobStaticBuffer, OdbcBlobStaticSize);
      // read from stream object (second chunk)
      SetString(VAux, PChar(Self.Memory), (VTotalActualSize-OdbcBlobStaticSize));
      // concat
      Result :=Result + VAux;
    end;
  end else begin
    // failed
    ACheckStatementResultProc(AStatementHandle, VRes);
  end;

(*
            VBlobMemStream:=TMemoryStream.Create;
            try
              if DataBase.LoadBlobIntoStream(, VBlobMemStream, VBlobMemSize, FALSE) then
              if (VBlobMemStream.Memory<>nil) and (VBlobMemSize>0) then begin
                SetString(VBlobAccum, PChar(VBlobMemStream.Memory), VBlobMemSize);
              end;
            finally
              FreeAndNil(VBlobMemStream);
            end;

*)
end;

end.
