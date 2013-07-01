unit u_PStoreTools;

interface

uses
  Windows,
  NativeNTAPI,
  NTRegistry,
  SysUtils,
  u_CryptoTools,
  u_LsaTools;

type
  TPSCryptMode = (pscm_None, pscm_Crypt);
  TPSStoreMode = (pssm_Registry, pssm_Lsa);

  IPKeyedCrypter = interface
    ['{F7B5318B-799E-4F2C-84C0-EEDA6A7774F4}']
    function KeyAvailable: Boolean;
    // тип шифрования конкретным ключом
    function SaveSecret(
      const ASecretKeyName, ASecretValue: WideString
    ): Boolean;
    function LoadSecret(
      const ASecretKeyName: WideString;
      out ASecretValue: WideString
    ): Boolean;
  end;

  IPStore = interface
    ['{4B135866-6AF2-4D06-8127-29330FA1191A}']
    // создание шифровальщика с конкретными алгоритмами
    function CreateKeyedCrypter(const ALsaAllowed: Boolean; const AHashAlgid, ACryptAlgid: ALG_ID): IPKeyedCrypter;
    // создание шифровальщика с алгоритмами по умолчанию
    function CreateDefaultCrypter(const ALsaAllowed: Boolean): IPKeyedCrypter;
  end;

  TALLRoutines = record
    // CryptoProvider
    hProv: HCRYPTPROV;
    dwProvError: HRESULT;
    // CryptoAPI
    fnCryptAcquireContext: Pointer;
    fnCryptReleaseContext: Pointer;
    fnCryptEncrypt: Pointer;
    fnCryptDecrypt: Pointer;
    fnCryptDeriveKey: Pointer;
    fnCryptDestroyKey: Pointer;
    fnCryptCreateHash: Pointer;
    fnCryptHashData: Pointer;
    fnCryptDestroyHash: Pointer;
    fnCryptGetProvParam: Pointer;
    fnCryptGetKeyParam: Pointer;
    // LSA Secrets API
    fnLsaOpenPolicy: Pointer;
    fnLsaStorePrivateData: Pointer;
    fnLsaRetrievePrivateData: Pointer;
    fnLsaClose: Pointer;
    fnLsaFreeMemory: Pointer;
    // helpers
    procedure Clear;
    function InitLib(const AContainerName: String): Boolean;
    procedure UninitLib;
    function OpenKeyByHash(
      const AHashAlgid, ACryptAlgid: ALG_ID;
      const ABaseHashInfo: String;
      const AKeyPtr: PHCRYPTKEY;
      out AErrorCode: HRESULT
    ): Boolean;
    function GetKeyBlockLen(
      const AKey: HCRYPTKEY;
      const ABlockLenPtr: PDWORD
    ): Boolean;
    function CryptAvailable: Boolean;
    // Lsa helpers
    function LsaAvailable: Boolean;
    function LsaReadBuffer(
      const ASecretKeyName: WideString;
      const ABufferAddress: PPLSA_UNICODE_STRING
    ): Boolean;
    function LsaSaveBuffer(
      const ASecretKeyName: WideString;
      const ABuffer: Pointer;
      const ABytesLen: USHORT
    ): Boolean;
    procedure LsaFreeBuffer(ABufferAddress: Pointer);
  end;
  PALLRoutines = ^TALLRoutines;

  TAllInfo = record
    pALLRoutines: TALLRoutines;
    sContainerName: String;
    sBaseHashInfo: String;
  end;
  PAllInfo = ^TAllInfo;

  TPStore = class(TInterfacedObject, IPStore)
  private
    // all data
    FAllInfo: TAllInfo;
  private
    { IPStore }
    function CreateKeyedCrypter(const ALsaAllowed: Boolean; const AHashAlgid, ACryptAlgid: ALG_ID): IPKeyedCrypter;
    function CreateDefaultCrypter(const ALsaAllowed: Boolean): IPKeyedCrypter;
  public
    constructor Create(
      const AContainerName, ABaseHashInfo: String
    );
    destructor Destroy; override;
  end;

  TPKeyedCrypter = class(TInterfacedObject, IPKeyedCrypter)
  private
    FCryptKey: HCRYPTKEY;
    FBlockLen: DWORD;
    FKeyError: HRESULT;
    FAllInfoPtr: PAllInfo;
    FLsaAllowed: Boolean;
    FUsePlainText: Boolean;
  private
    function DecryptBuffer(const ACipherBuffer: Pointer; const ALen: DWORD; const pdwDataLen: PDWORD): Boolean;
    function EncryptBuffer(const APlainSource: WideString; const ACipherBufferPtr: PUNICODE_STRING): Boolean;
  private
    { IPKeyedCrypter }
    function KeyAvailable: Boolean;
    function SaveSecret(
      const ASecretKeyName, ASecretValue: WideString
    ): Boolean;
    function LoadSecret(
      const ASecretKeyName: WideString;
      out ASecretValue: WideString
    ): Boolean;
  public
    constructor Create(
      const APStore: TPStore;
      const ALsaAllowed, AUsePlainText: Boolean;
      const AHashAlgid, ACryptAlgid: ALG_ID
    );
    destructor Destroy; override;
  end;


function GetPStoreIface: IPStore;

implementation

uses
  u_PStoreConst;

const
  c_Reg_Prefix = 'Software\VSA\DBMS'; // HKEY_CURRENT_USER
  
var
  g_PStore: IPStore;

function GetPStoreIface: IPStore;
begin
  Result := g_PStore;
  if (nil=Result) then begin
    g_PStore := TPStore.Create(c_ContainerName, c_BaseHashInfo);
    Result := g_PStore;
  end else begin
    Result := g_PStore;
  end;
end;

function PrepareForLsa(const ASource: WideString): WideString;
var p: Integer;
begin
  Result := ASource;
  repeat
    p := System.Pos('\', Result);
    if (p>0) then begin
      Result[p] := '_';
    end else begin
      Exit;
    end;
  until FALSE;
end;

procedure ClearUSBuffer(const AUSPtr: PUNICODE_STRING);
begin
  if (AUSPtr^.Buffer <> nil) then begin
    HeapFree(GetProcessHeap, 0, AUSPtr^.Buffer);
    AUSPtr^.Buffer := nil;
  end;
end;

{ TPStore }

function TPStore.CreateDefaultCrypter(const ALsaAllowed: Boolean): IPKeyedCrypter;
begin
  Result := TPKeyedCrypter.Create(Self, ALsaAllowed, FALSE, c_Default_HashAlgId, c_Default_CryptAlgId);
end;

function TPStore.CreateKeyedCrypter(const ALsaAllowed: Boolean; const AHashAlgid, ACryptAlgid: ALG_ID): IPKeyedCrypter;
begin
  Result := TPKeyedCrypter.Create(Self, ALsaAllowed, FALSE, AHashAlgid, ACryptAlgid);
end;

constructor TPStore.Create(
  const AContainerName, ABaseHashInfo: String
);
begin
  inherited Create;

  FAllInfo.pALLRoutines.Clear;
  FAllInfo.sContainerName := AContainerName;
  FAllInfo.sBaseHashInfo := ABaseHashInfo;
  FAllInfo.pALLRoutines.InitLib(AContainerName);
end;

destructor TPStore.Destroy;
begin
  FAllInfo.pALLRoutines.UninitLib;
  inherited;
end;

{ TPKeyedCrypter }

constructor TPKeyedCrypter.Create(
  const APStore: TPStore;
  const ALsaAllowed, AUsePlainText: Boolean;
  const AHashAlgid, ACryptAlgid: ALG_ID
);
begin
  inherited Create;

  FCryptKey := 0;
  FBlockLen := 0;
  FKeyError := 0;

  FAllInfoPtr := @(APStore.FAllInfo);
  FLsaAllowed := ALsaAllowed;
  FUsePlainText := AUsePlainText;

  if (not FUsePlainText) then begin
    if FAllInfoPtr^.pALLRoutines.OpenKeyByHash(
      AHashAlgid, ACryptAlgid,
      FAllInfoPtr^.sBaseHashInfo,
      @FCryptKey,
      FKeyError
    ) then begin
      // ключ получен - определим длину блока
      FAllInfoPtr^.pALLRoutines.GetKeyBlockLen(FCryptKey, @FBlockLen);
    end;
  end;
end;

function TPKeyedCrypter.DecryptBuffer(const ACipherBuffer: Pointer; const ALen: DWORD; const pdwDataLen: PDWORD): Boolean;
var
  VHash: HCRYPTHASH;
  VDataLen: DWORD;
begin
  // no hash here
  VHash := 0;
  VDataLen := ALen;
  
  Result := (TCryptDecrypt(FAllInfoPtr^.pALLRoutines.fnCryptDecrypt)(
    FCryptKey,
    VHash,
    TRUE,
    0,
    ACipherBuffer,
    @VDataLen
  ) <> FALSE);

  if Result then begin
    pdwDataLen^ := VDataLen;
  end;
end;

destructor TPKeyedCrypter.Destroy;
begin
  if (FCryptKey <> 0) then begin
    TCryptDestroyKey(FAllInfoPtr^.pALLRoutines.fnCryptDestroyKey)(FCryptKey);
    FCryptKey := 0;
  end;
  inherited;
end;

function TPKeyedCrypter.EncryptBuffer(const APlainSource: WideString; const ACipherBufferPtr: PUNICODE_STRING): Boolean;
var
  VHash: HCRYPTHASH;
  VDataLen: DWORD;
  //VLastError: HRESULT;
begin
  //VLastError := 0;
  VDataLen := 0;
  VHash := 0; // no hashing

  ClearUSBuffer(ACipherBufferPtr);
  
  if (0=FBlockLen) then begin
    // потоковый алгоритм
    ACipherBufferPtr^.Length_ := Length(APlainSource)*SizeOf(WideChar);
    ACipherBufferPtr^.MaximumLength := ACipherBufferPtr^.Length_ + SizeOf(WideChar);
    ACipherBufferPtr^.Buffer := HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, ACipherBufferPtr^.MaximumLength);
    CopyMemory(ACipherBufferPtr^.Buffer, @(APlainSource[1]), ACipherBufferPtr^.Length_);
    VDataLen := ACipherBufferPtr^.Length_;
    Result := (TCryptEncrypt(FAllInfoPtr^.pALLRoutines.fnCryptEncrypt)(
      FCryptKey,
      VHash,
      TRUE,
      0,
      PBYTE(ACipherBufferPtr^.Buffer),
      @VDataLen,
      ACipherBufferPtr^.Length_
    ) <> FALSE);

    Exit;
  end;

  // блочный
  // TODO: не тестил вообще
  ACipherBufferPtr^.Length_ := Length(APlainSource)*SizeOf(WideChar);
  ACipherBufferPtr^.MaximumLength := ACipherBufferPtr^.Length_ + (2*FBlockLen+1)*SizeOf(WideChar);
  ACipherBufferPtr^.Buffer := HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, ACipherBufferPtr^.MaximumLength);
  CopyMemory(ACipherBufferPtr^.Buffer, @(APlainSource[1]), ACipherBufferPtr^.Length_);

  Result := (TCryptEncrypt(FAllInfoPtr^.pALLRoutines.fnCryptEncrypt)(
    FCryptKey,
    VHash,
    TRUE,
    0,
    PBYTE(ACipherBufferPtr^.Buffer),
    @VDataLen,
    ACipherBufferPtr^.Length_
  ) <> FALSE);

  if Result then begin
    ACipherBufferPtr^.Length_ := VDataLen;
  end;
end;

function TPKeyedCrypter.KeyAvailable: Boolean;
begin
  Result := (FCryptKey <> 0);
end;

function TPKeyedCrypter.LoadSecret(const ASecretKeyName: WideString; out ASecretValue: WideString): Boolean;
var
  VLsaBuf: PUNICODE_STRING;
  VRegInfo: PKEY_VALUE_PARTIAL_INFORMATION;
  VCipherBuffer: Pointer;
  VCipherLen, VDataLen: DWORD;
begin
  // загружаем из хранилища и дешифруем
  ASecretValue := '';
  VLsaBuf := nil;
  VRegInfo := nil;
  try
    with FAllInfoPtr^.pALLRoutines do begin
      Result := FLsaAllowed and LsaReadBuffer(ASecretKeyName, @VLsaBuf);
    end;

    if Result then begin
      // прочитано из Lsa
      VCipherBuffer := VLsaBuf^.Buffer;
      VCipherLen    := VLsaBuf^.Length_;
    end else begin
      // не прочитано из Lsa - читаем из реестра
      Result := NTRegistryReadBuffer(c_Reg_Prefix, ASecretKeyName, @VRegInfo);
      if Result then begin
        VCipherBuffer := @(VRegInfo^.Data);
        VCipherLen    := VRegInfo^.DataLength;
      end else begin
        Exit;
      end;
    end;

    if (not FUsePlainText) and KeyAvailable then begin
      // decrypt
      VDataLen := 0;
      Result := DecryptBuffer(VCipherBuffer, VCipherLen, @VDataLen);
      if Result then begin
        SetString(ASecretValue, PWideChar(VCipherBuffer), VDataLen div SizeOf(WideChar));
      end;
    end else begin
      // plain text
      SetString(ASecretValue, PWideChar(VCipherBuffer), VCipherLen div SizeOf(WideChar));
    end;
  finally
    NTRegistryClearInfo(@VRegInfo);
    FAllInfoPtr^.pALLRoutines.LsaFreeBuffer(VLsaBuf);
  end;
end;

function TPKeyedCrypter.SaveSecret(const ASecretKeyName, ASecretValue: WideString): Boolean;
var
  VCipherBuffer: UNICODE_STRING;
  VBufToSave: Pointer;
  VLenToSave: Word;
begin
  FillChar(VCipherBuffer, SizeOf(VCipherBuffer), 0);
  try
    if (not FUsePlainText) and KeyAvailable then begin
      // шифруем
      Result := EncryptBuffer(ASecretValue, @VCipherBuffer);
      if (not Result) then
        Exit;
      VBufToSave := VCipherBuffer.Buffer;
      VLenToSave := VCipherBuffer.Length_;
    end else begin
      // без дополнительного шифрования
      VCipherBuffer.Buffer := nil;
      VBufToSave := @(ASecretValue[1]);
      VLenToSave := Length(ASecretValue)*SizeOf(WideChar);
    end;

    // грузим в Lsa
    with FAllInfoPtr^.pALLRoutines do begin
      Result := FLsaAllowed and LsaSaveBuffer(ASecretKeyName, VBufToSave, VLenToSave);
    end;

    if (not Result) then begin
      // не получилось - в реестр
      Result := NTRegistrySaveBuffer(c_Reg_Prefix, ASecretKeyName, VBufToSave, VLenToSave);
    end;
  finally
    ClearUSBuffer(@VCipherBuffer);
  end;
end;

{ TALLRoutines }

procedure TALLRoutines.Clear;
begin
  FillChar(Self, SizeOf(Self), 0);
end;

function TALLRoutines.CryptAvailable: Boolean;
begin
  Result := (hProv <> 0) and (fnCryptAcquireContext <> nil);
end;

function TALLRoutines.GetKeyBlockLen(
  const AKey: HCRYPTKEY;
  const ABlockLenPtr: PDWORD
): Boolean;
var
  VDataLen: DWORD;
begin
  VDataLen := SizeOf(ABlockLenPtr^);
  Result := (TCryptGetKeyParam(fnCryptGetKeyParam)(
    AKey,
    KP_BLOCKLEN,
    PBYTE(ABlockLenPtr),
    @VDataLen,
    0
  ) <> FALSE);
end;

function TALLRoutines.InitLib(const AContainerName: String): Boolean;
var
  VDLLHandle: THandle;
begin
  Result := FALSE;

  // этот модуль уже должен быть загружен
  VDLLHandle := GetModuleHandle(advapi32);
  if (0 = VDLLHandle) then
    Exit;

  // ищем LSA
  fnLsaOpenPolicy := GetProcAddress(VDLLHandle, 'LsaOpenPolicy');
  fnLsaStorePrivateData := GetProcAddress(VDLLHandle, 'LsaStorePrivateData');
  fnLsaRetrievePrivateData := GetProcAddress(VDLLHandle, 'LsaRetrievePrivateData');
  fnLsaClose := GetProcAddress(VDLLHandle, 'LsaClose');
  fnLsaFreeMemory := GetProcAddress(VDLLHandle, 'LsaFreeMemory');

  if (nil = fnLsaOpenPolicy) or
     (nil = fnLsaStorePrivateData) or
     (nil = fnLsaRetrievePrivateData) or
     (nil = fnLsaClose) or
     (nil = fnLsaFreeMemory) then begin
    // flag that no Lsa support
    fnLsaOpenPolicy := nil;
  end;

  // а теперь CryptoAPI
{$ifdef UNICODE}
  fnCryptAcquireContext := GetProcAddress(VDLLHandle, 'CryptAcquireContextW');
{$else}
  fnCryptAcquireContext := GetProcAddress(VDLLHandle, 'CryptAcquireContextA');
{$endif}
  fnCryptReleaseContext := GetProcAddress(VDLLHandle, 'CryptReleaseContext');

  fnCryptEncrypt := GetProcAddress(VDLLHandle, 'CryptEncrypt');
  fnCryptDecrypt := GetProcAddress(VDLLHandle, 'CryptDecrypt');

  fnCryptDeriveKey := GetProcAddress(VDLLHandle, 'CryptDeriveKey');
  fnCryptDestroyKey := GetProcAddress(VDLLHandle, 'CryptDestroyKey');

  fnCryptCreateHash  := GetProcAddress(VDLLHandle, 'CryptCreateHash');
  fnCryptHashData    := GetProcAddress(VDLLHandle, 'CryptHashData');
  fnCryptDestroyHash := GetProcAddress(VDLLHandle, 'CryptDestroyHash');

  fnCryptGetKeyParam := GetProcAddress(VDLLHandle, 'CryptGetKeyParam');
  fnCryptGetProvParam := GetProcAddress(VDLLHandle, 'CryptGetProvParam');

  if (nil = fnCryptAcquireContext) or
     (nil = fnCryptReleaseContext) or
     (nil = fnCryptEncrypt) or
     (nil = fnCryptDecrypt) or
     (nil = fnCryptDeriveKey) or
     (nil = fnCryptDestroyKey) or
     (nil = fnCryptCreateHash) or
     (nil = fnCryptHashData) or
     (nil = fnCryptDestroyHash) or
     (nil = fnCryptGetKeyParam) or
     (nil = fnCryptGetProvParam) then begin
    // flag that no Crypt support
    fnCryptAcquireContext := nil;
    Exit;
  end;

  // open
  Result := (TCryptAcquireContext(fnCryptAcquireContext)(
    @hProv,
    PChar(AContainerName),
    nil, // use default provider
    PROV_RSA_FULL,
    CRYPT_NEWKEYSET
  ) <> FALSE);

  if (not Result) then begin
    dwProvError := GetLastError;
    // 2148073487 = $8009000F = NTE_EXISTS
    if (NTE_EXISTS = dwProvError) then begin
      Result := (TCryptAcquireContext(fnCryptAcquireContext)(
        @hProv,
        PChar(AContainerName),
        nil, // use default provider
        PROV_RSA_FULL,
        0
      ) <> FALSE);
    end;
  end;

  // An application can obtain the name of the key container in use
  // by reading the PP_CONTAINER value with the CryptGetProvParam function.
end;

function TALLRoutines.LsaAvailable: Boolean;
begin
  Result := (fnLsaOpenPolicy<>nil);
end;

procedure TALLRoutines.LsaFreeBuffer(ABufferAddress: Pointer);
begin
  if (ABufferAddress <> nil) then begin
    TLsaFreeMemory(fnLsaFreeMemory)(ABufferAddress);
  end;
end;

function TALLRoutines.LsaReadBuffer(
  const ASecretKeyName: WideString;
  const ABufferAddress: PPLSA_UNICODE_STRING
): Boolean;
var
  VPolicy: LSA_HANDLE;
  Vkeyname: LSA_UNICODE_STRING;
  VObj: LSA_OBJECT_ATTRIBUTES;
  VResult: NTSTATUS;
  VLsaKeyName: WideString;
begin
  Result := LsaAvailable;
  if (not Result) then
    Exit;

  FillChar(VObj, Sizeof(VObj), 0);
  VObj.Length := Sizeof(VObj);
  VPolicy := 0;

  VResult := TLsaOpenPolicy(fnLsaOpenPolicy)(
    nil,
    @VObj,
    POLICY_GET_PRIVATE_INFORMATION or STANDARD_RIGHTS_READ,
    @VPolicy
  );
  
  if (VResult < STATUS_SUCCESS) then begin
    // no access
    Result := FALSE;
    Exit;
  end;

  VLsaKeyName := 'L$' + c_Lsa_Prefix + PrepareForLsa(ASecretKeyName);

  try
    with Vkeyname do begin
      Length_ := Length(VLsaKeyName) * SizeOf(WideChar);
      MaximumLength := Length_;
      Buffer := PWideChar(VLsaKeyName);
    end;

    VResult := TLsaRetrievePrivateData(fnLsaRetrievePrivateData)(
      VPolicy,
      @Vkeyname,
      ABufferAddress
    );

    Result := (VResult>=STATUS_SUCCESS);
    // -1073741811 = $C000000D = STATUS_OBJECT_NAME_NOT_FOUND
  finally
    TLsaClose(fnLsaClose)(VPolicy);
  end;
end;

function TALLRoutines.LsaSaveBuffer(
  const ASecretKeyName: WideString;
  const ABuffer: Pointer;
  const ABytesLen: USHORT
): Boolean;
var
  VPolicy: LSA_HANDLE;
  Vkeyname: LSA_UNICODE_STRING;
  Vkeydata: LSA_UNICODE_STRING;
  VObj: LSA_OBJECT_ATTRIBUTES;
  VResult: NTSTATUS;
  VLsaKeyName: WideString;
begin
  Result := LsaAvailable;
  if (not Result) then
    Exit;
  
  FillChar(VObj, Sizeof(VObj), 0);
  VObj.Length := Sizeof(VObj);
  VPolicy := 0;
  
  VResult := TLsaOpenPolicy(fnLsaOpenPolicy)(
    nil,
    @VObj,
    POLICY_CREATE_SECRET or POLICY_GET_PRIVATE_INFORMATION or STANDARD_RIGHTS_WRITE,
    @VPolicy
  );

  if (VResult < STATUS_SUCCESS) then begin
    // no access
    Result := FALSE;
    Exit;
  end;

  try
    VLsaKeyName := 'L$' + c_Lsa_Prefix + PrepareForLsa(ASecretKeyName);
    
    with Vkeyname do begin
      Length_ := System.Length(VLsaKeyName) * SizeOf(WideChar);
      MaximumLength := Length_;
      Buffer := PWideChar(VLsaKeyName);
    end;

    with Vkeydata do begin
      Length_ := ABytesLen;
      MaximumLength := ABytesLen;
      Buffer := ABuffer;
    end;

    // нельзя чтобы в keyname был символ '\'
    VResult := TLsaStorePrivateData(fnLsaStorePrivateData)(
      VPolicy,
      @Vkeyname,
      @Vkeydata
    );

    Result := (VResult>=STATUS_SUCCESS);
    // -1073741811 = $C000000D = STATUS_INVALID_PARAMETER
  finally
    TLsaClose(fnLsaClose)(VPolicy);
  end;
end;

function TALLRoutines.OpenKeyByHash(
  const AHashAlgid, ACryptAlgid: ALG_ID;
  const ABaseHashInfo: String;
  const AKeyPtr: PHCRYPTKEY;
  out AErrorCode: HRESULT
): Boolean;
const
  c_KEYLENGTH = $00800000;
var
  VHash: HCRYPTHASH;
begin
  AKeyPtr^ := 0;

  // create base hash by given string
  Result := (TCryptCreateHash(fnCryptCreateHash)(
    hProv,
    AHashAlgid,
    0,
    0,
    @VHash) <> FALSE);

  if (not Result) then begin
    AErrorCode := GetLastError;
    Exit;
  end;

  try
    Result := (TCryptHashData(fnCryptHashData)(
      VHash,
      @(ABaseHashInfo[1]),
      Length(ABaseHashInfo)*SizeOf(Char),
      0
    ) <> FALSE);

    if (not Result) then begin
      AErrorCode := GetLastError;
      Exit;
    end;

    // Derive key from hash
    Result := (TCryptDeriveKey(fnCryptDeriveKey)(
      hProv,
      ACryptAlgid,
      VHash,
      c_KEYLENGTH,
      AKeyPtr
    ) <> FALSE);

    if (not Result) then begin
      AErrorCode := GetLastError;
      Exit;
      // -2146893816 = $80090008 = NTE_BAD_ALGID
    end;
  finally
    TCryptDestroyHash(fnCryptDestroyHash)(VHash);
  end;
end;

procedure TALLRoutines.UninitLib;
begin
  fnCryptAcquireContext := nil;
  if (hProv <> 0) and (nil <> fnCryptReleaseContext) then begin
    TCryptReleaseContext(fnCryptReleaseContext)(hProv, 0);
    hProv := 0;
  end;
end;

initialization
  g_PStore := nil;
finalization
  g_PStore := nil;
end.
