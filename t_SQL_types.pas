unit t_SQL_types;

interface

(*

  1. dbExpress for Delphi - implementing
  2. ZeosLib for Delphi   - not yet
  3. SQLdb for Lazarus    - not yet
  
*)


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

const
  c_SQLCMD_VERSION_S  = 'SELECT @@VERSION';  // MSSQL+ASE+ASA
  c_SQLCMD_FROM_DUAL  = 'SELECT * FROM DUAL'; // if 'select @@version as v into DUAL' executed from model
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
    ''
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
  'SYSDATE',           // Oracle
  'CURRENT DATETIME',  // Informix
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
  'DATETIME',  // ASA
  'DATE',      // Oracle
  'DATETIME',  // Informix
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
  '',          // Oracle
  '',          // Informix
  '',          // DB2
  '',          // MySQL
  '',          // PostgreSQL
  'TIMESTAMP', // Mimer
  '',          // Firebird
  ''
  );

  // type to store LongInt (4 bytes with sign)
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

  // type to store MediumInt (3 bytes with sign)
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

  // type to store SmallInt (2 bytes with sign)
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
  '',         // MSSQL
  '',         // ASE
  '',         // ASA
  '',         // Oracle NUMBER(p)
  '',         // Informix
  '',         // DB2
  '',         // MySQL
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
  '',              // ASA
  'DUAL',          // Oracle
  '',              // Informix
  '',              // DB2
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
  'create view DUAL as select @@version as ENGINE_VERSION', // ASE
  'create view DUAL as select @@version as ENGINE_VERSION', // ASA
  '', // Oracle - with DUAL by default - nothing
  '', // Informix
  '', // DB2
  '', // MySQL
  'create view DUAL as select version() as ENGINE_VERSION', // PostgreSQL
  'create view DUAL as select ''MIMER'' as ENGINETYPE from SYSTEM.ONEROW', // Mimer
  'create view DUAL as select ''FIREBIRD'' as ENGINETYPE, rdb$get_context(''SYSTEM'',''ENGINE_VERSION'') as ENGINE_VERSION from rdb$database', // Firebird
  ''
  );


(*
TOP:

MSSQL:
Select top 10 * from ...

Informix:
Select first 10 * from systables
С IDS10.00.xC3
select skip 10 limit 10 * systables;


FireBird:
set term ^;
execute block as
begin
if (not (exists(select 1 from c_contenttype where id_contenttype=1))) then
begin
  execute STATEMENT 'INSERT into c_contenttype (id_contenttype, contenttype_text) values (1, ''image/png'')';
end
end^
set term ;^

ИЛИ

set term ^;
execute block as
begin
if (not (exists(select 1 from c_contenttype where id_contenttype=1))) then
begin
  INSERT into c_contenttype (id_contenttype, contenttype_text) values (1, 'image/png');
end
end^
set term ;^

если напрямую то
execute block as
begin
if (not (exists(select 1 from c_contenttype where id_contenttype=1))) then
begin
  INSERT into c_contenttype (id_contenttype, contenttype_text)
  values (1, 'image/png');
end
end
;


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
  c_RTL_Trusted_Connection = 'Trusted_Connection';

function GetEngineTypeByDBXDriverName(const ADBXDriverName: String; const AODBCDescription: WideString): TEngineType;

function GetEngineTypeUsingSQL_Version_S(const AText: String; var AResult: TEngineType): Boolean;

implementation

uses
  SysUtils;

function GetEngineTypeByODBCDescription(const AODBCDescription: WideString): TEngineType;
var VDescUpper: String;
begin
  VDescUpper := UpperCase(AODBCDescription);
  if (System.Pos('MIMER', VDescUpper)>0) then begin
    // MIMER
    Result := et_Mimer;
  end else if (System.Pos('FIREBIRD', VDescUpper)>0) then begin
    // FIREBIRD
    Result := et_Firebird;
  end else if (System.Pos('POSTGRESQL', VDescUpper)>0) then begin
    // POSTGRESQL
    Result := et_PostgreSQL;
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
  end else if ('SQL SERVER'=VDescUpper) then begin
    // MSSQL
    Result := et_MSSQL;
  end else begin
    Result := et_Unknown;
  end;
end;

function GetEngineTypeByDBXDriverName(const ADBXDriverName: String; const AODBCDescription: WideString): TEngineType;
begin
  if (0=Length(ADBXDriverName)) then begin
    Result := et_Unknown;
    Exit;
  end;

  if SameText(c_ODBC_DriverName,ADBXDriverName) then begin
    // check by ODBC driver description
    Result := GetEngineTypeByODBCDescription(AODBCDescription);
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

function GetEngineTypeUsingSQL_Version_S(const AText: String; var AResult: TEngineType): Boolean;
begin
  if (System.Pos('microsoft', AText)>0) then begin
    // MSSQL
    AResult := et_MSSQL;
    Result := TRUE;
  end else if (System.Pos('sybase', AText)>0) then begin
    // sybase ASE or ASA
    if (System.Pos('enterprise', AText)>0) then
      AResult := et_ASE
    else
      AResult := et_ASA;
    Result := TRUE;
  end else begin
    // unknown
    Result := FALSE;
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
SERVER_ATTRIBUTE
ATTRIBUTE_VALUE
=====================================
AUTOUPGRADE_ENABLED
NO
===
CATALOG_NAME
NO
===
CATALOG_VERSION_CREATED
1000.022
===
CATALOG_VERSION_CURRENT
1000.022
===
COLLATION_SEQ
ISO 8859-1
===
CURRENT_COLLATION_ID
0
===
IDENTIFIER_LENGTH
128
===
INTERVAL_FRAC_PREC
6
===
INTERVAL_LEAD_PREC
2
===
ROW_LENGTH
16000
===
TIMESTAMP_PREC
6
===
TIME_PREC
0
===
TXN_ISOLATION
REPEATABLE READ
===
USERID_LENGTH
128
===

14 rows found

SQL functionality. See
SYSTEM.SQL_CONFORMANCE on page 198.


MIMER/DB error -12101 in function PREPARE
         Syntax error, 'FROM' IDENTIFIER  assumed missing

MIMER/DB error -12200 in function PREPARE
         Table DUAL not found,
         table does not exist or no access privilege
*)

end.
