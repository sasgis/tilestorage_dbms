unit NTRegistry;

interface

uses
  Windows,
  NativeNTAPI;

{$IFNDEF UNICODE}
type
  UnicodeString = WideString;
{$ENDIF}

procedure NTRegistryClearInfo(const ARegInfoPtr: PPKEY_VALUE_PARTIAL_INFORMATION);

function NTRegistryReadBuffer(
  const ARegPrefix: UnicodeString;
  const ASecretKeyName: UnicodeString;
  const ARegInfoPtr: PPKEY_VALUE_PARTIAL_INFORMATION
): Boolean;

function NTRegistrySaveBuffer(
  const ARegPrefix: UnicodeString;
  const ASecretKeyName: UnicodeString;
  const ABuffer: Pointer;
  const ABytesLen: USHORT
): Boolean;

implementation

procedure InternalPrepareRegValue(
  const ASrc: UnicodeString;
  var AHelper: UnicodeString;
  ABuffer: PUNICODE_STRING
);
begin
  AHelper := ASrc;
  ABuffer^.Length_ := (Length(AHelper)+2);
  ABuffer^.MaximumLength := ABuffer^.Length_*SizeOf(WideChar);
  SetLength(AHelper, Length(AHelper)+2);
  AHelper[ABuffer^.Length_]   := #1;
  AHelper[ABuffer^.Length_-1] := #0;
  ABuffer^.Length_ := ABuffer^.MaximumLength;
  ABuffer^.Buffer := @(AHelper[1]);
end;

procedure NTRegistryClearInfo(const ARegInfoPtr: PPKEY_VALUE_PARTIAL_INFORMATION);
begin
  if (ARegInfoPtr^ <> nil) then begin
    HeapFree(GetProcessHeap, 0, ARegInfoPtr^);
    ARegInfoPtr^ := nil;
  end;
end;

function NTRegistryReadBuffer(
  const ARegPrefix: UnicodeString;
  const ASecretKeyName: UnicodeString;
  const ARegInfoPtr: PPKEY_VALUE_PARTIAL_INFORMATION
): Boolean;
var
  VResult: Longint;
  VRegName: UnicodeString;
  VRegKey: HKEY;
  VValueName: UNICODE_STRING;
  VResultLen: ULONG;
begin
  NTRegistryClearInfo(ARegInfoPtr);
  Result := FALSE;

  VRegName := ARegPrefix;
  VResult := RegOpenKeyExW(
    HKEY_CURRENT_USER,
    @(VRegName[1]),
    0,
    STANDARD_RIGHTS_READ or KEY_QUERY_VALUE, //KEY_READ
    VRegKey
  );

  // 2 = ERROR_FILE_NOT_FOUND

  if (ERROR_SUCCESS=VResult) then
  try
    // read values - use RtlQueryRegistryValues
    InternalPrepareRegValue(ASecretKeyName, VRegName, @VValueName);

    VResultLen := 0;

    VResult := NtQueryValueKey(
      VRegKey,
      @VValueName,
      KeyValuePartialInformation,
      nil,
      0,
      @VResultLen
    );

    if (STATUS_BUFFER_TOO_SMALL = DWORD(VResult)) and (0<VResultLen) then begin
      ARegInfoPtr^ := HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, VResultLen);
      if (nil <> ARegInfoPtr^) then begin
        VResult := NtQueryValueKey(
          VRegKey,
          @VValueName,
          KeyValuePartialInformation,
          ARegInfoPtr^,
          VResultLen,
          @VResultLen
        );
        Result := (STATUS_SUCCESS <= VResult);
      end;
    end;
  finally
    RegCloseKey(VRegKey);
  end;
end;

function NTRegistrySaveBuffer(
  const ARegPrefix: UnicodeString;
  const ASecretKeyName: UnicodeString;
  const ABuffer: Pointer;
  const ABytesLen: USHORT
): Boolean;
var
  VResult: Longint;
  VRegName: UnicodeString;
  VRegKey: HKEY;
  VValueName: UNICODE_STRING;
begin
  Result := FALSE;
  VRegName := ARegPrefix;
  VResult := RegCreateKeyExW(
    HKEY_CURRENT_USER,
    @(VRegName[1]),
    0,
    nil,
    0,
    STANDARD_RIGHTS_WRITE or KEY_SET_VALUE, //KEY_WRITE
    nil,
    VRegKey,
    nil
  );

  // set REG_BINARY value
  if (ERROR_SUCCESS=VResult) then
  try
    InternalPrepareRegValue(ASecretKeyName, VRegName, @VValueName);

    VResult := NtSetValueKey(
      VRegKey,
      @VValueName,
      0,
      REG_BINARY,
      ABuffer,
      ABytesLen
    );

    Result := (STATUS_SUCCESS <= VResult);
  finally
    RegCloseKey(VRegKey);
  end;
end;

end.