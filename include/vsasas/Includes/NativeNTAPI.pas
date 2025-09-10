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

  IO_STATUS_BLOCK = packed record
    Status: DWORD;
    Information: ULONG;
  end;
  PIO_STATUS_BLOCK = ^IO_STATUS_BLOCK;

  PIO_APC_ROUTINE = procedure(
    ApcContext: PVOID;
    IoStatusBlock: PIO_STATUS_BLOCK;
    Reserved: ULONG); stdcall;
  
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

  FILE_INFORMATION_CLASS = (
    FileDirectoryInformation = 1,
    FileFullDirectoryInformation = 2,
    FileBothDirectoryInformation = 3,
    FileBasicInformation = 4,
    FileStandardInformation = 5,
    FileInternalInformation = 6,
    FileEaInformation = 7,
    FileAccessInformation = 8,
    FileNameInformation = 9,
    FileRenameInformation = 10,
    FileLinkInformation = 11,
    FileNamesInformation = 12,
    FileDispositionInformation = 13,
    FilePositionInformation = 14,
    FileModeInformation = 16,
    FileAlignmentInformation = 17,
    FileAllInformation = 18,
    FileAllocationInformation = 19,
    FileEndOfFileInformation = 20,
    FileAlternateNameInformation = 21,
    FileStreamInformation = 22,
    FilePipeInformation = 23,
    FilePipeLocalInformation = 24,
    FilePipeRemoteInformation = 25,
    FileMailslotQueryInformation = 26,
    FileMailslotSetInformation = 27,
    FileCompressionInformation = 28,
    FileObjectIdInformation = 29,
    FileCompletionInformation = 30,
    FileMoveClusterInformation = 31,
    FileQuotaInformation = 32,
    FileReparsePointInformation = 33,
    FileNetworkOpenInformation = 34,
    FileAttributeTagInformation = 35,
    FileTrackingInformation = 36
  );

  FILE_RENAME_INFORMATION = packed record
    ReplaceIfExists: LongBool;
    RootDirectory: Handle;
    FileNameLength: ULONG;
    FileName: array [0..0] of WCHAR;
  end;
  PFILE_RENAME_INFORMATION = ^FILE_RENAME_INFORMATION;

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

function NtSetInformationFile(
  FileHandle: HANDLE; // IN
  IoStatusBlock: PIO_STATUS_BLOCK; // OUT
  FileInformation: PVOID; // IN
  FileInformationLength: ULONG; // IN
  FileInformationClass: FILE_INFORMATION_CLASS // IN
): NTSTATUS; stdcall; external ntdll_dll;

function NtReadFile(
  FileHandle: THandle; { IN }
  EventHandle: THandle; { IN OPTIONAL }
  UserApcRoutine: PIO_APC_ROUTINE; { IN OPTIONAL }
  UserApcContext: PVOID; { IN OPTIONAL}
  IoStatusBlock: PIO_STATUS_BLOCK; { OUT }
  Buffer: PVOID; { OUT }
  Length: ULONG; { IN }
  ByteOffset: PLARGE_INTEGER; { IN OPTIONAL }
  FileLockKey: PULONG { IN OPTIONAL }
): NTSTATUS; stdcall; external ntdll_dll;

implementation

end.