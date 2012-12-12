unit t_DBMS_Connect;

{$include i_DBMS.inc}

interface

const
  // префикс для внутренних параметров, которые не пролетают в драйвер подключения к БД
  ETS_INTERNAL_PARAMS_PREFIX   = '$';

  // синхронный режим выполнения всех запросов (включать только в случае ошибок)
  ETS_INTERNAL_SYNC_SQL_MODE   = ETS_INTERNAL_PARAMS_PREFIX + 'SYNC_SQL_MODE';

  // если 0 - нет дополнительной синхронизации
  c_SYNC_SQL_MODE_None = 0;
  
  // если 1 - синхронизируются все запросы к хранилищу внутри DLL
  c_SYNC_SQL_MODE_All_In_DLL = 1;

  // если 2 - только внутри OpenSQL и ExecSQL
  // потенциально заменить на синхронизацию конечных Statement-ов
  c_SYNC_SQL_MODE_Statements = 2;

  // если 3 - синхронизируются все запросы к хранилищу снаружи DLL
  c_SYNC_SQL_MODE_All_In_EXE = 3;

  // если 4 - синхронизируются запросы типа SELECT к хранилищу снаружи DLL
  c_SYNC_SQL_MODE_Query_In_EXE = 4;

  // префикс схемы для всех таблиц (длямо как он будет подставляться в SQL)
  ETS_INTERNAL_SCHEMA_PREFIX   = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA';

  // будет добавляться к каждому запросу при генерации структуры из скрипта
  ETS_INTERNAL_SCRIPT_APPENDER = ETS_INTERNAL_PARAMS_PREFIX + 'SCRIPT_APPENDER';

  // будет загружаться вручную
  ETS_INTERNAL_LOAD_LIBRARY     = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_LIBRARY';
  ETS_INTERNAL_LOAD_LIBRARY_ALT = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_LIBRARY_ALT';

  // загружать параметры при старте из ini-шки драйвера
  ETS_INTERNAL_LOAD_PARAMS_ON_CONNECT = ETS_INTERNAL_PARAMS_PREFIX + 'LOAD_PARAMS_ON_CONNECT';

  // свойства драйвера DBX
  ETS_INTERNAL_DBX_LibraryName   = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_LibraryName';
  ETS_INTERNAL_DBX_GetDriverFunc = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_GetDriverFunc';
  ETS_INTERNAL_DBX_VendorLib     = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_VendorLib';

  // для подключения через ODBC
  ETS_INTERNAL_ODBC_ConnectWithParams = ETS_INTERNAL_PARAMS_PREFIX + 'ODBC_ConnectWithParams';

  // разрешение сохранять (и читать сохранённый) пароль, а также режим работы
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // значения - либо 0 для отключки, либо 1 для включки, либо это:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';
  

const
  // параметры для Credentials
  c_Cred_UserName = 'username';
  c_Cred_Password = 'password';
  c_Cred_SaveAuth = 'saveauth';
  c_Cred_ResetErr = 'reseterr';
  
implementation

end.
