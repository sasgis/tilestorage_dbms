unit t_SQL_types;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  t_ETS_Tiles,
  t_types;

type
  // list of _ALL_ supported SQL servers
  TEngineType = (
    et_MSSQL,
    et_ASE,
    et_ASA,
    et_Oracle,
    et_Informix,
    et_DB2,
    et_MySQL,
    et_PostgreSQL,
    et_Mimer,
    et_Firebird,
    et_Unknown     // add new items before this line
  );

  TCheckEngineTypeMode = (
    cetm_None,   // do not check (if not checked yet)
    cetm_Check,  // check (if not checked yet), allow define by driver
    cetm_Force   // force re(check), ignore driver information
  );

  TQuotedPlace = (qp_Before, qp_After);

  TStatementExceptionType = (
    set_Success,
    set_TableNotFound,
    set_PrimaryKeyViolation,
    set_NoSpaceAvailable,
    set_ConnectionIsDead,
    set_DataTruncation,
    set_UnsynchronizedStatements,
    set_ReadOnlyConnection,
    set_Unknown
  );

  TStatementRepeatType = (srt_None, srt_Insert, srt_Update);

  TSecondarySQLCheckServerTypeMode = (schstm_None, schstm_SomeSybase);

  TProcedureNewMode = (pnm_None, pnm_SelectFromFunction, pnm_ExecuteProcedure);

  TRowCount1Mode = (rc1m_None, rc1m_Top1, rc1m_First1, rc1m_Limit1, rc1m_Fetch1Only, rc1m_Rows1);

  TUpsertMode = (
    upsm_None,
    upsm_Merge,
    upsm_DualMerge,
    upsm_InsertOnDupUpdate
  );

const
  c_SQLCMD_FROM_SYSDUMMY1 = 'SELECT * FROM SYSIBM.SYSDUMMY1'; // DB2 only!
  //c_SQLCMD_MySQL_DUAL = 'SELECT /*!1 111 AS F, */ * FROM DUAL'; //  /*!1 */ works at version 1 and higher
  //c_SQLCMD_Version_F  = 'SELECT version()'; // PostgreSQL, MySQL

  // unique enginenames (for scripts and etc.) - always uppercased
  c_SQL_Engine_Name : array [TEngineType] of String = (
    'MS',    // Microsoft SQL
    'ASE',   // Sybase ASE
    'ASA',   // Sybase ASA
    'ORA',   // Oracle
    'IFX',   // Informix
    'DB2',   // DB2
    'MY',    // MySQL
    'PG',    // PostgreSQL
    'MMR',   // Mimer
    'FB',    // Firebird
    ''       // Unknown or unsupported - use c_RTL_UNKNOWN for scripts, do not insert it here
  );

  (*
  // 'Integrated Security' or 'Trusted_Connection' (if allowed)
  c_SQL_Integrated_Security: array [TEngineType] of String = (
    'IntegratedSecurity',  // Microsoft SQL  // Trusted_Connection=True // Trusted_Connection=Yes
    '',                    // Sybase ASE
    '',                    // Sybase ASA
    'Integrated Security', // Oracle // Integrated Security=SSPI
    '',                    // Informix
    '',                    // DB2
    '',                    // MySQL
    'Integrated Security', // PostgreSQL
    'Integrated Security', // Mimer
    '',                    // Firebird
    ''
  );
  *)

{$if defined(ETS_USE_DBX)}
  // unique DBX drivernames (do not add item for ODBC!)
  c_SQL_DBX_Driver_Name: array [TEngineType] of String = (
    'MSSQL',
    'ASE',
    'ASA',
    'Oracle',
    'Informix',
    'DB2',
    'MySQL',
    '', // PostgreSQL via ODBC only?
    '', // Mimer via ODBC only
    '', // Firebird via ODBC only?
    ''
  );
{$ifend}

  // datetime function name
  c_SQL_DateTime_FunctionName: array [TEngineType] of String = (
  'GETDATE()',         // MSSQL
  'GETDATE()',         // ASE
  'GETDATE()',         // ASA
  'SYSTIMESTAMP',      // Oracle
  'CURRENT',           // Informix
  'CURRENT TIMESTAMP', // DB2
  'SYSDATE()',         // MySQL
  'CURRENT_TIMESTAMP', // PostgreSQL
  'LOCALTIMESTAMP',    // Mimer
  'CURRENT_TIMESTAMP', // Firebird
  ''
  );

  // type to store both date and time
  c_SQL_DateTime_FieldName: array [TEngineType] of String = (
  'DATETIME',  // MSSQL
  'DATETIME',  // ASE
  'TIMESTAMP', // ASA
  'TIMESTAMP', // Oracle
  'DATETIME YEAR TO FRACTION', // Informix
  'TIMESTAMP', // DB2
  'DATETIME',  // MySQL
  'TIMESTAMP', // PostgreSQL
  'TIMESTAMP', // Mimer
  'TIMESTAMP', // Firebird
  ''
  );

  // prefix before literal datetime
  c_SQL_DateTime_Literal_Prefix: array [TEngineType] of String = (
  '',          // MSSQL
  '',          // ASE
  '',          // ASA
  'TIMESTAMP', // Oracle
  '',          // Informix
  '',          // DB2
  '',          // MySQL
  '',          // PostgreSQL
  'TIMESTAMP', // Mimer
  '',          // Firebird
  ''
  );

  // do not add empty version (because '' treats by server as NULL)
  c_SQL_Empty_Version_Denied: array [TEngineType] of Boolean = (
  FALSE, // MSSQL
  FALSE, // ASE
  FALSE, // ASA
  TRUE,  // Oracle
  FALSE, // Informix
  FALSE, // DB2
  FALSE, // MySQL
  FALSE, // PostgreSQL
  FALSE, // Mimer
  FALSE, // Firebird
  TRUE   // always TRUE here!
  );

  // type to store BigInt (8 bytes with sign) from -9223372036854775808 to 9223372036854775807
  c_SQL_INT8_FieldName: array [TEngineType] of String = (
  'BIGINT', // MSSQL
  'BIGINT', // ASE
  'BIGINT', // ASA
  'NUMBER', // Oracle NUMBER(p)
  'BIGINT', // Informix
  'BIGINT', // DB2
  'BIGINT', // MySQL
  'BIGINT', // PostgreSQL
  'BIGINT', // Mimer
  'BIGINT', // Firebird - Dialect 3 only!
  ''
  );

  // type to store LongInt (4 bytes with sign) from -2147483648 to 2147483647
  c_SQL_INT4_FieldName: array [TEngineType] of String = (
  'INT',    // MSSQL
  'INT',    // ASE
  'INT',    // ASA
  'NUMBER', // Oracle NUMBER(p)
  'INT',    // Informix
  'INT',    // DB2
  'INT',    // MySQL
  'INT',    // PostgreSQL
  'INT',    // Mimer
  'INT',    // Firebird
  ''
  );

  // type to store MediumInt (3 bytes with sign) from -8388608 to 8388607
  c_SQL_INT3_FieldName: array [TEngineType] of String = (
  '',          // MSSQL
  '',          // ASE
  '',          // ASA
  '',          // Oracle
  '',          // Informix
  '',          // DB2
  'MEDIUMINT', // MySQL
  '',          // PostgreSQL
  '',          // Mimer
  '',          // Firebird
  ''
  );

  // type to store SmallInt (2 bytes with sign) from -32768 to 32767
  c_SQL_INT2_FieldName: array [TEngineType] of String = (
  'SMALLINT', // MSSQL
  'SMALLINT', // ASE
  'SMALLINT', // ASA
  'NUMBER',   // Oracle NUMBER(p)
  'SMALLINT', // Informix
  'SMALLINT', // DB2
  'SMALLINT', // MySQL
  'SMALLINT', // PostgreSQL
  'SMALLINT', // Mimer
  'SMALLINT', // Firebird
  ''
  );

  // type to store TinyInt (1 byte with sign)
  c_SQL_INT1_FieldName: array [TEngineType] of String = (
  'TINYINT',  // MSSQL (type is always unsigned - from 0 to 255)
  'TINYINT',  // ASE   (type is always unsigned - from 0 to 255)
  'TINYINT',  // ASA   (type is always unsigned - from 0 to 255)
  '',         // Oracle NUMBER(p)
  '',         // Informix
  '',         // DB2
  'TINYINT',  // MySQL (signed - from -128 to 127, unsigned - from 0 to 255)
  '',         // PostgreSQL
  '',         // Mimer
  '',         // Firebird
  ''
  );

  // use int fields with size in brackets
  c_SQL_INT_With_Size: array [TEngineType] of Boolean = (
  FALSE,   // MSSQL
  FALSE,   // ASE
  FALSE,   // ASA
  TRUE,    // Oracle NUMBER(p)
  FALSE,   // Informix
  FALSE,   // DB2
  FALSE,   // MySQL
  FALSE,   // PostgreSQL
  FALSE,   // Mimer
  FALSE,   // Firebird
  FALSE
  );

  // Forced tablename if FROM clause is mandatory
  c_SQL_FROM: array [TEngineType] of String = (
  '',              // MSSQL
  '',              // ASE
  'DUMMY',         // ASA (dummy_col INTEGER NOT NULL)
  'DUAL',          // Oracle
  'table(set{1})', // Informix
  'SYSIBM.SYSDUMMY1', // DB2
  '',              // MySQL
  '',              // PostgreSQL
  'SYSTEM.ONEROW', // Mimer
  'rdb$database',  // Firebird
  ''
  );

  // how to select first row only
  c_SQL_RowCount1_Mode: array [TEngineType] of TRowCount1Mode = (
    rc1m_Top1,           // MSSQL
    rc1m_Top1,           // ASE    // TODO: DELETE TOP 1 FROM ... // UPDATE TOP 1 table ...
    rc1m_Top1,           // ASA    // TODO: DELETE TOP 1 FROM ... // UPDATE TOP 1 table ... // ORDER BY clause is required
    rc1m_None,           // Oracle // select /*+ first_rows(10) */ * from t1 order by 1 desc;
    rc1m_First1,         // Informix // SELECT FIRST 1 a,b FROM tab
    rc1m_Fetch1Only,     // DB2    // SELECT * FROM tbl FETCH FIRST 1 ROW ONLY
    rc1m_Limit1,         // MySQL  // SELECT * FROM tbl LIMIT 1 // DELETE // UPDATE
    rc1m_Limit1,         // PostgreSQL
    rc1m_None,           // Mimer
    rc1m_Rows1,          // Firebird (from 2.0)
    rc1m_None            // always NONE here
  );
  
  // how to insert/update in single statement
  c_SQL_UpsertMode: array [TEngineType] of TUpsertMode = (
    upsm_Merge,             // MSSQL (from 2008) // ok with ';'
    upsm_Merge,             // ASE (from 15.7) // ok
    upsm_Merge,             // ASA  // ok
    upsm_None,              // Oracle // MERGE // upsm_DualMerge
    upsm_None,              // Informix // MERGE
    upsm_Merge,             // DB2 // ok
    upsm_InsertOnDupUpdate, // MySQL (from 5.0) // ok
    upsm_None,              // PostgreSQL  // no MERGE and others at 9.2 // with update insert or block statement
    upsm_None,              // Mimer       // none
    upsm_None,              // Firebird (MERGE from 2.1) // Update Or Insert
    upsm_None               // always NONE here
  );

  // how to call function or procedure to get sql for new object
  c_SQL_ProcedureNew_Mode: array [TEngineType] of TProcedureNewMode = (
  pnm_ExecuteProcedure,   // MSSQL
  pnm_ExecuteProcedure,   // ASE
  pnm_None,               // ASA
  pnm_None,               // Oracle
  pnm_None,               // Informix
  pnm_None,               // DB2
  pnm_None,               // MySQL
  pnm_SelectFromFunction, // PostgreSQL
  pnm_None,               // Mimer
  pnm_None,               // Firebird
  pnm_None                // always NONE here
  );

  // max length of SQL identifier and tablename
  c_SQL_ID_Len: array [TEngineType] of SmallInt = (
  128,    // MSSQL // Microsoft SQL Server 2000
  30,     // ASE // Sybase AS Enterprise 12.0 // 254 for Sybase AS Enterprise 15.0
  128,    // ASA // Sybase SQL Anywhere 10
  30,     // Oracle // ORACLE Version 9i2 - 11g
  128,    // Informix // INFORMIX SQL 11.x
  128,    // DB2 // IBM DB2 UDB 8.x
  64,     // MySQL // MySQL 3.23
  63,     // PostgreSQL // 'name' type // PostgreSQL 7.3 - 8.0 = 31
  128,    // Mimer
  31,     // Firebird
  0
  );

  // create view DUAL for some DBMS without DUAL
  c_SQL_DUAL_Create: array [TEngineType] of String = (
  'create view DUAL as select @@version as ENGINE_VERSION', // MSSQL
  'create view DUAL as select ''ASE'' as ENGINETYPE',       // ASE
  'create view DUAL as select ''ASA'' as ENGINETYPE',       // ASA
  '', // Oracle - with DUAL by default - nothing
  'create view DUAL(ENGINE_VERSION) as select DBINFO(''version'',''full'') as ENGINE_VERSION from table(set{1})', // Informix
  'create view DUAL as select * from SYSIBM.SYSVERSIONS',   // DB2
  '', // MySQL
  'create view DUAL as select version() as ENGINE_VERSION', // PostgreSQL
  'create view DUAL as select ''MIMER'' as ENGINETYPE from SYSTEM.ONEROW', // Mimer
  'create view DUAL as select ''FIREBIRD'' as ENGINETYPE, rdb$get_context(''SYSTEM'',''ENGINE_VERSION'') as ENGINE_VERSION from rdb$database', // Firebird
  ''
  );

  // MSSQL + ASE
  c_SQL_ENUM_SVC_Tables_MSSQL_ASE =
    'SELECT name FROM sysobjects WHERE type=''U'' AND name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // ASA
  c_SQL_ENUM_SVC_Tables_MSSQL_ASA =
    'SELECT table_name FROM SYSTABLE WHERE table_type=''BASE'' AND table_name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // Oracle
  c_SQL_ENUM_SVC_Tables_ORA =
    'SELECT table_name FROM all_tables WHERE table_name' +
     ' like ''%__$_%SVC%%'' escape ''$''';

  // Informix
  c_SQL_ENUM_SVC_Tables_IFX =
    'SELECT tabname FROM systables WHERE tabtype=''T'' AND owner=user AND tabname' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // DB2
  c_SQL_ENUM_SVC_Tables_DB2 =
    'SELECT name FROM SYSIBM.SYSTABLES WHERE type=''T'' AND creator=user AND name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // MySQL
  c_SQL_ENUM_SVC_Tables_MY =
    'SELECT table_name FROM information_schema.tables WHERE table_type=''BASE TABLE'' AND table_schema=schema() AND table_name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // PostgreSQL
  c_SQL_ENUM_SVC_Tables_PG =
    'SELECT table_name FROM information_schema.tables WHERE table_type=''BASE TABLE'' AND table_schema=''public'' AND table_name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // Mimer
  c_SQL_ENUM_SVC_Tables_MMR =
    'SELECT table_name FROM information_schema.tables WHERE table_type=''BASE TABLE'' AND table_schema=user AND table_name' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // Firebird
  c_SQL_ENUM_SVC_Tables_FB =
    'SELECT RDB$RELATION_NAME FROM RDB$RELATIONS WHERE RDB$RELATION_TYPE=0 AND RDB$OWNER_NAME=user AND trim(RDB$RELATION_NAME)' +
     ' like ''%__$_%SVC%'' escape ''$''';

  // select to enumerate all tables with tiles for specified service
  c_SQL_ENUM_SVC_Tables: array [TEngineType] of String = (
  c_SQL_ENUM_SVC_Tables_MSSQL_ASE,   // MSSQL
  c_SQL_ENUM_SVC_Tables_MSSQL_ASE,   // ASE
  c_SQL_ENUM_SVC_Tables_MSSQL_ASA,   // ASA
  c_SQL_ENUM_SVC_Tables_ORA,         // Oracle
  c_SQL_ENUM_SVC_Tables_IFX,         // Informix
  c_SQL_ENUM_SVC_Tables_DB2,         // DB2
  c_SQL_ENUM_SVC_Tables_MY,          // MySQL
  c_SQL_ENUM_SVC_Tables_PG,          // PostgreSQL
  c_SQL_ENUM_SVC_Tables_MMR,         // Mimer
  c_SQL_ENUM_SVC_Tables_FB,          // Firebird
  ''                                 // Unknown - always EMPTY!
  );


{$if defined(ETS_USE_ZEOS)}
  // use PingServer for ZEOSLib
  c_ZEOS_Use_PingServer: array [TEngineType] of Boolean = (
  FALSE,   // MSSQL
  FALSE,   // ASE
  FALSE,   // ASA
  FALSE,   // Oracle
  FALSE,   // Informix
  FALSE,   // DB2
  TRUE,    // MySQL
  FALSE,   // PostgreSQL
  FALSE,   // Mimer
  FALSE,   // Firebird
  FALSE
  );
{$ifend}

(*
TOP:

MSSQL:
Select top 10 * from ...

Informix:
Select first 10 * from systables
С IDS10.00.xC3
select skip 10 limit 10 * systables;


MSSQL via ZEOS (dblib):
'None of the dynamic libraries can be found: ntwdblib.dll'
['{408A0899-6692-4F6F-9649-80FC4EA668AC}']

MySQL:

BLOB DATA TYPE:
A BLOB is a binary large object that can hold a variable amount of data.
The four BLOB types are TINYBLOB, BLOB, MEDIUMBLOB, and LONGBLOB.
These differ only in the maximum length of the values they can hold.
The four TEXT types are TINYTEXT, TEXT, MEDIUMTEXT, and LONGTEXT.
These correspond to the four BLOB types and have the same maximum lengths and storage requirements.
http://dev.mysql.com/doc/refman/5.5/en/storage-requirements.html
http://dev.mysql.com/doc/refman/5.5/en/string-type-overview.html
http://dev.mysql.com/doc/refman/5.5/en/blob.html

MEDIUMBLOB:
A BLOB column with a maximum length of 16,777,215 (2^24 - 1) bytes.
Each MEDIUMBLOB value is stored using a 3-byte length prefix that indicates the number of bytes in the value.

LONGBLOB:
A BLOB column with a maximum length of 4,294,967,295 or 4GB (2^32 - 1) bytes.
The effective maximum length of LONGBLOB columns depends on the
configured maximum packet size in the client/server protocol and available memory.
Each LONGBLOB value is stored using a 4-byte length prefix that indicates the number of bytes in the value.

BLOB[(M)]:
A BLOB column with a maximum length of 65,535 (2^16 - 1) bytes.
Each BLOB value is stored using a 2-byte length prefix that indicates the number of bytes in the value.
An optional length M can be given for this type. If this is done, MySQL creates the column as
the smallest BLOB type large enough to hold values M bytes long.

TINYBLOB:
A BLOB column with a maximum length of 255 (2^8 - 1) bytes.
Each TINYBLOB value is stored using a 1-byte length prefix that indicates the number of bytes in the value.


ASE via DBLIB:
'Cannot perform more than one read There is no OS level error '#$D'Net-Library operation terminated due to disconnect There is no OS level error '
'Attempt to initiate a new SQL Server operation with results pending.  '#$D'Attempt to initiate a new SQL Server operation with results pending.  '
AFAIK - CT-LIB wanted ))

*)



// standart:
// 'BlackfishSQL'
// 'Interbase'

(*
via ODBC:
http://sourceforge.net/projects/open-dbexpress/

ConnectionName = 'OdbcConnection'
DriverName = 'Odbc'
GetDriverFunc = 'getSQLDriverODBC'
LibraryName = 'dbxoodbc.dll'
LoginPrompt = False
Params.Strings = (
  'DriverName=Odbc'
  'Database=DSN'
  'User_Name=user'
  'Password=password')
VendorLib = 'ODBC32.DLL'
*)

{$if defined(ETS_USE_DBX)}
const
  c_ODBC_DriverName  = 'Odbc';
  c_ODBC_LibraryName = 'dbxoodbc.dll';
  c_ODBC_GetDriverFunc = 'getSQLDriverODBCW'; // 'getSQLDriverODBC'
  c_ODBC_VendorLib = 'ODBC32.DLL';
{$ifend}

const
{$if defined(ETS_USE_DBX)}
  c_RTL_Connection = 'Connection';
  c_RTL_Interbase = 'Interbase'; // for Firebird
{$ifend}
  c_RTL_Trusted_Connection = 'OS Authentication';
  c_RTL_Numeric = 'numeric';
  c_RTL_UNKNOWN = 'UNKNOWN';

{$if defined(ETS_USE_ZEOS)}
  // for ZEOS
  c_ZEOS_Protocol = 'Protocol';
  c_ZEOS_HostName = 'HostName';
  c_ZEOS_Port     = 'Port';
  c_ZEOS_Database = 'Database';
  c_ZEOS_Catalog  = 'Catalog';
  c_ZEOS_User     = 'User';
  c_ZEOS_Password = 'Password';
{$ifend}

{$if defined(ETS_USE_DBX)}
  // for SQLDB
  c_SQLDB_Password       = 'Password';
  c_SQLDB_UserName       = 'UserName';
  c_SQLDB_CharSet        = 'CharSet';
  c_SQLDB_HostName       = 'HostName';
  c_SQLDB_Role           = 'Role';
  c_SQLDB_DatabaseName   = 'DatabaseName';
  c_SQLDB_Directory      = 'Directory';
  c_SQLDB_KeepConnection = 'KeepConnection';
  c_SQLDB_ConnectorType  = 'ConnectorType';
  // Port - в Params
{$ifend}

  // prefix and suffix for identifiers for tiles
  c_SQL_QuotedIdentifierForcedForTiles: array [TEngineType] of Boolean = (
    TRUE,   // MSSQL
    FALSE,  // ASE // OK with FALSE
    FALSE,  // ASA
    TRUE,   // Oracle
    TRUE,   // Informix
    TRUE,   // DB2
    TRUE,   // MySQL
    TRUE,   // PostgreSQL // OK with TRUE
    FALSE,  // Mimer // OK with FALSE
    TRUE,   // Firebird
    TRUE
  );

  c_SQL_QuotedIdentifierValue: array [TEngineType, TQuotedPlace] of AnsiChar = (
    ('[',']'),  // MSSQL
    ('[',']'),  // ASE // OK with '[]'
    ('"','"'),  // ASA
    ('"','"'),  // Oracle
    ('"','"'),  // Informix
    ('"','"'),  // DB2
    ('`','`'),  // MySQL
    ('"','"'),  // PostgreSQL // OK with '"'
    ('"','"'),  // Mimer // OK with '"'
    ('"','"'),  // Firebird
    ('"','"')
  );

  // default (very old!) datetime for empty version
  c_SQL_DateTimeForEmptyVersion: array [TEngineType] of TDateTime = (
    2,   // MSSQL
    0,   // ASE
    0,   // ASA
    0,   // Oracle
    0,   // Informix
    0,   // DB2
    0,   // MySQL
    0,   // PostgreSQL
    0,   // Mimer
    0,   // Firebird
    0
  );

{$if defined(ETS_USE_DBX)}
  // cast blob into hex literal and do not use :param (for dbExpress)
  c_DBX_CastBlobToHexLiteral: array [TEngineType] of Boolean = (
  FALSE,          // MSSQL
  FALSE,          // ASE
  FALSE,          // ASA
  FALSE,          // Oracle
  FALSE,          // Informix
  FALSE,          // DB2
  FALSE,          // MySQL
  FALSE,          // PostgreSQL
  FALSE,          // Mimer
  TRUE,           // Firebird // DBXCommon.TDBXContext.Error(???,'Incorrect values within SQLDA structure')
  FALSE
  );
{$ifend}

  // for PostgreSQL
  // '42P01:1:ОШИБКА: отношение "C1I0_NMC_RECENCY" не существует;'#$A'ERROR WHILE PREPARING PARAMETERS'
  // '42P01:7:ОШИБКА: отношение "Z_SERVICE" не существует;'#$A'ERROR WHILE EXECUTING THE QUERY' // POSTGRESQL
  // others
  // '42S02:208:[MICROSOFT][ODBC SQL SERVER DRIVER][SQL SERVER]Недопустимое имя объекта "FAI4_KSSAT".'
  // '42000:208:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]Z_SERVICE NOT FOUND. SPECIFY OWNER.OBJECTNAME OR USE SP_HELP TO CHECK WHETHER THE OBJECT EXISTS (SP_HELP MAY PRODUCE LOTS OF OUTPUT).'
  // '42S02:-206:[INFORMIX][INFORMIX ODBC DRIVER][INFORMIX]THE SPECIFIED TABLE (_F9I4_BINGSAT_) IS NOT IN THE DATABASE.'
  // '42S02:-12200:[MIMER][ODBC MIMER DRIVER][MIMER SQL]TABLE Z_SERVICE NOT FOUND, TABLE DOES NOT EXIST OR NO ACCESS PRIVILEGE'
  // '42S02:1146:[MYSQL][ODBC 5.2(W) DRIVER][MYSQLD-5.5.28-MARIADB]TABLE 'TEST.Z_SERVICE' DOESN'T EXIST'
  // '42S02:-204:[ODBC FIREBIRD DRIVER][FIREBIRD]DYNAMIC SQL ERROR'#$A'SQL ERROR CODE = -204'#$A'TABLE UNKNOWN'#$A'Z_SERVICE'#$A'AT LINE 1, COLUMN 25'
  // '42S02:-141:[SYBASE][ODBC DRIVER][SQL ANYWHERE]TABLE 'Z_SERVICE' NOT FOUND'
  // '42S02:-204:[IBM][CLI DRIVER][DB2/NT] SQL0204N  "DB2ADMIN.Z_SERVICE" IS AN UNDEFINED NAME.  SQLSTATE=42704'#$D#$A
  // '42704:-204:[IBM][CLI Driver][DB2/NT] SQL0204N  "DB2ADMIN.G15I9_yanarodmap" is an undefined name.  SQLSTATE=42704'#$D#$A
  // '42S02:942:[ORACLE][ODBC][ORA]ORA-00942: TABLE OR VIEW DOES NOT EXIST'#$A
  // sqlstate for 'table not exists' error
  c_ODBC_SQLSTATE_TableNotEists_1 : array [TEngineType] of String = (
    '42S02:208:',     // Microsoft SQL
    '42000:208:',     // Sybase ASE
    '42S02:-141:',    // Sybase ASA
    '42S02:942:',     // Oracle
    '42S02:-206:',    // Informix
    '42S02:-204:',    // DB2
    '42S02:1146:',    // MySQL
    '42P01:1:',       // PostgreSQL
    '42S02:-12200:',  // Mimer
    '42S02:-204:',    // Firebird
    '42'              // Unknown or unsupported - use like mask
  );
  c_ODBC_SQLSTATE_TableNotEists_2 : array [TEngineType] of String = (
    '',           // Microsoft SQL
    '42S02:208:', // Sybase ASE
    '',           // Sybase ASA
    '',           // Oracle
    '',           // Informix
    '42704:-204:',    // DB2
    '',           // MySQL
    '42P01:7:',   // PostgreSQL
    '',           // Mimer
    '',           // Firebird
    ''            // Unknown or unsupported - empty
  );

  // for PostgreSQL
  // '23505:7:ОШИБКА: повторяющееся значение ключа нарушает ограничение уникальности "PK_I53I24_BINGSAT"'#$A'Ключ "(X, Y, ID_VER)=(814, 441, 1134)" уже существует.;'#$A'ERROR WHILE EXECUTING THE QUERY'
  // others
  // '23000:2627:[MICROSOFT][ODBC SQL SERVER DRIVER][SQL SERVER]Нарушение "PK_FAI4_KSSAT" ограничения PRIMARY KEY. Не удается вставить повторяющийся ключ в объект "DBO.FAI4_KSSAT". Повторяющееся значение ключа: (511, 582, 0).'
  // '23000:2601:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]ATTEMPT TO INSERT DUPLICATE KEY ROW IN OBJECT 'FAI4_KSSAT' WITH UNIQUE INDEX 'PK_FAI4_KSSAT''#$A
  // '23000:-268:[INFORMIX][INFORMIX ODBC DRIVER][INFORMIX]UNIQUE CONSTRAINT (INFORMIX.PK_F9I4_BINGSAT) VIOLATED.'
  // '23000:-10101:[MIMER][ODBC MIMER DRIVER][MIMER SQL]PRIMARY KEY CONSTRAINT VIOLATED, ATTEMPT TO INSERT DUPLICATE KEY IN TABLE SYSADM.F9I4_BINGSAT'
  // '23000:1062:[MYSQL][ODBC 5.2(W) DRIVER][MYSQLD-5.5.28-MARIADB]DUPLICATE ENTRY '945-811-1134' FOR KEY 'PRIMARY''
  // '23000:-803:[ODBC FIREBIRD DRIVER][FIREBIRD]VIOLATION OF PRIMARY OR UNIQUE KEY CONSTRAINT "PK_F9I4_BINGSAT" ON TABLE "F9I4_BINGSAT"'
  // '23000:-193:[SYBASE][ODBC DRIVER][SQL ANYWHERE]PRIMARY KEY FOR TABLE 'F9I4_BINGSAT' IS NOT UNIQUE: PRIMARY KEY VALUE ('755,794,0')'
  // '23505:-803:[IBM][CLI DRIVER][DB2/NT] SQL0803N  ONE OR MORE VALUES IN THE INSERT STATEMENT, UPDATE STATEMENT, OR FOREIGN KEY UPDATE CAUSED BY A DELETE STATEMENT ARE NOT VALID BECAUSE THE PRIMARY KEY, UNIQUE CONSTRAINT OR UNIQUE INDEX IDENTIFIED BY "1" CONSTRAINS TABLE "DB2ADMIN.F9I4_BINGSAT" FROM HAVING DUPLICATE VALUES FOR THE INDEX KEY.  SQLSTATE=23505'#$D#$A
  // '23000:1:[ORACLE][ODBC][ORA]ORA-00001: UNIQUE CONSTRAINT (DB2ADMIN.PK_8I_KSSAT) VIOLATED'#$A
  // sqlstate for primary key constraint violation
  c_ODBC_SQLSTATE_PrimaryKeyViolation : array [TEngineType] of String = (
    '23000:2627:',   // Microsoft SQL
    '23000:2601:',   // Sybase ASE
    '23000:-193:',   // Sybase ASA
    '23000:1:',      // Oracle
    '23000:-268:',   // Informix
    '23505:-803:',   // DB2
    '23000:1062:',   // MySQL
    '23505:7:',      // PostgreSQL
    '23000:-10101:', // Mimer
    '23000:-803:',   // Firebird
    '23'             // Unknown or unsupported - use like mask
  );

  // '42000:1105:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0][SQL SERVER]Не удалось выделить место для объекта "DBO.I54I24_YANDEXSAT".'PK_I54I24_YANDEXSAT' в базе данных "SAS_MS", поскольку файловая группа "PRIMARY" переполнена. Выделите место на диске, удалив ненужные файлы или объекты в файловой группе, добавив дополнительные файлы в файловую группу или указав параметр автоматического увеличения размера для существующих файлов в файловой группе.'
  // 'ZZZZZ:1105:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]CAN'T ALLOCATE SPACE FOR OBJECT 'SYSLOGS' IN DATABASE 'SAS_ASE' BECAUSE 'LOGSEGMENT' SEGMENT IS FULL/HAS NO FREE EXTENTS. IF YOU RAN OUT OF SPACE IN SYSLOGS, DUMP THE TRANSACTION LOG. OTHERWISE, USE ALTER DATABASE TO INCREASE THE SIZE OF THE SEGMENT.'#$A
  // 'ZZZZZ:3475:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]THERE IS NO SPACE AVAILABLE IN SYSLOGS TO LOG A RECORD FOR WHICH SPACE HAS BEEN RESERVED IN DATABASE 'GIS' (ID 4). THIS PROCESS WILL RETRY AT INTERVALS OF ONE MINUTE.'#$A
  c_ODBC_SQLSTATE_NoSpaceAvailable_1 : array [TEngineType] of String = (
    '42000:1105:', // Microsoft SQL
    'ZZZZZ:1105:', // Sybase ASE
    '',            // Sybase ASA
    '',            // Oracle
    '',            // Informix
    '',            // DB2
    '',            // MySQL
    '',            // PostgreSQL
    '',            // Mimer
    '',            // Firebird
    ''             // Unknown or unsupported - no mask here - empty
  );
  c_ODBC_SQLSTATE_NoSpaceAvailable_2 : array [TEngineType] of String = (
    '',            // Microsoft SQL
    'ZZZZZ:3475:', // Sybase ASE
    '',            // Sybase ASA
    '',            // Oracle
    '',            // Informix
    '',            // DB2
    '',            // MySQL
    '',            // PostgreSQL
    '',            // Mimer
    '',            // Firebird
    ''             // Unknown or unsupported - no mask here - empty
  );

  // dead connection for PostgreSQL
  // '08S01:26:COULD NOT SEND QUERY TO BACKEND;'#$A'COULD NOT SEND QUERY TO BACKEND'
  // '42P01:26:COULD NOT SEND QUERY(CONNECTION DEAD);'#$A'COULD NOT SEND QUERY(CONNECTION DEAD)'
  // others:
  // '08S01:10054:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0]Поставщик TCP: Удаленный хост принудительно разорвал существующее подключение.'#$D#$A
  // '08S02:-1:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0]Поставщик SMUX: Физическое подключение недоступно [XFFFFFFFF]. '
  // 'HY000:1012:[ORACLE][ODBC][ORA]ORA-01012: NOT LOGGED ON'#$A'PROCESS ID: 3116'#$A'SESSION ID: 137 SERIAL NUMBER: 101'#$A
  // '08S01:-11020:[INFORMIX][INFORMIX ODBC DRIVER]COMMUNICATION LINK FAILURE.'
  // '40003:-30081:[IBM][CLI DRIVER] SQL30081N  A COMMUNICATION ERROR HAS BEEN DETECTED. COMMUNICATION PROTOCOL BEING USED: "TCP/IP".  COMMUNICATION API BEING USED: "SOCKETS".  LOCATION WHERE THE ERROR WAS DETECTED: "192.168.1.8".  COMMUNICATION FUNCTION DETECTING THE ERROR: "RECV".  PROTOCOL SPECIFIC ERROR CODE(S): "*", "*", "0".  SQLSTATE=08001'#$D#$A
  // '08S01:30046:[SYBASE][ODBC DRIVER]CONNECTION TO SYBASE SERVER HAS BEEN LOST. CONNECTION DIED WHILE READING FROM SOCKET. SOCKET RETURNED ERROR CODE 0. ERRNO RETURNED 0. ALL ACTIVE TRANSACTIONS HAVE BEEN ROLLED BACK.'
  // 'HY000:-308:[SYBASE][ODBC DRIVER][SQL ANYWHERE]CONNECTION WAS TERMINATED'
  // '08S01:-21048:[MIMER][ODBC MIMER DRIVER]UNEXPECTED COMMUNICATION ERROR'
  // 'HY000:2003:[MYSQL][ODBC 5.2(W) DRIVER][MYSQLD-5.5.28-MARIADB]CAN'T CONNECT TO MYSQL SERVER ON '127.0.0.1' (10061)'
  // '08S01:-901:[ODBC FIREBIRD DRIVER][FIREBIRD]CONNECTION LOST TO DATABASE'
  c_ODBC_SQLSTATE_ConnectionIsDead_1 : array [TEngineType] of String = (
    '08S01:10054:',  // Microsoft SQL
    '08S01:30046:',  // Sybase ASE
    'HY000:-308:',   // Sybase ASA
    'HY000:1012:',   // Oracle
    '08S01:-11020:', // Informix
    '40003:-30081:', // DB2
    'HY000:2003:',   // MySQL
    '08S01:26:',     // PostgreSQL
    '08S01:-21048:', // Mimer
    '08S01:-901:',   // Firebird
    ''               // Unknown or unsupported - no mask here - empty
  );
  c_ODBC_SQLSTATE_ConnectionIsDead_2 : array [TEngineType] of String = (
    '08S02:-1:',     // Microsoft SQL
    '',              // Sybase ASE
    '',              // Sybase ASA
    '',              // Oracle
    '',              // Informix
    '',              // DB2
    '',              // MySQL
    '42P01:26:',     // PostgreSQL
    '',              // Mimer
    '',              // Firebird
    ''               // Unknown or unsupported - no mask here - empty
  );

  // '22001:8152:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0][SQL SERVER]Символьные или двоичные данные могут быть усечены.'
  c_ODBC_SQLSTATE_DataTruncation : array [TEngineType] of String = (
    '22001:8152:',   // Microsoft SQL
    '',              // Sybase ASE
    '',              // Sybase ASA
    '',              // Oracle
    '',              // Informix
    '',              // DB2
    '',              // MySQL
    '',              // PostgreSQL
    '',              // Mimer
    '',              // Firebird
    ''               // Unknown or unsupported - no mask here - empty
  );

  // 'HY000:0:[MICROSOFT][ODBC SQL SERVER DRIVER]Подключение занято до получения результатов для другого HSTMT'
  c_ODBC_SQLSTATE_UnsynchronizedStatements : array [TEngineType] of String = (
    'HY000:0:',      // Microsoft SQL
    '',              // Sybase ASE
    '',              // Sybase ASA
    '',              // Oracle
    '',              // Informix
    '',              // DB2
    '',              // MySQL
    '',              // PostgreSQL
    '',              // Mimer
    '',              // Firebird
    ''               // Unknown or unsupported - no mask here - empty
  );

  // PostgreSQL:
  // 'HY000:1:CONNECTION IS READONLY, ONLY SELECT STATEMENTS ARE ALLOWED.'
  // others:
  // '25000:3906:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0][SQL SERVER]Не удалось обновить базу данных "SAS_MS", так как она предназначена только для чтения.'
  // 'ZZZZZ:3906:[SYBASE][ODBC DRIVER][ADAPTIVE SERVER ENTERPRISE]ATTEMPT TO BEGIN TRANSACTION IN DATABASE 'SAS_ASE' FAILED BECAUSE DATABASE IS READ ONLY.'#$A
  // 'HY000:-817:[ODBC FIREBIRD DRIVER][FIREBIRD]ATTEMPTED UPDATE DURING READ-ONLY TRANSACTION'
  c_ODBC_SQLSTATE_ReadOnlyConnection : array [TEngineType] of String = (
    '25000:3906:',   // Microsoft SQL
    'ZZZZZ:3906:',   // Sybase ASE
    '',              // Sybase ASA
    '',              // Oracle
    '',              // Informix
    '',              // DB2
    '',              // MySQL
    'HY000:1:',      // PostgreSQL
    '',              // Mimer
    'HY000:-817:',   // Firebird
    ''               // Unknown or unsupported - no mask here - empty
  );
  

  // максимальная общая длина sqlstate и nativeerror в начале текста исключения
  c_ODBC_SQLSTATE_MAX_LEN = 15;

{$if defined(ETS_USE_DBX)}
function GetEngineTypeByDBXDriverName(
  const ADBXDriverName: String;
  const AODBCDescription: WideString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;
{$ifend}

{$if defined(ETS_USE_ZEOS)}
function GetEngineTypeByZEOSLibProtocol(const AZEOSLibProtocol: String): TEngineType;
{$ifend}

function GetEngineTypeByODBCDescription(
  const AODBCDescription: AnsiString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;

function GetEngineTypeUsingSQL_Version_Upper(const AUppercasedText: AnsiString; var AResult: TEngineType): Boolean;

function GetEngineTypeUsingSelectVersionException(const AException: Exception): TEngineType;
function GetEngineTypeUsingSelectFromDualException(const AException: Exception): TEngineType;

// формирует 16-ричную константу для записи BLOB-а, есть работа через параметры невозможна
function ConvertTileToHexLiteralValue(const ABuffer: Pointer; const ASize: LongInt): TDBMS_String;

// проверка что текст исключения начинается с AStarter
function OdbcEceptionStartsWith(const AText, AStarter: String): Boolean;

// стандартный код ошибки независимо от контекста выполнения
// если да - заполняется AResult
// если нет - AResult не трогается
function StandardExceptionType(
  const AStatementExceptionType: TStatementExceptionType;
  const ASkipUnknown: Boolean;
  var AResult: Byte
): Boolean;

implementation

function GetEngineTypeByODBCDescription(
  const AODBCDescription: AnsiString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;
var VDescUpper: String;
begin
  VDescUpper := UpperCase(AODBCDescription);
  ASecondarySQLCheckServerTypeMode := schstm_None;
  if (System.Pos('MIMER', VDescUpper)>0) then begin
    // MIMER
    Result := et_Mimer;
  end else if (System.Pos('FIREBIRD', VDescUpper)>0) then begin
    // FIREBIRD
    Result := et_Firebird;
  end else if (System.Pos('POSTGRESQL', VDescUpper)>0) then begin
    // POSTGRESQL
    Result := et_PostgreSQL;
  end else if (System.Pos('MYSQL', VDescUpper)>0) then begin
    // MYSQL
    Result := et_MySQL;
  end else if (System.Pos('ORACLE', VDescUpper)>0) then begin
    // ORACLE
    Result := et_Oracle;
  end else if (System.Pos('INFORMIX', VDescUpper)>0) then begin
    // INFORMIX
    Result := et_Informix;
  end else if (System.Pos('DB2', VDescUpper)>0) then begin
    // DB2
    Result := et_DB2;
  end else if (System.Pos('ADAPTIVE', VDescUpper)>0) and (System.Pos('SERVER', VDescUpper)>0) and (System.Pos('ENTERPRISE', VDescUpper)>0) then begin
    // ASE
    Result := et_ASE;
  end else if (System.Pos('SQL', VDescUpper)>0) and (System.Pos('ANYWHERE', VDescUpper)>0) then begin
    // ASA
    Result := et_ASA;
  end else if ('SQL SERVER'=VDescUpper) then begin
    // MSSQL
    Result := et_MSSQL;
  end else if (System.Pos('SYBASE', VDescUpper)>0) then begin
    // some sybase
    ASecondarySQLCheckServerTypeMode := schstm_SomeSybase;
    Result := et_Unknown;
  end else begin
    Result := et_Unknown;
  end;
end;

{$if defined(ETS_USE_DBX)}
function GetEngineTypeByDBXDriverName(
  const ADBXDriverName: String;
  const AODBCDescription: WideString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;
begin
  ASecondarySQLCheckServerTypeMode := schstm_None;

  if (0=Length(ADBXDriverName)) then begin
    Result := et_Unknown;
    Exit;
  end;

  if SameText(c_ODBC_DriverName,ADBXDriverName) then begin
    // check by ODBC driver description
    Result := GetEngineTypeByODBCDescription(AODBCDescription, ASecondarySQLCheckServerTypeMode);
    Exit;
  end;

  if SameText(c_RTL_Interbase,ADBXDriverName) then begin
    // Interbase - for Firebird
    Result := et_Firebird;
    Exit;
  end;

  Result := Low(Result);
  while (Result<et_Unknown) do begin
    if (0<Length(c_SQL_DBX_Driver_Name[Result])) and SameText(ADBXDriverName, c_SQL_DBX_Driver_Name[Result]) then
      Exit;
    Inc(Result);
  end;
end;
{$ifend}

{$if defined(ETS_USE_ZEOS)}
function GetEngineTypeByZEOSLibProtocol(const AZEOSLibProtocol: String): TEngineType;
var V3: String;
begin
  V3 := System.Copy(AZEOSLibProtocol,1,3);
  if (3=Length(V3)) then begin
    // check names below
    // do not support interbase and sqlite
    V3 := LowerCase(V3);
    if (V3='db2') then
      Result := et_DB2
    else if (V3='fir') then
      Result := et_Firebird
    else if (V3='mss') then
      Result := et_MSSQL
    else if (V3='mys') then
      Result := et_MySQL
    else if (V3='ora') then
      Result := et_Oracle
    else if (V3='pos') then
      Result := et_PostgreSQL
    else if (V3='syb') then
      Result := et_ASE
    else
      Result := et_Unknown;
  end else begin
    Result := et_Unknown;
  end;

(*
'db2'
'firebird-1.0'
'firebird-1.5'
'firebird-2.0'
'interbase-5'
'interbase-6'
'mssql'
'mysql'
'mysql-4.0'
'mysql-4.1'
'oracle'
'postgresql'
'postgresql-8.0'
'postgresql-8.1'
'sqlite-2.8'
'sqlite-3'
'sybase'
*)
end;
{$ifend}

function GetEngineTypeUsingSQL_Version_Upper(const AUppercasedText: AnsiString; var AResult: TEngineType): Boolean;
begin
  if (System.Pos('ADAPTIVE SERVER ENTERPRISE', AUppercasedText)>0) then begin
    // Sybase ASE
    // 'ADAPTIVE SERVER ENTERPRISE/12.5.4/EBF 16791 ESD#10/P/NT (IX86)/OS 4.0/ASE1254/2159/32-BIT/OPT/MON NOV 02 05:01:55 2009'
    AResult := et_ASE;
    Result := TRUE;
  end else if (System.Pos('ANYWHERE', AUppercasedText)>0) then begin
    // Sybase ASA
    AResult := et_ASA;
    Result := TRUE;
  end else if (System.Pos('MICROSOFT', AUppercasedText)>0) and
              (System.Pos('SQL', AUppercasedText)>0) and
              (System.Pos('SERVER', AUppercasedText)>0) then begin
    // MSSQL
    // 'MICROSOFT SQL SERVER 2008 R2 (SP2) - 10.50.4000.0 (INTEL X86) '#$A#9'JUN 28 2012 08:42:37 '#$A#9'COPYRIGHT (C) MICROSOFT CORPORATION'#$A#9'DEVELOPER EDITION ON WINDOWS NT 6.0 <X86> (BUILD 6002: SERVICE PACK 2)'
    AResult := et_MSSQL;
    Result := TRUE;
  end else begin
    // unknown
    Result := FALSE;
  end;
end;

function GetEngineTypeUsingSelectVersionException(const AException: Exception): TEngineType;
begin
  // варианты ответа сервера:
  // нет секции FROM
  // нет такой переменной
  // полный бред и неверный синтаксис
  // имя типа сервера где-то в ответе
  Result := et_Unknown;
end;

function GetEngineTypeUsingSelectFromDualException(const AException: Exception): TEngineType;
begin
  Result := et_Unknown;
end;

function ConvertTileToHexLiteralValue(const ABuffer: Pointer; const ASize: LongInt): TDBMS_String;
const
  c_max_len = 32760;
var
  VCurPos: PByte;

  function _CopyUpToBytes(ABytesToCopy: LongInt): TDBMS_String;
  begin
    Result := '';
    while (ABytesToCopy>0) do begin
      Result := Result + IntToHex(VCurPos^,2);
      Inc(VCurPos);
      Dec(ABytesToCopy);
    end;
  end;

  function _MakeCast(const ASrc: TDBMS_String): TDBMS_String;
  begin
    Result := 'CAST(x''' + ASrc + ''' as BLOB)';
  end;

  procedure _AppendPart(var ATotal: TDBMS_String; const ASrc: TDBMS_String);
  begin
    if (0<Length(ATotal)) then begin
      ATotal := ATotal + ' || ';
    end;
    ATotal := ATotal + ASrc;
  end;

var
  VBytesToCopy: LongInt;
begin
  // FB при работе через параметры возвращает ошибку
  // DBXCommon.TDBXContext.Error(???,'Incorrect values within SQLDA structure')
  // так что пишем BLOB через строковый литерал
  // но всё равно если длина больше чем примерно 32765 - всё равно FB обламывается
  if (ASize<=0) then begin
    // пусто
    Result := 'NULL';
  end else if (ASize<=c_max_len) then begin
    // один литерал
    VCurPos := ABuffer;
    VBytesToCopy := ASize;
    Result := _MakeCast(_CopyUpToBytes(VBytesToCopy));
  end else begin
    // кучка литералов, так как блоб слишком длинный
    VCurPos := ABuffer;
    VBytesToCopy := ASize;
    Result := '';

    // пока длинные - откусываем по максимуму
    while (VBytesToCopy>=c_max_len) do begin
      _AppendPart(Result, _MakeCast(_CopyUpToBytes(c_max_len)));
      VBytesToCopy := VBytesToCopy - c_max_len;
    end;

    // пропихнём остаток
    if (VBytesToCopy>0) then begin
      _AppendPart(Result, _MakeCast(_CopyUpToBytes(VBytesToCopy)));
    end;
  end;
end;

function OdbcEceptionStartsWith(const AText, AStarter: String): Boolean;
begin
  if (0=Length(AStarter)) then
    Result := FALSE
  else
    Result := (StrLIComp(@AText[1], @AStarter[1], Length(AStarter)) = 0);
end;

function StandardExceptionType(
  const AStatementExceptionType: TStatementExceptionType;
  const ASkipUnknown: Boolean;
  var AResult: Byte
): Boolean;
begin
  case AStatementExceptionType of
    set_NoSpaceAvailable: begin
      AResult := ETS_RESULT_NO_SPACE_AVAILABLE;
      Result := TRUE;
    end;
    set_ConnectionIsDead: begin
      AResult := ETS_RESULT_DISCONNECTED;
      Result := TRUE;
    end;
    set_DataTruncation: begin
      AResult := ETS_RESULT_DATA_TRUNCATION;
      Result := TRUE;
    end;
    set_UnsynchronizedStatements: begin
      AResult := ETS_RESULT_NEED_EXCLUSIVE;
      Result := TRUE;
    end;
    set_ReadOnlyConnection: begin
      AResult := ETS_RESULT_READ_ONLY;
      Result := TRUE;
    end;
    set_Unknown: begin
      AResult := ETS_RESULT_UNKNOWN_EXEPTION;
      Result := (not ASkipUnknown);
    end;
    else begin
      // все остальные зависят от контекста
      // например set_TableNotFound может быть даже успешным значением
      Result := FALSE;
    end;
  end;
end;

(*
Oracle

The environment and identifier functions provide information about the instance and
session. These functions are:
SYS_CONTEXT
SYS_GUID
SYS_TYPEID
UID
USER
USERENV

*)

(*
Mimer

attributes of the current database system or server. See
SYSTEM.SERVER_INFO on page 196.

SQL>select * from SYSTEM.SERVER_INFO;
*)

end.
