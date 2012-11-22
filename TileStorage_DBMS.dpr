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
  t_DBMS_version in 't_DBMS_version.pas',
  t_DBMS_contenttype in 't_DBMS_contenttype.pas',
  t_DBMS_service in 't_DBMS_service.pas',
  u_DBMS_Utils in 'u_DBMS_Utils.pas',
  t_DBMS_Template in 't_DBMS_Template.pas',
  u_DBMS_Template in 'u_DBMS_Template.pas',
  t_SQL_types in 't_SQL_types.pas',
  t_DBMS_Connect in 't_DBMS_Connect.pas',
  t_types in 't_types.pas',
  u_exports in 'u_exports.pas';

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
  ETS_GetTileRectInfo;

begin
  IsMultiThread := TRUE;
end.
