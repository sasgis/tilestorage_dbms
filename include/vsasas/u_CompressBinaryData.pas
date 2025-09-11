unit u_CompressBinaryData;

interface

uses
  Classes,
  c_CompressBinaryData,
  i_7zHolder,
  i_BinaryData;

type
  PCompressTileRec = ^TCompressTileRec;
  TCompressTileRec = record
    // zlib
    FZLibBuf: Pointer;
    FZLibLen: Integer;
    // gzip
    FGzipStream: TMemoryStream;
    // 7z
    F7zBinData: IBinaryData;
  public
    procedure Cleanup;
  end;

const
  ZCompressTileRec: TCompressTileRec = ();
  
// common routines

function Compress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ATileCompressionMode: Byte
): IBinaryData;

function Decompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;

// gzip

function GZDecompress2BinaryData(
  const ASource: IBinaryData
): IBinaryData;

// raw routines

function RawCompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ATileCompressionMode: Byte;
  const ARecPtr: PCompressTileRec
): Boolean;

function RawDecompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ARecPtr: PCompressTileRec
): Boolean;

// set 7z dll holder

procedure Set7zHolder(const A7zHolder: I7zHolder);

implementation

uses
  Windows,
  SysUtils,
  ZLib,
  ALZLibExGZ,
  i_Simple7z,
  //u_StreamReadOnlyByBinaryData,
  u_BinaryDataByMemStream,
  u_BinaryData;

type
  TBinaryDataZLib = class(TBinaryData)
  public
    destructor Destroy; override;
  end;

  TPointerMemoryStream = class(TCustomMemoryStream)
  public
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

  TGZStreamProc = procedure (inStream, outStream: TStream);

var
  G7zHolder: I7zHolder;

procedure Set7zHolder(const A7zHolder: I7zHolder);
begin
  G7zHolder := A7zHolder;
end;

// make IBinaryData routines

function _MakeData(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;
begin
  // by default
  Result := TBinaryData.Create(
    ASize,
    ABuffer,
    False
  );
end;

function _MakeZLib(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;
begin
  // owned!
  Result := TBinaryDataZLib.Create(
    ASize,
    ABuffer,
    True
  );
end;

procedure EnsureMemStream(var AMemStream: TMemoryStream);
begin
  if (AMemStream <> nil) then begin
    AMemStream.Free;
  end;
  AMemStream := TMemoryStream.Create;
end;

// check routines (just simple test)

function CheckZLibHeader(
  const ASize: Integer;
  const ABuffer: Pointer
): Boolean;
begin
  Result := (PByte(ABuffer)^ = $78);
end;

function CheckGZHeader(
  const ASize: Integer;
  const ABuffer: Pointer
): Boolean;
begin
  with PGZHeader(ABuffer)^ do begin
    Result := (ASize >= SizeOf(TGZHeader)) and
              (Id1 = $1F) and (Id2 = $8B) and (Method = Z_DEFLATED);
  end;
end;

function Check7zHeader(
  const ASize: Integer;
  const ABuffer: Pointer
): Boolean;
type
  P7zHead = ^T7zHead;
  T7zHead = packed record
    b37: Byte;
    b7A: Byte;
  end;
begin
  with P7zHead(ABuffer)^ do begin
    Result := (ASize >= SizeOf(T7zHead)) and
              (b37 = $37) and (b7A = $7A);
  end;
end;

// gzip internal

function GZRawInternal(
  const ASize: Integer;
  const ABuffer: Pointer;
  var AStream: TMemoryStream;
  const AProc: TGZStreamProc
): Boolean;
var
  VSrc: TPointerMemoryStream;
begin
  Result := False;
  VSrc := TPointerMemoryStream.Create;
  try
    VSrc.SetPointer(ABuffer, ASize);
    EnsureMemStream(AStream);

    // compress or decompress
    AProc(VSrc, AStream);

    // done
    AStream.Position := 0;
    Inc(Result);
  finally
    VSrc.Free;
  end;
end;

function GZRawCompress2Stream(
  const ASize: Integer;
  const ABuffer: Pointer;
  var AStream: TMemoryStream
): Boolean;
begin
  Result := GZRawInternal(ASize, ABuffer, AStream, GZCompressStream);
end;

function GZRawDecompress2Stream(
  const ASize: Integer;
  const ABuffer: Pointer;
  var AStream: TMemoryStream
): Boolean;
begin
  Result := GZRawInternal(ASize, ABuffer, AStream, GZDecompressStream);
end;

// 7z

function SevenZipRawCompress2Stream(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ARecPtr: PCompressTileRec
): Boolean;
var
  V7zWriter: ISimple7zCompressor;
begin
  Assert(G7zHolder <> nil);

  Result := False;

  V7zWriter := G7zHolder.CreateCompressor;

  // if failed - return False to keep original tile
  if (nil = V7zWriter) then begin
    Exit;
  end;

  // compress
  ARecPtr^.F7zBinData := V7zWriter.CompressBuffer(ASize, ABuffer);
  if (ARecPtr^.F7zBinData <> nil) then begin
    // done
    Inc(Result);
  end;
end;

function SevenZipRawDecompress2Stream(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ARecPtr: PCompressTileRec
): Boolean;
var
  V7zReader: ISimple7zDecompressor;
begin
  Assert(G7zHolder <> nil);
  
  Result := False;

  V7zReader := G7zHolder.CreateDecompressor;

  // if failed - return False to use another lib
  if (nil = V7zReader) then begin
    Exit;
  end;

  // decompress
  ARecPtr^.F7zBinData := V7zReader.DecompressBuffer(ASize, ABuffer);
  if (ARecPtr^.F7zBinData <> nil) then begin
    // done
    Inc(Result);
  end;
end;

// gzip

function GZDecompress2BinaryData(
  const ASource: IBinaryData
): IBinaryData;
var
  VOutput: TMemoryStream;
begin
  Assert(ASource <> nil);
  VOutput := nil;
  try
    GZRawDecompress2Stream(ASource.Size, ASource.Buffer, VOutput);
    // uncompressed
    Result := TBinaryDataByMemStream.CreateWithOwn(VOutput);
    VOutput := nil;
  finally
    VOutput.Free;
  end;
end;

{$IF CompilerVersion >= 19}
procedure CompressBuf(const InBuf: Pointer; InBytes: Integer;
  out OutBuf: Pointer; out OutBytes: Integer); inline;
begin
  ZCompress(InBuf, InBytes, OutBuf, OutBytes);
end;

procedure DecompressBuf(const InBuf: Pointer; InBytes: Integer;
  OutEstimate: Integer; out OutBuf: Pointer; out OutBytes: Integer); inline;
begin
  ZDecompress(InBuf, InBytes, OutBuf, OutBytes, OutEstimate);
end;
{$IFEND}

// raw routines

function RawCompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ATileCompressionMode: Byte;
  const ARecPtr: PCompressTileRec
): Boolean;
begin
  Assert(ABuffer <> nil);
  Assert(ASize > 0);
  Result := False;

  with ARecPtr^ do
  case ATileCompressionMode of
    tcm_zlib: begin
      // zlib (deflate)
      try
        CompressBuf(ABuffer, ASize, FZLibBuf, FZLibLen);
      except
        // raise if error
        FZLibBuf := nil;
      end;
      if (FZLibBuf <> nil) and (FZLibLen < ASize) then begin
        // only if smaller than original
        Inc(Result);
      end;
    end;

    tcm_gzip: begin
      // gzip
      Result := GZRawCompress2Stream(ASize, ABuffer, FGzipStream);
      if Result then begin
        // keep uncompressed if not available
        // and only if smaller than original
        if (nil = FGzipStream) or (FGzipStream.Size >= ASize) then
          Result := False;
      end;
    end;

    tcm_7z_lzma: begin
      // 7z
      Result := SevenZipRawCompress2Stream(ASize, ABuffer, ARecPtr);
      if Result then begin
        // keep uncompressed if not available
        // and only if smaller than original
        (*
        // DEBUGGING:
        with TStreamReadOnlyByBinaryData.Create(F7zBinData) do begin
          SaveToFile('C:\7z_tile_compressed.7z');
          Free;
        end;
        *)
        if (nil = F7zBinData) or (F7zBinData.Size >= ASize) then
          Result := False;
      end;
    end;
  end;

(*
src = 1293424

zlib:
dst = 364348
screen decompress time = 0.67 - 0.79

gzip:
dst = 365042
screen decompress time = 0.52 - 0.68

7z lzma (5-20):
dst = 245945
screen decompress time = 0.92 - 1.1

7z ppmd:
dst = 294243
screen decompress time = 4.5

7z bzip2:
dst = 327282
screen decompress time = 13

*)
end;

function RawDecompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ARecPtr: PCompressTileRec
): Boolean;
begin
  Assert(ABuffer <> nil);
  Assert(ASize > 0);
  Result := False;
  
  // RFC 1950 ZLIB Compressed Data Format Specification version 3.3
  // RFC 1951 DEFLATE Compressed Data Format Specification version 1.3
  // RFC 1952 GZIP file format specification version 4.3

  // simple check for GZip
  if CheckGZHeader(ASize, ABuffer) then
  with ARecPtr^ do
  try
    // try to decompress
    Result := GZRawDecompress2Stream(ASize, ABuffer, FGzipStream);
    if Result then begin
      if (nil = FGzipStream) then
        Result := False;
      Exit;
    end;
  except
  end;

  // simple check for ZLib
  if CheckZLibHeader(ASize, ABuffer) then
  with ARecPtr^ do
  try
    // try to decompress
    DecompressBuf(ABuffer, ASize, 0, FZLibBuf, FZLibLen);
    Inc(Result);
    Exit;
  except
    // raise on error
    FZLibBuf := nil;
  end;

  // simple check for 7z
  if Check7zHeader(ASize, ABuffer) then begin
    Result := SevenZipRawDecompress2Stream(ASize, ABuffer, ARecPtr);
    if Result then begin
      // decompressed
      Exit;
    end;
  end;

  // last chance - force zlib
  with ARecPtr^ do
  try
    // try to decompress
    DecompressBuf(ABuffer, ASize, 0, FZLibBuf, FZLibLen);
    Inc(Result);
    Exit;
  except
    // raise on error
    FZLibBuf := nil;
  end;
end;

// common routines

function Compress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer;
  const ATileCompressionMode: Byte
): IBinaryData;
var
  VRec: TCompressTileRec;
begin
  VRec := ZCompressTileRec;
  try
    if RawCompress2BinaryData(ASize, ABuffer, ATileCompressionMode, @VRec) then begin
      // compressed
      with VRec do
      if (FZLibBuf <> nil) then begin
        // zlib
        Result := _MakeZLib(FZLibLen, FZLibBuf);
        FZLibBuf := nil;
      end else if (FGzipStream <> nil) then begin
        // gzip
        Result := TBinaryDataByMemStream.CreateWithOwn(FGzipStream);
        FGzipStream := nil;
      end else begin
        // 7z
        Result := F7zBinData;
      end;
    end else begin
      // keep uncompressed
      Result := _MakeData(ASize, ABuffer);
    end;
  finally
    VRec.Cleanup;
  end;
end;

function Decompress2BinaryData(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;
var
  VRec: TCompressTileRec;
begin
  VRec := ZCompressTileRec;
  try
    if RawDecompress2BinaryData(ASize, ABuffer, @VRec) then begin
      // decompressed
      with VRec do
      if (FZLibBuf <> nil) then begin
        // zlib
        Result := _MakeZLib(FZLibLen, FZLibBuf);
        FZLibBuf := nil;
      end else if (FGzipStream <> nil) then begin
        // gzip
        Result := TBinaryDataByMemStream.CreateWithOwn(FGzipStream);
        FGzipStream := nil;
      end else begin
        // 7z
        Result := F7zBinData;
      end;
    end else begin
      // use original data
      Result := _MakeData(ASize, ABuffer);
    end;
  finally
    VRec.Cleanup;
  end;
end;

{ TBinaryDataZLib }

destructor TBinaryDataZLib.Destroy;
begin
  if (FBuffer <> nil) then begin
    zlibFreeMem(nil, FBuffer);
    FBuffer := nil;
  end;
  inherited;
end;

{ TPointerMemoryStream }

function TPointerMemoryStream.Write(const Buffer; Count: Integer): Longint;
begin
  Result := 0;
end;

{ TCompressTileRec }

procedure TCompressTileRec.Cleanup;
begin
  if (FGzipStream <> nil) then begin
    FGzipStream.Free;
  end;
  if (FZLibBuf <> nil) then begin
    zlibFreeMem(nil, FZLibBuf);
  end;
  if (F7zBinData <> nil) then begin
    F7zBinData := nil;
  end;
end;

initialization
  G7zHolder := nil;
finalization
  G7zHolder := nil;
end.
