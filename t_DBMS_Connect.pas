unit t_DBMS_Connect;

{$include i_DBMS.inc}

interface

const
  // префикс для внутренних параметров, которые не пролетают в драйвер подключения к БД
  ETS_INTERNAL_PARAMS_PREFIX   = '$';

  // синхронный режим выполнения всех запросов (включать только в случае ошибок)
  ETS_INTERNAL_SYNC_SQL_MODE   = ETS_INTERNAL_PARAMS_PREFIX + 'SYNC_SQL_MODE';
  // если 0 - нет дополнительной синхронизации
  // если 1 - синхронизируются запросы полностью
  // если 2 - только внутри OpenSQL и ExecSQL

  // схема для всех таблиц
  ETS_INTERNAL_SCHEMA          = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA';

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

implementation

end.
