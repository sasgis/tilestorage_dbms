unit u_StatementHandleCache;

interface

uses
  Windows,
  SysUtils,
  Classes,
  odbcsql,
  i_StatementHandleCache;

type
  TStatementNotifyProc = procedure (Ptr: Pointer; Action: TListNotification) of object;

  TStatementList = class(TList)
  private
    FOnNotify: TStatementNotifyProc;
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    function ExtractLast(var APtr: Pointer): Boolean;
  end;

  TStatementHandleNonCached = class(TInterfacedObject, IStatementHandleCache)
  protected
    FDBCHandlePtr: PSQLHandle;
  protected
    { IStatementHandleCache }
    procedure FreeStatement(const AStatementHandle: SQLHANDLE); virtual;
    function GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN; virtual;
    procedure SyncStatements; virtual;
  public
    constructor Create(
      const ADBCHandlePtr: PSQLHandle
    );
  end;

  TStatementHandleCache = class(TStatementHandleNonCached, IStatementHandleCache)
  private
    FSync: IReadWriteSync;
    FUsedList: TStatementList;
    FUnusedList: TStatementList;
  private
    procedure DoOnNotify(Ptr: Pointer; Action: TListNotification);
  protected
    procedure CleanupStatementToKeepInList(const AStatementHandle: SQLHANDLE); virtual;
  protected
    { IStatementHandleCache }
    procedure FreeStatement(const AStatementHandle: SQLHANDLE); override;
    function GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN; override;
    procedure SyncStatements; override;
  public
    constructor Create(
      const ADBCHandlePtr: PSQLHandle
    );
    destructor Destroy; override;
  end;

  TStatementFetchableCache = class(TStatementHandleCache)
  protected
    procedure CleanupStatementToKeepInList(const AStatementHandle: SQLHANDLE); override;
  end;
  
implementation

uses
  u_Synchronizer;

{ TStatementHandleCache }

procedure TStatementHandleCache.CleanupStatementToKeepInList(const AStatementHandle: SQLHANDLE);
begin
  // пусто!
end;

constructor TStatementHandleCache.Create(const ADBCHandlePtr: PSQLHandle);
begin
  inherited Create(ADBCHandlePtr);
  FSync := MakeSyncRW_Var(Self, False);
  FUsedList := TStatementList.Create;
  FUsedList.FOnNotify := DoOnNotify;
  FUnusedList := TStatementList.Create;
  FUnusedList.FOnNotify := DoOnNotify;
end;

destructor TStatementHandleCache.Destroy;
begin
  FSync.BeginWrite;
  try
    // free all items
    FUnusedList.Clear;
    FreeAndNil(FUnusedList);
    FUsedList.Clear;
    FreeAndNil(FUsedList);
  finally
    FSync.EndWrite;
  end;

  inherited;

  FSync := nil;
end;

procedure TStatementHandleCache.DoOnNotify(Ptr: Pointer; Action: TListNotification);
begin
  if (lnDeleted=Action) then begin
    // free statement handle
    inherited FreeStatement(Ptr);
  end;
end;

procedure TStatementHandleCache.FreeStatement(const AStatementHandle: SQLHANDLE);
var
  VUsedPtr: Pointer;
begin
  FSync.BeginWrite;
  try
    // extract from used list ...
    VUsedPtr := FUsedList.Extract(AStatementHandle);
    if (VUsedPtr<>nil) then begin
      // ... and put to unused
      FUnusedList.Add(AStatementHandle);
      // cleanup internals
      CleanupStatementToKeepInList(AStatementHandle);
    end else begin
      // ... bit if not found - free statement
      inherited FreeStatement(AStatementHandle);
    end;
  finally
    FSync.EndWrite;
  end;
end;

function TStatementHandleCache.GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN;
begin
  FSync.BeginWrite;
  try
    // if has unused ...
    if FUnusedList.ExtractLast(AStatementHandle) then begin
      // ... get it
      Result := SQL_SUCCESS;
    end else begin
      // else make new
      Result := inherited GetStatementHandle(AStatementHandle);
      if not SQL_SUCCEEDED(Result) then
        Exit;
    end;
    // put it to list of used statements
    FUsedList.Add(AStatementHandle);
  finally
    FSync.EndWrite;
  end;
end;

procedure TStatementHandleCache.SyncStatements;
begin
  //inherited;
  FSync.BeginWrite;
  try
    // clear list of unused statements
    FUnusedList.Clear;
  finally
    FSync.EndWrite;
  end;
end;

{ TStatementList }

function TStatementList.ExtractLast(var APtr: Pointer): Boolean;
begin
  Result := (Count>0);
  if Result then begin
    APtr := List^[(Count-1)];
    List[(Count-1)] := nil;
    Delete(Count-1);
    Notify(APtr, lnExtracted);
  end else begin
    APtr := nil;
  end;
end;

procedure TStatementList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited;
  FOnNotify(Ptr, Action);
end;

{ TStatementHandleNonCached }

constructor TStatementHandleNonCached.Create(const ADBCHandlePtr: PSQLHandle);
begin
  inherited Create;
  FDBCHandlePtr := ADBCHandlePtr;
end;

procedure TStatementHandleNonCached.FreeStatement(const AStatementHandle: SQLHANDLE);
begin
  // free handle
  SQLFreeHandle(SQL_HANDLE_STMT, AStatementHandle);
end;

function TStatementHandleNonCached.GetStatementHandle(var AStatementHandle: SQLHANDLE): SQLRETURN;
begin
  // allocate handle
  Result := SQLAllocHandle(SQL_HANDLE_STMT, FDBCHandlePtr^, AStatementHandle);
end;

procedure TStatementHandleNonCached.SyncStatements;
begin
  // empty!
end;

{ TStatementFetchableCache }

procedure TStatementFetchableCache.CleanupStatementToKeepInList(const AStatementHandle: SQLHANDLE);
begin
  SQLFreeStmt(AStatementHandle, SQL_CLOSE);
  SQLFreeStmt(AStatementHandle, SQL_UNBIND);
  SQLFreeStmt(AStatementHandle, SQL_RESET_PARAMS);
end;

end.
