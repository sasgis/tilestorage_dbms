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
  ETS_INTERNAL_SCHEMA_PREFIX   = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA';

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

  // ���������� ��������� (� ������ ����������) ������, � ����� ����� ������
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // �������� - ���� 0 ��� ��������, ���� 1 ��� �������, ���� ���:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';

  // Tile Storage Section (TSS)
  // ��������� ��� ��������������� ������� �� INI-��� (����� ��������� �/��� ������)
  // ����������� ��� ����������� ���������� ����������� � �������������� ������ �� ��-�������
  ETS_INTERNAL_TSS_              = ETS_INTERNAL_PARAMS_PREFIX + 'TSS_';

  // ��������� ����������� - ����������� ���� ������ ���� DSN ���� ������� (�� ��� ���� ������������ ��� ��������)
  // ���� ������� ������ (����� Section:) - ��������� ������� �� ��
  // ���� ������ DSN (����� DSN:) - ������������ ��������� �� ���������
  // ���� ������ ������� (����� Prefix:) - ������������ ��������� ������� ������ (� �������� ����������� ������� ���� 'anotherdb..')
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

  // ����� ������������� �������� � ������
  // 0 - ��������� (������ � ������� ������������ ������ �� ��� ����, �� ������� �������� �����, �������� � ������� id)
  // 1 - �������� (������ ������� ��� ���������� ��� �������� � ������ ����������� �� ���� ������)
  ETS_INTERNAL_TSS_SYNC          = ETS_INTERNAL_TSS_ + 'Sync';


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

implementation

end.
