////{$define DBMS_REUSE_CONNECTIONS}

{$define CONNECTION_AS_RECORD}

{$if not defined(CONNECTION_AS_RECORD)}
  // для простоты поднимем флаг
  {$define CONNECTION_AS_CLASS}
{$ifend}



