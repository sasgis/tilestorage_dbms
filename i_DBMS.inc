////{$define DBMS_REUSE_CONNECTIONS}

// общий признак, использовать или нет датасеты
////{$define USE_ODBC_DATASET}

// используем напрямую ODBC
{$define USE_DIRECT_ODBC}

{$if defined(USE_DIRECT_ODBC)}


  {$DEFINE ODBCVER3}
  {$DEFINE ODBCVER3UP}
  //{$DEFINE ODBCVER350}
  //{$DEFINE ODBCVER351}
  //{$DEFINE ODBCVER380}

{$else}
  // если не используется напрямую ODBC
  // то используется либо DBX либо ZEOS
  {$define USE_ODBC_DATASET}

  {$define ETS_USE_ZEOS}

  {$if not defined(ETS_USE_ZEOS)}
    // для простоты поднимем флаг
    {$define ETS_USE_DBX}
  {$ifend}
{$ifend}

