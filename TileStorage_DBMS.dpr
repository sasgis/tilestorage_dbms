library TileStorage_DBMS;

{$SETPEOPTFLAGS $0100} // IMAGE_DLLCHARACTERISTICS_NX_COMPAT - enables DEP
{$SETPEOPTFLAGS $0040} // IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE - enables ASLR

{$include i_DBMS.inc}

uses
  u_MemoryManager in 'u_MemoryManager.pas',
  Windows,
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_ETS_Provider,
  i_DBMS_Provider in 'i_DBMS_Provider.pas',
  u_DBMS_Provider in 'u_DBMS_Provider.pas',
  u_DBMS_Connect in 'u_DBMS_Connect.pas',
  u_DBMS_TileEnum in 'u_DBMS_TileEnum.pas',
  t_DBMS_version in 't_DBMS_version.pas',
  t_DBMS_contenttype in 't_DBMS_contenttype.pas',
  t_DBMS_service in 't_DBMS_service.pas',
  u_DBMS_Utils in 'u_DBMS_Utils.pas',
  t_DBMS_Template in 't_DBMS_Template.pas',
  u_DBMS_Template in 'u_DBMS_Template.pas',
  t_SQL_types in 't_SQL_types.pas',
  t_DBMS_Connect in 't_DBMS_Connect.pas',
  i_StatementHandleCache in 'i_StatementHandleCache.pas',
  u_StatementHandleCache in 'u_StatementHandleCache.pas',
  t_TSS in 't_TSS.pas',
  i_TSS in 'i_TSS.pas',
  u_TileArea in 'u_TileArea.pas',
  t_types in 't_types.pas',
  u_exports in 'u_exports.pas',
  u_LsaTools in 'u_LsaTools.pas',
  u_CryptoTools in 'u_CryptoTools.pas',
  u_PStoreTools in 'u_PStoreTools.pas',
  u_Exif_Parser in 'u_Exif_Parser.pas',
  u_Tile_Parser in 'u_Tile_Parser.pas',
  t_ODBC_Buffer in 't_ODBC_Buffer.pas',
  t_ODBC_Connection in 't_ODBC_Connection.pas',
  t_ODBC_Exception in 't_ODBC_Exception.pas',
  u_ExecuteSQLArray in 'u_ExecuteSQLArray.pas',
  c_CompressBinaryData in 'include\vsasas\c_CompressBinaryData.pas',
  u_CompressBinaryData in 'include\vsasas\u_CompressBinaryData.pas',
  i_BinaryData in 'include\vsasas\i_BinaryData.pas',
  u_BinaryData in 'include\vsasas\u_BinaryData.pas',
  u_BinaryDataByMemStream in 'include\vsasas\u_BinaryDataByMemStream.pas';

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
