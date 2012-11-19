unit t_types;

{$include i_DBMS.inc}

interface

type
{$if defined(ETS_USE_ZEOS)}
  TDBMS_String = String;
{$else}
  TDBMS_String = WideString;
{$ifend}


implementation

end.
