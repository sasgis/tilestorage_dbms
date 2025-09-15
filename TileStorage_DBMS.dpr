library TileStorage_DBMS;

{$SETPEOPTFLAGS $0100} // IMAGE_DLLCHARACTERISTICS_NX_COMPAT - enables DEP
{$SETPEOPTFLAGS $0040} // IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE - enables ASLR

{$include i_DBMS.inc}

uses
  u_MemoryManager in 'src\u_MemoryManager.pas',
  Windows,
  SysUtils,
  Classes,
  odbcsql in 'include\odbcsql.pas',
  t_ETS_Path in 'include\vsasas\TileStorage\DBMS\ExtTileStorages\t_ETS_Path.pas',
  t_ETS_Provider in 'include\vsasas\TileStorage\DBMS\ExtTileStorages\t_ETS_Provider.pas',
  t_ETS_Tiles in 'include\vsasas\TileStorage\DBMS\ExtTileStorages\t_ETS_Tiles.pas',
  c_CompressBinaryData in 'include\vsasas\c_CompressBinaryData.pas',
  i_BinaryData in 'include\vsasas\i_BinaryData.pas',
  u_BinaryData in 'include\vsasas\u_BinaryData.pas',
  u_BinaryDataByMemStream in 'include\vsasas\u_BinaryDataByMemStream.pas',
  u_CompressBinaryData in 'include\vsasas\u_CompressBinaryData.pas',
  i_DBMS_Provider in 'src\i_DBMS_Provider.pas',
  i_StatementHandleCache in 'src\i_StatementHandleCache.pas',
  t_DBMS_Connect in 'src\t_DBMS_Connect.pas',
  t_DBMS_Template in 'src\t_DBMS_Template.pas',
  t_DBMS_contenttype in 'src\t_DBMS_contenttype.pas',
  t_DBMS_service in 'src\t_DBMS_service.pas',
  t_DBMS_version in 'src\t_DBMS_version.pas',
  t_ODBC_Buffer in 'src\t_ODBC_Buffer.pas',
  t_ODBC_Connection in 'src\t_ODBC_Connection.pas',
  t_ODBC_Exception in 'src\t_ODBC_Exception.pas',
  t_SQL_types in 'src\t_SQL_types.pas',
  t_TSS in 'src\t_TSS.pas',
  u_CryptoTools in 'src\u_CryptoTools.pas',
  u_DBMS_Connect in 'src\u_DBMS_Connect.pas',
  u_DBMS_Provider in 'src\u_DBMS_Provider.pas',
  u_DBMS_Template in 'src\u_DBMS_Template.pas',
  u_DBMS_TileEnum in 'src\u_DBMS_TileEnum.pas',
  u_DBMS_Utils in 'src\u_DBMS_Utils.pas',
  u_ExecuteSQLArray in 'src\u_ExecuteSQLArray.pas',
  u_Exif_Parser in 'src\u_Exif_Parser.pas',
  u_Exports in 'src\u_Exports.pas',
  u_LsaTools in 'src\u_LsaTools.pas',
  u_PStoreTools in 'src\u_PStoreTools.pas',
  u_StatementHandleCache in 'src\u_StatementHandleCache.pas',
  u_TileArea in 'src\u_TileArea.pas',
  u_Tile_Parser in 'src\u_Tile_Parser.pas';

{$R *.res}

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
  ETS_SetTileVersion,
  ETS_EnumTileVersions,
  ETS_MakeTileEnum,
  ETS_KillTileEnum,
  ETS_NextTileEnum,
  ETS_ExecOption,
  ETS_FreeMem,
  ETS_GetTileRectInfo;

begin
  IsMultiThread := TRUE;
  DisableThreadLibraryCalls(HInstance);
end.
