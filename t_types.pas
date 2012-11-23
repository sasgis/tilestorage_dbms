unit t_types;

{$include i_DBMS.inc}

interface

type
{$if defined(ETS_USE_DBX)}
  TDBMS_String = WideString;
{$else}
  TDBMS_String = String;
{$ifend}


implementation

end.
