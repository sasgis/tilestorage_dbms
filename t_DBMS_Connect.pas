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

  // префикс схемы для всех таблиц (прямо как он будет подставляться в SQL)
  ETS_INTERNAL_SCHEMA_PREFIX   = ETS_INTERNAL_PARAMS_PREFIX + 'SCHEMA_Prefix';

  // при перечислении всех тайлов в хранилище будет подставляться этот префикс схемы
  ETS_INTERNAL_ENUM_PREFIX     = ETS_INTERNAL_PARAMS_PREFIX + 'ENUM_Prefix';

  // текст SQL для запроса перечисления всех тайлов в хранилище
  // имя возвращается первым полем, число полей не более 3
  ETS_INTERNAL_ENUM_SELECT     = ETS_INTERNAL_PARAMS_PREFIX + 'ENUM_Select';

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

  // запрет использовать TOP 1 или LIMIT 1 при SELECT (даже если поддерживается сервером)
  ETS_INTERNAL_DenySelectRowCount1 = ETS_INTERNAL_PARAMS_PREFIX + 'DenySelectRowCount1';

  // разрешение сохранять (и читать сохранённый) пароль, а также режим работы
  ETS_INTERNAL_PWD_Save          = ETS_INTERNAL_PARAMS_PREFIX + 'PWD_Save';
  // значения - либо 0 для отключки, либо 1 для включки, либо это:
  ETS_INTERNAL_PWD_Save_Lsa      = 'Lsa';

  // Tile Storage Section (TSS)
  // параметры для секционирования вручную по INI-шке (между серверами и/или базами)
  // применяется для возможности резервного копирования и восстановления разных БД по-разному
  ETS_INTERNAL_TSS_              = ETS_INTERNAL_PARAMS_PREFIX + 'TSS_';

  // общая настройка алгоритма секционирования
  // возможные значения:
  // None - отключено (значение по умолчанию)
  // Linked - используется стандартная функциональность СУБД для работы с удалёнными таблицами
  //          корректный скрипт создания таблицы обеспечивается процедурой
  //          доступ к тайлам возможен локально (из рабочей БД)
  // Manual - используется ручное разделение таблиц по секциям (без использования особенностей СУБД)
  //          таблица создаётся непосредственно в определённой секции
  //          процедура не обязательна, но также может использоваться
  //          доступ к тайлам осуществляется только в рамках конкретной секции
  // один параметр без суффикса на все секции
  // параметр должен указываться ПЕРВЫМ среди всех параметров TSS
  ETS_INTERNAL_TSS_Algorithm = ETS_INTERNAL_TSS_ + 'Algorithm';

  // имя функции или хранимой процедуры для формирования скрипта создания новой тайловой таблицы
  // один параметр без суффикса на все секции
  ETS_INTERNAL_TSS_NewTileTable_Proc = ETS_INTERNAL_TSS_ + 'NewTileTable_Proc';

  // список однотипных параметров - настройка рабочей секции в определённом контексте
  // возможные значения:
  // Primary - используется первичная секция (значение по умолчанию)
  // Secondary - используется вторичная секция (первая из них, Primary->Next), если её нет - то Primary
  // Destination - используется определённая по алгоритму секция (доступно только для NewTileTable_Link)
  // один параметр указывается один раз и без суффикса на все секции
  // секция для запуска процедуры NewTileTable_Name
  ETS_INTERNAL_TSS_NewTileTable_Link = ETS_INTERNAL_TSS_ + 'NewTileTable_Link';
  // секция для хранения справочников
  ETS_INTERNAL_TSS_Guides_Link       = ETS_INTERNAL_TSS_ + 'Guides_Link';
  // секция для хранения тайлов, которые не попали ни в одну из секций
  ETS_INTERNAL_TSS_Undefined_Link    = ETS_INTERNAL_TSS_ + 'Undefined_Link';

  // дальнейшие параметры TSS допускают использование суффиксов в имени параметра

  // вторичное подключение - указывается либо секция либо DSN
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

  // код секции (для процедуры)
  // целое число
  // если не 0 - то передаётся в процедуру
  // если 0 или не число - используется ручной режим без процедуры
  ETS_INTERNAL_TSS_CODE          = ETS_INTERNAL_TSS_ + 'Code';

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

  // параметры для CalcTableCoord
  c_CalcTableCoord_Z = 'z';
  c_CalcTableCoord_X = 'x';
  c_CalcTableCoord_Y = 'y';

implementation

end.
