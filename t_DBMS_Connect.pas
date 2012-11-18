unit t_DBMS_Connect;

interface

const
  // ������� ��� ���������� ����������, ������� �� ��������� � ������� ����������� � ��
  ETS_INTERNAL_PARAMS_PREFIX   = '$';

  // ����� ��� ���� ������
  ETS_INTERNAL_SCHEMA          = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA';

  // ����� ����������� � ������� ������� ��� ��������� ��������� �� �������
  ETS_INTERNAL_SCRIPT_APPENDER = ETS_INTERNAL_PARAMS_PREFIX + 'SCRIPT_APPENDER';

  // ����� ����������� �������
  ETS_INTERNAL_LOAD_LIBRARY    = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_LIBRARY';

  // ��������� ��������� ��� ������ �� ini-��� ��������
  ETS_INTERNAL_LOAD_PARAMS_ON_CONNECT = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_PARAMS_ON_CONNECT';

  // �������� �������� DBX
  ETS_INTERNAL_DBX_LibraryName   = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_LibraryName';
  ETS_INTERNAL_DBX_GetDriverFunc = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_GetDriverFunc';
  ETS_INTERNAL_DBX_VendorLib     = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_VendorLib';

implementation

end.
