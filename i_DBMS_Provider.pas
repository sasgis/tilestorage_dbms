unit i_DBMS_Provider;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  t_ETS_Tiles,
  t_ETS_Provider;

type
  IDBMS_Provider = interface
  ['{3C04939D-C37A-49FB-A952-2EF06B0E45C0}']
    function DBMS_HandleGlobalException(const E: Exception): Byte;

    function DBMS_Complete(const AFlags: LongWord): Byte;
    function DBMS_Sync(const AFlags: LongWord): Byte;

    function DBMS_SetInformation(
      const AInfoClass: Byte; // see ETS_INFOCLASS_* constants
      const AInfoSize: LongWord;
      const AInfoData: Pointer;
      const AInfoResult: PLongWord
    ): Byte;

    function DBMS_SelectTile(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_InsertTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean
    ): Byte;

    function DBMS_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN
    ): Byte;

    function DBMS_EnumTileVersions(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_GetTileRectInfo(
      const ACallbackPointer: Pointer;
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
    ): Byte;

    function DBMS_ExecOption(
      const ACallbackPointer: Pointer;
      const AExecOptionIn: PETS_EXEC_OPTION_IN
    ): Byte;

  end;

  TStub_DBMS_Provider = packed record
    Prov: IDBMS_Provider;
  end;
  PStub_DBMS_Provider = ^TStub_DBMS_Provider;

  TDBMS_INFOCLASS_Callbacks = array [TETS_INFOCLASS_Callbacks] of Pointer;

implementation

end.
