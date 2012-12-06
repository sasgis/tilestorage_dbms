unit u_DBMS_Provider;

{$include i_DBMS.inc}

interface

uses
  Windows,
  SysUtils,
  Classes,
  t_types,
  t_SQL_types,
  t_ETS_Tiles,
  t_ETS_Path,
  t_ETS_Provider,
  t_DBMS_version,
  t_DBMS_contenttype,
  t_DBMS_service,
  t_DBMS_Template,
  i_DBMS_Provider,
  t_DBMS_Connect,
  u_DBMS_Connect,
  u_ExecuteSQLArray,
  u_DBMS_Utils;

type
  TDBMS_Provider = class(TInterfacedObject, IDBMS_Provider)
  private
    // initialization
    FStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
    FInitFlags: LongWord;  // see ETS_INIT_* constants
    FHostPointer: Pointer; // MANDATORY
    
    // sync object for common work
    FProvSync: IReadWriteSync;
    // sync object for work with guides
    FGuidesSync: IReadWriteSync;

    // flag
    FCompleted: Boolean;

    // ������� ������������� ����������������
    // ����������� ��� ������� ���������� ��������
    FReconnectPending: Boolean;

    // callbacks
    FHostCallbacks: TDBMS_INFOCLASS_Callbacks;
    
    // GlobalStorageIdentifier and ServiceName
    FPath: TETS_Path_Divided_W;

    // connection objects
    FConnection: IDBMS_Connection;

    // guides
    FVersionList: TVersionList;
    FContentTypeList: TContentTypeList;
    // primary ContentTpye from Host (from Map params)
    FPrimaryContentType: AnsiString;

    // flag (read successfully)
    FDBMS_Service_OK: Boolean;
    // service and global server params
    FDBMS_Service_Info: TDBMS_Service_Info;
    // service code (in DB only)
    FDBMS_Service_Code: AnsiString;

    // ��������� ������� ��� ��� � �����
    FFormatSettings: TFormatSettings;

    // ����������� ����������
    FUnknownExceptions: TStringList;

    // ��������������� �������� ��� ������� � ����������
    (*
    FInsertDS: array [TInsertUpdateSubType] of TDBMS_Dataset;
    FUpdateDS: array [TInsertUpdateSubType] of TDBMS_Dataset;
    *)
  private
    // common work
    procedure DoBeginWork(
      const AExclusively: Boolean;
      const AOperation: TSqlOperation;
      out AExclusivelyLocked: Boolean
    );
    procedure DoEndWork(const AExclusivelyLocked: Boolean);
    // work with guides
    procedure GuidesBeginWork(const AExclusively: Boolean);
    procedure GuidesEndWork(const AExclusively: Boolean);

    procedure ReadVersionsFromDB(const AExclusively: Boolean);
    procedure ReadContentTypesFromDB(const AExclusively: Boolean);
  private
    procedure InternalProv_Cleanup;

    function InternalProv_SetStorageIdentifier(
      const AInfoSize: LongWord;
      const AInfoData: PETS_SET_IDENTIFIER_INFO;
      const AInfoResult: PLongWord
    ): Byte;

    function InternalProv_Connect(const AExclusively: Boolean): Byte;
    function InternalProv_ReadServiceInfo(const AExclusively: Boolean): Byte;
    procedure InternalProv_ClearServiceInfo;
    procedure InternalProv_Disconnect;
    procedure InternalProv_ClearGuides;

    // ���������� ��� �������, ������������ � �� (����������)
    function InternalGetServiceNameByDB: TDBMS_String;
    // ���������� ��� �������, ������������ � ����� (�������)
    function InternalGetServiceNameByHost: TDBMS_String;

    // get version from cache (if not found - read from server)
    function InternalGetVersionAnsiValues(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean;
      const AVerValuePtr: PPAnsiChar;
      out AVerValueStr: AnsiString
    ): Boolean;

    // get contenttype from cache (if not found - read from server)
    function InternalGetContentTypeAnsiValues(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean;
      const AContentTypeTextPtr: PPAnsiChar;
      out AContentTypeTextStr: AnsiString
    ): Boolean;

  private
    // for cached version
    function GetVersionAnsiPointer(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetVersionWideString(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

    // for cached contenttype
    function GetContentTypeAnsiPointer(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;  // keep ansi
    function GetContentTypeWideString(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): WideString; // keep wide

  private
    // ��� ������ ����������� ����������
    FUnknownExceptionsCS: IReadWriteSync;
    procedure SaveUnknownException(const AException: Exception);
    procedure ClearUnknownExceptions;
    function HasUnknownExceptions: Boolean;
    function GetUnknownExceptions: String;
  private
    function SQLDateTimeToDBValue(const ADateTime: TDateTime): TDBMS_String;

    function GetSQLIntName_Div(const AXYMaskWidth, AZoom: Byte): String;

    function GetStatementExceptionType(const AException: Exception): TStatementExceptionType;

    function UpdateServiceVerComp(
      const ANewVerCompMode: AnsiChar;
      out AErrorText: String
    ): Byte;

    function UpdateTileLoadMode(
      const ANewTLMFlag: Byte;
      const AEnabled: Boolean;
      out AErrorText: String
    ): Byte;

    function UpdateTileSaveMode(
      const ANewTSMFlag: Byte;
      const AEnabled: Boolean;
      out AErrorText: String
    ): Byte;

    function UpdateVerByTileMode(
      const ANewVerByTileMode: SmallInt;
      out AErrorText: String
    ): Byte;

  private
    function CreateAllBaseTablesFromScript: Byte;
    
    // �������������� �������� ������ � ������� ������� (����������� ������� � ��)
    function AutoCreateServiceRecord(const AExclusively: Boolean): Byte;

    // �������������� �������� ������ ��� �������
    function AutoCreateServiceVersion(
      const AExclusively: Boolean;
      const AVersionAutodetected: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AReqVersionPtr: PVersionAA;
      out ARequestedVersionFound: Boolean
    ): Byte;

    function TryToObtainVerByTile(
      const AExclusively: Boolean;
      var ARequestedVersionFound: Boolean;
      const AIdContentType: SmallInt;
      var AVersionAutodetected: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      AReqVersionPtr: PVersionAA
    ): Byte;

    function GetMaxNextVersionInts(const ANewVersionPtr: PVersionAA; const AKeepVerNumber: Boolean): Boolean;

    // ������� ��� ������� ���������� �������� ������ � ����� ����� ��� ��������������� ������
    function ParseVerValueToVerNumber(
      const AGivenVersionValue: String;
      out ADoneVerNumber: Boolean;
      out ADateTimeIsDefined: Boolean;
      out ADateTimeValue: TDateTime
    ): Integer;

    function MakePtrVersionInDB(
      const ANewVersionPtr: PVersionAA;
      const AExclusively: Boolean
    ): Boolean;
    
    function MakeEmptyVersionInDB(
      const AIdVersion: SmallInt;
      const AExclusively: Boolean
    ): Boolean;
    
    function VersionExistsInDBWithIdVer(const AIdVersion: SmallInt): Boolean;

    // check if tile is in common tiles
    function CheckTileInCommonTiles(
      const ATileBuffer: Pointer;
      const ATileSize: LongInt;
      out AUseAsTileSize: LongInt
    ): Boolean;

    // create table using SQL commands from special table
    function CreateTableByTemplate(
      const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
      const AZoom: Byte;
      const ASubstSQLTypes: Boolean
    ): Byte;

    // divide XY into parts (upper - to tablename, lower - to identifiers)
    procedure InternalDivideXY(
      const AXY: TPoint;
      const ASQLTile: PSQLTile
    );

    function InternalCalcSQLTile(
      const AXYZ: PTILE_ID_XYZ;
      const ASQLTile: PSQLTile
    ): Byte;

    function FillTableNamesForTiles(
      ASQLTile: PSQLTile
    ): Boolean;

    function CalcBackToTilePos(
      XInTable, YInTable: Integer;
      const AXYUpperToTable: TPoint; //ASelectInRectItem: PSelectInRectItem;
      AXYResult: PPoint
    ): Boolean;

    function GetSQL_AddIntWhereClause(
      var AWhereClause: TDBMS_String;
      const AFieldName: TDBMS_String;
      const AWithMinBound, AWithMaxBound: Boolean;
      const AMinBoundValue, AMaxBoundValue: Integer
    ): Boolean;

  private
    procedure AddVersionOrderBy(
      const ASQLParts: PSQLParts;
      const AVerInfoPtr: PVersionAA;
      const ACutOnVersion: Boolean
    );

    // ������������ ������ SQL ��� ������ ������ �� ������ �������
    function GetSQL_SelectTilesInternal(
      const ASQLTile: PSQLTile;
      const AVersionIn: Pointer;
      const AOptionsIn: LongWord;
      const AInitialWhere: TDBMS_String;
      const ASelectXY: Boolean;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
    // ������������ ������ SQL ��� ��������� (SELECT) ����� ��� ������� TNE
    function GetSQL_SelectTile(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // ������������ ������ SQL ��� ������� (INSERT) � ���������� (UPDATE) ����� ��� ������� TNE
    // � ������ SQL �������� ������ �������� c_RTL_Tile_Body_Paramname, ��������� ������������� �����
    function GetSQL_InsertUpdateTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
      out AInsertUpdateSubType: TInsertUpdateSubType;
      out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
    ): Byte;

    // ������������ ������ SQL ��� �������� (DELETE) ����� ��� ������� TNE
    function GetSQL_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      out ADeleteSQLResult: TDBMS_String
    ): Byte;

    // ������������ ������ SQL ��� ��������� (SELECT) ������ ������������ ������ ����� (XYZ)
    function GetSQL_EnumTileVersions(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;

    // ��������� ������ ������ SQL ��� ��������� ����� ���������� �� ���������� �������
    function GetSQL_GetTileRectInfo(
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN;
      const AExclusively: Boolean;
      ASelectInRectList: TSelectInRectList
    ): Byte;

    // ��������� SQL ��� ��������� ������ ������ ��� �������� �������
    function GetSQL_SelectVersions: TDBMS_String;

    // ��������� SQL ��� ��������� ������ ����� ������
    function GetSQL_SelectContentTypes: TDBMS_String;

    // ��������� SQL ��� ������ ���������� ������� �� ��� �������� ����
    // ���� ���������� ������� ��� ��������� ��� ������������� � �����
    function GetSQL_SelectService_ByHost: TDBMS_String;

    // ��������� SQL ��� ������ ���������� ������� �� ��� ����������� ���� (��� � ��)
    function GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): TDBMS_String;

    function GetSQL_InsertIntoService(
      const AExclusively: Boolean;
      out ASQLTextResult: TDBMS_String
    ): Byte;
    
  private
    function DBMS_Complete(const AFlags: LongWord): Byte;

    // sync provider
    function DBMS_Sync(const AFlags: LongWord): Byte;

    function DBMS_SetInformation(
      const AInfoClass: Byte; // see ETS_INFOCLASS_* constants
      const AInfoSize: LongWord;
      const AInfoData: Pointer;
      const AInfoResult: PLongWord
    ): Byte;

    function DBMS_SelectTile(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_InsertTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean
    ): Byte;

    function DBMS_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN
    ): Byte;

    function DBMS_EnumTileVersions(
      const ACallbackPointer: Pointer;
      const ASelectBufferIn: PETS_SELECT_TILE_IN
    ): Byte;

    function DBMS_GetTileRectInfo(
      const ACallbackPointer: Pointer;
      const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
    ): Byte;

    function DBMS_ExecOption(
      const ACallbackPointer: Pointer;
      const AExecOptionIn: PETS_EXEC_OPTION_IN
    ): Byte;

  public
    constructor Create(
      const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS; // MANDATORY
      const AFlags: LongWord;  // see ETS_INIT_* constants
      const AHostPointer: Pointer // MANDATORY
    );
    destructor Destroy; override;
  end;
  
implementation

uses
  u_Synchronizer,
  u_Exif_Parser,
  u_Tile_Parser,
  u_DBMS_Template;

{ TDBMS_Provider }

procedure TDBMS_Provider.AddVersionOrderBy(
  const ASQLParts: PSQLParts;
  const AVerInfoPtr: PVersionAA;
  const ACutOnVersion: Boolean
);

  procedure _AddWithoutFieldValue(const AFieldName: TDBMS_String);
  begin
    ASQLParts^.SelectSQL := ASQLParts^.SelectSQL + ',w.' + AFieldName;

    ASQLParts^.OrderBySQL := ' order by ' + AFieldName + ' desc';
  
    // ��������� ������� � ��������
    ASQLParts^.FromSQL := ASQLParts^.FromSQL + ', ' + c_Prefix_Versions + InternalGetServiceNameByDB + ' w';

    ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=w.id_ver';
  end;

  procedure _AddWithFieldValue(const AFieldName, AGreatestValueForDB: TDBMS_String);
  begin
    _AddWithoutFieldValue(AFieldName);

    if ACutOnVersion then begin
      // compare using AFieldName field
      ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and w.' + AFieldName + '<=' + AGreatestValueForDB;
    end;
  end;

begin
  case FStatusBuffer^.id_ver_comp of
    TILE_VERSION_COMPARE_ID: begin
      // order by id_ver - not need to link versions
      if ACutOnVersion then begin
        // AVerInfoPtr<>nil
        ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver<=' + IntToStr(AVerInfoPtr^.id_ver);
      end;
      ASQLParts^.OrderBySQL := ' order by id_ver desc';
    end;
    TILE_VERSION_COMPARE_VALUE: begin
      // order by ver_value
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_value', DBMSStrToDB(AVerInfoPtr^.ver_value))
      else
        _AddWithoutFieldValue('ver_value');
    end;
    TILE_VERSION_COMPARE_DATE: begin
      // order by ver_value
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_date', SQLDateTimeToDBValue(AVerInfoPtr^.ver_date))
      else
        _AddWithoutFieldValue('ver_date');
    end;
    TILE_VERSION_COMPARE_NUMBER: begin
      // order by ver_value
      if (AVerInfoPtr<>nil) then
        _AddWithFieldValue('ver_number', IntToStr(AVerInfoPtr^.ver_number))
      else
        _AddWithoutFieldValue('ver_number');
    end;
    else {TILE_VERSION_COMPARE_NONE:} begin
      // cannot compare versions
      if (AVerInfoPtr<>nil) then begin
        ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=' + IntToStr(AVerInfoPtr^.id_ver);
      end;
    end;
  end;
end;

function TDBMS_Provider.AutoCreateServiceRecord(const AExclusively: Boolean): Byte;
var
  VSQLText: TDBMS_String;
begin
  // ����������� ������������ � �� ����������� ������ � ������������ ������
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  // ���������� ����� SQL ��� �������� ������
  Result := GetSQL_InsertIntoService(AExclusively, VSQLText);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // ��������� INSERT (��������� ������ � �������)
  try
    if FConnection.ExecuteDirectSQL(VSQLText) then
      Result := ETS_RESULT_OK
    else
      Result := ETS_RESULT_INVALID_STRUCTURE;
  except
    // ����������
    Result := ETS_RESULT_INVALID_STRUCTURE;
  end;
end;

function TDBMS_Provider.AutoCreateServiceVersion(
  const AExclusively: Boolean;
  const AVersionAutodetected: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AReqVersionPtr: PVersionAA;
  out ARequestedVersionFound: Boolean
): Byte;
var
  VVerIsInt: Boolean;
  VKeepVerNumber: Boolean;
  VGenerateNewIdVer: Boolean;
  VFoundAnotherVersionAA: TVersionAA;
  VDateTimeIsDefined: Boolean;
begin
  // ����������� ������ ��������� ������ � ������������ ������
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  if AVersionAutodetected then begin
    VVerIsInt := FALSE;
    VGenerateNewIdVer := TRUE;
  end else begin
    // ������ �� ���������� ������������� - ������� ����������� ������
    if (nil=AInsertBuffer^.szVersionIn) then begin
      // ��� ������
      AReqVersionPtr^.ver_value := '';
    end else if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
      // ��� Ansi
      AReqVersionPtr^.ver_value := AnsiString(PAnsiChar(AInsertBuffer^.szVersionIn));
    end else begin
      // ��� Wide
      AReqVersionPtr^.ver_value := WideString(PWideChar(AInsertBuffer^.szVersionIn));
    end;

    // ���� ������ ������
    if (0=Length(AReqVersionPtr^.ver_value)) then begin
      // �������� ���� �� ��������� ������ ������
      if c_SQL_Empty_Version_Denied[FConnection.GetCheckedEngineType] then begin
        Result := ETS_RESULT_EMPTY_VERSION_DENIED;
        Exit;
      end;

      // TODO: try to use 0 as id_ver
      if (not VersionExistsInDBWithIdVer(0)) then begin
        // ������ ������ ������ ������ ���� ���� ��� ���������
        if not c_SQL_Empty_Version_Denied[FConnection.GetCheckedEngineType] then begin
          MakeEmptyVersionInDB(0, AExclusively);
        end;
        // ������ ������ ������
        ReadVersionsFromDB(AExclusively);
        ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(0, AReqVersionPtr);
        if ARequestedVersionFound then begin
          Result := ETS_RESULT_OK;
          Exit;
        end;
      end;

      ARequestedVersionFound := FALSE;
      Result := ETS_RESULT_UNKNOWN_VERSION;
      Exit;
    end;

    VDateTimeIsDefined := FALSE;
    VVerIsInt := TryStrToInt(AReqVersionPtr^.ver_value, AReqVersionPtr^.ver_number);
    // flag to keep ver_number=ver_value even if incrementing id_ver
    VKeepVerNumber := FALSE;
    VGenerateNewIdVer := FALSE;
    // ������������� ��� ����������� �������� � �������� (��� ������������� ������)
    // ��� �������� ������� ����������� ���������� �������

    // ���� ������ �������������
    // � ���� ��� ������ � SmallInt (AReqVersionPtr^.ver_number ����� -32768 to 32767 - ��� �������� ���� �� -32768)
    // � ����� id_ver ��� ���
    // �� ������� ���������� ����������� ������ AReqVersionPtr^.ver_value
    // � ���� id_ver (SmallInt)
    // � � ���� ver_number (Integer)
  end;

  if AVersionAutodetected then begin
    // ���� ��������� ��������������� ������ �� ����� - ������ �� ����� id_ver ��� ����������
    VDateTimeIsDefined := TRUE;
    VKeepVerNumber := TRUE;
    VGenerateNewIdVer := TRUE;
  end else if VVerIsInt and (Abs(AReqVersionPtr^.ver_number)<=32767) then begin
    // ������ - ��������� ����� �����, �������� � id_ver SmallInt
    AReqVersionPtr^.id_ver := AReqVersionPtr^.ver_number;
    VKeepVerNumber := TRUE;
    if FVersionList.FindItemByIdVerInternal(AReqVersionPtr^.id_ver, @VFoundAnotherVersionAA) then begin
      // ������� ������ � ����� id_ver (�� �������� � ������ ��������� ver_value)
      ARequestedVersionFound := (VFoundAnotherVersionAA.ver_value = AReqVersionPtr^.ver_value);
      if ARequestedVersionFound then begin
        // ������ ���-�� � ������, � ������ ����� ����
        Result := ETS_RESULT_OK;
        Exit;
      end else begin
        // �� � ������� � ������� - ��������� ������ � ������ ��������� ver_value
        // ������ ���� ���� �������� ������ � ���������� ��������� ver_value � � ����� ���������� id_ver
        VGenerateNewIdVer := TRUE;
      end;
    end else begin
      // ������ � ����� id_ver �� ������� - ��� ��������� �������
      // ����� ������� ������ � ���������� ��������� id_ver, ver_number � ver_value
    end;
  end else if VVerIsInt then begin
    // ������ - ������� ����� �����, �� �������� � � id_ver SmallInt
    // ��� ��� id_ver �� ����� ��������, � ver_number � ver_value ����� �����������
    VGenerateNewIdVer := TRUE;
    VKeepVerNumber := TRUE;
  end else begin
    // ������ ������ �� ����� ����� (�������� yandex)
    // � ����� ������ ������� id_ver
    // �� ��� � ver_number �������� ���-������ ��� ���������
    VGenerateNewIdVer := TRUE;
    AReqVersionPtr^.ver_number := ParseVerValueToVerNumber(AReqVersionPtr^.ver_value, VKeepVerNumber, VDateTimeIsDefined, AReqVersionPtr^.ver_date);
  end;

  if VGenerateNewIdVer then begin
    // ������� ����� id_ver (� �������� ver_number)
    GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
  end;

  if (not VDateTimeIsDefined) then begin
    AReqVersionPtr^.ver_date := NowUTC;
  end;

  repeat
    if MakePtrVersionInDB(AReqVersionPtr, AExclusively) then begin
      ReadVersionsFromDB(AExclusively);
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(AReqVersionPtr^.id_ver, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;

    // TODO: make correct loop
    ARequestedVersionFound := FALSE;
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  until FALSE;
end;

function TDBMS_Provider.CalcBackToTilePos(
  XInTable, YInTable: Integer;
  const AXYUpperToTable: TPoint;
  AXYResult: PPoint
): Boolean;
var
  VXYMaskWidth: Byte;
begin
  // ������������ �������� �������� �������� ����������
  // ������ �� ���������� ������� �� �������� � ��������� (��������������) ������ �������
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  // ����� �����
  AXYResult^.X := XInTable;
  AXYResult^.Y := YInTable;

  // ���� �������� �� �������� - ������� "�������" �����
  if (0<VXYMaskWidth) then begin
    AXYResult^.X := AXYResult^.X or (AXYUpperToTable.X shl VXYMaskWidth);
    AXYResult^.Y := AXYResult^.Y or (AXYUpperToTable.Y shl VXYMaskWidth);
  end;

  Result := TRUE;

{
  // ������ ������:
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  if (0=VXYMaskWidth) then begin
    // do not divide
    ASQLTile^.XYUpperToTable.X := 0;
    ASQLTile^.XYUpperToTable.Y := 0;
    ASQLTile^.XYLowerToID := AXY;
  end else begin
    // divide
    VMask := (1 shl VXYMaskWidth)-1;
    ASQLTile^.XYUpperToTable.X := AXY.X shr VXYMaskWidth;
    ASQLTile^.XYUpperToTable.Y := AXY.Y shr VXYMaskWidth;
    ASQLTile^.XYLowerToID.X := AXY.X and VMask;
    ASQLTile^.XYLowerToID.Y := AXY.Y and VMask;
  end;
}
end;

function TDBMS_Provider.CheckTileInCommonTiles(
  const ATileBuffer: Pointer;
  const ATileSize: LongInt;
  out AUseAsTileSize: LongInt
): Boolean;
begin
  Result := FALSE;
  AUseAsTileSize := ATileSize;
  // TODO: check size and hash
end;

procedure TDBMS_Provider.ClearUnknownExceptions;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    FreeAndNil(FUnknownExceptions);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

constructor TDBMS_Provider.Create(
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
  const AFlags: LongWord;
  const AHostPointer: Pointer
);
begin
  inherited Create;

  GetLocaleFormatSettings(GetThreadLocale, FFormatSettings);
  FFormatSettings.DecimalSeparator := '.';
  FFormatSettings.DateSeparator    := c_Date_Separator;
  FFormatSettings.TimeSeparator    := c_Time_Separator;

  FCompleted := FALSE;
  FReconnectPending := FALSE;
  
  // initialization
  FStatusBuffer := AStatusBuffer;
  FInitFlags := AFlags;
  FHostPointer := AHostPointer;

  FPrimaryContentType := '';

  // sync objects
  FProvSync := MakeSyncRW_Std(Self);
  FGuidesSync := MakeSyncRW_Std(Self);

  FConnection := nil;

  // ���� �� ��������� ��������� - ���� ������ �� �������
  // ��� ��� ������� ��������� ���� ������ ���������
  // ���������� ����������� ������
  FUnknownExceptionsCS := MakeSyncSection(Self);
  FUnknownExceptions := nil;

  FVersionList := TVersionList.Create;
  FContentTypeList := TContentTypeList.Create;

  InternalProv_Cleanup;
end;

function TDBMS_Provider.CreateAllBaseTablesFromScript: Byte;
var
  VUniqueEngineType: String;
  VSQLTemplates: TDBMS_SQLTemplates_File;
begin
  // ������� ���������� ��� ���� ����
  VUniqueEngineType := c_SQL_Engine_Name[FConnection.GetCheckedEngineType];
  // ���� ����� - ������ ����������� ���� ����, � ������ ��� ������
  if (0=Length(VUniqueEngineType)) then begin
    Result := ETS_RESULT_UNKNOWN_DBMS;
    Exit;
  end;

  // �������� ������ ��� ��������� ��������� ��� ����������� ���� ��
  VSQLTemplates := TDBMS_SQLTemplates_File.Create(
    VUniqueEngineType,
    FConnection.ForcedSchemaPrefix,
    FConnection.GetInternalParameter(ETS_INTERNAL_SCRIPT_APPENDER)
  );
  try
    // �������� �� ��� ����
    Result := VSQLTemplates.ExecuteAllSQLs(FConnection);
  finally
    VSQLTemplates.Free;
  end;
end;

function TDBMS_Provider.CreateTableByTemplate(
  const ATemplateName, AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String;
  const AZoom: Byte;
  const ASubstSQLTypes: Boolean
): Byte;
var
  VDataset: TDBMS_Dataset;
  VExecuteSQLArray: TExecuteSQLArray;
  VSQLText: TDBMS_String;
  //VSQLAnsi: AnsiString;
  Vignore_errors: AnsiChar;
  //VStream: TStream;
  //VMemStream: TMemoryStream;
  VReplaceNumeric: String;
  i: Integer;
begin
  // � ����� ��� ������� ������� � ���������
  if (not FConnection.TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
    // �������� ������� �������
    CreateAllBaseTablesFromScript;
    // � ����� ����������?
    if (not FConnection.TableExists(FConnection.ForcedSchemaPrefix+Z_ALL_SQL)) then begin
      // ������ ������ � ��� ��� ������ ������
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // ���� ����������� ������� ��� ���� - �����
  if (FConnection.TableExists(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // ������� ��� ������� SQL ��� CREATE (�������� "C") ��� ������������ �������
  VExecuteSQLArray := nil;
  try
    VDataset := FConnection.MakePoolDataset;
    try
      VSQLText := 'select index_sql,ignore_errors,object_sql from ' + FConnection.ForcedSchemaPrefix + Z_ALL_SQL+
                  ' where object_name=' + DBMSStrToDB(ATemplateName) +
                    ' and object_oper=''C'' and skip_sql=''0'' order by index_sql';
      VDataset.OpenSQL(VSQLText);

      if VDataset.IsEmpty then begin
        // ������ �� ����������� - ������ ��� �������
        Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
        Exit;
      end;

      // ���-�� � �������� ����
      VExecuteSQLArray := TExecuteSQLArray.Create;

      VDataset.First;
      while (not VDataset.Eof) do begin
        // ����� ����� SQL ��� ���������� � ������� ����������
        Vignore_errors := VDataset.GetAnsiCharFlag('ignore_errors', ETS_UCT_YES);

        // ���� ���� ����� - ��������� ��� � ������
        if VDataset.ClobAsWideString('object_sql', VSQLText) then begin
          // � ��� ���� ��������� ��� �������
          VSQLText := StringReplace(VSQLText, ATemplateName, AUnquotedTableNameWithoutPrefix, [rfReplaceAll,rfIgnoreCase]);

          if ASubstSQLTypes then begin
            // ����� ���������� ���������� ����� ���� ����� ��� ������������ �������� XY
            // � ������ - �������� numeric �� INT ������ ������
            VReplaceNumeric := GetSQLIntName_Div(FDBMS_Service_Info.XYMaskWidth, AZoom);
            VSQLText := StringReplace(VSQLText, c_RTL_Numeric, VReplaceNumeric, [rfReplaceAll,rfIgnoreCase]);
          end;

          VExecuteSQLArray.AddSQLItem(
            VSQLText,
            (Vignore_errors<>ETS_UCT_NO)
          );
        end;

        // - ���������!
        VDataset.Next;
      end;

    finally
      FConnection.KillPoolDataset(VDataset);
    end;

    // � ������ ���� ���� �������� � ������ - ��������
    if (VExecuteSQLArray<>nil) then
    if (VExecuteSQLArray.Count>0) then
    for i := 0 to VExecuteSQLArray.Count-1 do
    try
      // ��������� ��������
      FConnection.ExecuteDirectSQL(VExecuteSQLArray.GetSQLItem(i).Text, FALSE);
    except
      on E: Exception do begin
        // ��� ���� ����������� ��������� ������ - ���� ������ � �������� �����
        if StandardExceptionType(GetStatementExceptionType(E), Result) then
          Exit;
        // ������ ������� � ����������� �� ���������
        if (not VExecuteSQLArray.GetSQLItem(i).SkipErrorsOnExec) then
          raise;
      end;
    end;
  finally
    FreeAndNil(VExecuteSQLArray);
  end;

  // ��������� ��� ����� ������� ���������
  if (FConnection.TableExists(AQuotedTableNameWithPrefix)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // �����
  Result := ETS_RESULT_INVALID_STRUCTURE;
end;

function TDBMS_Provider.DBMS_Complete(const AFlags: LongWord): Byte;
begin
  FCompleted := TRUE;
  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.DBMS_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN
): Byte;
var
  VExclusive: Boolean;
  VDeleteSQL: TDBMS_String;
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
begin
  VExclusive := ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Delete, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // make DELETE statements
    Result := GetSQL_DeleteTile(
      ADeleteBuffer,
      VDeleteSQL
    );
      
    if (ETS_RESULT_OK<>Result) then
      Exit;

    VStatementExceptionType := set_Success;
    try
      // execute DELETE statement
      FConnection.ExecuteDirectSQL(VDeleteSQL, TRUE);
      // done (successfully DELETEed)
      // Result := ETS_RESULT_OK;
    except on E: Exception do
      VStatementExceptionType := GetStatementExceptionType(E);
    end;

    // ��� ���������
    if not StandardExceptionType(VStatementExceptionType, Result) then
    case VStatementExceptionType of
      set_Success, set_TableNotFound: begin
        // ��� ������� - ��� � �����
        Result := ETS_RESULT_OK;
      end;
      set_PrimaryKeyViolation: begin
        // ������ ��� ���� �� ������
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_EnumTileVersions(
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte;
var
  VExclusive, VVersionFound: Boolean;
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_ENUM_TILE_VERSION_OUT;
  VETS_VERSION_W: TETS_VERSION_W;
  VETS_VERSION_A: TETS_VERSION_A;
  VVersionAA: TVersionAA;
  VSQLText: TDBMS_String;
  VVersionValueW, VVersionCommentW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_EnumVersions, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT id_ver from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_EnumTileVersions(ASelectBufferIn, VExclusive, VSQLText);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      FillChar(VEnumOut, SizeOf(VEnumOut), 0);
      
      if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
        // Ansi record
        FillChar(VETS_VERSION_A, SizeOf(VETS_VERSION_A), 0);
        VEnumOut.ResponseValue := @VETS_VERSION_A;
      end else begin
        // Wide record
        FillChar(VETS_VERSION_W, SizeOf(VETS_VERSION_W), 0);
        VEnumOut.ResponseValue := @VETS_VERSION_W;
      end;

      // open sql
      VStatementExceptionType := set_Success;
      try
        VDataset.OpenSQL(VSQLText);
      except on E: Exception do
        VStatementExceptionType := GetStatementExceptionType(E);
      end;

      if StandardExceptionType(VStatementExceptionType, Result) then begin
        // ��������������� ��������� ��������� ������
        Exit
      end;

      case VStatementExceptionType of
        set_Success: begin
          // �����
        end;
        set_TableNotFound: begin
          // ��� ������� - ��� � ������
          Result := ETS_RESULT_OK;
          Exit;
        end;
        set_PrimaryKeyViolation: begin
          Result := ETS_RESULT_INVALID_STRUCTURE;
          Exit;
        end;
      end;

      // ��� ������ ���� ��� ����������� ������
      if (not VDataset.Active) then begin
        // table not found
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else if VDataset.IsEmpty then begin
        // nothing
        Result := ETS_RESULT_OK;
      end else begin
        // enum all items
        if (not VDataset.IsUniDirectional) then begin
          VEnumOut.ResponseCount := VDataset.RecordCount;
        end else begin
          VEnumOut.ResponseCount := -1; // unknown count
        end;
        VDataset.First;
        while (not VDataset.Eof) do begin
          // find selected version
          VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);

          if (not VVersionFound) then begin
            // ���������� ���������� ������, ��� ��� �������� �� �� ����������� ����� ������
            // �������� ��� �������� � ������ ��������
            if (not VExclusive) then begin
              Result := ETS_RESULT_NEED_EXCLUSIVE;
              Exit;
            end;
            ReadVersionsFromDB(VExclusive);
            VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);
          end;

          if (not VVersionFound) then begin
            // OMG WTF
            VVersionAA.id_ver := VDataset.FieldByName('id_ver').AsInteger;
            VVersionAA.ver_value := '';
            VVersionAA.ver_comment := '';
          end;

          // make params for callback
          if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
            // Ansi record
            VETS_VERSION_A.id_ver := VVersionAA.id_ver;
            VETS_VERSION_A.ver_value := PAnsiChar(VVersionAA.ver_value);
            VETS_VERSION_A.ver_comment := PAnsiChar(VVersionAA.ver_comment);
          end else begin
            // Wide record
            VETS_VERSION_W.id_ver := VVersionAA.id_ver;
            VVersionValueW := VVersionAA.ver_value;
            VETS_VERSION_W.ver_value := PWideChar(VVersionValueW);
            VVersionCommentW := VVersionAA.ver_comment;
            VETS_VERSION_W.ver_comment := PWideChar(VVersionCommentW);
          end;

          // call host's callback
          Result := TETS_EnumTileVersions_Callback(FHostCallbacks[ETS_INFOCLASS_EnumTileVersions_Callback])(
            FHostPointer,
            ACallbackPointer,
            ASelectBufferIn,
            @VEnumOut
          );

          if (Result<>ETS_RESULT_OK) then
            break;

          // next record
          Inc(VEnumOut.ResponseIndex);
          VDataset.Next;
        end;

      end;
      
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_ExecOption(
  const ACallbackPointer: Pointer;
  const AExecOptionIn: PETS_EXEC_OPTION_IN
): Byte;
const
  c_EO_SetTLM         = 'SetTLM';
  c_EO_SetTSM         = 'SetTSM';
  c_EO_SetVerByTile   = 'SetVerByTile';                     
  c_EO_SetVerComp     = 'SetVerComp';
  c_EO_GetVersions    = 'GetVersions';
  c_EO_ReloadVersions = 'ReloadVersions';
  c_EO_ResetConnError = 'ResetConnError';
  c_EO_GetUnknErrors  = 'GetUnknErrors';
  c_EO_ClearErrors    = 'ClearErrors';

var
  VFullPrefix: String;

  function _AddReturnFooter: String;
  begin
    Result := '<br>' + // additional!
              '<a href="'+VFullPrefix+'">Return to Options</a>';
  end;

  function _AddTileLoadSaveModeLine(
    const AOption: Byte; // FStatusBuffer^.tile_load_mode or FStatusBuffer^.tile_save_mode
    const AFlag: Byte;
    const AExecOptionName: String; // c_EO_SetTLM or c_EO_SetTSM
    const ADescription: String
  ): String;
  var
    VEnabled: Boolean;
  begin
    VEnabled := ((AOption and AFlag) <> 0);

    if VEnabled then begin
      // enabled - click to disable
      Result := 'dis';
    end else begin
      // disabled - click to enable
      Result := 'en';
    end;

    Result := '<tr><td>' + ADescription + '</td><td>' + BoolToStr(VEnabled, TRUE) + '</td><td>' +
              'Click <a href="' +
              VFullPrefix + '/' + AExecOptionName + '/' + IntToStr(AFlag) + '/' + IntToStr(Ord(not VEnabled)) +
              '">HERE</a> to ' + Result + 'able</td></tr>';
  end;

  function _AddTileLoadModeLine(
    const AFlag: Byte;
    const ADescription: String
  ): String;
  begin
    Result := _AddTileLoadSaveModeLine(FStatusBuffer^.tile_load_mode, AFlag, c_EO_SetTLM, ADescription);
  end;

  function _AddTileSaveModeLine(
    const AFlag: Byte;
    const ADescription: String
  ): String;
  begin
    Result := _AddTileLoadSaveModeLine(FStatusBuffer^.tile_save_mode, AFlag, c_EO_SetTSM, ADescription);
  end;

  function _AddTable3ColHeader(const AFirstColCaption: String): String;
  begin
    Result := '<table><tr><td>'+AFirstColCaption+'</td><td>Enabled</td><td>Change</td></tr>';
  end;

  function _AddVerCompItem(const AVerCompMode: AnsiChar): String;
  begin
    if (AVerCompMode=FDBMS_Service_Info.id_ver_comp) then begin
      // current mode
      Result := 'Current';
    end else begin
      Result := '<a href="' + VFullPrefix + '/' + c_EO_SetVerComp + '/' + AVerCompMode + '">Select</a>';
    end;
  end;

  function _AddVerByTileItem(const AVerByTileValue: SmallInt; const ACaption: String): String;
  begin
    if (AVerByTileValue=FDBMS_Service_Info.new_ver_by_tile) then begin
      // current mode
      Result := 'Current';
    end else begin
      Result := '<a href="' + VFullPrefix + '/' + c_EO_SetVerByTile + '/' + IntToStr(AVerByTileValue) + '">Select</a>';
    end;
    Result := '<tr><td>' + ACaption + '</td><td>' + Result + '</td></tr>';
  end;

  procedure _TrimLeftDelims(var AFromSource: String);
  begin
    while (Length(AFromSource)>0) and (AFromSource[1]='/') do begin
      System.Delete(AFromSource,1,1);
    end;
  end;

  function _ExtractPart(var AFromSource: String): String;
  var p: Integer;
  begin
    if (0=Length(AFromSource)) then begin
      Result := '';
      Exit;
    end;

    p := System.Pos('/', AFromSource);
    if (p>0) then begin
      Result := System.Copy(AFromSource, 1, p-1);
      System.Delete(AFromSource, 1, p);
      _TrimLeftDelims(AFromSource);
    end else begin
      Result := AFromSource;
      AFromSource := '';
    end;
  end;

  function _AddPreamble(var AResponseText: String): Boolean;
  begin
    AResponseText := AResponseText +
                 '<br>' +
                 'Service code is "' + FDBMS_Service_Code + '"' +
                 '<br>' +
                 'Database server defined as ' + c_SQL_Engine_Name[FConnection.GetCheckedEngineType] + '<br>';

    Result := (nil<>FConnection) and (ETS_RESULT_OK=FConnection.EnsureConnected(FALSE, nil));
    if (not Result) then begin
      AResponseText := AResponseText +
                   '<br>' +
                   '<h1>Not connected</h1>' +
                   '<br>' +
                   FConnection.GetConnectionErrorMessage +
                   '<br>' +
                   '<br>' +
                   'Click <a href="' + VFullPrefix + '/' + c_EO_ResetConnError + '">HERE</a> to reset connection information if you want another try';


    end;
  end;

  procedure _ReloadVersions;
  var
    VExclusivelyLocked: Boolean;
  begin
    DoBeginWork(TRUE, so_ReloadVersions, VExclusivelyLocked);
    try
      ReadVersionsFromDB(TRUE);
    finally
      DoEndWork(VExclusivelyLocked);
    end;
  end;

  procedure _AddListOfVersions(var AResponseText: String);
  var
    VExclusivelyLocked: Boolean;
    i: SmallInt;
    pVer: PVersionAA;
  begin
    AResponseText := AResponseText +
                   '<br>' +
                   '<br>' +
                   '<table><tr><td>id_ver</td><td>ver_value</td><td>ver_date</td><td>ver_number</td><td>ver_comment</td></tr>';
    DoBeginWork(FALSE, so_OutputVersions, VExclusivelyLocked);
    try
      if (FVersionList.Count>0) then
      for i := 0 to FVersionList.Count - 1 do begin
        pVer := FVersionList.GetItemByIndex(i);
        if (pVer<>nil) then begin
          AResponseText := AResponseText +
                     '<tr><td>'+IntToStr(pVer^.id_ver)+
                     '</td><td>'+pVer^.ver_value+
                     '</td><td>'+FormatDateTime(c_DateTimeToListOfVersions, pVer^.ver_date)+
                     '</td><td>'+IntToStr(pVer^.ver_number)+
                     '</td><td>'+pVer^.ver_comment+'</td></tr>';
        end;
      end;
    finally
      DoEndWork(VExclusivelyLocked);
    end;

    AResponseText := AResponseText + '</table>';
  end;

var
  VValueW: WideString;
  VRequest: String;
  VResponse: String;
  VSetTLMValue: String;
  VSetTLMIndex: Integer;
begin
  Result := ETS_RESULT_OK;
  VResponse := '';
  // get input values
  VRequest := '';
  if ((AExecOptionIn^.dwOptionsIn and ETS_EOI_ANSI_VALUES) <> 0) then begin
    VFullPrefix := PAnsiChar(AExecOptionIn^.szFullPrefix);
    if (AExecOptionIn^.szRequest<>nil) then begin
      VRequest    := PAnsiChar(AExecOptionIn^.szRequest);
    end;
  end else begin
    VValueW     := PWideChar(AExecOptionIn^.szFullPrefix);
    VFullPrefix := VValueW;
    if (AExecOptionIn^.szRequest<>nil) then begin
      VValueW     := PWideChar(AExecOptionIn^.szRequest);
      VRequest    := VValueW;
    end;
  end;

  _TrimLeftDelims(VRequest);

  try
    if (0=Length(VRequest)) then begin
      // get information for empty request

      VResponse := '<h1>Options</h1>';

      if not _AddPreamble(VResponse) then
        Exit;
      
      // show version compare information
      
      VResponse := VResponse +
                   '<br>' +
                   'How to compare versions' + '<br>' +
                   '<table><tr><td>None</td><td>By ID</td><td>By Value</td><td>By Date</td><td>By Number</td></tr><tr><td>';

      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_NONE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_ID);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_VALUE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_DATE);
      VResponse := VResponse + '</td><td>';
      VResponse := VResponse + _AddVerCompItem(TILE_VERSION_COMPARE_NUMBER);

      VResponse := VResponse + '</td></tr></table>';

      // show tile_load_mode parsed information
      VResponse := VResponse +
                   '<br>' +
                   _AddTable3ColHeader('What to do if tile not found');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_WITHOUT_VERSION, 'Show tile without version if no tile for request with version');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_PREV_VERSION,    'Show tile with prevoius version if no tile for request with version');
      VResponse := VResponse + _AddTileLoadModeLine(ETS_TLM_LAST_VERSION,    'Show tile with last version if no tile for request without version');
      VResponse := VResponse + '</table>';


      // show tile_save_mode parsed information
      VResponse := VResponse +
                   '<br>' +
                   _AddTable3ColHeader('Storage can parse saving tile to obtain its version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_EMPTY,   'Allow to parse tile without version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_UNKNOWN, 'Allow to parse tile with unknown version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_PARSE_KNOWN,   'Allow to parse tile with known version');
      VResponse := VResponse + _AddTileSaveModeLine(ETS_TSM_ALLOW_NO_EXIF, 'Can save tile without version for parser (for another zoom generation)');
      VResponse := VResponse + '</table>';

      // VER_by_TILE algorithm
      VResponse := VResponse +
                   '<br>' +
                   'Select algorithm to use by tile parser' + '<br>' +
                   '<table><tr><td>Algorithm</td><td>State</td></tr>';

      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_None,            'None');
      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_NMC_Unique, 'NMC by unique TileIdentifier');
      VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_NMC_Latest, 'NMC by latest AcquisitionDate');
      //VResponse := VResponse + _AddVerByTileItem(c_Tile_Parser_Exif_DG_Catalog, 'DG Catalog mode');

      VResponse := VResponse + '</table>';


      // show list of versions
      VResponse := VResponse + '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetVersions+'">Show list of Versions</a>';


      // unknown exceptions
      if HasUnknownExceptions then begin
        // has items - add link to show
        VResponse := VResponse + '<br>' +
                   '<a href="'+VFullPrefix+'/'+c_EO_GetUnknErrors+'">Show Errors</a>';
      end;

      Exit;
    end;

    // extract first command
    VSetTLMValue := _ExtractPart(VRequest);

    if SameText(c_EO_SetTLM, VSetTLMValue) then begin
      // SetTLM
      // remains: 3 chars like '4/1' or '2/0'
      // ignore others
      if (3<=Length(VRequest)) then
      if TryStrToInt(VRequest[1], VSetTLMIndex) then
      if LoByte(VSetTLMIndex) in [ETS_TLM_WITHOUT_VERSION, ETS_TLM_PREV_VERSION, ETS_TLM_LAST_VERSION] then begin
        // ok
        // ���� 3-� ������ ����� 1 - ��������, ����� ���������
        Result := UpdateTileLoadMode(LoByte(VSetTLMIndex), (VRequest[3]='1'), VSetTLMValue);
        // check
        if (ETS_RESULT_OK=Result) then begin
          // success
          if (VRequest[3]='1') then
            VResponse := 'Enabled'
          else
            VResponse := 'Disabled';

          if (0<Length(VSetTLMValue)) then begin
            VResponse := VResponse + '<br>' + VSetTLMValue;
          end;

          VResponse := VResponse + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;

        AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE;
      end;
    end else if SameText(c_EO_SetTSM, VSetTLMValue) then begin
      // SetTSM
      // remains: 3-4 chars like '4/1' or '8/0' or '16/1'
      // ignore others
      if (3<=Length(VRequest)) then
      if TryStrToInt(Copy(VRequest,1,Length(VRequest)-2), VSetTLMIndex) then
      if LoByte(VSetTLMIndex) in [ETS_TSM_PARSE_EMPTY, ETS_TSM_PARSE_UNKNOWN, ETS_TSM_PARSE_KNOWN,ETS_TSM_ALLOW_NO_EXIF] then begin
        // ok
        // ���� 3-� ������ ����� 1 - ��������, ����� ���������
        Result := UpdateTileSaveMode(LoByte(VSetTLMIndex), (VRequest[Length(VRequest)]='1'), VSetTLMValue);
        // check
        if (ETS_RESULT_OK=Result) then begin
          // success
          if (VRequest[Length(VRequest)]='1') then
            VResponse := 'Enabled'
          else
            VResponse := 'Disabled';

          if (0<Length(VSetTLMValue)) then begin
            VResponse := VResponse + '<br>' + VSetTLMValue;
          end;

          VResponse := VResponse + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;
        // ����� �� ���� ���������� ��� � ������
      end;
    end else if SameText(c_EO_SetVerByTile, VSetTLMValue) then begin
      // SetVerByTile
      // remains: Smallint
      if TryStrToInt(VRequest, VSetTLMIndex) then
      if Abs(VSetTLMIndex)<=32767 then begin
        // ok
        Result := UpdateVerByTileMode(VSetTLMIndex, VSetTLMValue);
        // check result
        if (ETS_RESULT_OK=Result) then begin
          // success
          VResponse := 'Updated successfully' + '<br>' + _AddReturnFooter;
        end else begin
          // failed
          VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
        end;
        // ����� �� ���� ���������� ��� � ������
      end;
    end else if SameText(c_EO_SetVerComp, VSetTLMValue) then begin
      // SetVerComp
      // remains: ONE char
      if (1<=Length(VRequest)) then
      case VRequest[1] of
        TILE_VERSION_COMPARE_NONE,
        TILE_VERSION_COMPARE_ID,
        TILE_VERSION_COMPARE_VALUE,
        TILE_VERSION_COMPARE_DATE,
        TILE_VERSION_COMPARE_NUMBER: begin
          // ok
          Result := UpdateServiceVerComp(VRequest[1], VSetTLMValue);
          // check result
          if (ETS_RESULT_OK=Result) then begin
            // success
            VResponse := 'Updated successfully' + '<br>' + _AddReturnFooter;
            AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_CLEAR_MEMCACHE;
          end else begin
            // failed
            VResponse := 'Error(' + IntToStr(Result) + '): ' + VSetTLMValue + '<br>' + _AddReturnFooter;
          end;
        end;
      end;
    end else if SameText(c_EO_ResetConnError, VSetTLMValue) then begin
      // ResetConnError
      VResponse := '<h1>Reset connection information</h1>';
      if (FConnection=nil) then begin
        // nothing to reset
        VResponse := VResponse +
                   '<br>' +
                   'No connection - nothing to reset';
      end else begin
        // can reset
        FConnection.ResetConnectionError;
        VResponse := VResponse +
                   '<br>' +
                   'Done';
      end;

      // ���������
      VResponse := VResponse +
                   '<br>' +
                   _AddReturnFooter;
    end else if SameText(c_EO_GetUnknErrors, VSetTLMValue) then begin
      // GetUnknErrors
      // show all collected unknown errors
      if SameText(VRequest, c_EO_ClearErrors) then begin
        ClearUnknownExceptions;
      end;

      VResponse := '<h1>Errors</h1>';

      VSetTLMValue := GetUnknownExceptions;

      if (0<Length(VSetTLMValue)) then begin
        // add clear link
        VResponse := VResponse +
                   '<br>' +
                   'Click <a href="'+VFullPrefix+'/'+c_EO_GetUnknErrors+'/'+c_EO_ClearErrors+'">HERE</a> to clear Errors';

        VResponse := VResponse +
                   '<br>' +
                   '<br>' +
                   'List of Errors:' +
                   '<br>' +
                   '<br>' +
                   VSetTLMValue;
      end else begin
        VResponse := VResponse +
                   '<br>' +
                   'No Errors';
      end;


      VResponse := VResponse + '<br>' + _AddReturnFooter;

    end else if SameText(c_EO_GetVersions, VSetTLMValue) then begin
      // GetVersions
      // enumerate all versions and show
      if SameText(VRequest, c_EO_ReloadVersions) then begin
        _ReloadVersions;
      end;

      VResponse := '<h1>Versions</h1>';

      if not _AddPreamble(VResponse) then
        Exit;

      VResponse := VResponse +
                   '<br>' +
                   'Total count = ' + IntToStr(FVersionList.Count);

      if vf_EmptyVersion in FVersionList.VersionFlags then begin
        VResponse := VResponse +
                   '<br>' +
                   'Empty version has id_ver = ' + IntToStr(FVersionList.EmptyVersionIdVer);
      end;

      if (FVersionList.Count>0) then begin
        _AddListOfVersions(VResponse);
      end;

      // add reload link
      VResponse := VResponse +
                   '<br>' +
                   'Click <a href="'+VFullPrefix+'/'+c_EO_GetVersions+'/'+c_EO_ReloadVersions+'">HERE</a> to reload Versions from DB';

      VResponse := VResponse + '<br>' + _AddReturnFooter;
    end;

  finally
    if (0<Length(VResponse)) then begin
      // allocate memory and copy response
      VSetTLMIndex := (Length(VResponse)+1)*SizeOf(Char);
      AExecOptionIn.szResponse := GetMemory(VSetTLMIndex);
      CopyMemory(AExecOptionIn.szResponse, PChar(VResponse), VSetTLMIndex);
      AExecOptionIn.dwLength := Length(VResponse);
      if SizeOf(Char)=SizeOf(AnsiChar) then begin
        AExecOptionIn.dwOptionsOut := AExecOptionIn.dwOptionsOut or ETS_EOO_ANSI_VALUES;
      end;
    end;
  end;
end;

function TDBMS_Provider.DBMS_GetTileRectInfo(
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte;
var
  VExclusive: Boolean;
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_GET_TILE_RECT_OUT;
  VExclusivelyLocked: Boolean;
  VSelectInRectList: TSelectInRectList;
  VSelectInRectItem: PSelectInRectItem;
  i: Integer;
begin
  VExclusive := ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_SelectInRect, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    FillChar(VEnumOut, SizeOf(VEnumOut), 0);
      
    // ��� ���������� ����� ����������, ���� �������� ������� �� �������, ����� �������������� ��������� ��������
    // ������� ������� �������� ��� ����������� �������, � ����� ����� �� ��������� �� �������
    VSelectInRectList := TSelectInRectList.Create;
    try
      // ���������
      Result := GetSQL_GetTileRectInfo(ATileRectInfoIn, VExclusive, VSelectInRectList);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // ����� ����� ������� ����� �� ������ �������� �� ������� ��������� �� �������
      // ������������� � ����� ������ ����� ��� ����������
      // VEnumOut.ResponseCount := -1;

      // ��� ��� ������ ������ ������ ����������� - ����� �� ���� ������ ���������� �� �� ������
      //VEnumOut.TileInfo.szVersionOut := nil;
      // ���� ����� ����� �� ����������
      //VEnumOut.TileInfo.ptTileBuffer := nil;
      // TODO: content-type ����� �� ����� ���� ����-�� ����� ���������
      //VEnumOut.TileInfo.szContentTypeOut := nil;

      // �� ������� �� �����
      if VSelectInRectList.Count>0 then begin
        VDataset := FConnection.MakePoolDataset;
        try
          // ��� ������ ������������ ��� ��������
          for i := 0 to VSelectInRectList.Count-1 do begin
            // ������� ���������
            VSelectInRectItem := VSelectInRectList.SelectInRectItems[i];

            // ��� ������ �� ����� ������ �� ������ �� ����� �������������� ���������
            Result:=ETS_RESULT_OK;

            // �����������
            try
              VDataset.OpenSQL(VSelectInRectItem^.FullSqlText);
            except
              // ��� ������� - ��� ������ - ����� ����������
            end;

            if (VDataset.Active) and (not VDataset.IsEmpty) then begin
              // ���-�� ��������� - ���������� ��� � ����
              VDataset.First;
              while (not VDataset.Eof) do begin
                // ��������� ���������
                VEnumOut.TileInfo.dwOptionsOut := ETS_ROO_SAME_VERSION;

                // ��������� TilePos ��������� ������������ �����
                CalcBackToTilePos(
                  VDataset.FieldByName('x').AsInteger,
                  VDataset.FieldByName('y').AsInteger,
                  VSelectInRectItem.TabSQLTile.XYUpperToTable,
                  @(VEnumOut.TilePos)
                );

                // ��������� ������ � �����
                VEnumOut.TileInfo.dtLoadedUTC := VDataset.FieldByName('load_date').AsDateTime;
                VEnumOut.TileInfo.dwTileSize := VDataset.FieldByName('tile_size').AsInteger;
                // check if tile of tne
                if (VEnumOut.TileInfo.dwTileSize<=0) then begin
                  // tne
                  VEnumOut.TileInfo.dwOptionsOut := VEnumOut.TileInfo.dwOptionsOut or ETS_ROO_TNE_EXISTS;
                end else begin
                  // tile
                  VEnumOut.TileInfo.dwOptionsOut := VEnumOut.TileInfo.dwOptionsOut or ETS_ROO_TILE_EXISTS;
                end;

                // ���� ����
                Result := TETS_GetTileRectInfo_Callback(FHostCallbacks[ETS_INFOCLASS_GetTileRectInfo_Callback])(
                  FHostPointer,
                  ACallbackPointer,
                  ATileRectInfoIn,
                  @VEnumOut
                );

                // ��� ������ ����� �� ����� ������: � �� while, � �� for
                if (Result<>ETS_RESULT_OK) then
                  break;

                // - ���������!
                VDataset.Next;
              end;

            end;

            // ��� ������ ����� �� ����� ������: � �� while, � �� for
            if (Result<>ETS_RESULT_OK) then
              break;
          end; // for

        finally
          FConnection.KillPoolDataset(VDataset);
        end;
      end;

    finally
      FreeAndNil(VSelectInRectList);
    end;

  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_InsertTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean
): Byte;
var
  VExclusive: Boolean;
  VInsertSQL, VUpdateSQL: TDBMS_String;
  VUnquotedTableNameWithoutPrefix: TDBMS_String;
  VQuotedTableNameWithPrefix: TDBMS_String;
  VStatementRepeatType: TStatementRepeatType;
  VInsertUpdateSubType: TInsertUpdateSubType;
  VCastBodyAsHexLiteral: Boolean;
  VExecuteWithBlob: Boolean;
  VBodyAsLiteralValue: TDBMS_String;
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
begin
  VExclusive := ((AInsertBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Insert, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - INSERT tile to DB
      VStatementRepeatType := srt_None;
      
      // ������� ��������� INSERT � UPDATE
      Result := GetSQL_InsertUpdateTile(
        AInsertBuffer,
        AForceTNE,
        VExclusive,
        VInsertSQL,
        VUpdateSQL,
        VInsertUpdateSubType,
        VUnquotedTableNameWithoutPrefix,
        VQuotedTableNameWithPrefix
      );
      if (ETS_RESULT_OK<>Result) then
        Exit;

      if (iust_TILE=VInsertUpdateSubType) then begin
        // ���� ����� ���� � �������
        VCastBodyAsHexLiteral := c_DBX_CastBlobToHexLiteral[FConnection.GetCheckedEngineType];
        if VCastBodyAsHexLiteral then
          VBodyAsLiteralValue := ConvertTileToHexLiteralValue(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize)
        else
          VBodyAsLiteralValue := '';
      end else begin
        // ���� ����� ������ ����������� � �������
        VCastBodyAsHexLiteral := FALSE;
        VBodyAsLiteralValue := '';
      end;

      // ������ � ��������� BLOB� ��� ���
      VExecuteWithBlob := (iust_TILE=VInsertUpdateSubType) and (not VCastBodyAsHexLiteral);

      // �������� INSERT
      VStatementExceptionType := set_Success;
      try
        // ����� BLOB ���� ������ ��� 16-������ �������
        if VCastBodyAsHexLiteral then begin
          VInsertSQL := StringReplace(VInsertSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
        end;

        if VExecuteWithBlob then begin
          // INSERT with BLOB
          FConnection.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
        end else begin
          // INSERT without BLOB
          FConnection.ExecuteDirectSQL(VInsertSQL);
        end;
        
        // ������ (���������!)
        Result := ETS_RESULT_OK;
      except on E: Exception do
        // ���������� �� �������� ����� ������
        VStatementExceptionType := GetStatementExceptionType(E);
      end;

      if StandardExceptionType(VStatementExceptionType, Result) then begin
        // ��������������� ��������� ��������� ������
        Exit;
      end;

      case VStatementExceptionType of
        set_Success: begin
          // �����
        end;
        set_TableNotFound: begin
          // ��� ������� � ��
          if (not VExclusive) then begin
            // ������� ������ ������ � ������������ ������
            Result := ETS_RESULT_NEED_EXCLUSIVE;
            Exit;
          end;

          // ������� ������� ������� �� �������
          CreateTableByTemplate(
            c_Templated_RealTiles,
            VUnquotedTableNameWithoutPrefix,
            VQuotedTableNameWithPrefix,
            AInsertBuffer^.XYZ.z,
            TRUE
          );

          // ��������� ������������� �������
          if (not FConnection.TableExists(VQuotedTableNameWithPrefix)) then begin
            // �� ������� ���� ������� - �����
            Result := ETS_RESULT_TILE_TABLE_NOT_FOUND;
            Exit;
          end;

          // ��������� INSERT ��� ������ ��� ��������� �������
          VStatementRepeatType := srt_Insert;
        end;
        set_PrimaryKeyViolation: begin
          // ��������� ������������ �� ���������� ����� - ���� �����������
          VStatementRepeatType := srt_Update;
        end;
      end;

      // ������� ��������� INSERT ��� UPDATE ��������
      while (VStatementRepeatType <> srt_None) do begin
        // ��������� ������� ��� UPDATE ��� ����� ��� INSERT
        // ����� ���� ��� ���������� UPDATE - ��� ������� �� ��������� INSERT
        // ������ ����� ������ ���������� ����� SQL-� �� UPDATE � INSERT
        // � ������������ ������ ����� �������
        if (VStatementRepeatType = srt_Update) then begin
          if VCastBodyAsHexLiteral then begin
            VUpdateSQL := StringReplace(VUpdateSQL, c_RTL_Tile_Body_Paramname, VBodyAsLiteralValue, [rfReplaceAll,rfIgnoreCase]);
          end;
          VInsertSQL := VUpdateSQL;
        end;

        VStatementExceptionType := set_Success;
        try
          // ����� � VInsertSQL ����� ���� � ����� ��� UPDATE
          if VExecuteWithBlob then begin
            // UPDATE with BLOB
            FConnection.ExecuteDirectWithBlob(VInsertSQL, AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end else begin
            // UPDATE without BLOB
            FConnection.ExecuteDirectSQL(VInsertSQL);
          end;

          // ������ �������� ���������� �������
          VStatementRepeatType := srt_None;
          Result := ETS_RESULT_OK;
        except on E: Exception do
          // ������� ��� �� ������
          VStatementExceptionType := GetStatementExceptionType(E);
        end;

        if StandardExceptionType(VStatementExceptionType, Result) then begin
          // ��������������� ��������� ��������� ������
          Exit;
        end;

        case VStatementExceptionType of
          set_Success: begin
            Result := ETS_RESULT_OK;
            Exit;
          end;
          set_TableNotFound: begin
            // ������� ��� � ��� - �������� ��� ��������� �������, � �� ��������
            Result := ETS_RESULT_INVALID_STRUCTURE;
            Exit;
          end;
          set_PrimaryKeyViolation: begin
            // ���� ��� INSERT - ���� �� ����� ����� - �� ���� ��� UPDATE
            // ���� ��� UPDATE - ���� � ������ ���������� �������� �� �������� ����� �������
            if (VStatementRepeatType=srt_Update) then begin
              Result := ETS_RESULT_INVALID_STRUCTURE;
              Exit;
            end else begin
              // ����� ��������� update
              VStatementRepeatType := srt_Update;
            end;
          end;
        end; // of case
      end; // of while
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_SelectTile(
  const ACallbackPointer: Pointer;
  const ASelectBufferIn: PETS_SELECT_TILE_IN
): Byte;
var
  VExclusive: Boolean;
  VDataset: TDBMS_Dataset;
  VOut: TETS_SELECT_TILE_OUT;
  VStream: TStream;
  Vid_ver, Vid_contenttype: SmallInt;
  VSQLText: TDBMS_String;
  VVersionW, VContentTypeW: WideString; // keep wide
  VExclusivelyLocked: Boolean;
  VStatementExceptionType: TStatementExceptionType;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive, so_Select, VExclusivelyLocked);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT tile from DB
    VStream := nil;
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_SelectTile(ASelectBufferIn, VExclusive, VSQLText);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      FillChar(VOut, SizeOf(VOut), 0);

      // open sql
      VStatementExceptionType := set_Success;
      try
        VDataset.OpenSQL(VSQLText);
      except on E: Exception do
        VStatementExceptionType := GetStatementExceptionType(E);
      end;

      if StandardExceptionType(VStatementExceptionType, Result) then begin
        // ��������������� ��������� ��������� ������
        Exit;
      end;

      case VStatementExceptionType of
        set_Success: begin
          // �����
        end;
        set_TableNotFound: begin
          // ��� ������� - ��� � ������
          Result := ETS_RESULT_OK;
          Exit;
        end;
        set_PrimaryKeyViolation: begin
          Result := ETS_RESULT_INVALID_STRUCTURE;
          Exit;
        end;
      end;

      // get values
      if (not VDataset.Active) then begin
        // ���� ������� � ������� ��� - ������ ������ ����� ���� ��� - ������� ��������
        Result := ETS_RESULT_OK;
      end else if VDataset.IsEmpty then begin
        // ������� ����, �� ������ ���
        Result := ETS_RESULT_OK;
      end else begin
        // get first item (because of 'order by' clause)
        VOut.dtLoadedUTC := VDataset.FieldByName('load_date').AsDateTime;
        VOut.dwTileSize := VDataset.FieldByName('tile_size').AsInteger;
        // check if tile of tne
        if (VOut.dwTileSize<=0) then begin
          // tne
          VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TNE_EXISTS;
        end else begin
          // tile
          VOut.dwOptionsOut := VOut.dwOptionsOut or ETS_ROO_TILE_EXISTS;
          // get body
          VStream := VDataset.CreateFieldBlobReadStream('tile_body');
          if (nil=VStream) then
            VOut.ptTileBuffer := nil
          else
            VOut.ptTileBuffer := (VStream as TCustomMemoryStream).Memory;
        end;

        // version
        Vid_ver := VDataset.FieldByName('id_ver').AsInteger;
        if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
          // as AnsiString
          VOut.szVersionOut := GetVersionAnsiPointer(Vid_ver, VExclusive);
        end else begin
          // as WideString
          VVersionW := GetVersionWideString(Vid_ver, VExclusive);
          VOut.szVersionOut := PWideChar(VVersionW);
        end;

        // contenttype
        Vid_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
        if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_OUT) <> 0) then begin
          // as AnsiString
          VOut.szContentTypeOut := GetContentTypeAnsiPointer(Vid_contenttype, VExclusive);
        end else begin
          // as WideString
          VContentTypeW := GetContentTypeWideString(Vid_contenttype, VExclusive);
          VOut.szContentTypeOut := PWideChar(VContentTypeW);
        end;

        // call host
        Result := TETS_SelectTile_Callback(FHostCallbacks[ETS_INFOCLASS_SelectTile_Callback])(
          FHostPointer,
          ACallbackPointer,
          ASelectBufferIn,
          @VOut
        );
      end;
    finally
      FreeAndNil(VStream);
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;
end;

function TDBMS_Provider.DBMS_SetInformation(
  const AInfoClass: Byte;
  const AInfoSize: LongWord;
  const AInfoData: Pointer;
  const AInfoResult: PLongWord
): Byte;
begin
  if (ETS_INFOCLASS_SetStorageIdentifier=AInfoClass) then begin
    // set GlobalStorageIdentifier and ServiceName from PETS_SET_IDENTIFIER_INFO
    Result := InternalProv_SetStorageIdentifier(AInfoSize, PETS_SET_IDENTIFIER_INFO(AInfoData), AInfoResult);
    Exit;
  end;

  if (ETS_INFOCLASS_SetPrimaryContentType=AInfoClass) then begin
    // set primary ContentType
    if (AInfoSize=SizeOf(AnsiChar)) then begin
      // treat as PAnsiChar
      FPrimaryContentType := AnsiString(PAnsiChar(AInfoData));
      Result := ETS_RESULT_OK;
    end else if (AInfoSize=SizeOf(WideChar)) then begin
      // treat as PWideChar
      FPrimaryContentType := WideString(PWideChar(AInfoData));
      Result := ETS_RESULT_OK;
    end else begin
      // unknown
      Result := ETS_RESULT_INVALID_BUFFER_SIZE;
    end;
    Exit;
  end;

  if (TETS_INFOCLASS_Callbacks(AInfoClass)>=Low(TETS_INFOCLASS_Callbacks)) and (TETS_INFOCLASS_Callbacks(AInfoClass)<=High(TETS_INFOCLASS_Callbacks)) then begin
    // callbacks
    FHostCallbacks[TETS_INFOCLASS_Callbacks(AInfoClass)] := AInfoData;
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // unknown value
  Result := ETS_RESULT_UNKNOWN_INFOCLASS;
end;

function TDBMS_Provider.DBMS_Sync(const AFlags: LongWord): Byte;
var
  VExclusively: Boolean;
  VExclusivelyLocked: Boolean;
begin
  VExclusively := ((AFlags and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusively, so_Sync, VExclusivelyLocked);
  try
    if (nil<>FConnection) then begin
      FConnection.CompactPool;
    end;
  finally
    DoEndWork(VExclusivelyLocked);
  end;

  Result := ETS_RESULT_OK;
end;

destructor TDBMS_Provider.Destroy;
var
  VExclusivelyLocked: Boolean;
begin
  DoBeginWork(TRUE, so_Destroy, VExclusivelyLocked);
  try
    InternalProv_Disconnect;
  finally
    DoEndWork(VExclusivelyLocked);
  end;

  GuidesBeginWork(TRUE);
  try
    InternalProv_ClearGuides;
    FreeAndNil(FVersionList);
    FreeAndNil(FContentTypeList);
  finally
    GuidesEndWork(TRUE);
  end;

  FHostPointer := nil;
  FProvSync := nil;
  FGuidesSync := nil;

  FreeAndNil(FUnknownExceptions);
  FUnknownExceptionsCS := nil;

  inherited Destroy;
end;

procedure TDBMS_Provider.DoBeginWork(
  const AExclusively: Boolean;
  const AOperation: TSqlOperation;
  out AExclusivelyLocked: Boolean
);
begin
  AExclusivelyLocked := AExclusively OR
                        (FConnection=nil) OR
                        (FConnection.FullSyncronizeSQL);

  if AExclusivelyLocked then
    FProvSync.BeginWrite
  else
    FProvSync.BeginRead;
end;

procedure TDBMS_Provider.DoEndWork(const AExclusivelyLocked: Boolean);
begin
  if AExclusivelyLocked then
    FProvSync.EndWrite
  else
    FProvSync.EndRead;
end;

function TDBMS_Provider.FillTableNamesForTiles(
  ASQLTile: PSQLTile
): Boolean;
var
  VXYMaskWidth: Byte;
  //VNeedToQuote: Boolean; - use Result instead of
  VEngineType: TEngineType;
begin
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  ASQLTile^.UnquotedTileTableName := ASQLTile^.ZoomToTableNameChar(Result) +
                                     ASQLTile^.HXToTableNameChar(VXYMaskWidth) +
                                     FDBMS_Service_Info.id_div_mode +
                                     ASQLTile^.HYToTableNameChar(VXYMaskWidth) +
                                     '_' +
                                     InternalGetServiceNameByDB;

  VEngineType := FConnection.GetCheckedEngineType;

  // ����������� ��� ���
  Result := Result or c_SQL_QuotedIdentifierForcedForTiles[VEngineType];
  if Result then begin
    ASQLTile^.QuotedTileTableName := c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] + ASQLTile^.UnquotedTileTableName + c_SQL_QuotedIdentifierValue[VEngineType, qp_After];
  end else begin
    ASQLTile^.QuotedTileTableName := ASQLTile^.UnquotedTileTableName;
  end;
end;

function TDBMS_Provider.GetContentTypeAnsiPointer(
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(Aid_contenttype, AExclusively, @Result, VDummy) then
      Exit;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetContentTypeAnsiPointer(Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetContentTypeWideString(
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VContentTypeTextStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetContentTypeAnsiValues(Aid_contenttype, AExclusively, nil, VContentTypeTextStr) then begin
      Result := VContentTypeTextStr;
      Exit;
    end;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetContentTypeWideString(Aid_contenttype, TRUE);
  end;
end;

function TDBMS_Provider.GetMaxNextVersionInts(
  const ANewVersionPtr: PVersionAA;
  const AKeepVerNumber: Boolean
): Boolean;
var
  VDataset: TDBMS_Dataset;
  VSQLText: TDBMS_String;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      VSQLText := 'select max(id_ver) as id_ver';
      if (not AKeepVerNumber) then begin
        // get new value for ver_number too
        VSQLText := VSQLText + ', max(ver_number) as ver_number';
      end;
      VSQLText := VSQLText + ' from ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;
      VDataset.OpenSQL(VSQLText);
      // apply values
      if VDataset.IsEmpty or VDataset.FieldByName('id_ver').IsNull then
        ANewVersionPtr^.id_ver := 0
      else
        ANewVersionPtr^.id_ver := VDataset.FieldByName('id_ver').AsInteger;
      Inc(ANewVersionPtr^.id_ver);
      // may be ver_number too
      if (not AKeepVerNumber) then begin
        if VDataset.IsEmpty or VDataset.FieldByName('ver_number').IsNull then
          ANewVersionPtr^.ver_number := 0
        else
          ANewVersionPtr^.ver_number := VDataset.FieldByName('ver_number').AsInteger;
        Inc(ANewVersionPtr^.ver_number);
      end;
      // done
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.GetSQLIntName_Div(const AXYMaskWidth, AZoom: Byte): String;
var
  VEngineType: TEngineType;
begin
  // ���� ��� �� ������ ��� ������ ����� + 1 - ������ ������� ������ ����
  // � ������ � ��� ������ ������� �������� �� 0 �� 2^(Z-1)-1 ������������:

  // ���� ��� ����� ������ ����� (��� ����� ������������� �� ���������� UNSIGNED-����):

  // ����, �������� � INT1 (TINYINT):
  // 1  - �� 0 �� 2^0-1  =   0 NUMBER(1)
  // 2  - �� 0 �� 2^1-1  =   1
  // 3  - �� 0 �� 2^2-1  =   3
  // 4  - �� 0 �� 2^3-1  =   7
  // 5  - �� 0 �� 2^4-1  =  15 NUMBER(2)
  // 6  - �� 0 �� 2^5-1  =  31
  // 7  - �� 0 �� 2^6-1  =  63
  // 8  - �� 0 �� 2^7-1  = 127 NUMBER(3)
  
  // ����, �������� � INT2 (SMALLINT):
  // 9  - �� 0 �� 2^8-1  =   255
  // 10 - �� 0 �� 2^9-1  =   511
  // 11 - �� 0 �� 2^10-1 =  1023 NUMBER(4)
  // 12 - �� 0 �� 2^11-1 =  2047
  // 13 - �� 0 �� 2^12-1 =  4095
  // 14 - �� 0 �� 2^13-1 =  8191
  // 15 - �� 0 �� 2^14-1 = 16383 NUMBER(5)
  // 16 - �� 0 �� 2^15-1 = 32767

  // ����, �������� � INT3 (MEDIUMINT):
  // 17 - �� 0 �� 2^16-1 =   65535
  // 18 - �� 0 �� 2^17-1 =  131071 NUMBER(6)
  // 19 - �� 0 �� 2^18-1 =  262143
  // 20 - �� 0 �� 2^19-1 =  524287
  // 21 - �� 0 �� 2^20-1 = 1048575 NUMBER(7)
  // 22 - �� 0 �� 2^21-1 = 2097151
  // 23 - �� 0 �� 2^22-1 = 4194303
  // 24 - �� 0 �� 2^23-1 = 8388607

  // ����, �������� � INT4 (INTEGER):
  // 25 - �� 0 �� 2^24-1 =   16777215 NUMBER(8)
  // 26 - �� 0 �� 2^25-1 =   33554431
  // 27 - �� 0 �� 2^26-1 =   67108863
  // 28 - �� 0 �� 2^27-1 =  134217727 NUMBER(9)
  // 29 - �� 0 �� 2^28-1 =  268435455
  // 30 - �� 0 �� 2^29-1 =  536870911
  // 31 - �� 0 �� 2^30-1 = 1073741823 NUMBER(10)
  // 32 - �� 0 �� 2^31-1 = 2147483647

  // ���� ����� 10 - �� ������� �� ������� �� 1024 ������ � ������������� �����
  // � ����� ����� �� ������� �� 1024 ������ � ��� �������
  // ������ ��� ���������� ����� �����, ����� ������� �� 0 �� 1023
  // ���� ��� ��� �������������� ����� � ��������� �� 10 �� 15, ��� ������������� �������� �� 1024 �� 32768:
  // 10 - �� 0 �� 1023  - INT2 ��� NUMBER(4)
  // 11 - �� 0 �� 2047  - INT2 ��� NUMBER(4)
  // 12 - �� 0 �� 4095  - INT2 ��� NUMBER(4)
  // 13 - �� 0 �� 8191  - INT2 ��� NUMBER(4)
  // 14 - �� 0 �� 16383 - INT2 ��� NUMBER(5)
  // 15 - �� 0 �� 32767 - INT2 ��� NUMBER(5)

  // � ����������� �� ���� ������� �� � �������� ���� ����� ����������� ��� ����
  VEngineType := FConnection.GetCheckedEngineType;

  if UseSingleTable(AXYMaskWidth, AZoom) then begin
    // ������ �� ������� �� �������� (��� ������� ���������, ��� ��� �������)
    if c_SQL_INT_With_Size[VEngineType] then begin
      // ���� � ��������, ������ ����������� � ���������� ��������
      if (AZoom>32) then begin
        // ���� ��������� ��� ������� - ������������ ������
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AZoom>=31) then begin
        // 10 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(10)';
      end else if (AZoom>=28) then begin
        // 9 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(9)';
      end else if (AZoom>=25) then begin
        // 8 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(8)';
      end else if (AZoom>=21) then begin
        // 7 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(7)';
      end else if (AZoom>=18) then begin
        // 6 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(6)';
      end else if (AZoom>=15) then begin
        // 5 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(5)';
      end else if (AZoom>=11) then begin
        // 4 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(4)';
      end else if (AZoom>=8) then begin
        // 3 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(3)';
      end else if (AZoom>=5) then begin
        // 2 ��������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(2)';
      end else begin
        // 1 ������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(1)';
      end;
      // ����� ��� ���� � ��������
    end else begin
      // ���� ��� �������, ������ �� ������ � ������
      if (AZoom>32) then begin
        // ������ BIGINT �� ������ ������
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AZoom>24) then begin
        // INT4
        Result := c_SQL_INT4_FieldName[VEngineType];
      end else if (AZoom>16) then begin
        // INT3, ���� ��� - INT4
        Result := c_SQL_INT3_FieldName[VEngineType];
        if (0=Length(Result)) then
          Result := c_SQL_INT4_FieldName[VEngineType];
      end else if (AZoom>8) then begin
        // INT2
        Result := c_SQL_INT2_FieldName[VEngineType];
      end else begin
        // INT1, ���� ��� - INT2
        Result := c_SQL_INT1_FieldName[VEngineType];
        if (0=Length(Result)) then
          Result := c_SQL_INT2_FieldName[VEngineType];
      end;
      // ����� ��� ���� ��� �������
    end;
    // ����� ��� ������� �� ��������
  end else begin
    // ������� �� �������� �� ��������� ������ �����
    if c_SQL_INT_With_Size[VEngineType] then begin
      // ���� � ��������
      if (AXYMaskWidth>=16) then begin
        // ���� ��������� ��� ������� - ������������ ������
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else if (AXYMaskWidth>=14) then begin
        // 5 �������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(5)';
      end else begin
        // 4 �������
        Result := c_SQL_INT8_FieldName[VEngineType]+'(4)';
      end;
      // ����� ��� ���� � ��������
    end else begin
      // ���� ��� �������
      if (AXYMaskWidth>=16) then begin
        // ������ BIGINT �� ������ ������
        Result := c_SQL_INT8_FieldName[VEngineType];
      end else begin
        // INT2 - � �� ������, � �� ������
        Result := c_SQL_INT2_FieldName[VEngineType];
      end;
      // ����� ��� ���� ��� �������
    end;
  end;
end;

function TDBMS_Provider.GetSQL_AddIntWhereClause(
  var AWhereClause: TDBMS_String;
  const AFieldName: TDBMS_String;
  const AWithMinBound, AWithMaxBound: Boolean;
  const AMinBoundValue, AMaxBoundValue: Integer
): Boolean;
begin
  Result := FALSE;
  if AWithMinBound then begin
    if AWithMaxBound then begin
      // with maximum
      if (AMinBoundValue=AMaxBoundValue) then begin
        // ������ ���� ��������
        AWhereClause := AWhereClause + ' and v.' + AFieldName + ' = ' + IntToStr(AMinBoundValue);
      end else begin
        // ��������
        AWhereClause := AWhereClause + ' and v.' + AFieldName + ' between ' + IntToStr(AMinBoundValue) + ' and ' + IntToStr(AMaxBoundValue);
      end;
    end else begin
      // without maximum
      // ������ ������� �����
      AWhereClause := AWhereClause + ' and v.' + AFieldName + ' >= ' + IntToStr(AMinBoundValue);
    end;
  end else begin
    // without minimum
    if AWithMaxBound then begin
      // with maximum
      // ������ ������� ������
      AWhereClause := AWhereClause + ' and v.' + AFieldName + ' <= ' + IntToStr(AMaxBoundValue);
    end else begin
      // no filtering at all
      // ������ �� ������� ����� WHERE
    end;
  end;
end;

function TDBMS_Provider.GetSQL_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  out ADeleteSQLResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound: Boolean;
  VReqVersion: TVersionAA;
begin
  // ���������� ����������� ������
  if ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // ��� Ansi
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // ��� Wide
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  // ���� �� ������ ���������� ������ - ������ ������
  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // ��������� VSQLTile
  Result := InternalCalcSQLTile(ADeleteBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // �������� DELETE
  ADeleteSQLResult := 'delete from ' + FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName +
                      ' where x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);  
end;

function TDBMS_Provider.GetSQL_EnumTileVersions(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
  VSQLParts: TSQLParts;
begin
  // ��������� VSQLTile �� ���������� ���������
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  (*
  // check if table exists
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // check if failed
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
  end;
  *)

  // �������� SELECT
  VSQLParts.SelectSQL := 'select v.id_ver';
  VSQLParts.FromSQL := FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // ������� FROM, WHERE � ORDER BY
  AddVersionOrderBy(@VSQLParts, nil, FALSE);

  // ������ �� ������
  ASQLTextResult := VSQLParts.SelectSQL +
                  ' from ' + VSQLParts.FromSQL +
                 ' where v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                   ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetSQL_GetTileRectInfo(
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN;
  const AExclusively: Boolean;
  ASelectInRectList: TSelectInRectList
): Byte;
var
  VTileXYZMin, VTileXYZMax: TTILE_ID_XYZ;
  VSQLTileMin, VSQLTileMax: TSQLTile;
  i,j: Integer;
  VSelectInRectItem: PSelectInRectItem;
begin
  // ������� ����� ���������� � ������� �� ����� ������������ ��������������
  if (ATileRectInfoIn^.ptTileRect<>nil) then begin
    // ������������� ���� - ���� min � max
    VTileXYZMin.z  := ATileRectInfoIn.btTileZoom;
    VTileXYZMin.xy := ATileRectInfoIn.ptTileRect^.TopLeft;
    VTileXYZMax.z  := ATileRectInfoIn.btTileZoom;
    VTileXYZMax.xy := ATileRectInfoIn.ptTileRect^.BottomRight;
    // ��������� ������� �������, ��� ��� �� ���� ������ ������� ����������, � ������� �����������
    VTileXYZMax.xy.X := VTileXYZMax.xy.X-1;
    VTileXYZMax.xy.Y := VTileXYZMax.xy.Y-1;

    // ���������� ���������� � ��������
    Result := InternalCalcSQLTile(@VTileXYZMin, @VSQLTileMin);
    if (Result<>ETS_RESULT_OK) then
      Exit;
    Result := InternalCalcSQLTile(@VTileXYZMax, @VSQLTileMax);
    if (Result<>ETS_RESULT_OK) then
      Exit;

    VSelectInRectItem := nil;

    // ����������� ��������
    if (VSQLTileMin.XYUpperToTable.X<=VSQLTileMax.XYUpperToTable.X) and (VSQLTileMin.XYUpperToTable.Y<=VSQLTileMax.XYUpperToTable.Y) then begin
      // �������� ���� �� X � Y (��� ��� ����� ���� ���������� �� �������� - ������� ������� ����������)
      for i := VSQLTileMin.XYUpperToTable.X to VSQLTileMax.XYUpperToTable.X do
      for j := VSQLTileMin.XYUpperToTable.Y to VSQLTileMax.XYUpperToTable.Y do
      try
        New(VSelectInRectItem);
        // � ��� �������, ������� ��� ��� � ��� �������� � ����� ��������� (��� ��������� ���� ������� �������)
        // ������ ��� �������������� �������� ��������� � ��������� � ������ ����� ������� ������ �������
        with VSelectInRectItem^.TabSQLTile do begin
          XYUpperToTable.X := i;
          XYUpperToTable.Y := j;
          Zoom := ATileRectInfoIn.btTileZoom;
        end;

        with VSelectInRectItem^ do begin
          InitialWhereClause := '';

          // ������� ��� �������
          FillTableNamesForTiles(@(VSelectInRectItem^.TabSQLTile));

          // �� X
          GetSQL_AddIntWhereClause(
            InitialWhereClause,
            'x',
            (i=VSQLTileMin.XYUpperToTable.X),
            (i=VSQLTileMax.XYUpperToTable.X),
            VSQLTileMin.XYLowerToID.X,
            VSQLTileMax.XYLowerToID.X
          );

          // �� Y
          GetSQL_AddIntWhereClause(
            InitialWhereClause,
            'y',
            (j=VSQLTileMin.XYUpperToTable.Y),
            (j=VSQLTileMax.XYUpperToTable.Y),
            VSQLTileMin.XYLowerToID.Y,
            VSQLTileMax.XYLowerToID.Y
          );
        end;

        // � ������ ����� �������� SELECT
        Result := GetSQL_SelectTilesInternal(
          @(VSelectInRectItem^.TabSQLTile),
          ATileRectInfoIn^.szVersionIn,
          ATileRectInfoIn^.dwOptionsIn,
          VSelectInRectItem^.InitialWhereClause,
          TRUE,
          AExclusively,
          VSelectInRectItem^.FullSqlText
        );
          
        if (Result <> ETS_RESULT_OK) then
          Abort;

        // ����������� � ������
        ASelectInRectList.Add(VSelectInRectItem);
        VSelectInRectItem := nil;
      except
        if (nil <> VSelectInRectItem) then begin
          Dispose(VSelectInRectItem);
          VSelectInRectItem := nil;
        end;
      end;

    // ATileRectInfoIn^.

    end else begin
      // �����-�� ���������
      Result := ETS_RESULT_INVALID_STRUCTURE;
    end;
  end else begin
    // ������������� �� ���� - �������� �� ���� �������� ����������� ����
    Result := ETS_RESULT_NOT_IMPLEMENTED;
  end;
end;

function TDBMS_Provider.GetSQL_InsertIntoService(
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VDataset: TDBMS_Dataset;
  VNewIdService: SmallInt;
  VNewIdContentType: SmallInt;
  VNewServiceCode: AnsiString;
  VSQLText: TDBMS_String;
begin
  // id_service = max(id_service)+1
  // service_code = Trunc(Name,20)
  VNewServiceCode := InternalGetServiceNameByHost;

  if (0=Length(VNewServiceCode)) then begin
    // ��� ����������� �������������� �������
    Result := ETS_RESULT_INVALID_SERVICE_CODE;
    Exit;
  end;

  // ����� ����������� ����������� ���� ������� ���������� 20 ���������
  if Length(VNewServiceCode)>20 then
    SetLength(VNewServiceCode, 20);

  VDataset := FConnection.MakePoolDataset;
  try
    // � ����� ����� ���������� ��� ������� ��� ����
    VSQLText := GetSQL_SelectService_ByCode(VNewServiceCode);
    try
      VDataset.OpenSQL(VSQLText);
    except
      // ���� ���������� �� ������� �������, ������ ���� �� ���������� ��
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    if (not VDataset.IsEmpty) then begin
      // ����� ������ ��� ��������������� � �� (��������, � ������ ������� ���������� �����)
      Result := ETS_RESULT_INVALID_SERVICE_CODE;
      Exit;
    end;

    // ����� ������ ��������� ������ ����� ������
    ReadContentTypesFromDB(AExclusively);

    // ������� ��������� ��� �����
    if not FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VNewIdContentType) then begin
      // ����������
      Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
      Exit;
    end;

    // ������� ����� ����� ��������������
    // TODO: ������� � ����� � ���������� �����
    try
      VDataset.OpenSQL('SELECT max(id_service) as id_service FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE);
    except
      // ����� ���������� �� ������� �������
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    // ��������� �������������
    VNewIdService := VDataset.FieldByName('id_service').AsInteger + 1;

    // ��������� ������� INSERT
    // ������ ���� (id_ver_comp, id_div_mode, work_mode, use_common_tiles) �������� �� DEFAULT-��� ��������
    // ��� ������������� DBA ����� ������� ������ �������� � �������, � ����� �������� �������� ��� ������� ����� ��� ����������� � ��
    ASQLTextResult := 'INSERT INTO ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' (id_service,service_code,service_name,id_contenttype) VALUES (' +
                            IntToStr(VNewIdService) + ',' +
                            DBMSStrToDB(VNewServiceCode) + ',' +
                            DBMSStrToDB(InternalGetServiceNameByHost) + ',' +
                            IntToStr(VNewIdContentType) + ')';
    Result := ETS_RESULT_OK;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.GetSQL_InsertUpdateTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean;
  const AExclusively: Boolean;
  out AInsertSQLResult, AUpdateSQLResult: TDBMS_String;
  out AInsertUpdateSubType: TInsertUpdateSubType;
  out AUnquotedTableNameWithoutPrefix, AQuotedTableNameWithPrefix: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound, VRequestedContentTypeFound: Boolean;
  VIdContentType: SmallInt;
  VReqVersion: TVersionAA;
  VUseCommonTiles: Boolean;
  VNewTileSize: LongInt;
  VNewTileBody: TDBMS_String;
  VVersionAutodetected: Boolean;
begin
  // ���� ��� ���������� ����� ������ - ���� ������
  if (0=FContentTypeList.Count) then begin
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    ReadContentTypesFromDB(AExclusively);
  end;

  // ������� ��� �� ��� ����� ���������
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_IN) <> 0) then begin
    // ��� Ansi
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiContentTypeText(
      PAnsiChar(AInsertBuffer^.szContentType),
      VIdContentType
    );
  end else begin
    // ��� Wide
    VRequestedContentTypeFound := FContentTypeList.FindItemByWideContentTypeText(
      PWideChar(AInsertBuffer^.szContentType),
      VIdContentType
    );
  end;

  if (not VRequestedContentTypeFound) {or AForceTNE} then begin
    // ���� ��� ������ ���� ����� - ���������� ���������
    // TODO: ������, �� �������� ������ ���� ����� ����� ������ ������������ ���� �����
    // � ������ ����� �������� ContentType ����������� ������ ������
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VIdContentType);
  end;

  if (not VRequestedContentTypeFound) then begin
    Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
    Exit;
  end;

  VVersionAutodetected := FALSE;

  // ������� ��� �� ������ ���������
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // ��� Ansi
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // ��� Wide
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  // ��������������� ������ �� ����� (���� ���������)
  if (FDBMS_Service_Info.new_ver_by_tile<>c_Tile_Parser_None) then begin
    Result := TryToObtainVerByTile(
      AExclusively,
      VRequestedVersionFound,
      VIdContentType,
      VVersionAutodetected,
      AInsertBuffer,
      @VReqVersion
    );
    if (Result<>ETS_RESULT_OK) then
      Exit;
  end;

  if (not VRequestedVersionFound) then begin
    // ���� ����� ������ ��� - ������� ������� � �������������
    Result := AutoCreateServiceVersion(
      AExclusively,
      VVersionAutodetected,
      AInsertBuffer,
      @VReqVersion,
      VRequestedVersionFound);
    // ��������� ��������� �������� ����� ������
    if (Result<>ETS_RESULT_OK) then
      Exit;
  end;

  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // ��������� VSQLTile
  Result := InternalCalcSQLTile(AInsertBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // �������� ������ ��� ������� ��� ������ (��� ��������� ������)
  AUnquotedTableNameWithoutPrefix := VSQLTile.UnquotedTileTableName;
  // � ����� ������� ����� � ��������� �����
  AQuotedTableNameWithPrefix := FConnection.ForcedSchemaPrefix + VSQLTile.QuotedTileTableName;

  if AForceTNE then begin
    // ��� ������� ������� TNE �� ��������� ��������� ����� � ����� ������������
    VUseCommonTiles := FALSE;
    VNewTileSize := 0;
  end else begin
    // ��������� ��� ���� � ������ ����� ������������ ������
    VUseCommonTiles := CheckTileInCommonTiles(
      AInsertBuffer^.ptTileBuffer,
      AInsertBuffer^.dwTileSize,
      VNewTileSize // ���� ��� � ���� - ���� ������� ������ �� ����
    );
  end;

  if AForceTNE then begin
    // ������ TNE - ��� ���� ����� (���� �� ��������� ������)
    // ��������! ����� ���� ��� TILE � �������� TNE - ����� tile_size=0, � ���� ����� ���������!
    // ������� ��� ���������� ����������� �������� ����� � ������� TNE � ����������� TNE
    // TODO: ��������� �������� ������� (�����)
    AUpdateSQLResult := ''; // ', tile_body=null';
    AInsertSQLResult := '';
    VNewTileBody := '';
    AInsertUpdateSubType := iust_TNE;
  end else if VUseCommonTiles then begin
    // ����� ������������ ���� - �������� ������ �� ����
    AUpdateSQLResult := ', tile_body=null';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',null';
    AInsertUpdateSubType := iust_COMMON;
  end else begin
    // ������� ���� (�� ������ TNE � �� ����� ������������)
    AUpdateSQLResult := ', tile_body=' + c_RTL_Tile_Body_Paramname;
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',' + c_RTL_Tile_Body_Paramname;
    AInsertUpdateSubType := iust_TILE;
  end;

  // ������ ��������� INSERT
  AInsertSQLResult := 'INSERT INTO ' + AQuotedTableNameWithPrefix + ' (x,y,id_ver,id_contenttype,load_date,tile_size' + AInsertSQLResult + ') VALUES (' +
                      IntToStr(VSQLTile.XYLowerToID.X) + ',' +
                      IntToStr(VSQLTile.XYLowerToID.Y) + ',' +
                      IntToStr(VReqVersion.id_ver) + ',' +
                      IntToStr(VIdContentType) + ',' +
                      SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) + ',' +
                      IntToStr(VNewTileSize) + VNewTileBody + ')';

  // ������ ��������� UPDATE
  AUpdateSQLResult := 'UPDATE ' + AQuotedTableNameWithPrefix + ' SET id_contenttype=' + IntToStr(VIdContentType) +
                           ', load_date=' + SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) +
                           ', tile_size=' + IntToStr(VNewTileSize) +
                           AUpdateSQLResult +
                      ' WHERE x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);
end;

function TDBMS_Provider.GetSQL_SelectContentTypes: TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_CONTENTTYPE;
end;

function TDBMS_Provider.GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_code='+DBMSStrToDB(AServiceCode);
end;

function TDBMS_Provider.GetSQL_SelectService_ByHost: TDBMS_String;
begin
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + Z_SERVICE + ' WHERE service_name='+DBMSStrToDB(InternalGetServiceNameByHost);
end;

function TDBMS_Provider.GetSQL_SelectTile(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLTile: TSQLTile;
begin
  // ��������� VSQLTile �� ���������� ���������
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // �������� SELECT
  Result := GetSQL_SelectTilesInternal(
    @VSQLTile,
    ASelectBufferIn^.szVersionIn,
    ASelectBufferIn^.dwOptionsIn,
    // ����� ���� ���������� ����
    'v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y),
    FALSE, // ����� ���� ��������� ���� - ��� ���������� ��� �� � ����
    AExclusively,
    ASQLTextResult
  );
end;

function TDBMS_Provider.GetSQL_SelectTilesInternal(
  const ASQLTile: PSQLTile;
  const AVersionIn: Pointer;
  const AOptionsIn: LongWord;
  const AInitialWhere: TDBMS_String;
  const ASelectXY: Boolean;
  const AExclusively: Boolean;
  out ASQLTextResult: TDBMS_String
): Byte;
var
  VSQLParts: TSQLParts;
  VReqVersion: TVersionAA;
begin
  Result := ETS_RESULT_OK;

  // ���������
  VSQLParts.SelectSQL := 'SELECT v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := ASQLTile^.QuotedTileTableName + ' v';
  VSQLParts.WhereSQL := AInitialWhere;
  VSQLParts.OrderBySQL := '';

  if ASelectXY then begin
    // ����� ���� ���� �������� ����������
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.x,v.y,';
  end;

  // ���� �� ��������� ����� ������������ �����
  // � ������ ���������� �� ���� ������
  if (ETS_UCT_NO=FDBMS_Service_Info.use_common_tiles) then begin
    // ��� ����� ������������ ������
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.tile_size';
    if ((AOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      VSQLParts.SelectSQL := VSQLParts.SelectSQL + ',v.tile_body';
    end;
  end else begin
    // � ����� ������������� �������
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'isnull(k.common_size,v.tile_size) as tile_size';
    if ((AOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      VSQLParts.SelectSQL := VSQLParts.SelectSQL + ',isnull(k.common_body,v.tile_body) as tile_body';
    end;

    VSQLParts.FromSQL := VSQLParts.FromSQL + ' left outer join  u_' + InternalGetServiceNameByDB + ' k on v.tile_size<0 and v.tile_size=-k.id_common_tile and v.id_contenttype=k.id_common_type';
  end;

  // �������� FROM, WHERE � ORDER BY

  // ��������� ����������� ������
  if ((AOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // ��� Ansi
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AVersionIn),
      @VReqVersion
    );
  end else begin
    // ��� Wide
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(AVersionIn),
      @VReqVersion
    );
  end;

  // ���� �� ������ ���������� ������ - ������ ������
  // �� ����� ������ �������� � ���� ������ �� �� �� ��������
  if (not VSQLParts.RequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // ���� ������ ���� ������� (� ��� ����� ����������������� ������������� ��� ������ ������!)
  if (VReqVersion.id_ver=FVersionList.EmptyVersionIdVer) then begin
    // ������ ��� ������
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_LAST_VERSION) <> 0) then begin
      // ���� ��������� ������ (��������� � OrderBySQL �����)
      AddVersionOrderBy(@VSQLParts, @VReqVersion, FALSE);
    end else begin
      // ���� ������ ������ ������ (��� ��� ��� ���� - �������� ��� ORDER BY)
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
    end;
  end else begin
    // ������ � �������� �������
    if ((FStatusBuffer^.tile_load_mode and ETS_TLM_PREV_VERSION) <> 0) then begin
      // ��������� ���������� ������
      AddVersionOrderBy(@VSQLParts, @VReqVersion, TRUE);
      if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) = 0) then begin
        // �� �� ��������� ��� ������!
        VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver!=' + IntToStr(FVersionList.EmptyVersionIdVer);
      end;
    end else if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) <> 0) then begin
      // ��������� ������� ������ ����������� ������ ��� ������ ��� ������
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver in (' + IntToStr(VReqVersion.id_ver) + ',' + IntToStr(FVersionList.EmptyVersionIdVer) + ')';
    end else begin
      // ��������� ������� ������ ����������� ������
      VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
    end;
  end;

  // ��������� WHERE:
  // �) ���� ���������� � ' and ' - ������ ������;
  // �) ���� ������ ��� ������� - �� ����� ������ � WHERE
  if (0<Length(VSQLParts.WhereSQL)) then begin
    if SameText(System.Copy(VSQLParts.WhereSQL, 1, 5),' and ') then begin
      System.Delete(VSQLParts.WhereSQL, 1, 5);
    end;

    VSQLParts.WhereSQL := ' WHERE ' + VSQLParts.WhereSQL;
  end;


  // �������� �� ������
  ASQLTextResult := VSQLParts.SelectSQL + ' FROM ' + VSQLParts.FromSQL +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetSQL_SelectVersions: TDBMS_String;
begin
  // ����� �� �� ������� ������ ��� �������� �������
  Result := 'SELECT * FROM ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB;
end;

function TDBMS_Provider.GetVersionAnsiPointer(
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): PAnsiChar;
var
  VDummy: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(Aid_ver, AExclusively, @Result, VDummy) then
      Exit;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetVersionAnsiPointer(Aid_ver, TRUE);
  end;
end;

function TDBMS_Provider.GetVersionWideString(
  const Aid_ver: SmallInt;
  const AExclusively: Boolean
): WideString;
var
  VVerValueAnsiStr: AnsiString;
begin
  GuidesBeginWork(AExclusively);
  try
    if InternalGetVersionAnsiValues(Aid_ver, AExclusively, nil, VVerValueAnsiStr) then begin
      // found
      Result := VVerValueAnsiStr;
      Exit;
    end;
  finally
    GuidesEndWork(AExclusively);
  end;

  // not found
  if (AExclusively) then begin
    // not found at all
    Result := '';
  end else begin
    // try to repeat exclusively
    Result := GetVersionWideString(Aid_ver, TRUE);
  end;
end;

procedure TDBMS_Provider.GuidesBeginWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FGuidesSync.BeginWrite
  else
    FGuidesSync.BeginRead;
end;

procedure TDBMS_Provider.GuidesEndWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FGuidesSync.EndWrite
  else
    FGuidesSync.EndRead;
end;

function TDBMS_Provider.HasUnknownExceptions: Boolean;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    Result := (nil<>FUnknownExceptions) and (0<FUnknownExceptions.Count);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

function TDBMS_Provider.InternalCalcSQLTile(
  const AXYZ: PTILE_ID_XYZ;
  const ASQLTile: PSQLTile
): Byte;
begin
  // ��������� ��� (�� 1 �� 24)
  ASQLTile^.Zoom := AXYZ^.z;
  
  // ����� XY �� "�������" � "������" �����
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  // ������ ��� ������� ��� ������
  FillTableNamesForTiles(ASQLTile);

  Result := ETS_RESULT_OK;
end;

procedure TDBMS_Provider.InternalDivideXY(
  const AXY: TPoint;
  const ASQLTile: PSQLTile
);
var
  VMask: LongInt;
  VXYMaskWidth: Byte;
begin
  VXYMaskWidth := FDBMS_Service_Info.XYMaskWidth;

  if (0=VXYMaskWidth) then begin
    // do not divide
    ASQLTile^.XYUpperToTable.X := 0;
    ASQLTile^.XYUpperToTable.Y := 0;
    ASQLTile^.XYLowerToID := AXY;
  end else begin
    // divide
    VMask := (1 shl VXYMaskWidth)-1;
    ASQLTile^.XYUpperToTable.X := AXY.X shr VXYMaskWidth;
    ASQLTile^.XYUpperToTable.Y := AXY.Y shr VXYMaskWidth;
    ASQLTile^.XYLowerToID.X := AXY.X and VMask;
    ASQLTile^.XYLowerToID.Y := AXY.Y and VMask;
  end;
end;

function TDBMS_Provider.InternalGetContentTypeAnsiValues(
  const Aid_contenttype: SmallInt;
  const AExclusively: Boolean;
  const AContentTypeTextPtr: PPAnsiChar;
  out AContentTypeTextStr: AnsiString
): Boolean;
begin
  // find
  Result := FContentTypeList.FindItemByIdContentType(
    Aid_contenttype,
    AContentTypeTextPtr,
    AContentTypeTextStr
  );

  if (not Result) then begin
    // not found
    if not AExclusively then
      Exit;
      
    // read from DB
    ReadContentTypesFromDB(AExclusively);

    // again
    Result := FContentTypeList.FindItemByIdContentType(
      Aid_contenttype,
      AContentTypeTextPtr,
      AContentTypeTextStr
    );
  end;
end;

function TDBMS_Provider.InternalGetServiceNameByDB: TDBMS_String;
begin
  Result := FDBMS_Service_Code;
end;

function TDBMS_Provider.InternalGetServiceNameByHost: TDBMS_String;
begin
  Result := FPath.Path_Items[2];
end;

function TDBMS_Provider.InternalGetVersionAnsiValues(
  const Aid_ver: SmallInt;
  const AExclusively: Boolean;
  const AVerValuePtr: PPAnsiChar;
  out AVerValueStr: AnsiString
): Boolean;
begin
  // find
  Result := FVersionList.FindItemByIdVer(Aid_ver, AVerValuePtr, AVerValueStr);
  if (not Result) then begin
    // not found
    if not AExclusively then
      Exit;
      
    // read from DB
    ReadVersionsFromDB(AExclusively);

    Result := FVersionList.FindItemByIdVer(Aid_ver, AVerValuePtr, AVerValueStr);
  end;
end;

procedure TDBMS_Provider.InternalProv_Cleanup;
begin
  FillChar(FHostCallbacks, sizeof(FHostCallbacks), 0);
  FPath.Clear;
  InternalProv_ClearServiceInfo;
end;

procedure TDBMS_Provider.InternalProv_ClearGuides;
begin
  FVersionList.Clear;
  FContentTypeList.Clear;
end;

procedure TDBMS_Provider.InternalProv_ClearServiceInfo;
begin
  FDBMS_Service_OK := FALSE;
  FDBMS_Service_Code := '';
  with FDBMS_Service_Info do begin
    id_service := 0;
    id_contenttype := 0;
    id_ver_comp := TILE_VERSION_COMPARE_NONE;
    id_div_mode := TILE_DIV_ERROR;
    work_mode := ETS_SWM_DEFAULT;
    use_common_tiles := ETS_UCT_NO;
    // ������ ������ �����
    tile_load_mode    := 0;
    tile_save_mode    := 0;
    tile_hash_mode    := 0;
    new_ver_by_tile   := 0;
  end;
end;

function TDBMS_Provider.InternalProv_Connect(const AExclusively: Boolean): Byte;
begin
  if (not FCompleted) then begin
    Result := ETS_RESULT_INCOMPLETE;
    Exit;
  end;

  // ������ ����������
  if (nil<>FConnection) and (FReconnectPending) then begin
    if (not AExclusively) then begin
      // ���������������� ������ � ������������ ������
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    // ��������� � �� �����
    InternalProv_Disconnect;
    FReconnectPending := FALSE;
  end;

  // safe create connection object
  if (nil=FConnection) then begin
    // check exclusive mode
    if AExclusively then begin
      // make connection
      FConnection := GetConnectionByPath(@FPath);
      if (nil=FConnection) then begin
        Result := ETS_RESULT_CANNOT_CONNECT;
        Exit;
      end;
    end else begin
      // request exclusive access
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
  end;

  // ������� ������������
  Result := FConnection.EnsureConnected(AExclusively, FStatusBuffer);

  // ��� ������ �����
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // ������ ��������� ������� ����� �����������
  if (not FDBMS_Service_OK) then begin
    if (not AExclusively) then begin
      Result := ETS_RESULT_NEED_EXCLUSIVE;
      Exit;
    end;
    Result := InternalProv_ReadServiceInfo(AExclusively);
    if (ETS_RESULT_OK<>Result) then
      Exit;
    // ���� ������ ������� - ������� �� ���� ��� ������
    ReadVersionsFromDB(AExclusively);
    // ���� ������ ��� ������ - �������� ������ ��� ������ ������ (��� ������)
    try
      if (0=FVersionList.Count) then begin
        // ������ ������ ���� ���� ��������� ������ ������
        if not c_SQL_Empty_Version_Denied[FConnection.GetCheckedEngineType] then begin
          MakeEmptyVersionInDB(0, AExclusively);
        end;
        ReadVersionsFromDB(AExclusively);
      end;
    except
    end;
  end;
end;

procedure TDBMS_Provider.InternalProv_Disconnect;
begin
  // detach connection object from provider
  FreeDBMSConnection(FConnection);
end;

function TDBMS_Provider.InternalProv_ReadServiceInfo(const AExclusively: Boolean): Byte;
var
  VDataset: TDBMS_Dataset;
  VSelectCurrentServiceSQL: TDBMS_String;
  VStatementExceptionType: TStatementExceptionType;
begin
  FillChar(FDBMS_Service_Info, SizeOf(FDBMS_Service_Info), 0);
  VDataset := FConnection.MakePoolDataset;
  try
    // ������ �������� �������
    VSelectCurrentServiceSQL := GetSQL_SelectService_ByHost;

    // ����� ���� � ������� �������
    // ������ �� ���������� ��� ������������� �������� ����������� ���� �������
    VStatementExceptionType := set_Success;
    try
      VDataset.OpenSQL(VSelectCurrentServiceSQL);
    except on E: Exception do
      VStatementExceptionType := GetStatementExceptionType(E);
    end;

    if StandardExceptionType(VStatementExceptionType, Result) then begin
      // ��������������� ��������� ��������� ������
      InternalProv_ClearServiceInfo;
      Exit;
    end;
    
    case VStatementExceptionType of
      set_Success: begin
        // ok
      end;
      set_TableNotFound: begin
        // ��� ������� � ���������
        // ������ ������� ������� �� �������
        CreateAllBaseTablesFromScript;
        // ���������������
        try
          VDataset.OpenSQL(VSelectCurrentServiceSQL);
        except
        end;
      end;
      set_PrimaryKeyViolation: begin
        // ��� ����� ������ ��� ��� ������ ��������� ���������� ����
      end;
    end;

    // � ����� ������ ������, � ��� ��� � �� ������� ���������
    if (not VDataset.Active) then begin
      // � ����������� �����
      InternalProv_ClearServiceInfo;
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    // ��������, � ���� �� ������
    if VDataset.IsEmpty then begin
      // � �������-�� ������ ���
      // ������ ��������� ������� ���
      Result := AutoCreateServiceRecord(AExclusively);

      // �������� ���� �����������
      if (Result<>ETS_RESULT_OK) then begin
        InternalProv_ClearServiceInfo;
        Exit;
      end;

      // � ����� ������� �������������
      try
        VDataset.OpenSQL(VSelectCurrentServiceSQL);
      except
      end;
    end;

    // ��������� ��������
    if (not VDataset.Active) or VDataset.IsEmpty then begin
      // ��� � ��� �������
      InternalProv_ClearServiceInfo;
      Result := ETS_RESULT_UNKNOWN_SERVICE;
      Exit;
    end;

    // ����������� ������ �������
    FDBMS_Service_Code := VDataset.FieldByName('service_code').AsString;
    FDBMS_Service_Info.id_service := VDataset.FieldByName('id_service').AsInteger;
    FDBMS_Service_Info.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
    FDBMS_Service_Info.id_ver_comp := VDataset.GetAnsiCharFlag('id_ver_comp', TILE_VERSION_COMPARE_NONE);
    FDBMS_Service_Info.id_div_mode := VDataset.GetAnsiCharFlag('id_div_mode', TILE_DIV_ERROR);
    FDBMS_Service_Info.work_mode := VDataset.GetAnsiCharFlag('work_mode', ETS_SWM_DEFAULT);
    FDBMS_Service_Info.use_common_tiles := VDataset.GetAnsiCharFlag('use_common_tiles', ETS_UCT_NO);
    FDBMS_Service_OK := TRUE;

    // ��������� ���� ��������� ������ �� ������ ������ Z_SERVICE, ��� ��� �� ����� �� ����
    FDBMS_Service_Info.tile_load_mode   := VDataset.GetOptionalSmallInt('tile_load_mode');
    FDBMS_Service_Info.tile_save_mode   := VDataset.GetOptionalSmallInt('tile_save_mode');
    FDBMS_Service_Info.tile_hash_mode   := VDataset.GetOptionalSmallInt('tile_hash_mode');
    FDBMS_Service_Info.new_ver_by_tile  := VDataset.GetOptionalSmallInt('new_ver_by_tile');

    // �������� ��������� � ����� ���������
    if (FStatusBuffer<>nil) then
    with (FStatusBuffer^) do begin
      id_div_mode      := FDBMS_Service_Info.id_div_mode;
      id_ver_comp      := FDBMS_Service_Info.id_ver_comp;
      work_mode        := FDBMS_Service_Info.work_mode;
      use_common_tiles := FDBMS_Service_Info.use_common_tiles;
      // ������ ������ �����
      tile_load_mode   := LoByte(FDBMS_Service_Info.tile_load_mode);
      tile_save_mode   := LoByte(FDBMS_Service_Info.tile_save_mode);
    end;

    Result := ETS_RESULT_OK;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.InternalProv_SetStorageIdentifier(
  const AInfoSize: LongWord;
  const AInfoData: PETS_SET_IDENTIFIER_INFO;
  const AInfoResult: PLongWord
): Byte;
var
  VGlobalStorageIdentifier, VServiceName: WideString; // keep wide
begin
  // �������� �����
  if (nil = AInfoData) or (AInfoSize < Sizeof(AInfoData^)) then begin
    Result := ETS_RESULT_INVALID_BUFFER_SIZE;
    Exit;
  end;

  // ������������� �� ����� ���� ������
  if (nil = AInfoData^.szGlobalStorageIdentifier) then begin
    Result := ETS_RESULT_POINTER1_NIL;
    Exit;
  end;

  // ������������� �� ����� ���� ������
  if (nil = AInfoData^.szServiceName) then begin
    Result := ETS_RESULT_POINTER2_NIL;
    Exit;
  end;

  // ����� �������� �� ������
  if ((AInfoData^.dwOptionsIn and ETS_ROI_ANSI_SET_INFORMATION) <> 0) then begin
    // ��� AnsiString
    VGlobalStorageIdentifier := AnsiString(PAnsiChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := AnsiString(PAnsiChar(AInfoData^.szServiceName));
  end else begin
    // ��� WideString
    VGlobalStorageIdentifier := WideString(PWideChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := WideString(PWideChar(AInfoData^.szServiceName));
  end;

  // ������ � �������� ������ ���� �� ���� � ������� � ���
  FPath.ApplyFrom(VGlobalStorageIdentifier, VServiceName);

  // ��������� ��� �����������
  if (0<Length(FPath.Path_Items[0])) and (0<Length(FPath.Path_Items[2])) then begin
    // ��������� (� ����� ������ �������, �� ����������� ������ ����� ��������)
    Result := ETS_RESULT_OK;
  end else begin
    // �������� �����
    Result := ETS_RESULT_INVALID_PATH;
  end;
end;

function TDBMS_Provider.MakeEmptyVersionInDB(
  const AIdVersion: SmallInt;
  const AExclusively: Boolean
): Boolean;
var
  VNewVersion: TVersionAA;
begin
  Assert(AExclusively);

  // �������� ������ � �� ��� ������ ������ �������� �������
  VNewVersion.id_ver := AIdVersion;
  VNewVersion.ver_value :='';
  VNewVersion.ver_date := c_SQL_DateTimeForEmptyVersion[FConnection.GetCheckedEngineType]; //NowUTC;
  VNewVersion.ver_number := AIdVersion;
  VNewVersion.ver_comment := '';
  Result := MakePtrVersionInDB(@VNewVersion, AExclusively);
end;

function TDBMS_Provider.MakePtrVersionInDB(
  const ANewVersionPtr: PVersionAA;
  const AExclusively: Boolean
): Boolean;
var
  VVersionsTableName_UnquotedWithoutPrefix: String;
  VVersionsTableName_QuotedWithPrefix: String;
begin
  Assert(AExclusively);

  VVersionsTableName_UnquotedWithoutPrefix := c_Prefix_Versions + InternalGetServiceNameByDB;
  VVersionsTableName_QuotedWithPrefix := FConnection.ForcedSchemaPrefix + VVersionsTableName_UnquotedWithoutPrefix;

  // ��������, � ���� �� �������� � �������� �������
  if (not FConnection.TableExists(VVersionsTableName_QuotedWithPrefix)) then
  try
    // ��������
    CreateTableByTemplate(
      c_Templated_Versions,
      VVersionsTableName_UnquotedWithoutPrefix,
      VVersionsTableName_QuotedWithPrefix,
      0,
      FALSE
    );
  except
  end;

  // ��� ��������� ������������, ����� ������� ��� ������� ���������

  try
    // �������� SQL ��� ������� ������ � ����� ������ ��������
    FConnection.ExecuteDirectSQL(
      'INSERT INTO ' + VVersionsTableName_QuotedWithPrefix +
      '(id_ver,ver_value,ver_date,ver_number,ver_comment) VALUES (' +
      IntToStr(ANewVersionPtr^.id_ver) + ',' +
      DBMSStrToDB(ANewVersionPtr^.ver_value) + ',' +
      SQLDateTimeToDBValue(ANewVersionPtr^.ver_date) + ',' +
      IntToStr(ANewVersionPtr^.ver_number) + ',' +
      DBMSStrToDB(ANewVersionPtr^.ver_comment) + ')'
    );
    Result := TRUE;
  except
    Result := FALSE;
  end;
end;

function TDBMS_Provider.ParseVerValueToVerNumber(
  const AGivenVersionValue: String;
  out ADoneVerNumber: Boolean;
  out ADateTimeIsDefined: Boolean;
  out ADateTimeValue: TDateTime
): Integer;
var
  p: Integer;

  function _ExtractTailByte: Byte;
  var
    s: String;
    v: Integer;
  begin
    // ���������� ����������
    while (p>0) and (not (AGivenVersionValue[p] in ['0','1'..'9'])) do begin
      Dec(p);
    end;
    // �������� ��������
    s := '';
    while (p>0) and ((AGivenVersionValue[p] in ['0','1'..'9'])) do begin
      s := AGivenVersionValue[p] + s;
      Dec(p);
    end;
    // ������� ���� ����������
    if TryStrToInt(s, v) then
    if (v>=0) and (v<=255) then begin
      Result := LoByte(v);
      Exit;
    end;
    
    Result := 0;
  end;
  
var
  n1,n2,n3,n4: Byte;
begin
  // ������� ���������� �������� ���� 2.33.0 � ������������� � 0*256^0 + 33*256^1 + 2*256^2
  // ����� �������� ��� � ver_number - ��� ���������� ����� ������� ���������� ������
  // � ����� ������ ���� ������ �� ���������� - ����� ����� ������� 0
  // ����� ������ � ������� �������� �� ������
  //Result := 0;
  ADoneVerNumber := FALSE;
  ADateTimeIsDefined := FALSE;

  // ��� ���������� ������ � ���� 2011-08-25_18-15-38
  // ���� �� �� ������� ��� ��������
  // ����� �������� ��� ������� (� ��������) ����� ����� � ������������� ����� (�� ������)
  if ParseFullyQualifiedDateTime(AGivenVersionValue, ADateTimeValue) then begin
    ADateTimeIsDefined := TRUE;
    ADoneVerNumber := TRUE;
    Result := GetVersionNumberForDateTimeAsZeroDifference(ADateTimeValue);
    Exit;
  end;

  // ������� ��������� byte.byte.byte.byte (������ ������!)
  p := Length(AGivenVersionValue);
  n4 := _ExtractTailByte;
  n3:= _ExtractTailByte;
  n2 := _ExtractTailByte;
  n1 := _ExtractTailByte;
  Result := (Integer(n1) shl 24) or (Integer(n2) shl 16) or (Integer(n3) shl 8) or Integer(n4);
  ADoneVerNumber := (Result<>0);
end;

function TDBMS_Provider.GetStatementExceptionType(const AException: Exception): TStatementExceptionType;
var
  VMessage: String;
{$if defined(USE_DIRECT_ODBC)}
  VEngineType: TEngineType;
{$ifend}
begin
  VMessage := UpperCase(AException.Message);
{$if defined(USE_DIRECT_ODBC)}
  // ������� �� SQLSTATE � ������� ���� ������
  // ����� ������� ������
  VMessage := System.Copy(VMessage, 1, c_ODBC_SQLSTATE_MAX_LEN);

  if (0=Length(VMessage)) then begin
    // ��� ���� ������
    Result := set_Unknown;
    Exit;
  end;

  if (nil=FConnection) then
    VEngineType := et_Unknown
  else
    VEngineType := FConnection.GetCheckedEngineType;
  
  // �������� ��������� ������������ (�� ����������� ������� ��� PRIMARY KEY)
  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_PrimaryKeyViolation[et_Unknown]) then begin
    // �������� �� ����� - ������� � ��� ����������� ����
    if (et_Unknown=VEngineType) then begin
      // ����������� ������ - ��� ������ ��� ���������
      Result := set_PrimaryKeyViolation;
      Exit;
    end else begin
      // ����� �������� �� ���������� ���� ������
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_PrimaryKeyViolation[VEngineType]) then begin
        // ��� �����
        Result := set_PrimaryKeyViolation;
        Exit;
      end;
      // ��� ��������, ���� ��� ������ �������, �� �� �����
    end;
  end;


  // �������� ���������� ��������� (������� ��� �����)
  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_1[et_Unknown]) then begin
    // �������� �� ����� - ������� � ��� ����������� ����
    if (et_Unknown=VEngineType) then begin
      // ����������� ������ - ��� ������ ��� ���������
      Result := set_TableNotFound;
      Exit;
    end else begin
      // ����� �������� �� ���������� ���� ������
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_1[VEngineType]) then begin
        Result := set_TableNotFound;
        Exit;
      end;
      if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_TableNotEists_2[VEngineType]) then begin
        Result := set_TableNotFound;
        Exit;
      end;
      // ��� ��������, ���� ��� ������ �������, �� �� �����
    end;
  end;

  // ����� ������ ��� �� ��� ����� ���������
  if (0<Length(c_ODBC_SQLSTATE_NoSpaceAvailable_1[VEngineType])) then begin
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_NoSpaceAvailable_1[VEngineType]) then begin
      Result := set_NoSpaceAvailable;
      Exit;
    end;
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_NoSpaceAvailable_2[VEngineType]) then begin
      Result := set_NoSpaceAvailable;
      Exit;
    end;
  end;

  // ����� ���������� ���������
  if (0<Length(c_ODBC_SQLSTATE_ConnectionIsDead_1[VEngineType])) then begin
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_ConnectionIsDead_1[VEngineType]) then begin
      Result := set_ConnectionIsDead;
      // ������� ������� ������������� RECONNECT-� � ������������ ������
      FReconnectPending := TRUE;
      Exit;
    end;
    if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_ConnectionIsDead_2[VEngineType]) then begin
      Result := set_ConnectionIsDead;
      // ������� ������� ������������� RECONNECT-� � ������������ ������
      FReconnectPending := TRUE;
      Exit;
    end;
  end;

  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_DataTruncation[VEngineType]) then begin
    Result := set_DataTruncation;
    Exit;
  end;

  if OdbcEceptionStartsWith(VMessage, c_ODBC_SQLSTATE_UnsynchronizedStatements[VEngineType]) then begin
    Result := set_UnsynchronizedStatements;
    Exit;
  end;

  // '25000:3906:[MICROSOFT][SQL SERVER NATIVE CLIENT 10.0][SQL SERVER]�� ������� �������� ���� ������ "SAS_MS", ��� ��� ��� ������������� ������ ��� ������.'

  // ���-�� ����
  Result := set_Unknown;
  SaveUnknownException(AException);
{$else}
  // ZEOS and DBX
  if (AException<>nil) and (System.Pos('ServerDisconnected', AException.Classname)>0) then begin
    // ����������� ����������
    Result := set_ConnectionIsDead; //ETS_RESULT_DISCONNECTED;
    // ������� ������� ������������� RECONNECT-� � ������������ ������
    FReconnectPending := TRUE;
    Exit;
  end;

  if (System.Pos('VIOLATION', VMessage)>0) and (System.Pos('CONSTRAINT', VMessage)>0) then begin
    Result := set_PrimaryKeyViolation;
    Exit;
  end;

  Result := set_TableNotFound;
{$ifend}
end;

function TDBMS_Provider.GetUnknownExceptions: String;
begin
  FUnknownExceptionsCS.BeginWrite;
  try
    if (nil=FUnknownExceptions) then
      Result := ''
    else
      Result := FUnknownExceptions.Text;
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

procedure TDBMS_Provider.ReadContentTypesFromDB(const AExclusively: Boolean);
var
  VDataset: TDBMS_Dataset;
  VNewItem: TContentTypeA;
begin
  Assert(AExclusively);
  try
    FContentTypeList.SetCapacity(0);
    VDataset := FConnection.MakePoolDataset;
    try
      VDataset.OpenSQL(GetSQL_SelectContentTypes);
      if (not VDataset.IsEmpty) then begin
        // set capacity
        if (not VDataset.IsUniDirectional) then begin
          FContentTypeList.SetCapacity(VDataset.RecordCount);
        end;
        // enum
        VDataset.First;
        while (not VDataset.Eof) do begin
          // add record to array
          VNewItem.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
          VNewItem.contenttype_text := Trim(VDataset.FieldByName('contenttype_text').AsString);
          FContentTypeList.AddItem(@VNewItem);
          // next
          VDataset.Next;
        end;
      end;
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  except
  end;
end;

procedure TDBMS_Provider.ReadVersionsFromDB(const AExclusively: Boolean);
var
  VDataset: TDBMS_Dataset;
  VNewItem: TVersionAA;
begin
  Assert(AExclusively);
  try
    // ������ ��� ������ � ���������� ������
    FVersionList.Clear;
    VDataset := FConnection.MakePoolDataset;
    try
      VDataset.OpenSQL(GetSQL_SelectVersions);
      if (not VDataset.IsEmpty) then begin
        // ����� ��������� ������ �� ����� ������� � ��������
        if (not VDataset.IsUniDirectional) then begin
          FVersionList.SetCapacity(VDataset.RecordCount);
        end;
        // �����������
        VDataset.First;
        while (not VDataset.Eof) do begin
          // ��������� ��������
          VNewItem.id_ver := VDataset.FieldByName('id_ver').AsInteger;
          VNewItem.ver_value := Trim(VDataset.FieldByName('ver_value').AsString);
          VNewItem.ver_date := VDataset.FieldByName('ver_date').AsDateTime;
          VNewItem.ver_number := VDataset.FieldByName('ver_number').AsInteger;
          VNewItem.ver_comment := Trim(VDataset.FieldByName('ver_comment').AsString);
          FVersionList.AddItem(@VNewItem);
          // - ���������!
          VDataset.Next;
        end;
      end;
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  except
  end;
end;

procedure TDBMS_Provider.SaveUnknownException(const AException: Exception);
begin
  if (nil=AException) then
    Exit;
  FUnknownExceptionsCS.BeginWrite;
  try
    if (nil=FUnknownExceptions) then begin
      // ������ � ���������
      FUnknownExceptions := TStringList.Create;
    end else begin
      // ��������� � ���������
      FUnknownExceptions.Add('<br>');
    end;
    FUnknownExceptions.Add(AException.Message);
  finally
    FUnknownExceptionsCS.EndWrite;
  end;
end;

function TDBMS_Provider.SQLDateTimeToDBValue(const ADateTime: TDateTime): TDBMS_String;
begin
  if (FConnection<>nil) and (FConnection.GetCheckedEngineType=et_MSSQL) then
    Result := DBMSStrToDB(FormatDateTime(c_DateTimeToDBFormat_MSSQL, ADateTime, FFormatSettings))
  else
    Result := c_SQL_DateTime_Literal_Prefix[FConnection.GetCheckedEngineType] +
              DBMSStrToDB(FormatDateTime(c_DateTimeToDBFormat_Common, ADateTime, FFormatSettings));
end;

function TDBMS_Provider.TryToObtainVerByTile(
  const AExclusively: Boolean;
  var ARequestedVersionFound: Boolean;
  const AIdContentType: SmallInt;
  var AVersionAutodetected: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  AReqVersionPtr: PVersionAA
): Byte;
var
  VExifAttr: PByte;
  VLen: DWORD;
  VNeedFindVersion: Boolean;
begin
  // ������� ��������� ���������� ������
  // ��� ����� �������� (� ����������� �� ��������� ������)
  // ���� ��� ��� ������� ����
  if (c_Tile_Parser_None=FDBMS_Service_Info.new_ver_by_tile) then begin
    // ��������� ������ - ������ �� �������
    Result := ETS_RESULT_OK;
    Exit;
  end else if (0=Length(AReqVersionPtr^.ver_value)) then begin
    // ��������� ������ ������
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_EMPTY) = 0) then begin
      // ��� ������ ������ ������ ������ ��������
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end else if ARequestedVersionFound then begin
    // ����������� ������ �������
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_KNOWN) = 0) then begin
      // ��� ��������� ������ ������ ������ ��������
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end else begin
    // ����������� ������ �� �������
    if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_PARSE_UNKNOWN) = 0) then begin
      // ��� ����������� ������ ������ ������ ��������
      Result := ETS_RESULT_OK;
      Exit;
    end;
  end;

  VNeedFindVersion := FALSE;
  
  case FDBMS_Service_Info.new_ver_by_tile of
    // ������ ��� ��� ������ GE - ����� ���� �� �����
    (*
    c_Tile_Parser_Exif_GE: begin
      // ������ ���� ��� jpeg � ������ �� ���� ��������� (������ ��� ������ ���)
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, TRUE, $0000, VExifAttr, VLen) then begin
        Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      Result := ParseExifForGE(
        VExifAttr,
        VLen,
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
    *)
    
    c_Tile_Parser_Exif_NMC_Unique, c_Tile_Parser_Exif_NMC_Latest: begin
      // ������ ���� ��� jpeg � ������ �� ���� EXIF ($9286=UserComment)
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE, $9286, VExifAttr, VLen) then begin
        // � ��� ����� ����� ���� �������� ���� ������, �������� ���� ������� ��������
        if ((FDBMS_Service_Info.tile_save_mode and ETS_TSM_ALLOW_NO_EXIF) <> 0) then
          Result := ETS_RESULT_OK
        else
          Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      // ����� ���� EXIF ������� - ���������� �� ���� ��������� ������ (����� id_ver)
      Result := ParseExifForNMC(
        VExifAttr,
        VLen,
        // ������ ��������� ������ ���� ��� ������� � �� ������
        ARequestedVersionFound and (0<Length(AReqVersionPtr^.ver_value)),
        AReqVersionPtr^.ver_value,
        // ������� ��� ���� ����� ���������� ������������� ������ �����
        (c_Tile_Parser_Exif_NMC_Unique=FDBMS_Service_Info.new_ver_by_tile),
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
      AVersionAutodetected := TRUE;
    end;

    (*
    c_Tile_Parser_Exif_DG_Catalog: begin
      // ������ ��� �������� DigitalGlobe - ����� ������ �� NMC
      if not FindExifInJpeg(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize, FALSE, $9286, VExifAttr, VLen) then begin
        Result := ETS_RESULT_INVALID_EXIF;
        Exit;
      end;
      // ����� ���� EXIF ������� - ���������� �� ���� ��������� ������ (����� id_ver)
      Result := ParseExifUserComment(
        VExifAttr,
        VLen,
        ARequestedVersionFound,
        AReqVersionPtr^.ver_value,
        VNeedFindVersion,
        AReqVersionPtr
      );
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
    *)

    else begin
      // ����������� �������� - ���� ��� ����� ��������
      Result := ETS_RESULT_UNKNOWN_VERBYTILE;
      Exit;
    end;
  end;

  // ���� ������ ���������� - ���� �������
  if (Result=ETS_RESULT_OK) then
  if VNeedFindVersion then begin
    ARequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AReqVersionPtr^.ver_value),
      AReqVersionPtr
    );
  end;


end;

function TDBMS_Provider.UpdateServiceVerComp(
  const ANewVerCompMode: AnsiChar;
  out AErrorText: String
  ): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := FConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  VSQLText := 'UPDATE ' + FConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET id_ver_comp=' + DBMSStrToDB(ANewVerCompMode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    FConnection.ExecuteDirectSQL(VSQLText);
    // success
    FStatusBuffer^.id_ver_comp := ANewVerCompMode;
    FDBMS_Service_Info.id_ver_comp := ANewVerCompMode;
  except
    on E: Exception do begin
      AErrorText := E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateTileLoadMode(
  const ANewTLMFlag: Byte;
  const AEnabled: Boolean;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := FConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // ���� ���� � �� �� ��������� - � ������ �� ����� ���� ������ ��������
  if AEnabled then
    FStatusBuffer^.tile_load_mode     := FStatusBuffer^.tile_load_mode or ANewTLMFlag
  else
    FStatusBuffer^.tile_load_mode     := FStatusBuffer^.tile_load_mode and not ANewTLMFlag;

  FDBMS_Service_Info.tile_load_mode := FStatusBuffer^.tile_load_mode;

  // �������� ������
  VSQLText := 'UPDATE ' + FConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET tile_load_mode='  + IntToStr(FStatusBuffer^.tile_load_mode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    FConnection.ExecuteDirectSQL(VSQLText);
  except
    on E: Exception do begin
      AErrorText := 'Failed to store new value in database' + '<br>' + E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateTileSaveMode(
  const ANewTSMFlag: Byte;
  const AEnabled: Boolean;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := FConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // ���� ���� � �� �� ��������� - � ������ �� ����� ���� ������ ��������
  if AEnabled then
    FStatusBuffer^.tile_save_mode     := FStatusBuffer^.tile_save_mode or ANewTSMFlag
  else
    FStatusBuffer^.tile_save_mode     := FStatusBuffer^.tile_save_mode and not ANewTSMFlag;

  FDBMS_Service_Info.tile_save_mode := FStatusBuffer^.tile_save_mode;

  // �������� ������
  VSQLText := 'UPDATE ' + FConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET tile_save_mode='  + IntToStr(FStatusBuffer^.tile_save_mode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    FConnection.ExecuteDirectSQL(VSQLText);
  except
    on E: Exception do begin
      AErrorText := 'Failed to store new value in database' + '<br>' + E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.UpdateVerByTileMode(
  const ANewVerByTileMode: SmallInt;
  out AErrorText: String
): Byte;
var
  VSQLText: TDBMS_String;
begin
  AErrorText := '';
  Result := FConnection.EnsureConnected(FALSE, nil);
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // �������� ������
  VSQLText := 'UPDATE ' + FConnection.ForcedSchemaPrefix + Z_SERVICE +
                ' SET new_ver_by_tile=' + IntToStr(ANewVerByTileMode) +
              ' WHERE service_code=' + DBMSStrToDB(InternalGetServiceNameByDB);

  try
    FConnection.ExecuteDirectSQL(VSQLText);
    // ��� ������ �������������� ����������������
    // ��� � ������������� ����� ��������� ������������ ��������� �� ������ ������ ������
    FStatusBuffer^.new_ver_by_tile := ANewVerByTileMode;
    FDBMS_Service_Info.new_ver_by_tile := ANewVerByTileMode;
  except
    on E: Exception do begin
      AErrorText := E.Message;
      Result :=  ETS_RESULT_PROVIDER_EXCEPTION;
    end;
  end;
end;

function TDBMS_Provider.VersionExistsInDBWithIdVer(const AIdVersion: SmallInt): Boolean;
var
  VDataset: TDBMS_Dataset;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      // �������� ������������� ��������� ������ (�� ��������������) ��� �������� �������
      VDataset.OpenSQL('SELECT id_ver FROM ' + FConnection.ForcedSchemaPrefix + c_Prefix_Versions + InternalGetServiceNameByDB +
                       ' WHERE id_ver=' + IntToStr(AIdVersion));
      Result := (not VDataset.IsEmpty) and (not VDataset.FieldByName('id_ver').IsNull);
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

end.
