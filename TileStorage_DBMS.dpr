library TileStorage_DBMS;

uses
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_ETS_Provider,
  i_DBMS_Provider in 'i_DBMS_Provider.pas',
  u_DBMS_Provider in 'u_DBMS_Provider.pas',
  u_DBMS_Connect in 'u_DBMS_Connect.pas',
  u_ODBC_DSN in 'u_ODBC_DSN.pas',
  OdbcApi in 'dbxoodbc\OdbcApi.pas',
  DbxOpenOdbcTypes in 'dbxoodbc\DbxOpenOdbcTypes.pas',
  DbxOpenOdbcFuncs in 'dbxoodbc\DbxOpenOdbcFuncs.pas',
  t_DBMS_version in 't_DBMS_version.pas',
  t_DBMS_contenttype in 't_DBMS_contenttype.pas',
  t_DBMS_service in 't_DBMS_service.pas',
  u_DBMS_Utils in 'u_DBMS_Utils.pas',
  t_DBMS_Template in 't_DBMS_Template.pas',
  u_DBMS_Template in 'u_DBMS_Template.pas';

{$R *.res}


function ETS_Initialize(
  const AProvider_Handle: PETS_Provider_Handle;
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
  const AFlags: LongWord;  // see ETS_INIT_* constants
  const AHostPointer: Pointer // MANDATORY
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=AHostPointer) then begin
      Result := ETS_RESULT_INVALID_HOST_PTR;
      Exit;
    end;

    if (nil=AStatusBuffer) then begin
      Result := ETS_RESULT_POINTER1_NIL;
      Exit;
    end;

    // create
    PStub_DBMS_Provider(AProvider_Handle)^.Prov := TDBMS_Provider.Create(
      AStatusBuffer,
      AFlags,
      AHostPointer
    );
    Result := ETS_RESULT_OK;
  except
    // cleanup
    try
      PStub_DBMS_Provider(AProvider_Handle)^.Prov := nil;
    except
    end;
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_Uninitialize(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    // free
    PStub_DBMS_Provider(AProvider_Handle)^.Prov := nil;
    Result := ETS_RESULT_OK;
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_Complete(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_Complete(AFlags);
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;


function ETS_Sync(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord // ETS_ROI_EXCLUSIVELY
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_Sync(AFlags);
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_SetInformation(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInfoClass: Byte; // see ETS_INFOCLASS_* constants
  const AInfoSize: LongWord;
  const AInfoData: Pointer;
  const AInfoResult: PLongWord
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_SetInformation(
      AInfoClass,
      AInfoSize,
      AInfoData,
      AInfoResult
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_SelectTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=ACallbackPointer) then begin
      Result := ETS_RESULT_INVALID_CALLBACK_PTR;
      Exit;
    end;

    if (nil=ASelectBufferIn) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_SelectTile(
      ACallbackPointer,
      ASelectBufferIn
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_InsertTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInsertBuffer: PETS_INSERT_TILE_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=AInsertBuffer) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_InsertTile(
      AInsertBuffer,
      FALSE
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_InsertTNE(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInsertBuffer: PETS_INSERT_TILE_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=AInsertBuffer) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_InsertTile(
      AInsertBuffer,
      TRUE
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function  ETS_DeleteTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const ADeleteBuffer: PETS_DELETE_TILE_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=ADeleteBuffer) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_DeleteTile(
      ADeleteBuffer
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;


function ETS_EnumTileVersions(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=ACallbackPointer) then begin
      Result := ETS_RESULT_INVALID_CALLBACK_PTR;
      Exit;
    end;

    if (nil=ASelectBufferIn) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_EnumTileVersions(
      ACallbackPointer,
      ASelectBufferIn
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_GetTileRectInfo(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    if (nil=ACallbackPointer) then begin
      Result := ETS_RESULT_INVALID_CALLBACK_PTR;
      Exit;
    end;

    if (nil=ATileRectInfoIn) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_GetTileRectInfo(
      ACallbackPointer,
      ATileRectInfoIn
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

exports
  ETS_Initialize,
  ETS_Uninitialize,
  ETS_Complete,
  ETS_Sync,
  ETS_SetInformation,
  ETS_SelectTile,
  ETS_InsertTile,
  ETS_InsertTNE,
  ETS_DeleteTile,
  ETS_EnumTileVersions,
  ETS_GetTileRectInfo;

begin
  IsMultiThread := TRUE;
end.
