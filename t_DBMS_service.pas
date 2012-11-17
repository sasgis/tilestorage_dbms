unit t_DBMS_service;

interface

type
  TDBMS_Service_Info = packed record
    id_service: SmallInt;
    id_contenttype: SmallInt; // default contenttype
    id_ver_comp: AnsiChar; // Z_VER_COMP identifier ('0' by default)
    id_div_mode: AnsiChar; // Z_DIV_MODE identifier
    work_mode: AnsiChar; // in ['0','S','R'] ('0' by default)
    use_common_tiles: AnsiChar; // boolean ('0' by default)
  end;

  (*
  TDBMS_Service = record
    service_code: AnsiString; // use in DB only
    service_name: AnsiString; // use in host only
    service_info: TDBMS_Service_Info;
  end;
  PDBMS_Service = ^TDBMS_Service;
  *)

  TDBMS_Global_Info = packed record
    max_sysname_len: SmallInt;
    max_service_code_len: SmallInt;
    max_service_name_len: SmallInt;
    max_version_len: SmallInt;
    max_contenttype_len: SmallInt;
  end;

implementation

end.
