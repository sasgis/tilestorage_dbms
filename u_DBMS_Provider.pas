unit u_DBMS_Provider;

interface

uses
  Types,
  Windows,
  SysUtils,
  Classes,
  DB,
  t_SQL_types,
  t_ETS_Tiles,
  t_ETS_Path,
  t_ETS_Provider,
  t_DBMS_version,
  t_DBMS_contenttype,
  t_DBMS_service,
  t_DBMS_Template,
  i_DBMS_Provider,
  u_DBMS_Connect,
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
  private
    // common work
    procedure DoBeginWork(const AExclusively: Boolean);
    procedure DoEndWork(const AExclusively: Boolean);
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
    function InternalGetServiceNameByDB: WideString;
    // ���������� ��� �������, ������������ � ����� (�������)
    function InternalGetServiceNameByHost: WideString;

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
    ): PAnsiChar;
    function GetVersionWideString(
      const Aid_ver: SmallInt;
      const AExclusively: Boolean
    ): WideString;

    // for cached contenttype
    function GetContentTypeAnsiPointer(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): PAnsiChar;
    function GetContentTypeWideString(
      const Aid_contenttype: SmallInt;
      const AExclusively: Boolean
    ): WideString;

  private
    function SQLDateTimeToDBValue(const ADateTime: TDateTime): WideString;

    function CreateAllBaseTablesFromScript: Byte;
    
    // �������������� �������� ������ � ������� ������� (����������� ������� � ��)
    function AutoCreateServiceRecord(const AExclusively: Boolean): Byte;

    function AutoCreateServiceVersion(
      const AExclusively: Boolean;
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AReqVersionPtr: PVersionAA;
      out ARequestedVersionFound: Boolean
    ): Byte;

    function GetMaxNextVersionInts(const ANewVersionPtr: PVersionAA; const AKeepVerNumber: Boolean): Boolean;

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

    // check if table exists
    function TableExists(const ATableName: WideString): Boolean;

    // create table using SQL commands from special table
    function CreateTableByTemplate(
      const ATemplateName, ATableName: WideString;
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

  private
    procedure AddVersionOrderBy(
      const ASQLParts: PSQLParts;
      const AVerInfoPtr: PVersionAA;
      const ACutOnVersion: Boolean
    );

    // ������������ ������ SQL ��� ��������� (SELECT) ����� ��� ������� TNE
    function GetSQL_SelectTile(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;

    // ������������ ������ SQL ��� ������� (INSERT) � ���������� (UPDATE) ����� ��� ������� TNE
    // � ������ SQL �������� ������ ��������� :tile_body, ��������� ������������� �����
    function GetSQL_InsertUpdateTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult, ATableName: WideString;
      out ANeedTileBodyParam: Boolean
    ): Byte;

    // ������������ ������ SQL ��� �������� (DELETE) ����� ��� ������� TNE
    function GetSQL_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      out ADeleteSQLResult: WideString
    ): Byte;

    // ������������ ������ SQL ��� ��������� (SELECT) ������ ������������ ������ ����� (XYZ)
    function GetSQL_EnumTileVersions(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;


    // ��������� SQL ��� ��������� ������ ������ ��� �������� �������
    function GetSQL_SelectVersions: WideString;

    // ��������� SQL ��� ��������� ������ ����� ������
    function GetSQL_SelectContentTypes: WideString;

    // ��������� SQL ��� ������ ���������� ������� �� ��� �������� ����
    // ���� ���������� ������� ��� ��������� ��� ������������� � �����
    function GetSQL_SelectService_ByHost: WideString;

    // ��������� SQL ��� ������ ���������� ������� �� ��� ����������� ���� (��� � ��)
    function GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): WideString;

    function GetSQL_InsertIntoService(
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
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
  u_DBMS_Template;

{ TDBMS_Provider }

procedure TDBMS_Provider.AddVersionOrderBy(
  const ASQLParts: PSQLParts;
  const AVerInfoPtr: PVersionAA;
  const ACutOnVersion: Boolean
);

  procedure _AddWithoutFieldValue(const AFieldName: WideString);
  begin
    ASQLParts^.SelectSQL := ASQLParts^.SelectSQL + ',w.' + AFieldName;

    ASQLParts^.OrderBySQL := ' order by ' + AFieldName + ' desc';
  
    ASQLParts^.FromSQL := ASQLParts^.FromSQL + ', v_' + InternalGetServiceNameByDB + ' w';

    ASQLParts^.WhereSQL := ASQLParts^.WhereSQL + ' and v.id_ver=w.id_ver';
  end;

  procedure _AddWithFieldValue(const AFieldName, AGreatestValueForDB: WideString);
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
        _AddWithFieldValue('ver_value', WideStrToDB(AVerInfoPtr^.ver_value))
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
  VDataset: TDBMS_Dataset;
  VSQLText: WideString;
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

  VDataset := FConnection.MakePoolDataset;
  try
    // ��������� INSERT (��������� ������ � �������)
    try
      VDataset.SQL.Text := VSQLText;
      VDataset.ExecSQL(TRUE);
      Result := ETS_RESULT_OK;
    except
      // ����������
      Result := ETS_RESULT_INVALID_STRUCTURE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.AutoCreateServiceVersion(
  const AExclusively: Boolean;
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AReqVersionPtr: PVersionAA;
  out ARequestedVersionFound: Boolean
): Byte;
var
  VVerIsInt: Boolean;
  VKeepVerNumber: Boolean;
begin
  // only exclusively
  if (not AExclusively) then begin
    Result := ETS_RESULT_NEED_EXCLUSIVE;
    Exit;
  end;

  // get requested version value
  if (nil=AInsertBuffer^.szVersionIn) then begin
    AReqVersionPtr^.ver_value := '';
  end else if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    AReqVersionPtr^.ver_value := AnsiString(PAnsiChar(AInsertBuffer^.szVersionIn));
  end else begin
    AReqVersionPtr^.ver_value := WideString(PWideChar(AInsertBuffer^.szVersionIn));
  end;

  // check if empty version
  if (0=Length(AReqVersionPtr^.ver_value)) then begin
    // TODO: try to use 0 as id_ver
    if (not VersionExistsInDBWithIdVer(0)) then begin
      MakeEmptyVersionInDB(0, AExclusively);
      ReadVersionsFromDB(AExclusively);
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(0, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;

    // TODO: failed - use min(min-1,-1) as id_ver
    (*
    if (not VersionExistsInDBWithIdVer(-1)) then begin
      MakeEmptyVersionInDB(-1);
      ReadVersionsFromDB;
      ARequestedVersionFound := FVersionList.FindItemByIdVerInternal(-1, AReqVersionPtr);
      if ARequestedVersionFound then begin
        Result := ETS_RESULT_OK;
        Exit;
      end;
    end;
    *)

    // TODO: make correct loop
    ARequestedVersionFound := FALSE;
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  AReqVersionPtr^.ver_date := NowUTC;
  VVerIsInt := TryStrToInt(AReqVersionPtr^.ver_value, AReqVersionPtr^.ver_number);
  // flag to keep ver_number=ver_value even if incrementing id_ver
  VKeepVerNumber := FALSE;

  // TODO:  make it more correctly!!!
  // use Versions flags

  // check ver_comp
  case FDBMS_Service_Info.id_ver_comp of
    TILE_VERSION_COMPARE_ID, TILE_VERSION_COMPARE_NUMBER: begin
      // id_ver=ver_value OR ver_number=ver_value
      VKeepVerNumber := TRUE;
      if VVerIsInt then begin
        // check if allow to treat ver_value as SmallInt
        if (AReqVersionPtr^.ver_number<$8000) and (AReqVersionPtr^.ver_number>=0) then begin
          // allow treat ver_value as SmallInt
          AReqVersionPtr^.id_ver := AReqVersionPtr^.ver_number;
        end else begin
          // cannot treat ver_value as SmallInt
          // TODO: get max+1 for id_ver and reset TILE_VERSION_COMPARE_ID to TILE_VERSION_COMPARE_NUMBER
          GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
        end;
      end else begin
        // ver_value is not INT
        // TODO: get max+1 for id_ver and max+1 for ver_number
        // and reset TILE_VERSION_COMPARE_ID or TILE_VERSION_COMPARE_NUMBER to TILE_VERSION_COMPARE_DATE
        GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
      end;
    end;
    TILE_VERSION_COMPARE_VALUE, TILE_VERSION_COMPARE_DATE: begin
      // TODO: get max+1 for id_ver and max+1 for ver_number
      GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
    end;
    else {TILE_VERSION_COMPARE_NONE:} begin
      // TODO: get max+1 for id_ver and max+1 for ver_number
      GetMaxNextVersionInts(AReqVersionPtr, VKeepVerNumber);
    end;
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
  
  // initialization
  FStatusBuffer := AStatusBuffer;
  FInitFlags := AFlags;
  FHostPointer := AHostPointer;

  FPrimaryContentType := '';

  // sync objects
  FProvSync := MakeSyncRW_Std(Self);
  FGuidesSync := MakeSyncRW_Std(Self);

  FConnection := nil;

  FVersionList := TVersionList.Create;
  FContentTypeList := TContentTypeList.Create;

  InternalProv_Cleanup;
end;

function TDBMS_Provider.CreateAllBaseTablesFromScript: Byte;
var
  VUniqueEngineType: String;
  VSQLTemplates: TDBMS_SQLTemplates_File;
  VDataset: TDBMS_Dataset;
begin
  // ������� ���������� ��� ���� ����
  VUniqueEngineType := c_SQL_Engine_Name[FConnection.GetCheckedEngineType];
  // ���� ����� - ������ ����������� ���� ����, � ������ ��� ������
  if (0=Length(VUniqueEngineType)) then begin
    Result := ETS_RESULT_UNKNOWN_DBMS;
    Exit;
  end;

  // �������� ������ ��� ��������� ��������� ��� ����������� ���� ��
  VDataset := nil;
  VSQLTemplates := TDBMS_SQLTemplates_File.Create(
    VUniqueEngineType,
    FConnection.ForcedSchemaPrefix,
    FConnection.GetInternalParameter(ETS_INTERNAL_APPEND_DIVIDER)
  );
  try
    // �������� �� ��� ����
    VDataset := FConnection.MakePoolDataset;
    Result := VSQLTemplates.ExecuteAllSQLs(VDataset);
  finally
    FConnection.KillPoolDataset(VDataset);
    VSQLTemplates.Free;
  end;
end;

function TDBMS_Provider.CreateTableByTemplate(
  const ATemplateName, ATableName: WideString;
  const ASubstSQLTypes: Boolean
): Byte;
var
  VDataset, VExecSQL: TDBMS_Dataset;
  VSqlTextField: TField;
  VSQLText: WideString;
  //VSQLAnsi: AnsiString;
  Vignore_errors: AnsiChar;
  //VStream: TStream;
  //VMemStream: TMemoryStream;
begin
  // � ����� ��� ������� ������� � ���������
  if (not TableExists(FConnection.ForcedSchemaPrefix+c_Tablename_With_Templates)) then begin
    // �������� ������� �������
    CreateAllBaseTablesFromScript;
    // � ����� ����������?
    if (not TableExists(FConnection.ForcedSchemaPrefix+c_Tablename_With_Templates)) then begin
      // ������ ������ � ��� ��� ������ ������
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // ���� ����������� ������� ��� ���� - �����
  if (TableExists(ATableName)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // ������� ��� ������� SQL ��� CREATE (�������� "C") ��� ������������ �������
  VDataset := FConnection.MakePoolDataset;
  VExecSQL := FConnection.MakePoolDataset;
  try
    VSQLText := 'select * from ' + FConnection.ForcedSchemaPrefix + c_Tablename_With_Templates+
                ' where object_name=' + WideStrToDB(ATemplateName) +
                  ' and object_operation=''C'' and skip_sql=''0'' order by index_sql';
    VDataset.OpenSQL(VSQLText);

    if VDataset.IsEmpty then begin
      // ������ �� ����������� - ������ ��� �������
      Result := ETS_RESULT_NO_TEMPLATE_RECORDS;
      Exit;
    end;

    VDataset.First;
    while (not VDataset.Eof) do begin
      // ����� ����� SQL ��� ���������� � ������� ����������
      Vignore_errors := VDataset.GetAnsiCharFlag('ignore_errors', ETS_UCT_YES);
      VSqlTextField := VDataset.FieldByName('object_sql');
      if (not VSqlTextField.IsNull) then
      try
        (*
        if VSqlTextField.IsBlob then begin
          // CLOB
          VMemStream:=TMemoryStream.Create;
          try
            (VSqlTextField as TBlobField).SaveToStream(VMemStream);
            if (VMemStream.Size=(VSqlTextField as TBlobField).BlobSize) then begin
              SetString(VSQLAnsi, PAnsiChar(VMemStream.Memory), VMemStream.Size);
              VSQLText := VSQLAnsi;
            end else begin
              SetString(VSQLText, PWideChar(VMemStream.Memory), VMemStream.Size);
            end;
          finally
            FreeAndNil(VMemStream);
          end;
        end else begin
          // varchar
          VSQLText := VSqlTextField.AsWideString;
        end;
        *)

        // �������� � ��-������
        VSQLText := VSqlTextField.AsWideString;

        // � ��� ���� ��������� ��� �������
        VSQLText := StringReplace(VSQLText, ATemplateName, ATableName, [rfReplaceAll,rfIgnoreCase]);

        if ASubstSQLTypes then begin
          // ����� ���������� ���������� ����� ���� ����� ��� ������������ �������� XY
          // TODO: �������� numeric �� INT ������ ������
        end;

        // ������
        VExecSQL.SQL.Text := VSQLText;

        // ��������� (��������)
        VExecSQL.ExecSQL(FALSE);

        //(VDataset.FieldByName('object_sql') as TBlobField).BlobSize;

        (*
        VStream := VDataset.CreateBlobStream(VDataset.FieldByName('object_sql'), bmRead);
        try
          VExecSQL.SQL.LoadFromStream(VStream);
          VSQLText := VExecSQL.SQL.Text;
          // � ��� ���� ��������� ��� �������
          // TODO: ����� ���������� ���������� ����� ���� ����� ��� ������������ �������� XY
          VSQLText := StringReplace(VSQLText, ATemplateName, ATableName, [rfReplaceAll,rfIgnoreCase]);
          // ������
          VExecSQL.SQL.Text := VSQLText;
          // ��������� (��������)
          VExecSQL.ExecSQL(TRUE);
        finally
          FreeAndNil(VStream);
        end;
        *)
      except
        if (Vignore_errors=ETS_UCT_NO) then
          raise;
      end;
      // - ���������!
      VDataset.Next;
    end;

    // ��������� ��� ����� ������� ���������
    if (TableExists(ATableName)) then begin
      Result := ETS_RESULT_OK;
      Exit;
    end;
  finally
    FConnection.KillPoolDataset(VExecSQL);
    FConnection.KillPoolDataset(VDataset);
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
  VDataset: TDBMS_Dataset;
  VDeleteSQL: WideString;
begin
  VExclusive := ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - DELETE tile from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // make DELETE statements
      Result := GetSQL_DeleteTile(
        ADeleteBuffer,
        VDeleteSQL
      );
      
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // execute INSERT statement
      try
        VDataset.SQL.Text := VDeleteSQL;
        // exec (do not prepare statement)
        VDataset.ExecSQL(TRUE);
        // done (successfully INSERTed)
        Result := ETS_RESULT_OK;
      except
        // no table - no tile - OK
        Result := ETS_RESULT_OK;
      end;

    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
  VSQLText: WideString;
  VVersionValueW, VVersionCommentW: WideString;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
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
      try
        VDataset.OpenSQL(VSQLText);
      except
        // failed to select - no table - no versions
      end;

      // get values
      if (not VDataset.Active) then begin
        // table not found
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else if VDataset.IsEmpty then begin
        // nothing
        Result := ETS_RESULT_OK;
      end else begin
        // enum all items
        VEnumOut.ResponseCount := VDataset.RecordCount;
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
    DoEndWork(VExclusive);
  end;
end;

function TDBMS_Provider.DBMS_GetTileRectInfo(
  const ACallbackPointer: Pointer;
  const ATileRectInfoIn: PETS_GET_TILE_RECT_IN
): Byte;
(*
var
  VExclusive, VVersionFound: Boolean;
  VDataset: TDBMS_Dataset;
  VEnumOut: TETS_GET_TILE_RECT_OUT;
  VETS_VERSION_W: TETS_VERSION_W;
  VETS_VERSION_A: TETS_VERSION_A;
  VVersionAA: TVersionAA;
  VSQLText: WideString;
  VVersionValueW, VVersionCommentW: WideString;
  *)
begin
  Result := ETS_RESULT_NOT_IMPLEMENTED;
(*
  VExclusive := ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - SELECT id_ver from DB
    VDataset := FConnection.MakePoolDataset;
    try
      // fill full sql text and open
      Result := GetSQL_GetTileRectInfo(ATileRectInfoIn, VExclusive, VSQLText);
      if (ETS_RESULT_OK<>Result) then
        Exit;

      FillChar(VEnumOut, SizeOf(VEnumOut), 0);
      
      if ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
        // Ansi record
        FillChar(VETS_VERSION_A, SizeOf(VETS_VERSION_A), 0);
        VEnumOut.ResponseValue := @VETS_VERSION_A;
      end else begin
        // Wide record
        FillChar(VETS_VERSION_W, SizeOf(VETS_VERSION_W), 0);
        VEnumOut.ResponseValue := @VETS_VERSION_W;
      end;

      // open sql
      try
        VDataset.OpenSQL(VSQLText);
      except
        // failed to select - no table - no versions
      end;

      // get values
      if (not VDataset.Active) then begin
        // table not found
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else if VDataset.IsEmpty then begin
        // nothing
        Result := ETS_RESULT_OK;
      end else begin
        // enum all items
        VEnumOut.ResponseCount := VDataset.RecordCount;
        VDataset.First;
        while (not VDataset.Eof) do begin
          // find selected version
          VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);

          if (not VVersionFound) then begin
            // try to refresh versions
            ReadVersionsFromDB;
            VVersionFound := FVersionList.FindItemByIdVerInternal(VDataset.FieldByName('id_ver').AsInteger, @VVersionAA);
          end;

          if (not VVersionFound) then begin
            // OMG WTF
            VVersionAA.id_ver := VDataset.FieldByName('id_ver').AsInteger;
            VVersionAA.ver_value := '';
            VVersionAA.ver_comment := '';
          end;

          // make params for callback
          if ((ATileRectInfoIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
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
          Result := TETS_GetTileRectInfo_Callback(FHostCallbacks[ETS_INFOCLASS_GetTileRectInfo_Callback])(
            FHostPointer,
            ACallbackPointer,
            ATileRectInfoIn,
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
    DoEndWork(VExclusive);
  end;
*)
end;

function TDBMS_Provider.DBMS_InsertTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean
): Byte;
var
  VExclusive: Boolean;
  VDataset: TDBMS_Dataset;
  VInsertSQL, VUpdateSQL, VTableName: WideString;
  VParam: TParam;
  VNeedUpdate: Boolean;
  VNeedTileBodyParam: Boolean;
begin
  VExclusive := ((AInsertBuffer^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
  try
    // connect (if not connected)
    Result := InternalProv_Connect(VExclusive);

    if (ETS_RESULT_OK<>Result) then
      Exit;

    // if connected - INSERT tile to DB
    VDataset := FConnection.MakePoolDataset;
    try
      VNeedUpdate := FALSE;
      
      // ������� ��������� INSERT � UPDATE
      Result := GetSQL_InsertUpdateTile(
        AInsertBuffer,
        AForceTNE,
        VExclusive,
        VInsertSQL,
        VUpdateSQL,
        VTableName,
        VNeedTileBodyParam
      );
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // �������� INSERT
      try
        VDataset.SQL.Text := VInsertSQL;
        if VNeedTileBodyParam then begin
          // ������� �������� (��� BLOB)
          VParam := VDataset.Params.FindParam('tile_body');
          if (VParam<>nil) then begin
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;
        // ��������� INSERT (���� ��� VNeedTileBodyParam - �� �������� ��� "����������")
        VDataset.ExecSQL(not VNeedTileBodyParam);
        // ������ (���������!)
        Result := ETS_RESULT_OK;
      except
        // ���������� �� �������� ����� ������
        on E: Exception do begin
          // ���������, ����� �� ���� �������
          if (not TableExists(VTableName)) then begin
            // ������� ������� ������� �� �������
            CreateTableByTemplate(c_Templated_RealTiles, VTableName, TRUE);
            // ��������� ������������� �������
            if (not TableExists(VTableName)) then begin
              // �� ������� ���� ������� - �����
              Result := ETS_RESULT_TILE_TABLE_NOT_FOUND;
              Exit;
            end;
          end;
          // ��������� INSERT
          try
            VDataset.ExecSQL(not VNeedTileBodyParam);
            Result := ETS_RESULT_OK;
          except
            VNeedUpdate := TRUE;
          end;
        end;
      end;

      if VNeedUpdate then begin
        // ������� ��������� UPDATE
        VDataset.SQL.Text := VUpdateSQL;
        if VNeedTileBodyParam then begin
          // ������� �������� (��� BLOB)
          VParam := VDataset.Params.FindParam('tile_body');
          if (VParam<>nil) then begin
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;
        // ��������� UPDATE
        try
          // (���� ��� VNeedTileBodyParam - �� �������� ��� "����������")
          VDataset.ExecSQL(not VNeedTileBodyParam);
          // ������ (���������!)
          Result := ETS_RESULT_OK;
        except
          // ����� ������ ���������, ��� ��� ������������� �� �����������
          Result := ETS_RESULT_INVALID_STRUCTURE;
        end;
      end;
    finally
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
  VSQLText, VVersionW, VContentTypeW: WideString;
begin
  VExclusive := ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusive);
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
      try
        VDataset.OpenSQL(VSQLText);
      except
        // failed to select - no table - tile not found
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
          VStream := VDataset.CreateBlobStream(VDataset.FieldByName('tile_body'), bmRead);
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
      VStream.Free;
      FConnection.KillPoolDataset(VDataset);
    end;
  finally
    DoEndWork(VExclusive);
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
begin
  VExclusively := ((AFlags and ETS_ROI_EXCLUSIVELY) <> 0);

  DoBeginWork(VExclusively);
  try
    if (nil<>FConnection) then begin
      FConnection.CompactPool;
    end;
  finally
    DoEndWork(VExclusively);
  end;

  Result := ETS_RESULT_OK;
end;

destructor TDBMS_Provider.Destroy;
begin
  DoBeginWork(TRUE);
  try
    InternalProv_Disconnect;
  finally
    DoEndWork(TRUE);
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
  
  inherited;
end;

procedure TDBMS_Provider.DoBeginWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FProvSync.BeginWrite
  else
    FProvSync.BeginRead;
end;

procedure TDBMS_Provider.DoEndWork(const AExclusively: Boolean);
begin
  if AExclusively then
    FProvSync.EndWrite
  else
    FProvSync.EndRead;
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
  VSQLText: WideString;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      VSQLText := 'select max(id_ver) as id_ver';
      if (not AKeepVerNumber) then begin
        // get new value for ver_number too
        VSQLText := VSQLText + ', max(ver_number) as ver_number';
      end;
      VSQLText := VSQLText + ' from ' + FConnection.ForcedSchemaPrefix + 'v_' + InternalGetServiceNameByDB;
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

function TDBMS_Provider.GetSQL_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  out ADeleteSQLResult: WideString
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

  // ���� �� ������ ���������� ������ - ����� ������
  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // ��������� VSQLTile
  Result := InternalCalcSQLTile(ADeleteBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // �������� DELETE
  ADeleteSQLResult := 'delete from ' + FConnection.ForcedSchemaPrefix + VSQLTile.TileTableName +
                      ' where x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);  
end;

function TDBMS_Provider.GetSQL_EnumTileVersions(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: WideString
): Byte;
var
  VSQLTile: TSQLTile;
  VSQLParts: TSQLParts;
begin
  // %DIV%%ZOOM%%HEAD%_%SERVICE% - table with tiles
  // u_%SERVICE% - table with common tiles

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
  VSQLParts.FromSQL := FConnection.ForcedSchemaPrefix + VSQLTile.TileTableName + ' v';
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

function TDBMS_Provider.GetSQL_InsertIntoService(
  const AExclusively: Boolean;
  out ASQLTextResult: WideString
): Byte;
var
  VDataset: TDBMS_Dataset;
  VNewIdService: SmallInt;
  VNewIdContentType: SmallInt;
  VNewServiceCode: AnsiString;
  VSQLText: WideString;
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
      VDataset.OpenSQL('select max(id_service) as id_service from ' + FConnection.ForcedSchemaPrefix + 't_service');
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
    ASQLTextResult := 'insert into ' + FConnection.ForcedSchemaPrefix + 't_service(id_service,service_code,service_name,id_contenttype) values (' +
                            IntToStr(VNewIdService) + ',' +
                            WideStrToDB(VNewServiceCode) + ',' +
                            WideStrToDB(InternalGetServiceNameByHost) + ',' +
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
  out AInsertSQLResult, AUpdateSQLResult, ATableName: WideString;
  out ANeedTileBodyParam: Boolean
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound, VRequestedContentTypeFound: Boolean;
  VIdContentType: SmallInt;
  VReqVersion: TVersionAA;
  VUseCommonTiles: Boolean;
  VNewTileSize: LongInt;
  VNewTileBody: WideString;
begin
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

  if (not VRequestedVersionFound) then begin
    // ���� ����� ������ ��� - ������� ������� � �������������
    Result := AutoCreateServiceVersion(
      AExclusively,
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
    // TODO: ������, �� ������� ������ ���� ����� ����� ������ ������������ ���� �����
    // � ������ ����� �������� ContentType ����������� ������ ������
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VIdContentType);
  end;

  if (not VRequestedContentTypeFound) then begin
    Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
    Exit;
  end;

  // ��������� VSQLTile
  Result := InternalCalcSQLTile(AInsertBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // �������� ����� ��� ������� ��� ������ (��� ��������� ������)
  // ����� ������� ����� � ��������� �����
  ATableName := FConnection.ForcedSchemaPrefix + VSQLTile.TileTableName;

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
    // TODO: ������� �������� ������� �� ������ �������
    AUpdateSQLResult := ''; // ', tile_body=null';
    AInsertSQLResult := '';
    VNewTileBody := '';
    ANeedTileBodyParam := FALSE;
  end else if VUseCommonTiles then begin
    // ����� ������������ ���� - �������� ������ �� ����
    AUpdateSQLResult := ', tile_body=null';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',null';
    ANeedTileBodyParam := FALSE;
  end else begin
    // ������� ���� (�� ������ TNE � �� ����� ������������)
    AUpdateSQLResult := ', tile_body=:tile_body';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',:tile_body';
    ANeedTileBodyParam := TRUE;
  end;

  // ������ ��������� INSERT
  AInsertSQLResult := 'insert into ' + ATableName + ' (x,y,id_ver,id_contenttype,load_date,tile_size' + AInsertSQLResult + ') values (' +
                      IntToStr(VSQLTile.XYLowerToID.X) + ',' +
                      IntToStr(VSQLTile.XYLowerToID.Y) + ',' +
                      IntToStr(VReqVersion.id_ver) + ',' +
                      IntToStr(VIdContentType) + ',' +
                      SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) + ',' +
                      IntToStr(VNewTileSize) + VNewTileBody + ')';

  // ������ ��������� UPDATE
  AUpdateSQLResult := 'update ' + ATableName + ' set id_contenttype=' + IntToStr(VIdContentType) +
                           ', load_date=' + SQLDateTimeToDBValue(AInsertBuffer^.dtLoadedUTC) +
                           ', tile_size=' + IntToStr(VNewTileSize) +
                           AUpdateSQLResult +
                      ' where x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);
end;

function TDBMS_Provider.GetSQL_SelectContentTypes: WideString;
begin
  Result := 'select * from ' + FConnection.ForcedSchemaPrefix + 'c_contenttype';
end;

function TDBMS_Provider.GetSQL_SelectService_ByCode(const AServiceCode: AnsiString): WideString;
begin
  Result := 'select * from ' + FConnection.ForcedSchemaPrefix + 't_service where service_code='+WideStrToDB(AServiceCode);
end;

function TDBMS_Provider.GetSQL_SelectService_ByHost: WideString;
begin
  Result := 'select * from ' + FConnection.ForcedSchemaPrefix + 't_service where service_name='+WideStrToDB(InternalGetServiceNameByHost);
end;

function TDBMS_Provider.GetSQL_SelectTile(
  const ASelectBufferIn: PETS_SELECT_TILE_IN;
  const AExclusively: Boolean;
  out ASQLTextResult: WideString
): Byte;
var
  VSQLTile: TSQLTile;
  VSQLParts: TSQLParts;
  VReqVersion: TVersionAA;
begin
  // %DIV%%ZOOM%%HEAD%_%SERVICE% - table with tiles
  // u_%SERVICE% - table with common tiles

  // ��������� VSQLTile �� ���������� ���������
  Result := InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );
  if (Result<>ETS_RESULT_OK) then
    Exit;

  (*
  // ���� ������� ��� ��� - �� ������� � �������, � ����� ������ (�� ����� ����� ���)
  // ������ � ������������ ������
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := ETS_RESULT_UNKNOWN_TILE_TABLE;
      Exit;
      {
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // �������� ���������� �������� ����� �������
      if (Result<>ETS_RESULT_OK) then
        Exit;
      }
    end;
  end;
  *)

  // ���������
  VSQLParts.SelectSQL := 'select v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := VSQLTile.TileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // �������� SELECT

  // ���� �� ��������� ����� ������������ �����
  if (ETS_UCT_NO=FDBMS_Service_Info.use_common_tiles) then begin
    // ���
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.tile_size,v.tile_body';
  end else begin
    // ��
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'isnull(k.common_size,v.tile_size) as tile_size,isnull(k.common_body,v.tile_body) as tile_body';
    VSQLParts.FromSQL := VSQLParts.FromSQL + ' left outer join  u_' + InternalGetServiceNameByDB + ' k on v.tile_size<0 and v.tile_size=-k.id_common_tile and v.id_contenttype=k.id_common_type';
  end;

  // �������� FROM, WHERE � ORDER BY

  // ��������� ����������� ������
  if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    // ��� Ansi
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ASelectBufferIn^.szVersionIn),
      @VReqVersion
    );
  end else begin
    // ��� Wide
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ASelectBufferIn^.szVersionIn),
      @VReqVersion
    );
  end;

  // ���� �� ������ ���������� ������ - ����� ������
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

  // �������� �� ������
  ASQLTextResult := VSQLParts.SelectSQL +
                  ' from ' + VSQLParts.FromSQL +
                 ' where v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                   ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                    VSQLParts.WhereSQL +
                    VSQLParts.OrderBySQL;
end;

function TDBMS_Provider.GetSQL_SelectVersions: WideString;
begin
  // select * from v_%SERVICE%
  Result := 'select * from ' + FConnection.ForcedSchemaPrefix + 'v_'+InternalGetServiceNameByDB;
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

function TDBMS_Provider.InternalCalcSQLTile(
  const AXYZ: PTILE_ID_XYZ;
  const ASQLTile: PSQLTile
): Byte;
begin
  // ��������� ��� (�� 1 �� 24)
  ASQLTile^.Zoom := AXYZ^.z;
  // ������ ������ ����� ������� ��� ������
  ASQLTile^.TileTableName := FDBMS_Service_Info.id_div_mode + ASQLTile^.ZoomToTableNameChar;

  // ���������� ����� ����
  case FDBMS_Service_Info.id_div_mode of
    TILE_DIV_1024..TILE_DIV_32768: begin
      // ������� �� ��������
      ASQLTile^.XYMaskWidth := 10 + Ord(FDBMS_Service_Info.id_div_mode) - Ord(TILE_DIV_1024);
    end;
    else {TILE_DIV_NONE} begin
      // �� ������� �� ��������
      ASQLTile^.XYMaskWidth := 0;
    end;
  end;

  // ����� XY �� "�������" � "������" �����
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  // ��������� "�������" ����� XY � ���������� ��� ������� � ����� �������
  ASQLTile^.TileTableName := ASQLTile^.TileTableName + ASQLTile^.GetXYUpperInfix + '_' + InternalGetServiceNameByDB;

  Result := ETS_RESULT_OK;
end;

procedure TDBMS_Provider.InternalDivideXY(
  const AXY: TPoint;
  const ASQLTile: PSQLTile
);
var
  VMask: LongInt;
begin
  if (0=ASQLTile^.XYMaskWidth) then begin
    // do not divide
    ASQLTile^.XYUpperToTable.X := 0;
    ASQLTile^.XYUpperToTable.Y := 0;
    ASQLTile^.XYLowerToID := AXY;
  end else begin
    // divide
    VMask := (1 shl ASQLTile^.XYMaskWidth)-1;
    ASQLTile^.XYUpperToTable.X := AXY.X shr ASQLTile^.XYMaskWidth;
    ASQLTile^.XYUpperToTable.Y := AXY.Y shr ASQLTile^.XYMaskWidth;
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

function TDBMS_Provider.InternalGetServiceNameByDB: WideString;
begin
  Result := FDBMS_Service_Code;
end;

function TDBMS_Provider.InternalGetServiceNameByHost: WideString;
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
  end;
end;

function TDBMS_Provider.InternalProv_Connect(const AExclusively: Boolean): Byte;
begin
  if (not FCompleted) then begin
    Result := ETS_RESULT_INCOMPLETE;
    Exit;
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
  Result := FConnection.EnsureConnected(AExclusively);

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
        MakeEmptyVersionInDB(0, AExclusively);
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
  VSelectCurrentServiceSQL: WideString;
begin
  FillChar(FDBMS_Service_Info, SizeOf(FDBMS_Service_Info), 0);
  VDataset := FConnection.MakePoolDataset;
  try
    // ������ �������� �������
    VSelectCurrentServiceSQL := GetSQL_SelectService_ByHost;

    // ����� ���� � ������� �������
    // ������ �� ���������� ��� ������������� �������� ����������� ���� �������
    try
      VDataset.OpenSQL(VSelectCurrentServiceSQL);
    except
      // ���������� ��� �������� �������� - ������ ��� �������
    end;

    if (not VDataset.Active) then begin
      // �� ��������� - ������ ������� ������� �� �������
      CreateAllBaseTablesFromScript;
      // ���������������
      try
        VDataset.OpenSQL(VSelectCurrentServiceSQL);
      except
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
  VGlobalStorageIdentifier, VServiceName: WideString;
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
  VNewVersion.ver_date := 0; //NowUTC;
  VNewVersion.ver_number := AIdVersion;
  VNewVersion.ver_comment := '';
  Result := MakePtrVersionInDB(@VNewVersion, AExclusively);
end;

function TDBMS_Provider.MakePtrVersionInDB(
  const ANewVersionPtr: PVersionAA;
  const AExclusively: Boolean
): Boolean;
var
  VDataset: TDBMS_Dataset;
  VVersionsTableName: String;
begin
  Assert(AExclusively);

  VDataset := FConnection.MakePoolDataset;
  try
    VVersionsTableName := FConnection.ForcedSchemaPrefix + 'v_' + InternalGetServiceNameByDB;

    // ��������, � ���� �� �������� � �������� �������
    if (not TableExists(VVersionsTableName)) then
    try
      // ��������
      CreateTableByTemplate(c_Templated_Versions, VVersionsTableName, FALSE);
    except
    end;

    // ��� ��������� ������������, ����� ������� ��� ������� ���������

    // �������� SQL ��� ������� ������ � ����� ������
    VDataset.SQL.Text := 'insert into ' + VVersionsTableName +
              '(id_ver,ver_value,ver_date,ver_number) values (' +
              IntToStr(ANewVersionPtr^.id_ver) + ',' +
              WideStrToDB(ANewVersionPtr^.ver_value) + ',' +
              SQLDateTimeToDBValue(ANewVersionPtr^.ver_date) + ',' +
              IntToStr(ANewVersionPtr^.ver_number) + ')';
    try
      // �������� (��������)
      VDataset.ExecSQL(TRUE);
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
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
        FContentTypeList.SetCapacity(VDataset.RecordCount);
        // enum
        VDataset.First;
        while (not VDataset.Eof) do begin
          // add record to array
          VNewItem.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
          VNewItem.contenttype_text := VDataset.FieldByName('contenttype_text').AsString;
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
        FVersionList.SetCapacity(VDataset.RecordCount);
        // �����������
        VDataset.First;
        while (not VDataset.Eof) do begin
          // ��������� ��������
          VNewItem.id_ver := VDataset.FieldByName('id_ver').AsInteger;
          VNewItem.ver_value := VDataset.FieldByName('ver_value').AsString;
          VNewItem.ver_date := VDataset.FieldByName('ver_date').AsDateTime;
          VNewItem.ver_number := VDataset.FieldByName('ver_number').AsInteger;
          VNewItem.ver_comment := VDataset.FieldByName('ver_comment').AsString;
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

function TDBMS_Provider.SQLDateTimeToDBValue(const ADateTime: TDateTime): WideString;
begin
  Result := c_SQL_DateTime_Literal_Prefix[FConnection.GetCheckedEngineType] +
            WideStrToDB(FormatDateTime(c_DateTimeToDBFormat, ADateTime, FFormatSettings));
end;

function TDBMS_Provider.TableExists(const ATableName: WideString): Boolean;
var
  VDataset: TDBMS_Dataset;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      // ������� ������������� �������� ������������� � ����������� �������
      VDataset.OpenSQL('select 1 from ' + ATableName + ' where 0=1');
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
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
      VDataset.OpenSQL('select id_ver from ' + FConnection.ForcedSchemaPrefix + 'v_' + InternalGetServiceNameByDB + ' where id_ver=' + IntToStr(AIdVersion));
      Result := (not VDataset.IsEmpty) and (not VDataset.FieldByName('id_ver').IsNull);
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

end.
