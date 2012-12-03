unit t_SQL_types;

{$include i_DBMS.inc}

interface

(*

  1. dbExpress for Delphi - implemented
  2. ZeosLib for Delphi   - implemented
  3. mODBC for Delphi     - implemented

*)

uses
  SysUtils,
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
    et_PostgreSQL, // via ODBC only?
    et_Mimer,      // via ODBC only
    et_Firebird,   // via ODBC only?
    et_Unknown     // add new items before this line
  );

  TCheckEngineTypeMode = (
    cetm_None,   // do not check (if not checked yet)
    cetm_Check,  // check (if not checked yet), allow define by driver
    cetm_Force   // force re(check), ignore driver information
  );

  TQuotedPlace = (qp_Before, qp_After);

  TSqlOperation = (
    so_Select,
    so_Insert,
    so_Delete,
    so_EnumVersions,
    so_SelectInRect,
    so_Sync,
    so_Destroy
  );

  TStatementExceptionType = (set_Unknown, set_TableNotFound, set_PrimaryKeyViolation);

  TStatementRepeatType = (srt_None, srt_Insert, srt_Update);

  TSecondarySQLCheckServerTypeMode = (schstm_None, schstm_SomeSybase);

const
  c_SQLCMD_FROM_DUAL  = 'SELECT * FROM DUAL'; // if 'select @@version as v into DUAL' executed from model
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

  
(*
TOP:

MSSQL:
Select top 10 * from ...

Informix:
Select first 10 * from systables
� IDS10.00.xC3
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

const
  c_ODBC_DriverName  = 'Odbc';
  c_ODBC_LibraryName = 'dbxoodbc.dll';
  c_ODBC_GetDriverFunc = 'getSQLDriverODBCW'; // 'getSQLDriverODBC'
  c_ODBC_VendorLib = 'ODBC32.DLL';

const
  c_RTL_Connection = 'Connection';
  c_RTL_Interbase = 'Interbase'; // for Firebird
  c_RTL_Trusted_Connection = 'OS Authentication';
  c_RTL_Numeric = 'numeric';
  c_RTL_UNKNOWN = 'UNKNOWN';

  c_RTL_Tile_Body_Paramsrc  = 'tile_body'; // OK: MIMER, PostgreSQL, ASE, MSSQL
  c_RTL_Tile_Body_Paramname = ':' + c_RTL_Tile_Body_Paramsrc;

  // for ZEOS
  c_ZEOS_Protocol = 'Protocol';
  c_ZEOS_HostName = 'HostName';
  c_ZEOS_Port     = 'Port';
  c_ZEOS_Database = 'Database';
  c_ZEOS_Catalog  = 'Catalog';
  c_ZEOS_User     = 'User';
  c_ZEOS_Password = 'Password';

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
  // Port - � Params

  // prefix and suffix for identifiers for tiles
  c_SQL_QuotedIdentifierForcedForTiles: array [TEngineType] of Boolean = (
    TRUE,   // MSSQL
    FALSE,  // ASE // OK with FALSE
    FALSE,  // ASA
    FALSE,  // Oracle
    TRUE,   // Informix
    TRUE,   // DB2
    TRUE,   // MySQL
    TRUE,   // PostgreSQL // OK with TRUE
    FALSE,  // Mimer // OK with FALSE
    TRUE,   // Firebird
    FALSE
  );

  c_SQL_QuotedIdentifierValue: array [TEngineType, TQuotedPlace] of Char = (
    ('[',']'),  // MSSQL
    ('[',']'),  // ASE // OK with '[]'
    ('"','"'),  // ASA
    ('"','"'),  // Oracle
    ('_','_'),  // Informix
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
    0,   // ASE // OK with FALSE
    0,   // ASA
    0,   // Oracle
    0,   // Informix
    0,   // DB2
    0,   // MySQL
    0,   // PostgreSQL // OK with TRUE
    0,   // Mimer // OK with FALSE
    0,   // Firebird
    0
  );

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

  // sqlstate for 'table not exists' error
  c_ODBC_SQLSTATE_TableNotEists : array [TEngineType] of String = (
    '42S02:',    // Microsoft SQL
    '42S02:',    // Sybase ASE // 42000 and 42S02
    '',   // Sybase ASA
    '',   // Oracle
    '',   // Informix
    '',   // DB2
    '',    // MySQL
    '42P01:',    // PostgreSQL
    '42S02:',    // Mimer
    '',    // Firebird
    ''       // Unknown or unsupported - use c_RTL_UNKNOWN for scripts, do not insert it here
  );

  // sqlstate for primary key constraint violation
  c_ODBC_SQLSTATE_PrimaryKeyViolation : array [TEngineType] of String = (
    '23000:',    // Microsoft SQL
    '23000:',    // Sybase ASE
    '',   // Sybase ASA
    '',   // Oracle
    '',   // Informix
    '',   // DB2
    '',   // MySQL
    '23505:',    // PostgreSQL
    '23000:',    // Mimer
    '',    // Firebird
    ''       // Unknown or unsupported - use c_RTL_UNKNOWN for scripts, do not insert it here
  );


function GetEngineTypeByDBXDriverName(
  const ADBXDriverName: String;
  const AODBCDescription: WideString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;

function GetEngineTypeByZEOSLibProtocol(const AZEOSLibProtocol: String): TEngineType;

function GetEngineTypeByODBCDescription(
  const AODBCDescription: WideString;
  out ASecondarySQLCheckServerTypeMode: TSecondarySQLCheckServerTypeMode
): TEngineType;

function GetEngineTypeUsingSQL_Version_Upper(const AUppercasedText: String; var AResult: TEngineType): Boolean;

function GetEngineTypeUsingSelectVersionException(const AException: Exception): TEngineType;

// ��������� 16-������ ��������� ��� ������ BLOB-�, ���� ������ ����� ��������� ����������
function ConvertTileToHexLiteralValue(const ABuffer: Pointer; const ASize: LongInt): TDBMS_String;

implementation

function GetEngineTypeByODBCDescription(
  const AODBCDescription: WideString;
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

function GetEngineTypeUsingSQL_Version_Upper(const AUppercasedText: String; var AResult: TEngineType): Boolean;
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
  end else if (System.Pos('MICROSOFT', AUppercasedText)>0) then begin
    // MSSQL
    AResult := et_MSSQL;
    Result := TRUE;
  end else begin
    // unknown
    Result := FALSE;
  end;
end;

function GetEngineTypeUsingSelectVersionException(const AException: Exception): TEngineType;
begin
  // �������� ������ �������:
  // ��� ������ FROM
  // ��� ����� ����������
  // ������ ���� � �������� ���������
  // ��� ���� ������� ���-�� � ������
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
  // FB ��� ������ ����� ��������� ���������� ������
  // DBXCommon.TDBXContext.Error(???,'Incorrect values within SQLDA structure')
  // ��� ��� ����� BLOB ����� ��������� �������
  // �� �� ����� ���� ����� ������ ��� �������� 32765 - �� ����� FB ������������
  if (ASize<=0) then begin
    // �����
    Result := 'NULL';
  end else if (ASize<=c_max_len) then begin
    // ���� �������
    VCurPos := ABuffer;
    VBytesToCopy := ASize;
    Result := _MakeCast(_CopyUpToBytes(VBytesToCopy));
  end else begin
    // ����� ���������, ��� ��� ���� ������� �������
    VCurPos := ABuffer;
    VBytesToCopy := ASize;
    Result := '';

    // ���� ������� - ���������� �� ���������
    while (VBytesToCopy>=c_max_len) do begin
      _AppendPart(Result, _MakeCast(_CopyUpToBytes(c_max_len)));
      VBytesToCopy := VBytesToCopy - c_max_len;
    end;

    // ��������� �������
    if (VBytesToCopy>0) then begin
      _AppendPart(Result, _MakeCast(_CopyUpToBytes(VBytesToCopy)));
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
