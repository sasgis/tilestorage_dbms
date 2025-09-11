unit u_DBMS_TileEnum;

{$include i_DBMS.inc}

interface

uses
  Types,
  SysUtils,
  Classes,
  t_ETS_Tiles,
  t_ETS_Path,
  t_ETS_Provider,
  t_ODBC_Buffer,
  t_DBMS_version,
  t_DBMS_service,
  t_DBMS_contenttype,
  i_DBMS_Provider,
  u_DBMS_Connect;

type
  TTileEnumState = (
    tes_Start,
    tes_Error,
    tes_Fetched
  );

  TDBMS_TileEnum = class(TInterfacedObject, IDBMS_TileEnum)
  private
    FDBMS_Worker: IDBMS_Worker;
    FDBMS_Service_Info: PDBMS_Service_Info;
    FVersionList: TVersionList;
    FContentTypeList: TContentTypeList;
    FStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
    FFlags: LongWord;
    FHostPointer: Pointer;
    FCallbackProc: Pointer;
    FConnectionForEnum: IDBMS_Connection;
    FUseSingleSection: Boolean;
    FScanMaxRows: AnsiString;
  private
    FState: TTileEnumState;
    FLastError: Byte;
    FListOfTables: TStringList;
    FNextTableIndex: Integer;
    FENUM_Prefix: String;
    FENUM_Select: String;
    FFetchTilesCols: TOdbcFetchCols7;
  private
    FNextBufferOut: TETS_NEXT_TILE_ENUM_OUT;
    FTileXYZ: TTILE_ID_XYZ;
    FXYUpperToTable: TPoint;
    // ��� ������ �����
    FTileVersionId: SmallInt;
    FTileVersionA: AnsiString;
    FTileVersionW: WideString;
    // ��� ���� �����
    FTileContentTypeId: SmallInt;
    FTileContentTypeA: AnsiString;
    FTileContentTypeW: WideString;
  private
    procedure ConnChanged;
    procedure InitTileCache;
  private
    function SetError(const AErrorCode: Byte): Byte;
    function CallHostForCurrentRecord(
      const ACallbackPointer: Pointer;
      const ANextBufferIn: PETS_GET_TILE_RECT_IN
    ): Byte;
    function ReadListOfTables: Boolean;
    function GetTablesWithTilesBySelect: Boolean;
    function CannotSwitchToNextSection(var AResult: Byte): Boolean;
    function OpenNextTableAndFetch(const ANextBufferIn: PETS_GET_TILE_RECT_IN): Boolean;
    procedure GetZoomAndHighXYFromCurrentTable;
  private
    function InternalFetch: Boolean; inline;
    procedure InternalClose; inline;
  private
    { IDBMS_TileEnum }
    function GetNextTile(
      const ACallbackPointer: Pointer;
      const ANextBufferIn: PETS_GET_TILE_RECT_IN
    ): Byte;
  public
    constructor Create(
      const ADBMS_Worker: IDBMS_Worker;
      const ADBMS_Service_Info: PDBMS_Service_Info;
      const AVersionList: TVersionList;
      const AContentTypeList: TContentTypeList;
      const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
      const AFlags: LongWord;
      const AHostPointer: Pointer;
      const ACallbackProc: Pointer;
      const AConnectionForEnum: IDBMS_Connection;
      const AUseSingleSection: Boolean
    );
    destructor Destroy; override;
  end;


implementation

uses
  t_SQL_types,
  t_DBMS_Connect,
  t_DBMS_Template;

{ TDBMS_TileEnum }

function TDBMS_TileEnum.CallHostForCurrentRecord(
  const ACallbackPointer: Pointer;
  const ANextBufferIn: PETS_GET_TILE_RECT_IN
): Byte;
var
  VNewIdVer, VNewIdContentType: SmallInt;
  VFoundValue: AnsiString;
begin
  // ���������� ������� ������ � ���������� �� ����
  FNextBufferOut.TileInfo.dwOptionsOut := 0;

  // ���������� Z ��� ��������� �� ����� �������

  // ���� ���������� XY ("�������" �����)
  // � �������������� "�������" �������� �� ����� �������
  FDBMS_Service_Info.CalcBackToTilePos(
    FFetchTilesCols.Base.GetAsLongInt(1),
    FFetchTilesCols.Base.GetAsLongInt(2),
    FXYUpperToTable,
    @(FTileXYZ.xy)
  );
  
  // ������ �����
  FFetchTilesCols.Base.ColToSmallInt(3, VNewIdVer);

  // ���� ������ ��������� -  ������ ������ �� �������� ������
  // ���� �� ���������� - � ������ ������ �� ������
  if (VNewIdVer <> FTileVersionId) then begin
    // ������ ��������� - ���� ������ �� ��������������
    if FVersionList.FindItemByIdVer(VNewIdVer, nil, VFoundValue) then begin
      // �������� �������
      FTileVersionId := VNewIdVer;
      if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_ANSI_VERSION_OUT) <> 0) then begin
        // ��� Ansi
        FTileVersionA := VFoundValue;
        FNextBufferOut.TileInfo.szVersionOut := PAnsiChar(@FTileVersionA[1]);
      end else begin
        // ��� Wide
        FTileVersionW := VFoundValue;
        FNextBufferOut.TileInfo.szVersionOut := PWideChar(@FTileVersionW[1]);
      end;
    end else begin
      // ������ �� �������
      Result := ETS_RESULT_ENUM_UNKNOWN_VERSION;
      Exit;
    end;
  end;

  // ������ �����
  FFetchTilesCols.Base.ColToLongInt(4, FNextBufferOut.TileInfo.dwTileSize);

  // �������� �� ������������
  // Assert(FFetchTilesCols.Base.IsNull(7) = (FNextBufferOut.TileInfo.dwTileSize=0));

  // ���� TNE - ������ ���� � ��� ����� �� ������
  // TODO: ��������������� ��� ���������� ������� ����� ������������ ������
  if (FNextBufferOut.TileInfo.dwTileSize <= 0) or FFetchTilesCols.Base.IsNull(7) then begin
    // TNE
    with FNextBufferOut.TileInfo do begin
      ptTileBuffer := nil;
      szContentTypeOut := nil;
      dwOptionsOut := dwOptionsOut or ETS_ROO_TNE_EXISTS;
    end;
  end else begin
    // TILE
    with FNextBufferOut.TileInfo do begin
      dwOptionsOut := dwOptionsOut or ETS_ROO_TILE_EXISTS;
      // ���� �����
      ptTileBuffer := FFetchTilesCols.Base.GetLOBBuffer(7);
    end;

    // ��� �����
    FFetchTilesCols.Base.ColToSmallInt(5, VNewIdContentType);

    // ���� ��� ����� �������� -  ������ ������ �� ��������
    if (VNewIdContentType <> FTileContentTypeId) then begin
      // ������� ��� ����� �� ��������������
      if FContentTypeList.FindItemByIdContentType(VNewIdContentType, nil, VFoundValue) then begin
        // ����� �������� �������
        FTileContentTypeId := VNewIdContentType;
        if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_ANSI_CONTENTTYPE_OUT) <> 0) then begin
          // ��� Ansi
          FTileContentTypeA := VFoundValue;
          FNextBufferOut.TileInfo.szContentTypeOut := PAnsiChar(@FTileContentTypeA[1]);
        end else begin
          // ��� Wide
          FTileContentTypeW := VFoundValue;
          FNextBufferOut.TileInfo.szContentTypeOut := PWideChar(@FTileContentTypeW[1]);
        end;
      end else begin
        // ��� ����� �� ������ - ������ ����
        Result := ETS_RESULT_ENUM_UNKNOWN_CONTENTTYPE;
        Exit;
      end;
    end;
  end;

  // ����
  FFetchTilesCols.Base.ColToDateTime(6, FNextBufferOut.TileInfo.dtLoadedUTC);

  // ������ �� ��� � ������� ��������� ������
  Result := TETS_NextTileEnum_Callback(FCallbackProc)(
    FHostPointer,
    ACallbackPointer,
    ANextBufferIn,
    @FNextBufferOut
  );
end;

function TDBMS_TileEnum.CannotSwitchToNextSection(var AResult: Byte): Boolean;
begin
  // ���� ������ ���������� ����� ������� - ������ �� ���
  // ���� ������ ��� ������ - ����
  Result := FUseSingleSection or (nil = FConnectionForEnum.FNextSectionConn);

  // ������ ������ ��������
  FConnectionForEnum.FODBCConnectionHolder.DisConnect;

  if Result then begin
    // �������� ����� (��� ������, ��� �� ���������)
    SetError(ETS_RESULT_COMPLETED_SUCCESSFULLY);
    AResult := ETS_RESULT_OK;
  end else begin
    // ��������� � ��������� ������
    FConnectionForEnum := FConnectionForEnum.FNextSectionConn;
    // ���������� ����� ������
    ConnChanged;
  end;
end;

procedure TDBMS_TileEnum.ConnChanged;
begin
  FLastError := FConnectionForEnum.EnsureConnected(TRUE, FStatusBuffer);
  if (ETS_RESULT_OK <> FLastError) then begin
    FState := tes_Error;
    Exit;
  end;

  FENUM_Prefix := FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_ENUM_PREFIX);
  FENUM_Select := FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_ENUM_SELECT);

  // ���� �� ������ ������ - ���� ������ �� ��������� ��� �������� ������� �� (���� �� ������)
  if (0 = Length(FENUM_Select)) then begin
    FENUM_Select := c_SQL_ENUM_SVC_Tables[FConnectionForEnum.GetCheckedEngineType];
  end;

  // �������� � ������� %SVC% �� �������� ��� �������
  if (0 < Length(FENUM_Select)) then begin
    FENUM_Select := StringReplace(
      FENUM_Select,
      c_Templated_SVC,
      FConnectionForEnum.FPathDiv.ServiceName,
      [rfReplaceAll, rfIgnoreCase]
    );
  end;
end;

constructor TDBMS_TileEnum.Create(
  const ADBMS_Worker: IDBMS_Worker;
  const ADBMS_Service_Info: PDBMS_Service_Info;
  const AVersionList: TVersionList;
  const AContentTypeList: TContentTypeList;
  const AStatusBuffer: PETS_SERVICE_STORAGE_OPTIONS;
  const AFlags: LongWord;
  const AHostPointer: Pointer;
  const ACallbackProc: Pointer;
  const AConnectionForEnum: IDBMS_Connection;
  const AUseSingleSection: Boolean
);
begin
  inherited Create;
  // ���� �������
  FDBMS_Worker := ADBMS_Worker;
  FDBMS_Service_Info :=  ADBMS_Service_Info;
  FVersionList := AVersionList;
  FContentTypeList := AContentTypeList;
  FStatusBuffer := AStatusBuffer;
  FFlags := AFlags;
  FHostPointer := AHostPointer;
  FCallbackProc := ACallbackProc;
  FConnectionForEnum := AConnectionForEnum;
  FUseSingleSection := AUseSingleSection;
  // ���� ������� ����
  FState := tes_Start;
  FLastError := ETS_RESULT_OK;
  FListOfTables := nil;
  if TryStrToInt(FConnectionForEnum.GetInternalParameter(ETS_INTERNAL_SCAN_MaxRows), FNextTableIndex) then begin
    FScanMaxRows := IntToStr(FNextTableIndex);
  end else begin
    FScanMaxRows := '';
  end;
  FNextTableIndex := 0;
  // ��� �����
  FillChar(FNextBufferOut, SizeOf(FNextBufferOut), 0);
  FNextBufferOut.TileFull := @FTileXYZ;
  // ����������� ������ ��� �����������
  FFetchTilesCols.Init;
  InitTileCache;
  ConnChanged;
end;

destructor TDBMS_TileEnum.Destroy;
begin
  InternalClose;
  FreeAndNil(FListOfTables);
  FConnectionForEnum := nil;
  FDBMS_Worker := nil;
  inherited Destroy;
end;

function TDBMS_TileEnum.GetNextTile(
  const ACallbackPointer: Pointer;
  const ANextBufferIn: PETS_GET_TILE_RECT_IN
): Byte;
begin
  if (tes_Error = FState) then begin
    // ������ ��� �� ���������
    Result := FLastError;
    Exit;
  end;

  if FDBMS_Worker.IsUninitialized then begin
    Result := ETS_RESULT_OK;
    FLastError := ETS_RESULT_OK;
    Exit;
  end;

  // ������ ��� ������ ���� � FConnectionForEnum
  if (nil=FConnectionForEnum) then begin
    // ��� ������
    Result := SetError(ETS_RESULT_CANNOT_CONNECT);
    Exit;
  end;

  repeat
    // �������
    if FDBMS_Worker.IsUninitialized then begin
      Result := ETS_RESULT_OK;
      FLastError := ETS_RESULT_OK;
      Exit;
    end;

    // ����� ������� ����� ������ (�����������)
    while (tes_Start = FState) do begin
      // �����������
      if FDBMS_Worker.IsUninitialized then begin
        Result := ETS_RESULT_OK;
        FLastError := ETS_RESULT_OK;
        Exit;
      end;

      // ���������� ����������� (���� ��� �� ����������)
      Result := FConnectionForEnum.EnsureConnected(TRUE, FStatusBuffer);
      if (ETS_RESULT_OK <> Result) then begin
        FLastError := Result;
        FState := tes_Error;
        Exit;
      end;

      // �������� ������ �������� ������ ������ �������
      // ������� ��������� ������� ������������ �� 0
      if not ReadListOfTables then begin
        // �� ������ �������� (���� ������) ������ ������
        Result := SetError(ETS_RESULT_INVALID_STRUCTURE);
        Exit;
      end;

      // ������ ������ ��������
      if (0=FListOfTables.Count) then begin
        // �� �� ������ - ��������� � ���������� �����������, ����� �� ���������
        if CannotSwitchToNextSection(Result) then
          Exit;
      end;

      // ������ ������ �� ������ - ������ �� ������ ���������� �������
      if OpenNextTableAndFetch(ANextBufferIn) then begin
        // ������� ������� ������� � ��������� ���� �� ���� ������
        FState := tes_Fetched;
        break;
      end else begin
        // �� ������ ������� �������:
        // ���� ������� ��������� (������ ������� ����������)
        // ���� ������
        if (ETS_RESULT_OK = FLastError) then begin
          // ������� �� �������������� ���������� ������� - ��� � ��������� ������
          if CannotSwitchToNextSection(Result) then
            Exit;
        end else begin
          // ������
          Result := FLastError;
          FState := tes_Error;
          Exit;
        end;
      end;
    end;

    if (tes_Fetched = FState) then begin
      // ������ �������� - ������ callback
      // ����� ��������� � �� ����
      Result := CallHostForCurrentRecord(ACallbackPointer, ANextBufferIn);

      // �������� ���������
      if (ETS_RESULT_OK <> Result) then begin
        // �����-�� �����
        FLastError := Result;
        FState := tes_Error;
        Exit;
      end;

      // ����� ��������� ������
      if InternalFetch then begin
        // �� � ������� - �� ��������� �������� ����� ����������� ������ �������
        //Exit;
      end else begin
        // �� �� � �������:
        // ������� ��������� - ���� ������ ���������
        // ��� ������ ������
        if (ETS_RESULT_OK = FLastError) then begin
          // ��������� ������� - ���� ���������
          // ������� ������������� �� ��������� � ��������� �������
          // ������ �� ������ ������ ��� ������� �� ��������
          if OpenNextTableAndFetch(ANextBufferIn) then begin
            // ������� ������� ������� � ��������� ���� �� ���� ������
            // �� � ������� - �� ��������� �������� ����� ����������� ������ �������
            //Exit;
          end else begin
            // ������� ��������� ��� ������
            if (ETS_RESULT_OK = FLastError) then begin
              // ��� ���� ��������� ������� - ���� ������ �����������
              if CannotSwitchToNextSection(Result) then
                Exit;
              FState := tes_Start;
              //Exit;
            end else begin
              // ��� ���� ������
              Result := FLastError;
              FState := tes_Error;
              //Exit;
            end;
          end;
        end else begin
          // ������
          FLastError := Result;
          FState := tes_Error;
          //Exit;
        end;
      end;

      // ��� ��� ������� ��������� ������ �� ���� - ��� � ����� ������ ���� �������
      Exit;
    end;

  until FALSE;
end;

function TDBMS_TileEnum.GetTablesWithTilesBySelect: Boolean;
var
  VFetchTablesCols: TOdbcFetchCols3;
  VTableName: AnsiString;
begin
  Result := FALSE;
  try
    VFetchTablesCols.Init;
    try
      Result := FConnectionForEnum.FODBCConnectionHolder.OpenDirectSQLFetchCols(
        FENUM_Select,
        @(VFetchTablesCols.Base)
      );

      if Result then
      while VFetchTablesCols.Base.FetchRecord do begin
        VFetchTablesCols.Base.ColToAnsiString(1, VTableName);
        FListOfTables.Add(VTableName);
      end;
    finally
      VFetchTablesCols.Base.Close;
    end;
  except
  end;
end;

procedure TDBMS_TileEnum.GetZoomAndHighXYFromCurrentTable;
var
  VTablename: String;
  VFirst: Char;
  VPos: Integer;
begin
  // ������� ����� ��� ����� ������: I54I24_bingsat
  VTablename := FListOfTables[FNextTableIndex];

  // ������ ��� - ��� ������ ������ (� ������� - 'I')
  VFirst := VTablename[1];
  if (VFirst in ['1'..'9']) then begin
    // ���� �� 1 �� 9
    FTileXYZ.z := Ord(VFirst) - Ord('1') + 1;
  end else if (VFirst in ['A'..'W']) then begin
    // ���� �� 10
    FTileXYZ.z := Ord(VFirst) - Ord('A') + 10;
  end else if (VFirst in ['a'..'w']) then begin
    // ���� �� 10
    FTileXYZ.z := Ord(VFirst) - Ord('a') + 10;
  end else begin
    // � ���������� ��� ������
    FTileXYZ.z := 0;
    FXYUpperToTable.X := 0;
    FXYUpperToTable.Y := 0;
    Exit;
  end;

  // ���� ������� �������� XY �� ����� �������
  // ��� ����� ���������� ��� ��� �� �������������
  // � ���������� ������ ������
  VPos := System.Pos('_', VTablename);
  VTablename := System.Copy(VTablename, 2, (VPos-2));

  // ���� ����������� ��������� - ��� ������ ������� �� ��������
  // �� ����� ���� �� ����� ���� � ����� ��������
  VTablename := UpperCase(VTablename);
  VPos := System.Pos(FDBMS_Service_Info^.id_div_mode, VTablename);

  if (VPos>0) then begin
    // ���� ����������� - ����� ��� X, � ����� ���� Y (��� HEX)
    FXYUpperToTable.X := StrToIntDef('$'+System.Copy(VTablename, 1, (VPos-1)), 0);
    FXYUpperToTable.Y := StrToIntDef('$'+System.Copy(VTablename, (VPos+1), Length(VTablename)), 0);
  end else begin
    // � ���������� ��� ������
    FTileXYZ.z := 0;
    FXYUpperToTable.X := 0;
    FXYUpperToTable.Y := 0;
  end;
end;

procedure TDBMS_TileEnum.InitTileCache;
begin
  FTileVersionId := 0;
  FTileVersionA := '';
  FTileVersionW := '';
  FTileContentTypeId := 0;
  FTileContentTypeA := '';
  FTileContentTypeW := '';
end;

procedure TDBMS_TileEnum.InternalClose;
begin
  FFetchTilesCols.Base.Close;
end;

function TDBMS_TileEnum.InternalFetch: Boolean;
begin
  // ����� ��������� ������ �� ������������� ��������� �������
  Result := FFetchTilesCols.Base.FetchRecord;
end;

function TDBMS_TileEnum.OpenNextTableAndFetch(const ANextBufferIn: PETS_GET_TILE_RECT_IN): Boolean;
var
  VSQLText: AnsiString;
  VEngineType: TEngineType;
begin
  Result := FALSE;

  repeat
    if (FNextTableIndex >= FListOfTables.Count) then begin
      // ������ ��� ������� � �����������
      Exit;
    end;

    VEngineType := FConnectionForEnum.GetCheckedEngineType;

    // ������� ������� ������� � ���� �������
    VSQLText := 'v.x,v.y,v.id_ver,v.tile_size,v.id_contenttype,v.load_date,v.tile_body' +
                 ' FROM ' + FENUM_Prefix +
                 c_SQL_QuotedIdentifierValue[VEngineType, qp_Before] +
                 FListOfTables[FNextTableIndex] +
                 c_SQL_QuotedIdentifierValue[VEngineType, qp_After] +
                 ' v';

    // �������� ���� ���������� TNE
    if ((ANextBufferIn^.dwOptionsIn and ETS_ROI_SELECT_TILE_BODY) <> 0) then begin
      // ����� ������ ������� ������������ �����
      VSQLText := VSQLText + ' WHERE v.tile_size>0';
    end;

    // �������� ���� ���������� ��������
    // ������� TOP N ��� LIMIT N ��� ��� ��� (� ����������� �� ����)
    if (0<Length(FScanMaxRows)) then
    // ����� ������ ���� ���� -
    case c_SQL_RowCount1_Mode[VEngineType] of
      rc1m_Top1: begin
        VSQLText := 'TOP '+FScanMaxRows+' ' + VSQLText;
      end;
      rc1m_First1: begin
        VSQLText := 'FIRST '+FScanMaxRows+' ' + VSQLText;
      end;
      rc1m_Limit1: begin
        VSQLText := VSQLText + ' LIMIT '+FScanMaxRows;
      end;
      rc1m_Fetch1Only: begin
        VSQLText := VSQLText + ' FETCH FIRST '+FScanMaxRows+' ROW ONLY';
      end;
      rc1m_Rows1: begin
        VSQLText := VSQLText + ' ROWS '+FScanMaxRows;
      end;
    end;

    VSQLText := 'SELECT ' + VSQLText;

    try
      InternalClose;
      if FConnectionForEnum.FODBCConnectionHolder.OpenDirectSQLFetchCols(VSQLText, @(FFetchTilesCols.Base)) then begin
        // ������ �������
        if InternalFetch then begin
          // ��������� ������ - ����� � �������
          Result := TRUE;
          // ������ ���������� ������ �� ��� ��� ���� �� ����� �������
          GetZoomAndHighXYFromCurrentTable;
          // � �������������� ������� �� �������
          Inc(FNextTableIndex);
          Exit;
        end;
        // ��� ���� �������, �� ������� ���
        // ������� � ��������� �������
        Inc(FNextTableIndex);
      end else begin
        // �� ������ ���� ������� - ������ ������
        FLastError := ETS_RESULT_ENUM_TABLE_STRUCT;
        Exit;
      end;
    except
      FLastError := ETS_RESULT_ENUM_TABLE_STRUCT;
      Exit;
    end;

  until FALSE;
end;

function TDBMS_TileEnum.ReadListOfTables: Boolean;
begin
  // ������� ������ ������ ������ � ������� �����������
  // ���������� ������ �������� ������� �������� �������
  FreeAndNil(FListOfTables);
  FNextTableIndex := 0;

  if (nil=FListOfTables) then
    FListOfTables := TStringList.Create
  else
    FListOfTables.Clear;

  // ���� ������ ������� ��� ������, �� �� ����� ���� ���������� �����������
  // ������� ���� ����� ����� ������ �� INI
  if (0 < Length(FENUM_Select)) then begin
    // ����� ��������� ��������� ������
    Result := GetTablesWithTilesBySelect;
  end else begin
    // ���� ������� �� ������������ - ��� ������ ���������
    Result := FALSE;
    FLastError := ETS_RESULT_ENUM_NOT_SUPPORTED;
    (*
    Result := FConnectionForEnum.FODBCConnectionHolder.GetTablesWithTiles(
      FConnectionForEnum.FPathDiv.ServiceName,
      FListOfTables
    );
    *)
  end;
end;

function TDBMS_TileEnum.SetError(const AErrorCode: Byte): Byte;
begin
  FState := tes_Error;
  FLastError := AErrorCode;
  Result := AErrorCode;
end;

end.
