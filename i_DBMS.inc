////{$define DBMS_REUSE_CONNECTIONS}

// используем напрямую ODBC
{$define USE_DIRECT_ODBC}

{$if defined(USE_DIRECT_ODBC)}

  {$define CONNECTION_AS_RECORD}

  {$if not defined(CONNECTION_AS_RECORD)}
    // для простоты поднимем флаг
    {$define CONNECTION_AS_CLASS}
  {$ifend}

  {$DEFINE ODBCVER3}
  {$DEFINE ODBCVER3UP}
  //{$DEFINE ODBCVER350}
  //{$DEFINE ODBCVER351}
  //{$DEFINE ODBCVER380}

{$else}
  // если не используется напрямую ODBC
  // то используется либо DBX либо ZEOS
  {$define ETS_USE_ZEOS}

  {$if not defined(ETS_USE_ZEOS)}
    // для простоты поднимем флаг
    {$define ETS_USE_DBX}
  {$ifend}

  {$if defined(ETS_USE_DBX)}
    {$define USE_WIDESTRING_FOR_SQL}
  {$ifend}

{$ifend}

