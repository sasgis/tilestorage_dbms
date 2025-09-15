unit NativeNTAPI;

interface

uses
  Windows;

type
  PVOID = Pointer;
  PLPWSTR = ^LPWSTR;
  USHORT = Word;
  PWSTR = PWideChar;
  NTSTATUS = LongInt;
  HANDLE = THandle;

  UNICODE_STRING = packed record
    Length_: USHORT; // in bytes
    MaximumLength: USHORT; // in bytes
    Buffer: PWSTR;
  end;
  PUNICODE_STRING = ^UNICODE_STRING;
  PPUNICODE_STRING = ^PUNICODE_STRING;

  LARGE_INTEGER = Int64;
  PLARGE_INTEGER = ^LARGE_INTEGER;

const
  ntdll_dll = 'ntdll.dll';

  STATUS_SUCCESS                    = $00000000;
  STATUS_BUFFER_TOO_SMALL           = $C0000023;

type
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