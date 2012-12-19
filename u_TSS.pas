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

  // ��������� ����� ��� ����������� � ����, ��������� - ���
  TTSS_WithConnection = class(TTSS_Base)
  protected
    FSQLConnection: TDBMS_Custom_Connection;
    FSyncPool: IReadWriteSync;
    FPath: TETS_Path_Divided_W;
    FEngineType: TEngineType;
    FODBCDescription: WideString;
    // ���������� ��������� �� ini (����� ��� ��� �������� �������� � ����� ���������� TSS)
    FInternalParams: TStringList;
    // ��������� ��� �� �����, � ������� ��������� (��� ������������� - � ������ � ����� quoted)
    FETS_INTERNAL_SCHEMA_PREFIX: TDBMS_String;
    // ���� ����� ����� ����� DLL - ���������� �� TStringList
    FInternalLoadLibraryStd: THandle;
    FInternalLoadLibraryAlt: THandle;
    // �������� ��������� �������� � �������
    FConnectionErrorMessage: String;
    FConnectionErrorCode: Byte;
    // ���� TRUE - ������ ����� ����������� ��� Lsa Secret
    // ���� FALSE - ������ � ������� (� ����� ������� �� ���������)
    FSavePwdAsLsaSecret: Boolean;
    FReadPrevSavedPwd: Boolean;
  end;

  // �������� ���������� ��������� ������ - ��� ������ ���� ������
  // ��������� ������ ����� ����������� � ����
  TTSS_Primary = class(TTSS_WithConnection)
  end;

  // ��������� ��������� ����� ��� ����������� � ����
  // ����� ����� ��� ��������� ������ �� ���������
  TTSS_Secondary_WithConnection = class(TTSS_WithConnection)
  end;

  // ��������� ��������� �� ����� ������ ����������� � ����
  // ����� ������������ ��������� �����������
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

  // ��������� ������ ����������� ����� ����������� �������
  // �������� ��� ���� ����� ������� ����� ������� ��������� ��� ���� � ������ �� �� ���� �� �������
  // ��� ��������� ������� �� ��������� ������
  TTSS_Secondary_OverridePrefix = class(TTSS_Secondary_WithoutConnection)
  end;

implementation

end.