// используем напрямую ODBC
{$define USE_DIRECT_ODBC}

{$if defined(USE_DIRECT_ODBC)}
  // признак ранней линковки ODBC
  {$define USE_STATIC_LINK_ODBC}
  // признак использования MODBC
  {$define USE_MODBC}

  {$if not defined(USE_MODBC)}
    {$define USE_VSAODBC}
  {$ifend}
  
{$else}
  // если не используется напрямую ODBC
  // то используется либо DBX либо ZEOS
  {$define ETS_USE_ZEOS}

  {$if not defined(ETS_USE_ZEOS)}
    // для простоты поднимем флаг
    {$define ETS_USE_DBX}
  {$ifend}
{$ifend}

