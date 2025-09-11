unit odbcsql;

interface

{$IF CompilerVersion < 19}
type
  NativeInt = Integer;
  NativeUInt = Cardinal;
{$IFEND}

const
  odbc_lib_name = 'odbc32.dll';

const
  SQL_NULL_DATA    = -1;
  SQL_DATA_AT_EXEC = -2;
  SQL_NO_TOTAL     = -4;

  // return values from functions
  SQL_SUCCESS           = 0;
  SQL_SUCCESS_WITH_INFO = 1;

  SQL_NO_DATA = 100;

  SQL_PARAM_TYPE_UNKNOWN   = 0;
  SQL_PARAM_INPUT          = 1;
  SQL_PARAM_INPUT_OUTPUT   = 2;
  SQL_RESULT_COL           = 3;
  SQL_PARAM_OUTPUT         = 4;
  SQL_RETURN_VALUE         = 5;
  SQL_PARAM_DATA_AVAILABLE = 101;

  SQL_ERROR          = -1;
  SQL_INVALID_HANDLE = -2;

  SQL_STILL_EXECUTING = 2;
  SQL_NEED_DATA       = 99;

  // flags for null-terminated string
  SQL_NTS  = -3;
  SQL_NTSL = -3;

  // maximum message length
  SQL_MAX_MESSAGE_LENGTH = 512;

  // date/time length constants
  SQL_DATE_LEN      = 10;
  // add P+1 if precision is nonzero
  SQL_TIME_LEN      = 8;
  // add P+1 if precision is nonzero
  SQL_TIMESTAMP_LEN = 19;

  // handle type identifiers
  SQL_HANDLE_ENV  = 1;
  SQL_HANDLE_DBC  = 2;
  SQL_HANDLE_STMT = 3;
  SQL_HANDLE_DESC = 4;

  // env attribute
  SQL_ATTR_ODBC_VERSION       = 200;
  SQL_ATTR_CONNECTION_POOLING = 201;
  SQL_ATTR_CP_MATCH           = 202;
  SQL_ATTR_OUTPUT_NTS         = 10001;
  SQL_OV_ODBC3 = pointer(3);

  // values for SQLStatistics()
  SQL_INDEX_UNIQUE = 0;
  SQL_INDEX_ALL    = 1;
  SQL_QUICK        = 0;
  SQL_ENSURE       = 1;

  // connection attributes
  SQL_ACCESS_MODE       = 101;
  SQL_AUTOCOMMIT        = 102;
  SQL_LOGIN_TIMEOUT     = 103;
  SQL_OPT_TRACE         = 104;
  SQL_OPT_TRACEFILE     = 105;
  SQL_TRANSLATE_DLL     = 106;
  SQL_TRANSLATE_OPTION  = 107;
  SQL_TXN_ISOLATION     = 108;
  SQL_CURRENT_QUALIFIER = 109;
  SQL_ODBC_CURSORS      = 110;
  SQL_QUIET_MODE        = 111;
  SQL_PACKET_SIZE       = 112;
  SQL_ATTR_AUTO_IPD     = 10001;
  SQL_ATTR_METADATA_ID  = 10014;

  // statement attributes
  SQL_QUERY_TIMEOUT           = 0;
  SQL_ATTR_APP_ROW_DESC       = 10010;
  SQL_ATTR_APP_PARAM_DESC     = 10011;
  SQL_ATTR_IMP_ROW_DESC       = 10012;
  SQL_ATTR_IMP_PARAM_DESC     = 10013;
  SQL_ATTR_QUERY_TIMEOUT      = SQL_QUERY_TIMEOUT; // ODBC 3.0
  SQL_ATTR_CURSOR_SCROLLABLE  = -1;
  SQL_ATTR_CURSOR_SENSITIVITY = -2;

  // SQL_ATTR_CURSOR_SCROLLABLE values
  SQL_NONSCROLLABLE = 0;
  SQL_SCROLLABLE    = 1;

	// SQL_AUTOCOMMIT options
  SQL_AUTOCOMMIT_OFF = pointer(0);
  SQL_AUTOCOMMIT_ON  = pointer(1);

  // identifiers of fields in the SQL descriptor
  SQL_DESC_COUNT                  = 1001;
  SQL_DESC_TYPE                   = 1002;
  SQL_DESC_LENGTH                 = 1003;
  SQL_DESC_OCTET_LENGTH_PTR       = 1004;
  SQL_DESC_PRECISION              = 1005;
  SQL_DESC_SCALE                  = 1006;
  SQL_DESC_DATETIME_INTERVAL_CODE = 1007;
  SQL_DESC_NULLABLE               = 1008;
  SQL_DESC_INDICATOR_PTR          = 1009;
  SQL_DESC_DATA_PTR               = 1010;
  SQL_DESC_NAME                   = 1011;
  SQL_DESC_UNNAMED                = 1012;
  SQL_DESC_OCTET_LENGTH           = 1013;
  SQL_DESC_ALLOC_TYPE             = 1099;

  // identifiers of fields in the diagnostics area
  SQL_DIAG_RETURNCODE            = 1;
  SQL_DIAG_NUMBER                = 2;
  SQL_DIAG_ROW_COUNT             = 3;
  SQL_DIAG_SQLSTATE              = 4;
  SQL_DIAG_NATIVE                = 5;
  SQL_DIAG_MESSAGE_TEXT          = 6;
  SQL_DIAG_DYNAMIC_FUNCTION      = 7;
  SQL_DIAG_CLASS_ORIGIN          = 8;
  SQL_DIAG_SUBCLASS_ORIGIN       = 9;
  SQL_DIAG_CONNECTION_NAME       = 10;
  SQL_DIAG_SERVER_NAME           = 11;
  SQL_DIAG_DYNAMIC_FUNCTION_CODE = 12;

  // SQL data type codes
  SQL_UNKNOWN_TYPE  = 0;
  SQL_CHAR          = 1;
  SQL_NUMERIC       = 2;
  SQL_DECIMAL       = 3;
  SQL_INTEGER       = 4;
  SQL_SMALLINT      = 5;
  SQL_FLOAT         = 6;
  SQL_REAL          = 7;
  SQL_DOUBLE        = 8;
  SQL_DATETIME      = 9;
  SQL_DATE          = 9;
  SQL_INTERVAL      = 10;
  SQL_TIME          = 10;
  SQL_TIMESTAMP     = 11;
  SQL_VARCHAR       = 12;
  SQL_LONGVARCHAR   = -1;
  SQL_BINARY        = -2;
  SQL_VARBINARY     = -3;
  SQL_LONGVARBINARY = -4;
  SQL_BIGINT        = -5;
  SQL_TINYINT       = -6;
  SQL_BIT           = -7;
  SQL_WCHAR         = -8;
  SQL_WVARCHAR      = -9;
  SQL_WLONGVARCHAR  = -10;
  SQL_GUID          = -11;

  // One-parameter shortcuts for date/time data types
  SQL_TYPE_DATE      = 91;
  SQL_TYPE_TIME      = 92;
  SQL_TYPE_TIMESTAMP = 93;

  // C datatype to SQL datatype mapping
  SQL_SIGNED_OFFSET    = -20;
  SQL_UNSIGNED_OFFSET  = -22;

  SQL_C_CHAR           = SQL_CHAR;
  SQL_C_WCHAR          = SQL_WCHAR;
  SQL_C_LONG           = SQL_INTEGER;
  SQL_C_SHORT          = SQL_SMALLINT;
  SQL_C_FLOAT          = SQL_REAL;
  SQL_C_DOUBLE         = SQL_DOUBLE;
  SQL_C_NUMERIC        = SQL_NUMERIC;
  SQL_C_DEFAULT        = 99;
  SQL_C_DATE           = SQL_DATE;
  SQL_C_TIME           = SQL_TIME;
  SQL_C_TIMESTAMP      = SQL_TIMESTAMP;
  SQL_C_TYPE_DATE      = SQL_TYPE_DATE;
  SQL_C_TYPE_TIME      = SQL_TYPE_TIME;
  SQL_C_TYPE_TIMESTAMP = SQL_TYPE_TIMESTAMP;
  SQL_C_BINARY         = SQL_BINARY;
  SQL_C_BIT            = SQL_BIT;
  SQL_C_TINYINT        = SQL_TINYINT;
  SQL_C_SBIGINT        = SQL_BIGINT  + SQL_SIGNED_OFFSET;
  SQL_C_UBIGINT        = SQL_BIGINT  + SQL_UNSIGNED_OFFSET;
  SQL_C_SLONG          = SQL_C_LONG  + SQL_SIGNED_OFFSET;
  SQL_C_SSHORT         = SQL_C_SHORT + SQL_SIGNED_OFFSET;
  SQL_C_STINYINT       = SQL_TINYINT + SQL_SIGNED_OFFSET;
  SQL_C_ULONG          = SQL_C_LONG  + SQL_UNSIGNED_OFFSET;
  SQL_C_USHORT         = SQL_C_SHORT + SQL_UNSIGNED_OFFSET;
  SQL_C_UTINYINT       = SQL_TINYINT + SQL_UNSIGNED_OFFSET;

  // Driver specific SQL data type defines.
  // Microsoft has -150 thru -199 reserved for Microsoft SQL Server Native
  // Client driver usage
  SQL_SS_VARIANT         = -150;
  SQL_SS_UDT             = -151;
  SQL_SS_XML             = -152;
  SQL_SS_TABLE           = -153;
  SQL_SS_TIME2           = -154;
  SQL_SS_TIMESTAMPOFFSET = -155;

  // Statement attribute values for cursor sensitivity
  SQL_UNSPECIFIED = 0;
  SQL_INSENSITIVE = 1;
  SQL_SENSITIVE   = 2;

  // GetTypeInfo() request for all data types
  SQL_ALL_TYPES = 0;

  // Default conversion code for SQLBindCol(), SQLBindParam() and SqlGetData()
  SQL_DEFAULT = 99;

  // SQLSQLLEN GetData() code indicating that the application row descriptor
  // specifies the data type
  SQL_ARD_TYPE = -99;
  SQL_APD_TYPE = -100;

  // SQL date/time type subcodes
  SQL_CODE_DATE      = 1;
  SQL_CODE_TIME      = 2;
  SQL_CODE_TIMESTAMP = 3;

  // CLI option values
  SQL_FALSE = 0;
  SQL_TRUE  = 1;

  // values of NULLABLE field in descriptor
  SQL_NO_NULLS = 0;
  SQL_NULLABLE = 1;

  // Value returned by SqlGetTypeInfo() to denote that it is
  // not known whether or not a data type supports null values.
  SQL_NULLABLE_UNKNOWN = 2;

  // Values returned by SqlGetTypeInfo() to show WHERE clause supported
  SQL_PRED_NONE  = 0;
  SQL_PRED_CHAR  = 1;
  SQL_PRED_BASIC = 2;

  // values of UNNAMED field in descriptor
  SQL_NAMED   = 0;
  SQL_UNNAMED = 1;

  // values of ALLOC_TYPE field in descriptor
  SQL_DESC_ALLOC_AUTO = 1;
  SQL_DESC_ALLOC_USER = 2;

  // FreeStmt() options
  SQL_CLOSE        = 0;
  SQL_DROP         = 1;
  SQL_UNBIND       = 2;
  SQL_RESET_PARAMS = 3;

  // Codes used for FetchOrientation in SQLFetchScroll() and SQLDataSources()
  SQL_FETCH_NEXT  = 1;
  SQL_FETCH_FIRST = 2;

  // Other codes used for FetchOrientation in SQLFetchScroll()
  SQL_FETCH_LAST     = 3;
  SQL_FETCH_PRIOR    = 4;
  SQL_FETCH_ABSOLUTE = 5;
  SQL_FETCH_RELATIVE = 6;

  // SQLEndTran() options
  SQL_COMMIT   = 0;
  SQL_ROLLBACK = 1;

  // null handles returned by SQLAllocHandle()
  SQL_NULL_HENV = 0;
  SQL_NULL_HDBC = 0;
  SQL_NULL_HSTMT = 0;
  SQL_NULL_HDESC = 0;

  // null handle used in place of parent handle when allocating HENV
  SQL_NULL_HANDLE = nil;

  // Information requested by SqlGetInfo()
  SQL_MAX_DRIVER_CONNECTIONS        = 0;
  SQL_MAXIMUM_DRIVER_CONNECTIONS    = SQL_MAX_DRIVER_CONNECTIONS;
  SQL_MAX_CONCURRENT_ACTIVITIES     = 1;
  SQL_MAXIMUM_CONCURRENT_ACTIVITIES = SQL_MAX_CONCURRENT_ACTIVITIES;
  SQL_DATA_SOURCE_NAME              = 2;
  SQL_DRIVER_NAME                   = 6;
  SQL_FETCH_DIRECTION               = 8;
  SQL_SERVER_NAME                   = 13;
  SQL_SEARCH_PATTERN_ESCAPE         = 14;
  SQL_DBMS_NAME                     = 17;
  SQL_DBMS_VER                      = 18;
  SQL_ACCESSIBLE_TABLES             = 19;
  SQL_ACCESSIBLE_PROCEDURES         = 20;
  SQL_CURSOR_COMMIT_BEHAVIOR        = 23;
  SQL_DATA_SOURCE_READ_ONLY         = 25;
  SQL_DEFAULT_TXN_ISOLATION         = 26;
  SQL_IDENTIFIER_CASE               = 28;
  SQL_IDENTIFIER_QUOTE_CHAR         = 29;
  SQL_MAX_COLUMN_NAME_LEN           = 30;
  SQL_MAXIMUM_COLUMN_NAME_LENGTH    = SQL_MAX_COLUMN_NAME_LEN;
  SQL_MAX_CURSOR_NAME_LEN           = 31;
  SQL_MAXIMUM_CURSOR_NAME_LENGTH    = SQL_MAX_CURSOR_NAME_LEN;
  SQL_MAX_SCHEMA_NAME_LEN           = 32;
  SQL_MAXIMUM_SCHEMA_NAME_LENGTH    = SQL_MAX_SCHEMA_NAME_LEN;
  SQL_MAX_CATALOG_NAME_LEN          = 34;
  SQL_MAXIMUM_CATALOG_NAME_LENGTH   = SQL_MAX_CATALOG_NAME_LEN;
  SQL_MAX_TABLE_NAME_LEN            = 35;
  SQL_SCROLL_CONCURRENCY            = 43;
  SQL_TXN_CAPABLE                   = 46;
  SQL_TRANSACTION_CAPABLE           = SQL_TXN_CAPABLE;
  SQL_USER_NAME                     = 47;
  SQL_TXN_ISOLATION_OPTION          = 72;
  SQL_TRANSACTION_ISOLATION_OPTION  = SQL_TXN_ISOLATION_OPTION;
  SQL_INTEGRITY                     = 73;
  SQL_GETDATA_EXTENSIONS            = 81;
  SQL_NULL_COLLATION                = 85;
  SQL_ALTER_TABLE                   = 86;
  SQL_ORDER_BY_COLUMNS_IN_SELECT    = 90;
  SQL_SPECIAL_CHARACTERS            = 94;
  SQL_MAX_COLUMNS_IN_GROUP_BY       = 97;
  SQL_MAXIMUM_COLUMNS_IN_GROUP_BY   = SQL_MAX_COLUMNS_IN_GROUP_BY;
  SQL_MAX_COLUMNS_IN_INDEX          = 98;
  SQL_MAXIMUM_COLUMNS_IN_INDEX      = SQL_MAX_COLUMNS_IN_INDEX;
  SQL_MAX_COLUMNS_IN_ORDER_BY       = 99;
  SQL_MAXIMUM_COLUMNS_IN_ORDER_BY   = SQL_MAX_COLUMNS_IN_ORDER_BY;
  SQL_MAX_COLUMNS_IN_SELECT         = 100;
  SQL_MAXIMUM_COLUMNS_IN_SELECT     = SQL_MAX_COLUMNS_IN_SELECT;
  SQL_MAX_COLUMNS_IN_TABLE          = 101;
  SQL_MAX_INDEX_SIZE                = 102;
  SQL_MAXIMUM_INDEX_SIZE            = SQL_MAX_INDEX_SIZE;
  SQL_MAX_ROW_SIZE                  = 104;
  SQL_MAXIMUM_ROW_SIZE              = SQL_MAX_ROW_SIZE;
  SQL_MAX_STATEMENT_LEN             = 105;
  SQL_MAXIMUM_STATEMENT_LENGTH      = SQL_MAX_STATEMENT_LEN;
  SQL_MAX_TABLES_IN_SELECT          = 106;
  SQL_MAXIMUM_TABLES_IN_SELECT      = SQL_MAX_TABLES_IN_SELECT;
  SQL_MAX_USER_NAME_LEN             = 107;
  SQL_MAXIMUM_USER_NAME_LENGTH      = SQL_MAX_USER_NAME_LEN;
  SQL_OJ_CAPABILITIES               = 115;
  SQL_OUTER_JOIN_CAPABILITIES       = SQL_OJ_CAPABILITIES;

  // Options for SqlDriverConnect
  SQL_DRIVER_NOPROMPT          = 0;
  SQL_DRIVER_COMPLETE          = 1;
  SQL_DRIVER_PROMPT            = 2;
  SQL_DRIVER_COMPLETE_REQUIRED = 3;

  // SQLSetStmtAttr SQL Server Native Client driver specific defines.
  // Statement attributes
  SQL_SOPT_SS_BASE                      = 1225;
  // Text pointer logging
  SQL_SOPT_SS_TEXTPTR_LOGGING           = SQL_SOPT_SS_BASE + 0;
  // dbcurcmd SqlGetStmtOption only
  SQL_SOPT_SS_CURRENT_COMMAND           = SQL_SOPT_SS_BASE + 1;
  // Expose FOR BROWSE hidden columns
  SQL_SOPT_SS_HIDDEN_COLUMNS            = SQL_SOPT_SS_BASE + 2;
  // Set NOBROWSETABLE option
  SQL_SOPT_SS_NOBROWSETABLE             = SQL_SOPT_SS_BASE + 3;
  // Regionalize output character conversions
  SQL_SOPT_SS_REGIONALIZE               = SQL_SOPT_SS_BASE + 4;
  // Server cursor options
  SQL_SOPT_SS_CURSOR_OPTIONS            = SQL_SOPT_SS_BASE + 5;
  // Real vs. Not Real row count indicator
  SQL_SOPT_SS_NOCOUNT_STATUS            = SQL_SOPT_SS_BASE + 6;
  // Defer prepare until necessary
  SQL_SOPT_SS_DEFER_PREPARE             = SQL_SOPT_SS_BASE + 7;
  // Notification timeout
  SQL_SOPT_SS_QUERYNOTIFICATION_TIMEOUT = SQL_SOPT_SS_BASE + 8;
  // Notification message text
  SQL_SOPT_SS_QUERYNOTIFICATION_MSGTEXT = SQL_SOPT_SS_BASE + 9;
  // SQL service broker name
  SQL_SOPT_SS_QUERYNOTIFICATION_OPTIONS = SQL_SOPT_SS_BASE + 10;
  // Direct subsequent calls to parameter related methods to set properties on
  // constituent columns/parameters of container types
  SQL_SOPT_SS_PARAM_FOCUS               = SQL_SOPT_SS_BASE + 11;
  // Sets name scope for subsequent catalog function calls
  SQL_SOPT_SS_NAME_SCOPE                = SQL_SOPT_SS_BASE + 12;
  SQL_SOPT_SS_MAX_USED                  = SQL_SOPT_SS_NAME_SCOPE;

  SQL_IS_POINTER   = -4;
  SQL_IS_UINTEGER  = -5;
  SQL_IS_INTEGER   = -6;
  SQL_IS_USMALLINT = -7;
  SQL_IS_SMALLINT  = -8;

type
  SqlSmallint  = Smallint;
  SqlDate      = byte;
  SqlTime      = byte;
  SqlDecimal   = byte;
  SqlDouble    = double;
  SqlFloat     = double;
  SqlInteger   = integer;
  SqlUInteger  = cardinal;
  SqlNumeric   = byte;
  SqlPointer   = pointer;
  SqlReal      = single;
  SqlUSmallint = word;
  SqlTimestamp = byte;
  SqlVarchar   = byte;
  PSqlSmallint = ^SqlSmallint;
  PSqlInteger  = ^SqlInteger;

  SqlReturn     = SqlSmallint;
  SqlLen        = NativeInt;
  SqlULen       = NativeUInt;
  {$ifdef CPU64}
  SqlSetPosIRow = NativeUInt;
  {$else}
  SqlSetPosIRow = word;
  {$endif CPU64}
  PSqlLen = ^SqlLen;

  SqlHandle = pointer;
  SqlHEnv   = SqlHandle;
  SqlHDbc   = SqlHandle;
  SqlHStmt  = SqlHandle;
  SqlHDesc  = SqlHandle;
  SqlHWnd   = NativeUInt; // match e.g.Windows.HWND


type
  SQL_TIMESTAMP_STRUCT = packed record
    Year:     SqlSmallint;
    Month:    SqlUSmallint;
    Day:      SqlUSmallint;
    Hour:     SqlUSmallint;
    Minute:   SqlUSmallint;
    Second:   SqlUSmallint;
    Fraction: SqlUInteger;
  end;
  PSQL_TIMESTAMP_STRUCT = ^SQL_TIMESTAMP_STRUCT;

  SQL_TIME_STRUCT = packed record
    Hour:     SqlUSmallint;
    Minute:   SqlUSmallint;
    Second:   SqlUSmallint;
  end;
  PSQL_TIME_STRUCT = ^SQL_TIME_STRUCT;

  SQL_DATE_STRUCT = packed record
    year:	    SqlSmallint;
    month:	  SqlUSmallint;
    day:	    SqlUSmallint;
  end;
  PSQL_DATE_STRUCT = ^SQL_DATE_STRUCT;

function SQLAllocHandle(HandleType: SqlSmallint; InputHandle: SqlHandle;
  var OutputHandle: SqlHandle): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLBindCol(StatementHandle: SqlHStmt; ColumnNumber: SqlUSmallint;
  TargetType: SqlSmallint; TargetValue: SqlPointer;
  BufferLength: SqlLen; StrLen_or_Ind: PSqlLen): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLBindParameter(StatementHandle: SqlHStmt; ParameterNumber: SqlUSmallint;
  InputOutputType, ValueType, ParameterType: SqlSmallint; ColumnSize: SqlULen;
  DecimalDigits: SqlSmallint; ParameterValue: SqlPointer; BufferLength: SqlLen;
  var StrLen_or_Ind: SqlLen): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLCloseCursor(StatementHandle: SqlHStmt): SqlReturn;
stdcall; external odbc_lib_name;

function SQLConnectA(ConnectionHandle: SqlHDbc;
  ServerName: PAnsiChar; NameLength1: SqlSmallint;
  UserName: PAnsiChar; NameLength2: SqlSmallint;
  Authentication: PAnsiChar; NameLength3: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLConnectW(ConnectionHandle: SqlHDbc;
  ServerName: PWideChar; NameLength1: SqlSmallint;
  UserName: PWideChar; NameLength2: SqlSmallint;
  Authentication: PWideChar; NameLength3: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDataSourcesA(EnvironmentHandle: SqlHEnv; Direction: SqlUSmallint;
  ServerName: PAnsiChar;  BufferLength1: SqlSmallint; var NameLength1: SqlSmallint;
  Description: PAnsiChar; BufferLength2: SqlSmallint; var NameLength2: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDataSourcesW(EnvironmentHandle: SqlHEnv; Direction: SqlUSmallint;
  ServerName: PWideChar;  BufferLength1: SqlSmallint; var NameLength1: SqlSmallint;
  Description: PWideChar; BufferLength2: SqlSmallint; var NameLength2: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDescribeColA(StatementHandle: SqlHStmt; ColumnNumber: SqlUSmallint;
  ColumnName: PAnsiChar; BufferLength: SqlSmallint; var NameLength: SqlSmallint;
  var DataType: SqlSmallint; var ColumnSize: SqlULen; var DecimalDigits: SqlSmallint;
  var Nullable: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDescribeColW(StatementHandle: SqlHStmt; ColumnNumber: SqlUSmallint;
  ColumnName: PWideChar; BufferLength: SqlSmallint; var NameLength: SqlSmallint;
  var DataType: SqlSmallint; var ColumnSize: SqlULen; var DecimalDigits: SqlSmallint;
  var Nullable: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDisconnect(ConnectionHandle: SqlHDbc): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDriverConnectA(ConnectionHandle: SqlHDbc; WindowHandle: SQLHWnd;
  InConnectionString: PAnsiChar; StringLength1: SqlSmallint;
  OutConnectionString: PAnsiChar; BufferLength: SqlSmallint;
  var StringLength2Ptr: SqlSmallint; DriverCompletion: SqlUSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLDriverConnectW(ConnectionHandle: SqlHDbc; WindowHandle: SQLHWnd;
  InConnectionString: PWideChar; StringLength1: SqlSmallint;
  OutConnectionString: PWideChar; BufferLength: SqlSmallint;
  var StringLength2Ptr: SqlSmallint; DriverCompletion: SqlUSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLExecDirectA(StatementHandle: SqlHStmt;
  StatementText: PAnsiChar; TextLength: SqlInteger): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLExecDirectW(StatementHandle: SqlHStmt;
  StatementText: PWideChar; TextLength: SqlInteger): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLFetch(StatementHandle: SqlHStmt): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLFreeHandle(HandleType: SqlSmallint; Handle: SqlHandle): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLFreeStmt(StatementHandle: SqlHStmt; Option: SqlUSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLGetData(StatementHandle: SqlHStmt; ColumnNumber: SqlUSmallint;
  TargetType: SqlSmallint; TargetValue: SqlPointer; BufferLength: SqlLen;
  StrLen_or_Ind: PSqlLen): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLGetDiagRecA(HandleType: SqlSmallint; Handle: SqlHandle; RecNumber: SqlSmallint;
  Sqlstate: PAnsiChar; var NativeError: SqlInteger;
  MessageText: PAnsiChar; BufferLength: SqlSmallint; var TextLength: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLGetDiagRecW(HandleType: SqlSmallint; Handle: SqlHandle; RecNumber: SqlSmallint;
  Sqlstate: PWideChar; var NativeError: SqlInteger;
  MessageText: PWideChar; BufferLength: SqlSmallint; var TextLength: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLGetInfoA(ConnectionHandle: SqlHDbc; InfoType: SqlUSmallint;
  InfoValuePtr: SqlPointer; BufferLength: SqlSmallint; StringLengthPtr: PSqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLGetInfoW(ConnectionHandle: SqlHDbc; InfoType: SqlUSmallint;
  InfoValuePtr: SqlPointer; BufferLength: SqlSmallint; StringLengthPtr: PSqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLNumResultCols(StatementHandle: SqlHStmt; var ColumnCount: SqlSmallint): SqlReturn;
  stdcall; external odbc_lib_name;

function SQLSetEnvAttr(EnvironmentHandle: SqlHEnv; Attribute: SqlInteger;
  ValuePtr: SqlPointer; StringLength: SqlInteger): SqlReturn;
  stdcall; external odbc_lib_name;

{*****************************************************************************}

{ additional SQLDataSources fetch directions  }
const
  SQL_FETCH_FIRST_USER = 31;
  SQL_FETCH_FIRST_SYSTEM = 32;

{ maximum data source name size  }
const
  SQL_MAX_DSN_LENGTH = 32;
  SQL_MAX_OPTION_STRING_LENGTH = 256;

const
  // DB2
  SQL_DB2_GRAPHIC              = -95;
  SQL_DB2_VARGRAPHIC           = -96;
  SQL_DB2_LONGVARGRAPHIC       = -97;
  SQL_DB2_BLOB                 = -98;
  SQL_DB2_CLOB                 = -99;
  SQL_DB2_DBCLOB               = -350;
  SQL_DB2_XML                  = -370;
  SQL_DB2_DATALINK             = -400;
  SQL_DB2_USER_DEFINED_TYPE    = -450;
  SQL_DB2_BLOB_LOCATOR         = 31;
  SQL_DB2_CLOB_LOCATOR         = 41;
  SQL_DB2_DBCLOB_LOCATOR       = -351;

{ interval code  }
const
  SQL_CODE_YEAR = 1;
  SQL_CODE_MONTH = 2;
  SQL_CODE_DAY = 3;
  SQL_CODE_HOUR = 4;
  SQL_CODE_MINUTE = 5;
  SQL_CODE_SECOND = 6;
  SQL_CODE_YEAR_TO_MONTH = 7;
  SQL_CODE_DAY_TO_HOUR = 8;
  SQL_CODE_DAY_TO_MINUTE = 9;
  SQL_CODE_DAY_TO_SECOND = 10;
  SQL_CODE_HOUR_TO_MINUTE = 11;
  SQL_CODE_HOUR_TO_SECOND = 12;
  SQL_CODE_MINUTE_TO_SECOND = 13;

  SQL_INTERVAL_YEAR = 100+SQL_CODE_YEAR;
  SQL_INTERVAL_MONTH = 100+SQL_CODE_MONTH;
  SQL_INTERVAL_DAY = 100+SQL_CODE_DAY;
  SQL_INTERVAL_HOUR = 100+SQL_CODE_HOUR;
  SQL_INTERVAL_MINUTE = 100+SQL_CODE_MINUTE;
  SQL_INTERVAL_SECOND = 100+SQL_CODE_SECOND;
  SQL_INTERVAL_YEAR_TO_MONTH = 100+SQL_CODE_YEAR_TO_MONTH;
  SQL_INTERVAL_DAY_TO_HOUR = 100+SQL_CODE_DAY_TO_HOUR;
  SQL_INTERVAL_DAY_TO_MINUTE = 100+SQL_CODE_DAY_TO_MINUTE;
  SQL_INTERVAL_DAY_TO_SECOND = 100+SQL_CODE_DAY_TO_SECOND;
  SQL_INTERVAL_HOUR_TO_MINUTE = 100+SQL_CODE_HOUR_TO_MINUTE;
  SQL_INTERVAL_HOUR_TO_SECOND = 100+SQL_CODE_HOUR_TO_SECOND;
  SQL_INTERVAL_MINUTE_TO_SECOND = 100+SQL_CODE_MINUTE_TO_SECOND;

const
  SQL_MAX_NUMERIC_LEN = 16;

type
  SQLCHAR = Byte;
  PSQLCHAR = PAnsiChar;
  SQLWCHAR = Word;
  PSQLWCHAR = PWideChar;
  SQLSCHAR = ShortInt;

  SQLBIGINT = Int64;
  PSQLBIGINT = ^SQLBIGINT;

  PSQLDOUBLE = ^SqlDouble;

  PSQLHandle = ^SqlHandle;

  SQL_NUMERIC_STRUCT = packed record
    precision:  SQLCHAR;
    scale:      SQLSCHAR;
    sign:       SQLCHAR; //* 1 if positive, 0 if negative */
    val:        array[0..SQL_MAX_NUMERIC_LEN-1] of SQLCHAR;
  end;
  PSQL_NUMERIC_STRUCT = ^SQL_NUMERIC_STRUCT;

// test for SQL_SUCCESS or SQL_SUCCESS_WITH_INFO
function SQL_SUCCEEDED(const rc: SqlReturn): Boolean; inline;

implementation

function SQL_SUCCEEDED(const rc: SqlReturn): Boolean;
begin
  Result := (rc and (not 1)) = 0;
end;

end.

