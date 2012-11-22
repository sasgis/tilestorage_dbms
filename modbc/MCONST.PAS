unit mconst;

interface

resourcestring
  SmUpdateFailed = 'Update failed';
  SmParameterNotFound = 'Parameter ''%s'' not found';
  SmParamTooBig = 'Parameter ''%s'', cannot save data larger than %d bytes';
  SmParameterTypes = ';Input;Output;Input/Output;Result';
  SmInvalidParamFieldType = 'Must have a valid field type selected';
  SmTruncationError = 'Parameter ''%s'' truncated on output';
  SmInvalidVersion = 'Unable to load bind parameters';
  SmFieldUndefinedType = 'Field ''%s'' is of unknown type';
  SmFieldUnsupportedType = 'Field ''%s'' is of an unsupported type';
  SmNoDataSource = 'ODBC datasource not defined';
  SmForwardNotSupported = 'FORWARD ONLY cursors not supported, use ODBC cursor library';
  SmAllocateSTMTError = 'Can`t allocate statement handle';
  SmAllocateHENVError = 'Can`t allocate enviroument handle';
  SmAllocateHDBCError = 'Can`t allocate HDBC handle';

  SmUndefinedRecNo = 'Record Number can''t be determined by driver';
  SmErrAbsSetToRec = 'Absolute set to record is not supported by driver';
  SmFieldUnupdatedType = 'Sorry :(  but this type not supported for update. Look SetFieldData function';
  SmStatementUndefined = 'sql statement not defined';
  SmNoRowsAffected = 'No rows affected';
  SmMoreRowsAffected = 'More then one rows affected';
  SmInsertNotSupported = 'Internal insert is not supported by the driver';
  SmUpdateNotSupported = 'Internal update is not supported by the driver';
  SmDeleteNotSupported = 'Internal delete is not supported by the driver';
  SmSetEnvAttrError = 'Can`t set enviroument attribute';
  SmDatabaseNotOpened = 'Database not opened';
  SmTextFalse = 'False';
  SmTextTrue = 'True';

implementation

end.
 