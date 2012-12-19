unit u_TSS;

{$include i_DBMS.inc}

interface

uses
  SysUtils,
  Classes,
  t_ETS_Path,
  t_types,
  t_SQL_types,
  t_TSS,
  i_TSS,
  u_DBMS_Connect;

type
  TTSS_Base = class(TObject)
  private
    FNext_TSS: TTSS_Base;
    FTSS_Info: TTSS_Info;
  public
    property Next_TSS: TTSS_Base read FNext_TSS;
    property TSS_Info: TTSS_Info read FTSS_Info;
  end;

  // некоторые имеют своё подключение к СУБД, некоторые - нет
  TTSS_WithConnection = class(TTSS_Base)
  protected
    FSQLConnection: TDBMS_Custom_Connection;
    FSyncPool: IReadWriteSync;
    FPath: TETS_Path_Divided_W;
    FEngineType: TEngineType;
    FODBCDescription: WideString;
    // внутренние параметры из ini (кроме тех что хранятся отдельно и кроме параметров TSS)
    FInternalParams: TStringList;
    // формально это не схема, а префикс полностью (при необходимости - с точкой и сразу quoted)
    FETS_INTERNAL_SCHEMA_PREFIX: TDBMS_String;
    // если будет более одной DLL - переделать на TStringList
    FInternalLoadLibraryStd: THandle;
    FInternalLoadLibraryAlt: THandle;
    // кэшируем результат коннекта к серверу
    FConnectionErrorMessage: String;
    FConnectionErrorCode: Byte;
    // если TRUE - пароль будет сохраняться как Lsa Secret
    // если FALSE - просто в реестре (в обоих случаях он шифруется)
    FSavePwdAsLsaSecret: Boolean;
    FReadPrevSavedPwd: Boolean;
  end;

  // отдельно выделяется первичная секция - она должна быть всегда
  // первичная всегда имеет подключение к СУБД
  TTSS_Primary = class(TTSS_WithConnection)
  end;

  // некоторые вторичные имеют своё подключение к СУБД
  // тогда здесь нет отдельной ссылки на первичную
  TTSS_Secondary_WithConnection = class(TTSS_WithConnection)
  end;

  // некоторые вторичные не имеют своего подключение к СУБД
  // тогда используется первичное подключение
  TTSS_Secondary_WithoutConnection = class(TTSS_Base)
  private
    FPrimaryTSS: TTSS_Primary;
  public
    property PrimaryTSS: TTSS_Primary read FPrimaryTSS;
  end;

  //
  TTSS_Secondary_AnotherSection = class(TTSS_Secondary_WithConnection)
  end;

  //
  TTSS_Secondary_SystemDSNOnly = class(TTSS_Secondary_WithConnection)
  end;

  // отдельная секция реализована через специальный префикс
  // например для того чтобы таблица имела другого владельца или была в другой БД на этом же сервере
  // все параметры берутся из первичной секции
  TTSS_Secondary_OverridePrefix = class(TTSS_Secondary_WithoutConnection)
  end;

implementation

end.