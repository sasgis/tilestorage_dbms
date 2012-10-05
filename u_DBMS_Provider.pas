unit u_DBMS_Provider;

interface

uses
  Types,
  SysUtils,
  Classes,
  DB,
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
    
  private
    // common work
    procedure DoBeginWork(const AExclusively: Boolean);
    procedure DoEndWork(const AExclusively: Boolean);
    // work with guides
    procedure GuidesBeginWork(const AExclusively: Boolean);
    procedure GuidesEndWork(const AExclusively: Boolean);

    procedure ReadVersionsFromDB;
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

    function InternalGetServiceNameByDB: WideString;
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
      const ATemplateName, ATableName: WideString
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

    // get SQL text for SELECT (tile or tne)
    function GetSQL_SelectTile(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;

    // get SQL text for INSERT or UPDATE tile
    function GetSQL_InsertTile(
      const AInsertBuffer: PETS_INSERT_TILE_IN;
      const AForceTNE: Boolean;
      const AExclusively: Boolean;
      out AInsertSQLResult, AUpdateSQLResult, ATableName: WideString
    ): Byte;

    // get SQL text for DELETE (tile or tne)
    function GetSQL_DeleteTile(
      const ADeleteBuffer: PETS_DELETE_TILE_IN;
      out ADeleteSQLResult: WideString
    ): Byte;

    // get SQL text for SELECT (versions)
    function GetSQL_EnumTileVersions(
      const ASelectBufferIn: PETS_SELECT_TILE_IN;
      const AExclusively: Boolean;
      out ASQLTextResult: WideString
    ): Byte;

    
    // get others
    function GetSQL_SelectVersions: WideString;
    function GetSQL_SelectContentTypes: WideString;
    function GetSQL_SelectService: WideString;
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
        _AddWithFieldValue('ver_date', WideStrToDB(FormatDateTime('c_DateToDBFormat',AVerInfoPtr^.ver_date)))
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

(*
create table v_%SERVICE% (
   id_ver               smallint                       not null,
   ver_value            varchar(50)                    not null,
   ver_date             datetime                       not null,
   ver_number           int                            default 0 not null,
   ver_comment          varchar(255)                   null,
   constraint PK_V_%SERVICE% primary key (id_ver)
)
lock datarows
go
*)
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

function TDBMS_Provider.CreateTableByTemplate(
  const ATemplateName, ATableName: WideString
): Byte;
var
  VSQLTemplates: TDBMS_SQLTemplates_File;
  VDataset, VExecSQL: TDBMS_Dataset;
  VSQLText: WideString;
  Vignore_errors: AnsiChar;
  VStream: TStream;
begin
  if (not TableExists(c_Template_Tablename)) then begin
    // create template table
    VSQLTemplates := TDBMS_SQLTemplates_File.Create;
    VDataset := FConnection.MakePoolDataset;
    try
      VSQLTemplates.ExecuteAllSQLs(VDataset);
    finally
      FConnection.KillPoolDataset(VDataset);
      VSQLTemplates.Free;
    end;

    // not created
    if (not TableExists(c_Template_Tablename)) then begin
      // OMG WTF
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;
  end;

  // if created - done
  if (TableExists(ATableName)) then begin
    Result := ETS_RESULT_OK;
    Exit;
  end;

  // get all SQLs from table with templates
  VDataset := FConnection.MakePoolDataset;
  VExecSQL := FConnection.MakePoolDataset;
  try
    VSQLText := 'select * from ' + c_Template_Tablename +
                ' where object_name=' + WideStrToDB(ATemplateName) +
                  ' and object_operation=''C'' and skip_sql=''0'' order by index_sql';
    VDataset.OpenSQL(VSQLText);

    if VDataset.IsEmpty then begin
      Result := ETS_RESULT_INVALID_STRUCTURE;
      Exit;
    end;

    VDataset.First;
    while (not VDataset.Eof) do begin
      // TODO: get SQL text and replace tablename
      Vignore_errors := VDataset.GetAnsiCharFlag('ignore_errors', ETS_UCT_YES);
      if (not VDataset.FieldByName('object_sql').IsNull) then
      try
        VStream := VDataset.CreateBlobStream(VDataset.FieldByName('object_sql'), bmRead);
        try
          VExecSQL.SQL.LoadFromStream(VStream);
          VSQLText := VExecSQL.SQL.Text;
          VSQLText := StringReplace(VSQLText, ATemplateName, ATableName, [rfReplaceAll,rfIgnoreCase]);
          VExecSQL.SQL.Text := VSQLText;
          // execute SQL command
          VExecSQL.ExecSQL(TRUE);
        finally
          FreeAndNil(VStream);
        end;
      except
        if (Vignore_errors=ETS_UCT_NO) then
          raise;
      end;
      // next SQL command
      VDataset.Next;
    end;

    // check if created
    if (TableExists(ATableName)) then begin
      Result := ETS_RESULT_OK;
      Exit;
    end;
  finally
    FConnection.KillPoolDataset(VExecSQL);
    FConnection.KillPoolDataset(VDataset);
  end;

  // failed
  Result := ETS_RESULT_INVALID_STRUCTURE;
end;

function TDBMS_Provider.DBMS_Complete(const AFlags: LongWord): Byte;
begin
  // TODO: provider is completely initiaized
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
      
      // make INSERT and UPDATE statements
      Result := GetSQL_InsertTile(
        AInsertBuffer,
        AForceTNE,
        VExclusive,
        VInsertSQL,
        VUpdateSQL,
        VTableName
      );
      if (ETS_RESULT_OK<>Result) then
        Exit;

      // execute INSERT statement
      try
        VDataset.SQL.Text := VInsertSQL;
        if (not AForceTNE) then begin
          // parse params (buffer as blob)
          VParam := VDataset.Params.FindParam('tile_body');
          if (VParam<>nil) then begin
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;
        // exec (do not prepare statement for TNE)
        VDataset.ExecSQL(AForceTNE);
        // done (successfully INSERTed)
        Result := ETS_RESULT_OK;
      except
        on E: Exception do begin
          // check table exists
          if (not TableExists(VTableName)) then begin
            // execute create table statement
            CreateTableByTemplate(c_Templated_RealTiles, VTableName);
            // check if failed to create
            if (not TableExists(VTableName)) then begin
              Result := ETS_RESULT_INVALID_STRUCTURE;
              Exit;
            end;
          end;
          // repeat INSERT statement
          try
            // (do not prepare statement for TNE)
            VDataset.ExecSQL(AForceTNE);
            Result := ETS_RESULT_OK;
          except
            VNeedUpdate := TRUE;
          end;
        end;
      end;

      // if need to execute UPDATE statement
      if VNeedUpdate then begin
        VDataset.SQL.Text := VUpdateSQL;
        if (not AForceTNE) then begin
          // parse params (buffer as blob)
          VParam := VDataset.Params.FindParam('tile_body');
          if (VParam<>nil) then begin
            VParam.SetBlobData(AInsertBuffer^.ptTileBuffer, AInsertBuffer^.dwTileSize);
          end;
        end;
        // exec
        try
          // (do not prepare statement for TNE)
          VDataset.ExecSQL(AForceTNE);
          // done (successfully INSERTed)
          Result := ETS_RESULT_OK;
        except
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
        // table not found
        Result := ETS_RESULT_INVALID_STRUCTURE;
      end else if VDataset.IsEmpty then begin
        // nothing
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

function TDBMS_Provider.GetSQL_DeleteTile(
  const ADeleteBuffer: PETS_DELETE_TILE_IN;
  out ADeleteSQLResult: WideString
): Byte;
var
  VSQLTile: TSQLTile;
  VRequestedVersionFound: Boolean;
  VReqVersion: TVersionAA;
begin
  // get version identifier
  if ((ADeleteBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ADeleteBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  // check if no version
  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;

  // parse tile coordinates
  Result := InternalCalcSQLTile(ADeleteBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // make DELETE statement
  ADeleteSQLResult := 'delete from ' + VSQLTile.TileTableName +
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
  //VReqVersion: TVersionAA;
begin
  // %DIV%%ZOOM%%HEAD%_%SERVICE% - table with tiles
  // u_%SERVICE% - table with common tiles

  InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );

  // check if table exists
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // check if failed
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
  end;

  // make SELECT clause
  VSQLParts.SelectSQL := 'select v.id_ver';
  VSQLParts.FromSQL := VSQLTile.TileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // make FROM, WHERE and ORDER BY
  AddVersionOrderBy(@VSQLParts, nil, FALSE);

  // make full SQL
  ASQLTextResult := VSQLParts.SelectSQL + ' from ' + VSQLParts.FromSQL +
                                ' where v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                                  ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) + VSQLParts.WhereSQL + VSQLParts.OrderBySQL;

  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_InsertTile(
  const AInsertBuffer: PETS_INSERT_TILE_IN;
  const AForceTNE: Boolean;
  const AExclusively: Boolean;
  out AInsertSQLResult, AUpdateSQLResult, ATableName: WideString
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
  // get version identifier
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    VRequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end else begin
    VRequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(AInsertBuffer^.szVersionIn),
      @VReqVersion
    );
  end;

  if (not VRequestedVersionFound) then begin
    // no such version - try to create new version here
    // TODO: fill new version params based on service params
  end;

  if (not VRequestedVersionFound) then begin
    Result := ETS_RESULT_UNKNOWN_VERSION;
    Exit;
  end;
  
  // get contenttype identifier
  if ((AInsertBuffer^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_IN) <> 0) then begin
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiContentTypeText(
      PAnsiChar(AInsertBuffer^.szVersionIn),
      VIdContentType
    );
  end else begin
    VRequestedContentTypeFound := FContentTypeList.FindItemByWideContentTypeText(
      PWideChar(AInsertBuffer^.szVersionIn),
      VIdContentType
    );
  end;

  if (not VRequestedContentTypeFound) and AForceTNE then begin
    // if no such contenttype for tne - use primary value
    VRequestedContentTypeFound := FContentTypeList.FindItemByAnsiValueInternal(FPrimaryContentType, VIdContentType);
  end;

  if (not VRequestedContentTypeFound) then begin
    Result := ETS_RESULT_UNKNOWN_CONTENTTYPE;
    Exit;
  end;

  // parse tile coordinates
  Result := InternalCalcSQLTile(AInsertBuffer^.XYZ, @VSQLTile);
  if (Result<>ETS_RESULT_OK) then
    Exit;

  // keep tablename
  ATableName := VSQLTile.TileTableName;

  if AForceTNE then begin
    // do not check common tiles for TNE
    VUseCommonTiles := FALSE;
    VNewTileSize := 0;
  end else begin
    // check if tile is in common tiles
    VUseCommonTiles := CheckTileInCommonTiles(
      AInsertBuffer^.ptTileBuffer,
      AInsertBuffer^.dwTileSize,
      VNewTileSize
    );
  end;

  if AForceTNE then begin
    // TNE - no tile body at all (neither field name nor field value)
    AUpdateSQLResult := '';
    AInsertSQLResult := '';
    VNewTileBody := '';
  end else if VUseCommonTiles then begin
    // set link to common tile record
    AUpdateSQLResult := ', tile_body=null';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',null';
  end else begin
    // set as is (neither common tile nor TNE)
    AUpdateSQLResult := ', tile_body=:tile_body';
    AInsertSQLResult := ',tile_body';
    VNewTileBody := ',:tile_body';
  end;

  // make INSERT statement
  AInsertSQLResult := 'insert into ' + ATableName + ' (x,y,id_ver,id_contenttype,load_date,tile_size' + AInsertSQLResult + ') values (' +
                      IntToStr(VSQLTile.XYLowerToID.X) + ',' +
                      IntToStr(VSQLTile.XYLowerToID.Y) + ',' +
                      IntToStr(VReqVersion.id_ver) + ',' +
                      IntToStr(VIdContentType) + ',' +
                      WideStrToDB(FormatDateTime(c_UTCLoadDateTimeToDBFormat,AInsertBuffer^.dtLoadedUTC)) + ',' +
                      IntToStr(VNewTileSize) + VNewTileBody + ')';

  // make UPDATE statement
  AUpdateSQLResult := 'update ' + ATableName + ' set id_contenttype=' + IntToStr(VIdContentType) +
                           ', load_date=' + WideStrToDB(FormatDateTime(c_UTCLoadDateTimeToDBFormat,AInsertBuffer^.dtLoadedUTC)) +
                           ', tile_size=' + IntToStr(VNewTileSize) +
                           AUpdateSQLResult +
                      ' where x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                        ' and y=' + IntToStr(VSQLTile.XYLowerToID.Y) +
                        ' and id_ver=' + IntToStr(VReqVersion.id_ver);
end;

function TDBMS_Provider.GetSQL_SelectContentTypes: WideString;
begin
  Result := 'select * from c_contenttype';
end;

function TDBMS_Provider.GetSQL_SelectService: WideString;
begin
  Result := 'select * from t_service where service_name='+WideStrToDB(InternalGetServiceNameByHost);
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

  InternalCalcSQLTile(
    ASelectBufferIn^.XYZ,
    @VSQLTile
  );

  // check if table exists
  if AExclusively then begin
    if not TableExists(VSQLTile.TileTableName) then begin
      Result := CreateTableByTemplate(c_Templated_RealTiles, VSQLTile.TileTableName);
      // check if failed
      if (Result<>ETS_RESULT_OK) then
        Exit;
    end;
  end;

  VSQLParts.SelectSQL := 'select v.id_ver,v.id_contenttype,v.load_date,';
  VSQLParts.FromSQL := VSQLTile.TileTableName + ' v';
  VSQLParts.WhereSQL := '';
  VSQLParts.OrderBySQL := '';

  // make SELECT clause

  // check if allow to use common tiles
  if (ETS_UCT_NO=FDBMS_Service_Info.use_common_tiles) then begin
    // no common tiles
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'v.tile_size,v.tile_body';
  end else begin
    // with common tiles
    VSQLParts.SelectSQL := VSQLParts.SelectSQL + 'isnull(k.common_size,v.tile_size) as tile_size,isnull(k.common_body,v.tile_body) as tile_body';
    VSQLParts.FromSQL := VSQLParts.FromSQL + ' left outer join  u_' + InternalGetServiceNameByDB + ' k on v.tile_size<0 and v.tile_size=-k.id_common_tile and v.id_contenttype=k.id_common_type';
  end;

  // make FROM, WHERE and ORDER BY

  // get version identifier
  if ((ASelectBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_IN) <> 0) then begin
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByAnsiValue(
      PAnsiChar(ASelectBufferIn^.szVersionIn),
      @VReqVersion
    );
  end else begin
    VSQLParts.RequestedVersionFound := FVersionList.FindItemByWideValue(
      PWideChar(ASelectBufferIn^.szVersionIn),
      @VReqVersion
    );
  end;

  if (VSQLParts.RequestedVersionFound) then begin
    // version found
    if (VReqVersion.id_ver=FVersionList.EmptyVersionIdVer) then begin
      // request with empty version
      if ((FStatusBuffer^.tile_load_mode and ETS_TLM_LAST_VERSION) <> 0) then begin
        // allow last version
        AddVersionOrderBy(@VSQLParts, @VReqVersion, FALSE);
      end else begin
        // use only empty version (without order by)
        VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
      end;
    end else begin
      // non-empty version
      if ((FStatusBuffer^.tile_load_mode and ETS_TLM_PREV_VERSION) <> 0) then begin
        // allow prev version
        AddVersionOrderBy(@VSQLParts, @VReqVersion, TRUE);
        if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) = 0) then begin
          // but no empty version!
          VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver!=' + IntToStr(FVersionList.EmptyVersionIdVer);
        end;
      end else if ((FStatusBuffer^.tile_load_mode and ETS_TLM_WITHOUT_VERSION) <> 0) then begin
        // allow requested version or empty version only
        VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver in (' + IntToStr(VReqVersion.id_ver) + ',' + IntToStr(FVersionList.EmptyVersionIdVer) + ')';
      end else begin
        // allow requested version only
        VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and v.id_ver=' + IntToStr(VReqVersion.id_ver);
      end;
    end;
  end else begin
    // unknown version - force no tile
    VSQLParts.WhereSQL := VSQLParts.WhereSQL + ' and 0=1';
  end;

  // make full SQL
  ASQLTextResult := VSQLParts.SelectSQL + ' from ' + VSQLParts.FromSQL +
                                ' where v.x=' + IntToStr(VSQLTile.XYLowerToID.X) +
                                  ' and v.y=' + IntToStr(VSQLTile.XYLowerToID.Y) + VSQLParts.WhereSQL + VSQLParts.OrderBySQL;

  Result := ETS_RESULT_OK;
end;

function TDBMS_Provider.GetSQL_SelectVersions: WideString;
begin
  // select * from v_%SERVICE%
  Result := 'select * from v_'+InternalGetServiceNameByDB;
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
  // base table prefix
  ASQLTile^.Zoom := AXYZ^.z;
  ASQLTile^.TileTableName := FDBMS_Service_Info.id_div_mode + ASQLTile^.ZoomToTableNameChar;

  // check div_mode
  case FDBMS_Service_Info.id_div_mode of
    TILE_DIV_1024..TILE_DIV_32768: begin
      // divide into tables
      ASQLTile^.XYMaskWidth := 10 + Ord(FDBMS_Service_Info.id_div_mode) - Ord(TILE_DIV_1024);
    end;
    else {TILE_DIV_NONE} begin
      // all-in-one
      ASQLTile^.XYMaskWidth := 0;
    end;
  end;

  // divide XY
  InternalDivideXY(AXYZ^.xy, ASQLTile);

  // add upper part of XY and SERVICE name
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
var
  VDataset: TDBMS_Dataset;
  VNewItem: TContentTypeA;
begin
  // find
  Result := FContentTypeList.FindItemByIdContentType(Aid_contenttype, AContentTypeTextPtr, AContentTypeTextStr);
  if (not Result) then begin
    // not found
    if not AExclusively then
      Exit;
      
    // read from DB
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
    ReadVersionsFromDB;

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

  // try to connect
  Result := FConnection.EnsureConnected(AExclusively);

  // exit on error
  if (ETS_RESULT_OK<>Result) then
    Exit;

  // read params after connect
  if (not FDBMS_Service_OK) then begin
    Result := InternalProv_ReadServiceInfo(AExclusively);
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
begin
  FillChar(FDBMS_Service_Info, SizeOf(FDBMS_Service_Info), 0);
  VDataset := FConnection.MakePoolDataset;
  try
    VDataset.OpenSQL(GetSQL_SelectService);
    if VDataset.IsEmpty then begin
      // no service
      InternalProv_ClearServiceInfo;
      // TODO: autocreate service record
      Result := ETS_RESULT_UNKNOWN_SERVICE;
    end else begin
      // found
      FDBMS_Service_Code := VDataset.FieldByName('service_code').AsString;
      FDBMS_Service_Info.id_service := VDataset.FieldByName('id_service').AsInteger;
      FDBMS_Service_Info.id_contenttype := VDataset.FieldByName('id_contenttype').AsInteger;
      FDBMS_Service_Info.id_ver_comp := VDataset.GetAnsiCharFlag('id_ver_comp', TILE_VERSION_COMPARE_NONE);
      FDBMS_Service_Info.id_div_mode := VDataset.GetAnsiCharFlag('id_div_mode', TILE_DIV_ERROR);
      FDBMS_Service_Info.work_mode := VDataset.GetAnsiCharFlag('work_mode', ETS_SWM_DEFAULT);
      FDBMS_Service_Info.use_common_tiles := VDataset.GetAnsiCharFlag('use_common_tiles', ETS_UCT_NO);
      FDBMS_Service_OK := TRUE;
      Result := ETS_RESULT_OK;
    end;
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
  if (nil = AInfoData) or (AInfoSize < Sizeof(AInfoData^)) then begin
    Result := ETS_RESULT_INVALID_BUFFER_SIZE;
    Exit;
  end;

  if (nil = AInfoData^.szGlobalStorageIdentifier) then begin
    Result := ETS_RESULT_POINTER1_NIL;
    Exit;
  end;

  if (nil = AInfoData^.szServiceName) then begin
    Result := ETS_RESULT_POINTER2_NIL;
    Exit;
  end;

  // get values
  if ((AInfoData^.dwOptionsIn and ETS_ROI_ANSI_SET_INFORMATION) <> 0) then begin
    // AnsiString
    VGlobalStorageIdentifier := AnsiString(PAnsiChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := AnsiString(PAnsiChar(AInfoData^.szServiceName));
  end else begin
    // WideString
    VGlobalStorageIdentifier := WideString(PWideChar(AInfoData^.szGlobalStorageIdentifier));
    VServiceName             := WideString(PWideChar(AInfoData^.szServiceName));
  end;

  // parse
  FPath.ApplyFrom(VGlobalStorageIdentifier, VServiceName);

  // check result
  if (0<Length(FPath.Path_Items[0])) and (0<Length(FPath.Path_Items[2])) then begin
    // may be correct
    Result := ETS_RESULT_OK;
  end else begin
    // error
    Result := ETS_RESULT_INVALID_PATH;
  end;
end;

procedure TDBMS_Provider.ReadVersionsFromDB;
var
  VDataset: TDBMS_Dataset;
  VNewItem: TVersionAA;
begin
  FVersionList.SetCapacity(0);
  VDataset := FConnection.MakePoolDataset;
  try
    VDataset.OpenSQL(GetSQL_SelectVersions);
    if (not VDataset.IsEmpty) then begin
      // set capacity
      FVersionList.SetCapacity(VDataset.RecordCount);
      // enum
      VDataset.First;
      while (not VDataset.Eof) do begin
        // add record to array
        VNewItem.id_ver := VDataset.FieldByName('id_ver').AsInteger;
        VNewItem.ver_value := VDataset.FieldByName('ver_value').AsString;
        VNewItem.ver_date := VDataset.FieldByName('ver_date').AsDateTime;
        VNewItem.ver_number := VDataset.FieldByName('ver_number').AsInteger;
        VNewItem.ver_comment := VDataset.FieldByName('ver_comment').AsString;
        FVersionList.AddItem(@VNewItem);
        // next
        VDataset.Next;
      end;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

function TDBMS_Provider.TableExists(const ATableName: WideString): Boolean;
var
  VDataset: TDBMS_Dataset;
begin
  VDataset := FConnection.MakePoolDataset;
  try
    try
      VDataset.OpenSQL('select 1 from ' + ATableName + ' where 0=1');
      Result := TRUE;
    except
      Result := FALSE;
    end;
  finally
    FConnection.KillPoolDataset(VDataset);
  end;
end;

end.
