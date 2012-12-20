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

  (*
  // свойства драйвера DBX
  ETS_INTERNAL_DBX_LibraryName   = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_LibraryName';
  ETS_INTERNAL_DBX_GetDriverFunc = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_GetDriverFunc';
  ETS_INTERNAL_DBX_VendorLib     = ETS_INTERNAL_PARAMS_PREFIX + 'DBX_VendorLib';
  *)
  
  // для подключения через ODBC
  ETS_INTERNAL_ODBC_ConnectWithParams = ETS_INTERNAL_PARAMS_PREFIX + 'ODBC_ConnectWithParams';

  // разрешение сохранять (и читать сохранённый) пароль, а также режим работы
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // значения - либо 0 для отключки, либо 1 для включки, либо это:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';

  // Tile Storage Section (TSS)
  // параметры для секционирования вручную по INI-шке (между серверами и/или базами)
  // применяется для возможности резервного копирования и восстановления разных БД по-разному
  ETS_INTERNAL_TSS_              = ETS_INTERNAL_PARAMS_PREFIX + 'TSS_';

  // вторичное подключение - указывается либо секция либо DSN либо префикс (не все СУБД поддерживают все варианты)
  // если указана секция (после Section:) - параметры берутся из неё
  // если указан DSN (после DSN:) - используются параметры по умолчанию
  // если указан префикс (после Prefix:) - используются параметры текущей секции (к запросам добавляется префикс типа 'anotherdb..')
  // единственный обязательный параметр из TSS
  ETS_INTERNAL_TSS_DEST          = ETS_INTERNAL_TSS_ + 'Dest';

  // ограничение области секции в тайловых координатах (что входит в полуинтервал - попадает в секцию)
  // для бОльшей скорости работы (операции умножения и деления на 2) задаётся тайлами как прямоугольник
  // задаётся зум и номера тайлов, минимальная граница включается, максимальная - исключается
  // например Z8,L84,T36,R85,B37 задаёт прямоугольник в 1 тайл на 8 зуме
  // работает только в паре с ZOOM
  ETS_INTERNAL_TSS_AREA          = ETS_INTERNAL_TSS_ + 'Area';

  // указываются зумы, на которые работает секция в рамках заданной области
  // например 15-18 или 15,16,18
  // работает только в паре с AREA
  ETS_INTERNAL_TSS_ZOOM          = ETS_INTERNAL_TSS_ + 'Zoom';

  // указываются зумы, которые всегда попадают в эту секцию по всем координатам
  // например 1-12
  // очевидно не требует указания RECT или ZOOM
  ETS_INTERNAL_TSS_FULL          = ETS_INTERNAL_TSS_ + 'Full';

  // режим работы секции
  // 0 - отключено
  // 1 - обычная работа (по умолчанию)
  // 2 - инверсия окончательного условия "попал - не попал"
  ETS_INTERNAL_TSS_MODE          = ETS_INTERNAL_TSS_ + 'Mode';

  // режим синхронизации сервисов и версий
  // 0 - отключено (версии и сервисы дообавляются только на тот сайт, на который залетают тайлы, возможно с разными id)
  // 1 - включено (запрос вставки или обновления для сервисов и версий дублируется по всем сайтам)
  ETS_INTERNAL_TSS_SYNC          = ETS_INTERNAL_TSS_ + 'Sync';


const
  // параметры для Credentials
  c_Cred_UserName = 'username';
  c_Cred_Password = 'password';
  c_Cred_SaveAuth = 'saveauth';
  c_Cred_ResetErr = 'reseterr';

  // параметры для MakeVersion
  c_MkVer_Value        = 'ver_value';
  c_MkVer_Date         = 'ver_date';
  c_MkVer_Number       = 'ver_number';
  c_MkVer_Comment      = 'ver_comment';
  c_MkVer_UpdOld       = 'updoldver';
  c_MkVer_SwitchToVer  = 'switchtover';

implementation

end.
