unit u_Simple7z;

interface

uses
  Windows,
  SysUtils,
  Classes,
  SevenZip,
  i_BinaryData,
  i_Simple7z,
  u_BaseInterfacedObject,
  ActiveX;

const
  c_7z_dll = '7z.dll';

type
  T7zCreateObjectFunc = function (const clsid, iid :TGUID; var outObject): HRESULT; stdcall;

  TSimple7zObject = class(TBaseInterfacedObject)
  private
    FHolder: ISimple7zHolder;
    FCreateObjectAddr: Pointer;
    FDLLHandle: THandle;
    FObjRes: HRESULT;
  protected
    procedure DoCreateObject; virtual; abstract;
  public
    constructor Create(const AHolder: ISimple7zHolder);
    destructor Destroy; override;
  end;

  TSimple7zHolder = class(TSimple7zObject, ISimple7zHolder)
  private
    { ISimple7zHolder }
    function GetCreateObjectAddress: Pointer;
  protected
    procedure DoCreateObject; override;
  end;

  TSimple7zDecompressor = class(TSimple7zObject, ISimple7zDecompressor)
  private
    FInArchive: IInArchive;
  private
    { ISimple7zDecompressor }
    function DecompressBuffer(
      const ASize: Integer;
      const ABuffer: Pointer
    ): IBinaryData;
  protected
    procedure DoCreateObject; override;
  end;

  TSimple7zCompressor = class(TSimple7zObject, ISimple7zCompressor)
  private
    FOutArchive: IOutArchive;
  private
    procedure SetCompressionMode;
  private
    { ISimple7zCompressor }
    function CompressBuffer(
      const ASize: Integer;
      const ABuffer: Pointer
    ): IBinaryData;
  protected
    procedure DoCreateObject; override;
  end;

  // binary data and 7z streams implementation
  TBinaryDataBy7zCustom = class(TBaseInterfacedObject,
                                IBinaryData,
                                ISequentialOutStream,
                                IOutStream,
                                IOutStreamFlush,
                                ISequentialInStream,
                                IInStream,
                                IStreamGetSize,
                                IProgress)
  private
    FSrcSize: Integer;
    FSrcBuffer: Pointer;
    FSrcPosition: Integer;
    FOutSize: Integer;
    FOutBuffer: Pointer;
    FOutCapacity: Integer;
    FOutPosition: Integer;
  private
    // out
    procedure CleanupOut;
    procedure SetCapacity(const ANewCapacity: Integer);
    function SeekOut(const Offset: Integer; const Origin: Word): Integer; overload;
    function SeekOut(const Offset: Int64; const Origin: TSeekOrigin): Int64; overload;
    // src
    function SeekSrc(const Offset: Integer; const Origin: Word): Integer; overload;
    function SeekSrc(const Offset: Int64; const Origin: TSeekOrigin): Int64; overload;
  private
    { IBinaryData }
    function GetBuffer: Pointer;
    function GetSize: Integer;
    { ISequentialOutStream }
    function Write(data: Pointer; size: Cardinal; processedSize: PCardinal): HRESULT; stdcall;
    { IOutStream }
    function IOutStream_Seek(offset: Int64; seekOrigin: Cardinal; newPosition: PInt64): HRESULT; stdcall;
    function IOutStream.Seek = IOutStream_Seek;
    function SetSize(newSize: Int64): HRESULT; stdcall;
    { IOutStreamFlush }
    function Flush: HRESULT; stdcall;
    { ISequentialInStream }
    function Read(data: Pointer; size: Cardinal; processedSize: PCardinal): HRESULT; stdcall;
    { IInStream }
    function Seek(offset: Int64; seekOrigin: Cardinal; newPosition: PInt64): HRESULT; stdcall;
    { IStreamGetSize }
    function IStreamGetSize_GetSize(size: PInt64): HRESULT; stdcall;
    function IStreamGetSize.GetSize = IStreamGetSize_GetSize;
    { IProgress }
    function SetTotal(total: Int64): HRESULT; stdcall;
    function SetCompleted(completeValue: PInt64): HRESULT; stdcall;
  public
    constructor Create(
      const ASrcSize: Integer;
      const ASrcBuffer: Pointer
    );
    destructor Destroy; override;
  end;

  TBinaryDataBy7zCompressor = class(TBinaryDataBy7zCustom,
                                    IArchiveUpdateCallback
                                    )
  private
    { IArchiveUpdateCallback }
    function GetUpdateItemInfo(index: Cardinal;
      newData: PInteger; // 1 - new data, 0 - old data
      newProperties: PInteger; // 1 - new properties, 0 - old properties
      indexInArchive: PCardinal // -1 if there is no in archive, or if doesn't matter
    ): HRESULT; stdcall;
    function GetProperty(index: Cardinal; propID: PROPID; var value: OleVariant): HRESULT; stdcall;
    function GetStream(index: Cardinal; var inStream: ISequentialInStream): HRESULT; stdcall;
    function SetOperationResult(operationResult: Integer): HRESULT; stdcall;
  end;

  TBinaryDataBy7zDecompressor = class(TBinaryDataBy7zCustom,
                                      IArchiveOpenCallBack,
                                      IArchiveExtractCallback)
  private
    { IArchiveOpenCallBack }
    function IArchiveOpenCallBack_SetTotal(files, bytes: PInt64): HRESULT; stdcall;
    function IArchiveOpenCallBack.SetTotal = IArchiveOpenCallBack_SetTotal;
    function IArchiveOpenCallBack_SetCompleted(files, bytes: PInt64): HRESULT; stdcall;
    function IArchiveOpenCallBack.SetCompleted = IArchiveOpenCallBack_SetCompleted;
    { IArchiveExtractCallback }
    function GetStream(
      index: Cardinal;
      var outStream: ISequentialOutStream;
      askExtractMode: NAskMode
    ): HRESULT; stdcall;
    // GetStream OUT: S_OK - OK, S_FALSE - skeep this file
    function PrepareOperation(askExtractMode: NAskMode): HRESULT; stdcall;
    function SetOperationResult(resultEOperationResult: NExtOperationResult): HRESULT; stdcall;
  end;

implementation

uses
  SysConst,
  RTLConsts;

const
  ZFileTime: TFileTime = ();
  MemoryDelta = $2000; { Must be a power of 2 }
  MAXCHECK : int64 = (1 shl 20);

procedure RINOK(const hr: HRESULT);
begin
  if hr <> S_OK then
    raise Exception.Create(SysErrorMessage(hr));
end;
  
{ TSimple7zCompressor }

function TSimple7zCompressor.CompressBuffer(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;
var
  VResult: HRESULT;
  VOutStream: ISequentialOutStream;
  VOutCallback: IArchiveUpdateCallback;
begin
  if (FOutArchive <> nil) then
  try
    // make result object
    Result := TBinaryDataBy7zCompressor.Create(
      ASize,
      ABuffer
    );

    // prepare
    Supports(Result, ISequentialOutStream, VOutStream);
    Assert(VOutStream <> nil);
    Supports(Result, IArchiveUpdateCallback, VOutCallback);
    Assert(VOutCallback <> nil);

    // compress to result object
    VResult := FOutArchive.UpdateItems(VOutStream, 1, VOutCallback);
    if (VResult <> S_OK) then begin
      // failed
      Result := nil;
    end;
  except
    Result := nil;
  end;
end;

procedure TSimple7zCompressor.DoCreateObject;
begin
  if (FCreateObjectAddr <> nil) then
  if (FOutArchive = nil) then begin
    FObjRes := T7zCreateObjectFunc(FCreateObjectAddr)(CLSID_CFormat7z, IOutArchive, FOutArchive);
    if Succeeded(FObjRes) then begin
      SetCompressionMode;
    end;
  end;
end;

procedure TSimple7zCompressor.SetCompressionMode;
const
  c_METHOD: T7zCompressionMethod = m7LZMA;
  cCompMode: PWideChar = '0';
  cCompLevel: PWideChar = 'X';
  cDictionary: PWideChar = 'd';
  cMultiThreading: PWideChar = 'MT';
  cSolid: PWideChar = 's';
  cCompressionMethod: array[T7zCompressionMethod] of PWideChar = ('COPY', 'LZMA', 'BZIP2', 'PPMD', 'DEFLATE', 'DEFLATE64');
  cBoolProp: array [Boolean] of PWideChar = ('OFF', 'ON');
var
  VSetProperties: ISetProperties;
  VPropNames: array [0..5] of PWideChar;
  VPropArray: array [0..5] of PROPVARIANT;
  VPropCount: Integer;
begin
  if (FOutArchive <> nil) then
  if Supports(FOutArchive, ISetProperties, VSetProperties) then begin
    VPropCount := 0;

    case c_METHOD of
      m7LZMA: begin
        // additional params for LZMA

        // procedure SetDictionnarySize(Arch: I7zOutArchive; size: Cardinal);
        VPropNames[VPropCount] := cDictionary;
        VPropArray[VPropCount].vt := VT_UI4;
        VPropArray[VPropCount].ulVal := 20;
        Inc(VPropCount);

        // procedure SevenZipSetSolidSettings(Arch: I7zOutArchive; solid: boolean);
        VPropNames[VPropCount] := cSolid;
        VPropArray[VPropCount].vt := VT_BSTR;
        VPropArray[VPropCount].bstrVal := cBoolProp[False];
        Inc(VPropCount);
      end;
      m7PPMd: begin
        // additional params for PPMd
        
      end;
    end;

    // procedure SetCompressionLevel(Arch: I7zOutArchive; level: Cardinal);
    VPropNames[VPropCount] := cCompLevel;
    VPropArray[VPropCount].vt := VT_UI4;
    VPropArray[VPropCount].ulVal := 5; // ( SAVE=0, FAST=3, NORMAL=5, MAXIMUM=7, ULTRA=9)
    Inc(VPropCount);

    // procedure SetMultiThreading(Arch: I7zOutArchive; ThreadCount: Cardinal);
    VPropNames[VPropCount] := cMultiThreading;
    VPropArray[VPropCount].vt := VT_UI4;
    VPropArray[VPropCount].ulVal := 1;
    Inc(VPropCount);

    // procedure SevenZipSetCompressionMethod(Arch: I7zOutArchive; method: T7zCompressionMethod);
    VPropNames[VPropCount] := cCompMode;
    VPropArray[VPropCount].vt := VT_BSTR;
    VPropArray[VPropCount].bstrVal := cCompressionMethod[c_METHOD];
    Inc(VPropCount);

    // apply
    RINOK(
      VSetProperties.SetProperties(@VPropNames, @VPropArray, VPropCount)
    )
    ;
  end;
end;

{ TSimple7zDecompressor }

function TSimple7zDecompressor.DecompressBuffer(
  const ASize: Integer;
  const ABuffer: Pointer
): IBinaryData;
var
  VIndex: Cardinal;
  VInStream: IInStream;
  VOpenCallback: IArchiveOpenCallBack;
  VOutCallback: IArchiveExtractCallback;
  VResult: HRESULT;
begin
  try
    // make result object
    Result := TBinaryDataBy7zDecompressor.Create(
      ASize,
      ABuffer
    );

    // prepare
    Supports(Result, IInStream, VInStream);
    Assert(VInStream <> nil);
    Supports(Result, IArchiveOpenCallBack, VOpenCallback);
    Assert(VOpenCallback <> nil);

    VResult := FInArchive.Open(VInStream, @MAXCHECK, VOpenCallback);
    if (VResult <> S_OK) then begin
      // failed
      Result := nil;
      Exit;
    end;

    Supports(Result, IArchiveExtractCallback, VOutCallback);
    Assert(VOutCallback <> nil);

    // decompress to result object
    VIndex := 0;
    VResult := FInArchive.Extract(@VIndex, 1, 0, VOutCallback);
    if (VResult <> S_OK) then begin
      // failed
      Result := nil;
    end;
  except
    Result := nil;
  end;

  // create stream interface
  // V7zStream := T7zStream.Create(VSrc, soReference);

  // open stream interface
  // V7zReader.OpenStream(V7zStream);

  // decompress
  // V7zReader.ExtractItem(0, ARecPtr^.FStream, False);
  // RINOK(FInArchive.Extract(@item, 1, 0, self as IArchiveExtractCallback));
end;

procedure TSimple7zDecompressor.DoCreateObject;
begin
  if (FCreateObjectAddr <> nil) then
  if (FInArchive = nil) then begin
    FObjRes := T7zCreateObjectFunc(FCreateObjectAddr)(CLSID_CFormat7z, IInArchive, FInArchive);
  end;
end;

{ TSimple7zObject }

constructor TSimple7zObject.Create(const AHolder: ISimple7zHolder);
begin
  inherited Create;
  FHolder := AHolder;
  FObjRes := 0;

  if (nil = AHolder) then begin
    FDLLHandle := LoadLibrary(c_7z_dll);
    // detect factory function
    if (FDLLHandle <> 0) then begin
      FCreateObjectAddr := GetProcAddress(FDLLHandle, 'CreateObject');
    end else begin
      // not loaded
      FCreateObjectAddr := nil;
    end;
  end else begin
    // get from holder
    FDLLHandle := 0;
    FCreateObjectAddr := AHolder.GetCreateObjectAddress;
  end;

  DoCreateObject;
end;

destructor TSimple7zObject.Destroy;
begin
  if (FDLLHandle <> 0) then begin
    FreeLibrary(FDLLHandle);
    FDLLHandle := 0;
  end;
  inherited;
end;

{ TBinaryDataBy7zCompressor }

function TBinaryDataBy7zCompressor.GetProperty(
  index: Cardinal;
  propID: PROPID;
  var value: OleVariant
): HRESULT;
begin
  case propID of
    kpidAttributes:
      begin
        TPropVariant(Value).vt := VT_UI4;
{$WARN SYMBOL_PLATFORM OFF}
        TPropVariant(Value).ulVal := faArchive;
{$WARN SYMBOL_PLATFORM ON}
      end;
    kpidLastWriteTime:
      begin
        TPropVariant(value).vt := VT_FILETIME;
        TPropVariant(value).filetime := ZFileTime;
      end;
    kpidPath:
      begin
        (*
        if item.Path <> '' then
          value := item.Path;
        *)
      end;
    kpidIsFolder: Value := False;
    kpidSize:
      begin
        TPropVariant(Value).vt := VT_UI8;
        TPropVariant(Value).uhVal.QuadPart := FSrcSize;
      end;
    kpidCreationTime:
      begin
        TPropVariant(value).vt := VT_FILETIME;
        TPropVariant(value).filetime := ZFileTime;
      end;
    kpidIsAnti: value := False;
  else
   // beep(0,0);
  end;
  Result := S_OK;
end;

function TBinaryDataBy7zCompressor.GetStream(
  index: Cardinal;
  var inStream: ISequentialInStream
): HRESULT;
begin
  inStream := (Self as ISequentialInStream);
  Result := S_OK;
end;

function TBinaryDataBy7zCompressor.GetUpdateItemInfo(
  index: Cardinal;
  newData, newProperties: PInteger;
  indexInArchive: PCardinal
): HRESULT;
begin
  newData^ := 1;
  newProperties^ := 1;
  indexInArchive^ := Cardinal(-1);
  Result := S_OK;
end;

function TBinaryDataBy7zCompressor.SetOperationResult(
  operationResult: Integer): HRESULT;
begin
  Result := S_OK;
end;

{ TBinaryDataBy7zCustom }

procedure TBinaryDataBy7zCustom.CleanupOut;
begin
  if (FOutBuffer <> nil) then begin
    FreeMem(FOutBuffer);
    FOutBuffer := nil;
  end;
  FOutCapacity := 0;
  FOutSize := 0;
  FOutPosition := 0;
end;

constructor TBinaryDataBy7zCustom.Create(
  const ASrcSize: Integer;
  const ASrcBuffer: Pointer
);
begin
  inherited Create;
  // src
  FSrcSize := ASrcSize;
  FSrcBuffer := ASrcBuffer;
  FSrcPosition := 0;
  // dst
  FOutSize := 0;
  FOutBuffer := nil;
  FOutCapacity := 0;
  FOutPosition := 0;
end;

destructor TBinaryDataBy7zCustom.Destroy;
begin
  CleanupOut;
  inherited;
end;

function TBinaryDataBy7zCustom.Flush: HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.GetBuffer: Pointer;
begin
  // output data
  Result := FOutBuffer;
end;

function TBinaryDataBy7zCustom.GetSize: Integer;
begin
  // output data
  Result := FOutSize;
end;

function TBinaryDataBy7zCustom.IOutStream_Seek(
  offset: Int64;
  seekOrigin: Cardinal;
  newPosition: PInt64
): HRESULT;
begin
  SeekOut(offset, TSeekOrigin(seekOrigin));
  if newPosition <> nil then
    newPosition^ := FOutPosition;
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.IStreamGetSize_GetSize(
  size: PInt64): HRESULT;
begin
  if size <> nil then
    size^ := FSrcSize;
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.Read(
  data: Pointer;
  size: Cardinal;
  processedSize: PCardinal
): HRESULT;
var
  VWritten: Integer;
begin
  if (FSrcPosition >= 0) and (Integer(size) >= 0) then
  begin
    VWritten := FSrcSize - FSrcPosition;
    if VWritten > 0 then
    begin
      // success
      if VWritten > Integer(size) then VWritten := size;
      Move(Pointer(Longint(FSrcBuffer) + FSrcPosition)^, data^, VWritten);
      Inc(FSrcPosition, VWritten);
      Result := S_OK;
      if (processedSize <> nil) then
        processedSize^ := VWritten;
    end else begin
      // end of stream
      Result := S_OK;
      if (processedSize <> nil) then
        processedSize^ := 0;
    end;
    Exit;
  end;

  // nothing to read
  if (size > 0) then begin
    // failed
    Result := E_FAIL;
  end else begin
    Result := S_OK;
  end;
  if (processedSize <> nil) then begin
    processedSize^ := 0;
  end;
end;

function TBinaryDataBy7zCustom.Seek(
  offset: Int64;
  seekOrigin: Cardinal;
  newPosition: PInt64
): HRESULT;
begin
  SeekSrc(offset, TSeekOrigin(seekOrigin));
  if newPosition <> nil then
    newPosition^ := FSrcPosition;
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.SeekOut(const Offset: Integer; const Origin: Word): Integer;
begin
  case Origin of
    soFromBeginning: FOutPosition := Offset;
    soFromCurrent: Inc(FOutPosition, Offset);
    soFromEnd: FOutPosition := FOutSize + Offset;
  end;
  Result := FOutPosition;
end;

function TBinaryDataBy7zCustom.SeekOut(const Offset: Int64;
  const Origin: TSeekOrigin): Int64;
begin
  if (Offset < Low(Longint)) or (Offset > High(Longint)) then
    raise ERangeError.CreateRes(@SRangeError);
  Result := SeekOut(Longint(Offset), Ord(Origin));
end;

function TBinaryDataBy7zCustom.SeekSrc(const Offset: Integer; const Origin: Word): Integer;
begin
  case Origin of
    soFromBeginning: FSrcPosition := Offset;
    soFromCurrent: Inc(FSrcPosition, Offset);
    soFromEnd: FSrcPosition := FSrcSize + Offset;
  end;
  Result := FSrcPosition;
end;

function TBinaryDataBy7zCustom.SeekSrc(const Offset: Int64;
  const Origin: TSeekOrigin): Int64;
begin
  if (Offset < Low(Longint)) or (Offset > High(Longint)) then
    raise ERangeError.CreateRes(@SRangeError);
  Result := SeekSrc(Longint(Offset), Ord(Origin));
end;

procedure TBinaryDataBy7zCustom.SetCapacity(const ANewCapacity: Integer);
var
  VNewCapacity: Integer;
begin
  if (ANewCapacity > 0) and (ANewCapacity <> FOutSize) then
    VNewCapacity := (ANewCapacity + (MemoryDelta - 1)) and not (MemoryDelta - 1)
  else
    VNewCapacity := ANewCapacity;

  if (0 = VNewCapacity) then begin
    CleanupOut;
  end else begin
    // alloc or realloc memory
    if (FOutBuffer <> nil) then begin
      ReallocMem(FOutBuffer, VNewCapacity);
    end else begin
      GetMem(FOutBuffer, VNewCapacity);
    end;
    if FOutBuffer = nil then
      raise EStreamError.CreateRes(@SMemoryStreamError);
    FOutCapacity := VNewCapacity;
  end;
end;

function TBinaryDataBy7zCustom.SetCompleted(completeValue: PInt64): HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.SetSize(newSize: Int64): HRESULT;
var
  VNewCapacity: Integer;
begin
  if (newSize > 0) then begin
    VNewCapacity := newSize;
    if FOutCapacity < VNewCapacity then begin
      SetCapacity(VNewCapacity);
    end;
    FOutSize := newSize;
    Result := S_OK;
  end else begin
    CleanupOut;
    Result := S_OK;
  end;
end;

function TBinaryDataBy7zCustom.SetTotal(total: Int64): HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zCustom.Write(
  data: Pointer;
  size: Cardinal;
  processedSize: PCardinal
): HRESULT;
var
  VNewPos: Integer;
begin
  if (FOutPosition >= 0) and (Integer(size) >= 0) then
  begin
    VNewPos := FOutPosition + Integer(size);
    if VNewPos > 0 then
    begin
      if VNewPos > FOutSize then
      begin
        if VNewPos > FOutCapacity then
          SetCapacity(VNewPos);
        FOutSize := VNewPos;
      end;
      System.Move(data^, Pointer(Longint(FOutBuffer) + FOutPosition)^, size);
      FOutPosition := VNewPos;
      if (processedSize <> nil) then begin
        processedSize^ := size;
      end;
      Result := S_OK;
      Exit;
    end;
  end;

  // nothing to write
  if (size > 0) then begin
    // failed
    Result := E_FAIL;
  end else begin
    Result := S_OK;
  end;
  if (processedSize <> nil) then begin
    processedSize^ := 0;
  end;
end;

{ TBinaryDataBy7zDecompressor }

function TBinaryDataBy7zDecompressor.GetStream(
  index: Cardinal;
  var outStream: ISequentialOutStream;
  askExtractMode: NAskMode
): HRESULT;
begin
  outStream := (Self as ISequentialOutStream);
  Result := S_OK;
end;

function TBinaryDataBy7zDecompressor.IArchiveOpenCallBack_SetCompleted(files, bytes: PInt64): HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zDecompressor.IArchiveOpenCallBack_SetTotal(files, bytes: PInt64): HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zDecompressor.PrepareOperation(
  askExtractMode: NAskMode): HRESULT;
begin
  Result := S_OK;
end;

function TBinaryDataBy7zDecompressor.SetOperationResult(
  resultEOperationResult: NExtOperationResult): HRESULT;
begin
  Result := S_OK;
end;

{ TSimple7zHolder }

procedure TSimple7zHolder.DoCreateObject;
begin
  // empty
end;

function TSimple7zHolder.GetCreateObjectAddress: Pointer;
begin
  if (FDLLHandle <> 0) then
    Result := FCreateObjectAddr
  else
    Result := nil;
end;

end.
