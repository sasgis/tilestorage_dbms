unit t_DBMS_Connect;

{$include i_DBMS.inc}

interface

const
  // ������� ��� ���������� ����������, ������� �� ��������� � ������� ����������� � ��
  ETS_INTERNAL_PARAMS_PREFIX   = '$';

  // ���������� ����� ���������� ���� �������� (�������� ������ � ������ ������)
  ETS_INTERNAL_SYNC_SQL_MODE   = ETS_INTERNAL_PARAMS_PREFIX + 'SYNC_SQL_MODE';

  // ���� 0 - ��� �������������� �������������
  c_SYNC_SQL_MODE_None = 0;
  
  // ���� 1 - ���������������� ��� ������� � ��������� ������ DLL
  c_SYNC_SQL_MODE_All_In_DLL = 1;

  // ���� 2 - ������ ������ OpenSQL � ExecSQL
  // ������������ �������� �� ������������� �������� Statement-��
  c_SYNC_SQL_MODE_Statements = 2;

  // ���� 3 - ���������������� ��� ������� � ��������� ������� DLL
  c_SYNC_SQL_MODE_All_In_EXE = 3;

  // ���� 4 - ���������������� ������� ���� SELECT � ��������� ������� DLL
  c_SYNC_SQL_MODE_Query_In_EXE = 4;

  // ������� ����� ��� ���� ������ (����� ��� �� ����� ������������� � SQL)
  ETS_INTERNAL_SCHEMA_PREFIX   = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA_Prefix';

  // ��� ������������ ���� ������ � ��������� ����� ������������� ���� ������� �����
  ETS_INTERNAL_ENUM_PREFIX     = ETS_INTERNAL_PARAMS_PREFIX + 'ENUM_Prefix';

  // ����� SQL ��� ������� ������������ ���� ������ � ���������
  // ��� ������������ ������ �����, ����� ����� �� ����� 3
  ETS_INTERNAL_ENUM_SELECT     = ETS_INTERNAL_PARAMS_PREFIX + 'ENUM_Select';

  // ����� ����������� � ������� ������� ��� ��������� ��������� �� �������
  ETS_INTERNAL_SCRIPT_APPENDER = ETS_INTERNAL_PARAMS_PREFIX + 'SCRIPT_APPENDER';

  // ����� ����������� �������
  ETS_INTERNAL_LOAD_LIBRARY     = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_LIBRARY';
  ETS_INTERNAL_LOAD_LIBRARY_ALT = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_LIBRARY_ALT';

  // ��������� ��������� ��� ������ �� ini-��� ��������
  ETS_INTERNAL_LOAD_PARAMS_ON_CONNECT = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_PARAMS_ON_CONNECT';

  (*
  // �������� �������� DBX
  ETS_INTERNAL_DBX_LibraryName   = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_LibraryName';
  ETS_INTERNAL_DBX_GetDriverFunc = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_GetDriverFunc';
  ETS_INTERNAL_DBX_VendorLib     = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_VendorLib';
  *)

  // ��� ����������� ����� ODBC
  ETS_INTERNAL_ODBC_ConnectWithParams = ETS_INTERNAL_PARAMS_PREFIX + 'ODBC_ConnectWithParams';

  // ������ ������������ TOP 1 ��� LIMIT 1 ��� SELECT (���� ���� �������������� ��������)
  ETS_INTERNAL_DenySelectRowCount1 = ETS_INTERNAL_PARAMS_PREFIX + 'DenySelectRowCount1';

  // ���������� ��������� (� ������ ����������) ������, � ����� ����� ������
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // �������� - ���� 0 ��� ��������, ���� 1 ��� �������, ���� ���:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';

  // Tile Storage Section (TSS)
  // ��������� ��� ��������������� ������� �� INI-��� (����� ��������� �/��� ������)
  // ����������� ��� ����������� ���������� ����������� � �������������� ������ �� ��-�������
  ETS_INTERNAL_TSS_              = ETS_INTERNAL_PARAMS_PREFIX + 'TSS_';

  // ����� ��������� ��������� ���������������
  // ��������� ��������:
  // None - ��������� (�������� �� ���������)
  // Linked - ������������ ����������� ���������������� ���� ��� ������ � ��������� ���������
  //          ���������� ������ �������� ������� �������������� ����������
  //          ������ � ������ �������� �������� (�� ������� ��)
  // Manual - ������������ ������ ���������� ������ �� ������� (��� ������������� ������������ ����)
  //          ������� �������� ��������������� � ����������� ������
  //          ��������� �� �����������, �� ����� ����� ��������������
  //          ������ � ������ �������������� ������ � ������ ���������� ������
  // ���� �������� ��� �������� �� ��� ������
  // �������� ������ ����������� ������ ����� ���� ���������� TSS
  ETS_INTERNAL_TSS_Algorithm = ETS_INTERNAL_TSS_ + 'Algorithm';

  // ��� ������� ��� �������� ��������� ��� ������������ ������� �������� ����� �������� �������
  // ���� �������� ��� �������� �� ��� ������
  ETS_INTERNAL_TSS_NewTileTable_Proc = ETS_INTERNAL_TSS_ + 'NewTileTable_Proc';

  // ������ ���������� ���������� - ��������� ������� ������ � ����������� ���������
  // ��������� ��������:
  // Primary - ������������ ��������� ������ (�������� �� ���������)
  // Secondary - ������������ ��������� ������ (������ �� ���, Primary->Next), ���� � ��� - �� Primary
  // Destination - ������������ ����������� �� ��������� ������ (�������� ������ ��� NewTileTable_Link)
  // ���� �������� ����������� ���� ��� � ��� �������� �� ��� ������
  // ������ ��� ������� ��������� NewTileTable_Name
  ETS_INTERNAL_TSS_NewTileTable_Link = ETS_INTERNAL_TSS_ + 'NewTileTable_Link';
  // ������ ��� �������� ������������
  ETS_INTERNAL_TSS_Guides_Link       = ETS_INTERNAL_TSS_ + 'Guides_Link';
  // ������ ��� �������� ������, ������� �� ������ �� � ���� �� ������
  ETS_INTERNAL_TSS_Undefined_Link    = ETS_INTERNAL_TSS_ + 'Undefined_Link';

  // ���������� ��������� TSS ��������� ������������� ��������� � ����� ���������

  // ��������� ����������� - ����������� ���� ������ ���� DSN
  // ������������ ������������ �������� �� TSS
  ETS_INTERNAL_TSS_DEST          = ETS_INTERNAL_TSS_ + 'Dest';

  // ����������� ������� ������ � �������� ����������� (��� ������ � ������������ - �������� � ������)
  // ��� ������� �������� ������ (�������� ��������� � ������� �� 2) ������� ������� ��� �������������
  // ������� ��� � ������ ������, ����������� ������� ����������, ������������ - �����������
  // �������� Z8,L84,T36,R85,B37 ����� ������������� � 1 ���� �� 8 ����
  // �������� ������ � ���� � ZOOM
  ETS_INTERNAL_TSS_AREA          = ETS_INTERNAL_TSS_ + 'Area';

  // ����������� ����, �� ������� �������� ������ � ������ �������� �������
  // �������� 15-18 ��� 15,16,18
  // �������� ������ � ���� � AREA
  ETS_INTERNAL_TSS_ZOOM          = ETS_INTERNAL_TSS_ + 'Zoom';

  // ����������� ����, ������� ������ �������� � ��� ������ �� ���� �����������
  // �������� 1-12
  // �������� �� ������� �������� RECT ��� ZOOM
  ETS_INTERNAL_TSS_FULL          = ETS_INTERNAL_TSS_ + 'Full';

  // ����� ������ ������
  // 0 - ���������
  // 1 - ������� ������ (�� ���������)
  // 2 - �������� �������������� ������� "����� - �� �����"
  ETS_INTERNAL_TSS_MODE          = ETS_INTERNAL_TSS_ + 'Mode';

  // ��� ������ (��� ���������)
  // ����� �����
  // ���� �� 0 - �� ��������� � ���������
  // ���� 0 ��� �� ����� - ������������ ������ ����� ��� ���������
  ETS_INTERNAL_TSS_CODE          = ETS_INTERNAL_TSS_ + 'Code';

const
  // ��������� ��� Credentials
  c_Cred_UserName = 'username';
  c_Cred_Password = 'password';
  c_Cred_SaveAuth = 'saveauth';
  c_Cred_ResetErr = 'reseterr';

  // ��������� ��� MakeVersion
  c_MkVer_Value        = 'ver_value';
  c_MkVer_Date         = 'ver_date';
  c_MkVer_Number       = 'ver_number';
  c_MkVer_Comment      = 'ver_comment';
  c_MkVer_UpdOld       = 'updoldver';
  c_MkVer_SwitchToVer  = 'switchtover';

  // ��������� ��� CalcTableCoord
  c_CalcTableCoord_Z = 'z';
  c_CalcTableCoord_X = 'x';
  c_CalcTableCoord_Y = 'y';

implementation

end.
