unit t_types;

{$include i_DBMS.inc}

interface

{$if defined(ETS_USE_DBX)}
  {$define USE_WIDESTRING_FOR_SQL}
{$ifend}

type
{$if defined(USE_WIDESTRING_FOR_SQL)}
  TDBMS_String = WideString;
{$else}
  TDBMS_String = String;
{$ifend}


implementation

end.
