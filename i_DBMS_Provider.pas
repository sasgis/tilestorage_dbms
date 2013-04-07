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
    function DBMS_Complete(const AFlags: LongWord): Byte;

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

    function DBMS_MakeTileEnum(
      const AEnumTilesHandle: PETS_EnumTiles_Handle;
      const AFlags: LongWord;
      const AHostPointer: Pointer
    ): Byte;

    function DBMS_ExecOption(
      const ACallbackPointer: Pointer;
      const AExecOptionIn: PETS_EXEC_OPTION_IN
    ): Byte;

    function Uninitialize: Byte;
  end;

  TStub_DBMS_Provider = packed record
    Prov: IDBMS_Provider;
  end;
  PStub_DBMS_Provider = ^TStub_DBMS_Provider;

  IDBMS_TileEnum = interface
    ['{E81D8936-2015-4FBB-9493-5020553BD889}']
    function GetNextTile(
      const ACallbackPointer: Pointer;
      const ANextBufferIn: PETS_GET_TILE_RECT_IN
    ): Byte;
  end;

  TStub_DBMS_TileEnum = packed record
    TileEnum: IDBMS_TileEnum;
  end;
  PStub_DBMS_TileEnum = ^TStub_DBMS_TileEnum;

  TDBMS_INFOCLASS_Callbacks = array [TETS_INFOCLASS_Callbacks] of Pointer;

  TSqlOperation = (
    so_Select,
    so_Insert,
    so_Delete,
    so_EnumVersions,
    so_ReloadVersions,
    so_OutputVersions,
    so_SelectInRect,
    so_Sync,
    so_EnumTiles,
    so_Destroy
  );

  IDBMS_Worker = interface
    ['{A1FE7963-F8ED-494B-9040-84184E254E3F}']
    procedure DoBeginWork(
      const AExclusively: Boolean;
      const AOperation: TSqlOperation;
      out AExclusivelyLocked: Boolean
    );
    procedure DoEndWork(const AExclusivelyLocked: Boolean);
    // check if uninitialized
    function IsUninitialized: Boolean;
  end;

implementation

end.
