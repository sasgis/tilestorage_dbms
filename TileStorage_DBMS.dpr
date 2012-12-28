library TileStorage_DBMS;

{$include i_DBMS.inc}

uses
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
  t_TSS in 't_TSS.pas',
  i_TSS in 'i_TSS.pas',
  u_ZoomList in 'u_ZoomList.pas',
  u_TileArea in 'u_TileArea.pas',
  t_types in 't_types.pas',
  u_exports in 'u_exports.pas',
  u_LsaTools in 'u_LsaTools.pas',
  u_CryptoTools in 'u_CryptoTools.pas',
  u_PStoreTools in 'u_PStoreTools.pas',
  u_Exif_Parser in 'u_Exif_Parser.pas',
  u_Tile_Parser in 'u_Tile_Parser.pas',
  ODBCSQL in 'ODBCSQL.PAS',
  t_ODBC_Buffer in 't_ODBC_Buffer.pas',
  t_ODBC_Connection in 't_ODBC_Connection.pas',
  t_ODBC_Exception in 't_ODBC_Exception.pas',
  u_ExecuteSQLArray in 'u_ExecuteSQLArray.pas';

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
  ETS_EnumTileVersions,
  ETS_MakeTileEnum,
  ETS_KillTileEnum,
  ETS_NextTileEnum,
  ETS_ExecOption,
  ETS_FreeMem,
  ETS_GetTileRectInfo;

begin
  IsMultiThread := TRUE;
end.
