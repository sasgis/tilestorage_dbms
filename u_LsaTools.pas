unit u_LsaTools;

interface

uses
  Windows;

type
  PVOID = Pointer;
  PLPWSTR = ^LPWSTR;
  USHORT = Word;
  PWSTR = PWideChar;
  NTSTATUS = Integer;

  UNICODE_STRING = packed record
    Length_: USHORT; // in bytes
    MaximumLength: USHORT; // in bytes
    Buffer: PWSTR;
  end;
  PUNICODE_STRING = ^UNICODE_STRING;
  PPUNICODE_STRING = ^PUNICODE_STRING;

  LSA_UNICODE_STRING = UNICODE_STRING;
  PLSA_UNICODE_STRING = ^LSA_UNICODE_STRING;
  PPLSA_UNICODE_STRING = ^PLSA_UNICODE_STRING;

const
  POLICY_VIEW_LOCAL_INFORMATION     = $00000001;
  POLICY_VIEW_AUDIT_INFORMATION     = $00000002;
  POLICY_GET_PRIVATE_INFORMATION    = $00000004;
  POLICY_TRUST_ADMIN                = $00000008;
  POLICY_CREATE_ACCOUNT             = $00000010;
  POLICY_CREATE_SECRET              = $00000020;
  POLICY_CREATE_PRIVILEGE           = $00000040;
  POLICY_SET_DEFAULT_QUOTA_LIMITS   = $00000080;
  POLICY_SET_AUDIT_REQUIREMENTS     = $00000100;
  POLICY_AUDIT_LOG_ADMIN            = $00000200;
  POLICY_SERVER_ADMIN               = $00000400;
  POLICY_LOOKUP_NAMES               = $00000800;
  POLICY_NOTIFICATION               = $00001000;

  // POLICY_READ                       = (STANDARD_RIGHTS_READ or POLICY_VIEW_AUDIT_INFORMATION or POLICY_GET_PRIVATE_INFORMATION);

  STATUS_SUCCESS                    = $00000000;
  STATUS_ACCESS_VIOLATION           = $C0000005;
  STATUS_INVALID_HANDLE             = $C0000008;
  STATUS_INVALID_PARAMETER          = $C000000D;
  STATUS_OBJECT_NAME_NOT_FOUND      = $C0000034;

  ntdll_dll = 'ntdll.dll';

type
  HANDLE = THandle;
  LSA_HANDLE = HANDLE;
  PLSA_HANDLE = ^LSA_HANDLE;

  PLSA_OBJECT_ATTRIBUTES = ^LSA_OBJECT_ATTRIBUTES;
  LSA_OBJECT_ATTRIBUTES = packed record
    Length: ULONG;
    RootDirectory: HANDLE;
    ObjectName: PLSA_UNICODE_STRING;
    Attributes: ULONG;
    SecurityDescriptor: PVOID;
    SecurityQualityOfService: PVOID;
  end;

  TLsaOpenPolicy = function(
    SystemName: PLSA_UNICODE_STRING;
    ObjectAttributes: PLSA_OBJECT_ATTRIBUTES;
    DesiredAccess: ACCESS_MASK;
    PolicyHandle: PLSA_HANDLE
  ): NTSTATUS; stdcall;

  TLsaStorePrivateData = function(
    PolicyHandle: LSA_HANDLE;
    KeyName: PLSA_UNICODE_STRING;
    PrivateData: PLSA_UNICODE_STRING
  ): NTSTATUS; stdcall;

  TLsaClose = function(
    ObjectHandle: LSA_HANDLE
  ): NTSTATUS; stdcall;

  TLsaRetrievePrivateData = function(
    PolicyHandle: LSA_HANDLE;
    KeyName: PLSA_UNICODE_STRING;
    PrivateData: PPLSA_UNICODE_STRING
  ): NTSTATUS; stdcall;

  TLsaFreeMemory = function(
    Buffer: PVOID
  ): NTSTATUS; stdcall;

  KEY_VALUE_INFORMATION_CLASS = (
    KeyValueBasicInformation           = 0,
    KeyValueFullInformation            = 1,
    KeyValuePartialInformation         = 2,
    KeyValueFullInformationAlign64     = 3,
    KeyValuePartialInformationAlign64  = 4,
    MaxKeyValueInfoClass               = 5
  );

  KEY_VALUE_BASIC_INFORMATION = packed record
    TitleIndex: ULONG;
    Type_: ULONG;
    NameLength: ULONG;
    Name: array [0..0] of WCHAR;
  end;
  PKEY_VALUE_BASIC_INFORMATION = ^KEY_VALUE_BASIC_INFORMATION;

  KEY_VALUE_FULL_INFORMATION = packed record
    TitleIndex: ULONG;
    Type_: ULONG;
    DataOffset: ULONG;
    DataLength: ULONG;
    NameLength: ULONG;
    Name: array [0..0] of WCHAR;
  end;
  PKEY_VALUE_FULL_INFORMATION = ^KEY_VALUE_FULL_INFORMATION;

  KEY_VALUE_PARTIAL_INFORMATION = packed record
    TitleIndex: ULONG;
    Type_: ULONG;
    DataLength: ULONG;
    Data: array [0..0] of UCHAR;
  end;
  PKEY_VALUE_PARTIAL_INFORMATION = ^KEY_VALUE_PARTIAL_INFORMATION;
  PPKEY_VALUE_PARTIAL_INFORMATION = ^PKEY_VALUE_PARTIAL_INFORMATION;


function NtQueryValueKey(
  KeyHandle: HANDLE; // IN
  ValueName: PUNICODE_STRING; // IN
  KeyValueInformationClass: KEY_VALUE_INFORMATION_CLASS; // IN
  KeyValueInformation: PVOID; // OUT
  Length_: ULONG; // IN
  ResultLength: PULONG // OUT
): NTSTATUS; stdcall; external ntdll_dll;

function NtSetValueKey(
  KeyHandle: HANDLE; // IN
  ValueName: PUNICODE_STRING; // IN
  TitleIndex: ULONG; // IN OPTIONAL
  Type_: ULONG; // IN
  Data: PVOID; // IN OPTIONAL
  DataSize: ULONG // IN
): NTSTATUS; stdcall; external ntdll_dll;



implementation

end.