unit u_exports;

interface

uses
  SysUtils,
  t_ETS_Tiles,
  t_ETS_Provider,
  i_DBMS_Provider,
  u_DBMS_Provider;

function ETS_Initialize(
  const AProvider_Handle: PETS_Provider_Handle;
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
  const AFlags: LongWord;  // see ETS_INIT_* constants
  const AHostPointer: Pointer // MANDATORY
): Byte; stdcall; export;

function ETS_Uninitialize(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord
): Byte; stdcall; export;

function ETS_Complete(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord
): Byte; stdcall; export;

function ETS_Sync(
  const AProvider_Handle: PETS_Provider_Handle;
  const AFlags: LongWord // ETS_ROI_EXCLUSIVELY
): Byte; stdcall; export;

function ETS_SetInformation(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInfoClass: Byte; // see ETS_INFOCLASS_* constants
  const AInfoSize: LongWord;
  const AInfoData: Pointer;
  const AInfoResult: PLongWord
): Byte; stdcall; export;

function ETS_SelectTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte; stdcall; export;

function ETS_InsertTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInsertBuffer: PETS_INSERT_TILE_IN
): Byte; stdcall; export;

function ETS_InsertTNE(
  const AProvider_Handle: PETS_Provider_Handle;
  const AInsertBuffer: PETS_INSERT_TILE_IN
): Byte; stdcall; export;

function  ETS_DeleteTile(
  const AProvider_Handle: PETS_Provider_Handle;
  const ADeleteBuffer: PETS_DELETE_TILE_IN
): Byte; stdcall; export;
  
function ETS_EnumTileVersions(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte; stdcall; export;

function ETS_GetTileRectInfo(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte; stdcall; export;

function ETS_ExecOption(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const AExecOptionIn: PETS_EXEC_OPTION_IN
): Byte; stdcall; export;

function ETS_FreeMem(
  const ABuffer: Pointer
): Byte; stdcall; export;
  
implementation

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

    Result := ETS_RESULT_OK;
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

function ETS_ExecOption(
  const AProvider_Handle: PETS_Provider_Handle;
  const ACallbackPointer: Pointer;
  const AExecOptionIn: PETS_EXEC_OPTION_IN
): Byte; stdcall; export;
begin
  try
    if (nil=AProvider_Handle) then begin
      Result := ETS_RESULT_INVALID_PROVIDER_PTR;
      Exit;
    end;

    (*
    if (nil=ACallbackPointer) then begin
      Result := ETS_RESULT_INVALID_CALLBACK_PTR;
      Exit;
    end;
    *)

    if (nil=AExecOptionIn) then begin
      Result := ETS_RESULT_INVALID_INPUT_BUFFER;
      Exit;
    end;

    Result := PStub_DBMS_Provider(AProvider_Handle)^.Prov.DBMS_ExecOption(
      ACallbackPointer,
      AExecOptionIn
    );
  except
    Result := ETS_RESULT_PROVIDER_EXCEPTION;
  end;
end;

function ETS_FreeMem(
  const ABuffer: Pointer
): Byte; stdcall; export;
begin
  if (ABuffer<>nil) then begin
    FreeMemory(ABuffer);
    Result := ETS_RESULT_OK;
  end else begin
    Result := ETS_RESULT_INVALID_INPUT_BUFFER;
  end;
end;

end.
