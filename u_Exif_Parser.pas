unit u_Exif_Parser;

interface

uses
  Windows,
  SysUtils,
  Classes;

type
  TPointedMemoryStream = class(TMemoryStream)
  end;
  
function FindExifInJpeg(const AJpegBuffer: Pointer;
                        const AJpegSize: Cardinal;
                        const AForGE: Boolean;
                        const AExifTag: Word;
                        out AOffset: PByte;
                        out ASize: DWORD): Boolean; stdcall;

implementation

type
  // 4.6.2 IFD Structure
  // The IFD used in this standard consists of:
  // a 2-byte count (number of fields),
  // 12-byte field Interoperability arrays,
  // and 4-byte offset to the next IFD, in conformance with TIFF Rev. 6.0.
  TIFD_12 = packed record
    tag: Word;     // Bytes 0-1 Tag
    type_: Word;      // Bytes 2-3 Type
    count: DWORD;  // Bytes 4-7 Count
    offset: DWORD; // Bytes 8-11 Value Offset
  end;
  PIFD_12 = ^TIFD_12;

  TIFD_NN = packed record
    number_of_fields: Word;
    items: array of TIFD_12;
    offset_to_next: DWORD;
  end;
  PIFD_NN = ^TIFD_NN;

function FindExifInJpeg(const AJpegBuffer: Pointer;
                        const AJpegSize: Cardinal;
                        const AForGE: Boolean;
                        const AExifTag: Word;
                        out AOffset: PByte;
                        out ASize: DWORD): Boolean; stdcall;
const
  c_SOI_Size = 1024;

  function _GetNextWord(ASrcPtr: PByte): Word;
  begin
    //CopyMemory(@Result, ASrcPtr, sizeof(Result));
    Result := ASrcPtr^;
    Result := (Result shl 8);
    Inc(ASrcPtr);
    Result := Result + ASrcPtr^;
  end;

  function _GetNextDWORD(ASrcPtr: PByte): DWORD;
  begin
    //CopyMemory(@Result, ASrcPtr, sizeof(Result));
    Result := ASrcPtr^;

    Result := (Result shl 8);
    Inc(ASrcPtr);
    Result := Result + ASrcPtr^;

    Result := (Result shl 8);
    Inc(ASrcPtr);
    Result := Result + ASrcPtr^;

    Result := (Result shl 8);
    Inc(ASrcPtr);
    Result := Result + ASrcPtr^;
  end;

  procedure _ReadIFD12(var ASrcPtr: PByte;
                       p: PIFD_12);
  begin
    p^.tag := _GetNextWord(ASrcPtr);
    Inc(ASrcPtr,2);
    p^.type_ := _GetNextWord(ASrcPtr);
    Inc(ASrcPtr,2);
    p^.count := _GetNextDWORD(ASrcPtr);
    Inc(ASrcPtr,4);
    p^.offset := _GetNextDWORD(ASrcPtr);
    Inc(ASrcPtr,4);
  end;

  function _FindSection(const ASrcPtr: PByte;
                        const AByte1, AByte2: Byte;
                        const AMaxSteps: Word;
                        out ANewPtr: PByte): Boolean;
  var i: Word;
  begin
    Result:=FALSE;
    ANewPtr:=ASrcPtr;
    i:=AMaxSteps;
    while (i>0) do begin
      // check
      if (AByte1=ANewPtr^) then begin
        Inc(ANewPtr);
        if (AByte2=ANewPtr^) then begin
          Inc(ANewPtr);
          Result:=TRUE;
          Exit;
        end;
      end;
      // next
      Inc(ANewPtr);
      Dec(i);
    end;
  end;

var
  VChkLen, VEndian, V42: Word;
  VIFD0: DWORD;
  VSOIPtr, VAPP1Ptr, VPointer: PByte;
  VIFD_NN: TIFD_NN;
  VTagFound: Boolean;
  
begin
  Result:=FALSE;
  AOffset:=nil;
  ASize:=0;

  if (nil=AJpegBuffer) or (0=AJpegSize) then
    Exit;

  // test stream - get SOI section
  if (AJpegSize>=c_SOI_Size) then
    VChkLen:=c_SOI_Size
  else
    VChkLen:=AJpegSize;

  if not _FindSection(AJpegBuffer, $FF, $D8, VChkLen, VSOIPtr) then
    Exit;

  // get JFIF as $FF $E0
  // skipped

  if AForGE then begin
    // get $FF $FE
    if not _FindSection(VSOIPtr, $FF, $FE, VChkLen, AOffset) then
      Exit;

    // get size of section
    VEndian := _GetNextWord(AOffset);

    Inc(AOffset,2);

    // done
    ASize := VEndian;
    Inc(Result);
    
    Exit;
  end;

  // get APP1
  if not _FindSection(VSOIPtr, $FF, $E1, VChkLen, VAPP1Ptr) then
    Exit;

  VPointer:=VAPP1Ptr;
  Inc(VPointer,2); // size of APP1

  // check Exif tag
  VTagFound:=FALSE;
  if ({'E'}$45=VPointer^) then begin
    Inc(VPointer);
    if ({'x'}$78=VPointer^) then begin
      Inc(VPointer);
      if ({'i'}$69=VPointer^) then begin
        Inc(VPointer);
        if ({'f'}$66=VPointer^) then begin
          Inc(VPointer);
          VTagFound:=TRUE;
        end;
      end;
    end;
  end;

  if (not VTagFound) then
    Exit;

  // check next zeroes
  VTagFound:=FALSE;
  if ($00=VPointer^) then begin
    Inc(VPointer);
    if ($00=VPointer^) then begin
      Inc(VPointer);
      VTagFound:=TRUE;
    end;
  end;
    
  if (not VTagFound) then
    Exit;

  // Attribute information goes here
  AOffset := VPointer;

  // get (4949.H) (little endian) or "MM" (4D4D.H) (big endian)
  VEndian := _GetNextWord(VPointer);

  if ($4949<>VEndian) and ($4D4D<>VEndian) then
    Exit;

  Inc(VPointer, 2);

  // get 42 (2 bytes) = 002A.H (fixed)
  V42 := _GetNextWord(VPointer);

  if ($002A<>V42) then
    Exit;

  Inc(VPointer, 2);

  // get 0th IFD offset (4 bytes).
  // If the TIFF header is followed immediately by the 0th IFD, it is written as 00000008.H.
  VIFD0 := _GetNextDWORD(VPointer);
  Inc(VPointer, 4);

  if (VIFD0<>$00000008) then
    Inc(VPointer,(VIFD0-$00000008));

  // IFD 0th
  // The IFD used in this standard consists of:
  // a 2-byte count (number of fields),
  // 12-byte field Interoperability arrays,
  // and 4-byte offset to the next IFD, in conformance with TIFF Rev. 6.0.
  VIFD_NN.number_of_fields := _GetNextWord(VPointer);
  if (0=VIFD_NN.number_of_fields) then
    Exit;

  // $00 $02
  SetLength(VIFD_NN.items, VIFD_NN.number_of_fields);
  Inc(VPointer, 2);

  // read items
  // $82 $98 $00 $02 $00 $00 $00 $20 $00 $00 $00 $26
  // $87 $69 $00 $04 $00 $00 $00 $01 $00 $00 $00 $46
  for V42 := 0 to VIFD_NN.number_of_fields-1 do begin
    _ReadIFD12(VPointer, @(VIFD_NN.items[V42]));
  end;

  // read next IFD offset
  // $00 $00 $00 $00
  VIFD_NN.offset_to_next := _GetNextDWORD(VPointer);
  Inc(VPointer, 4);

  // TODO: check next IFDs in loop

  VTagFound:=FALSE;
  // loop items for Exif
  for V42 := 0 to VIFD_NN.number_of_fields-1 do
  with VIFD_NN.items[V42] do
  if ($8769=tag) then
  if ($0004=type_) then begin
    // Exif IFD Pointer
    // Tag = 34665 (8769.H)
    // Type = LONG (treat as UNSIGNED LONG WORD)
    // Count = 1
    // Default = none

    // goes to offset = $00 $00 $00 $46
    VPointer:=AOffset;
    Inc(VPointer, offset);
    VTagFound:=TRUE;
    break;
  end;

  // no exif
  if (not VTagFound) then
    Exit;

  // do it again
  VIFD_NN.number_of_fields := _GetNextWord(VPointer);
  if (0=VIFD_NN.number_of_fields) then
    Exit;

  SetLength(VIFD_NN.items, VIFD_NN.number_of_fields);
  Inc(VPointer, 2);

  // read items
  // $00 $01
  // $92 $86 $00 $07 $00 $00 $10 $EB $00 $00 $00 $54
  // type = $00 $07
  // count = $00 $00 $10 $EB
  // offset = $00 $00 $00 $54
  // $41 $53 $43 $49 $49 $00 $00 $00 $3C $3F $78 $6D $6C $20 $76 $65 $72 $73 $69 $6F $6E $3D $22 $31 $2E $30 $22 $20 $65 $6E $63 $6F $64 $69
  //                                 <   ?
  for V42 := 0 to VIFD_NN.number_of_fields-1 do begin
    _ReadIFD12(VPointer, @(VIFD_NN.items[V42]));
  end;

  // loop items for AExifTag ($9286 = UserComment)
  VTagFound:=FALSE;
  for V42 := 0 to VIFD_NN.number_of_fields-1 do
  with VIFD_NN.items[V42] do
  if (AExifTag=tag) then begin
    Inc(AOffset, offset+8);
    VTagFound:=TRUE;
    break;
  end;

  if (not VTagFound) then
    Exit;

  // treat VExifAttr as PAnsiChar
  ASize := StrLen(PAnsiChar(AOffset));
  if (0=ASize) then
    Exit;

  Inc(Result);
end;

end.
