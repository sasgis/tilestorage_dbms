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

  // �������� �������� DBX
  ETS_INTERNAL_DBX_LibraryName   = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_LibraryName';
  ETS_INTERNAL_DBX_GetDriverFunc = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_GetDriverFunc';
  ETS_INTERNAL_DBX_VendorLib     = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_VendorLib';

  // ��� ����������� ����� ODBC
  ETS_INTERNAL_ODBC_ConnectWithParams = ETS_INTERNAL_PARAMS_PREFIX + 'ODBC_ConnectWithParams';

  // ���������� ��������� (� ������ ����������) ������, � ����� ����� ������
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // �������� - ���� 0 ��� ��������, ���� 1 ��� �������, ���� ���:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';
  

const
  // ��������� ��� Credentials
  c_Cred_UserName = 'username';
  c_Cred_Password = 'password';
  c_Cred_SaveAuth = 'saveauth';
  c_Cred_ResetErr = 'reseterr';
  
implementation

end.
