unit u_7zHolder;

interface

{$if not defined(FORCE_NO_SYNC_7Z_HOLDER)}
// set in DLL
{$define SYNC_7Z_HOLDER}
{$ifend}

uses
  SysUtils,
  i_Simple7z,
  i_7zHolder,
{$if defined(SYNC_7Z_HOLDER)}
  i_ListenerTime,
  i_NotifierTime,
{$ifend}
  u_BaseInterfacedObject;

type
  T7zHolder = class(TBaseInterfacedObject, I7zHolder)
  private
{$if defined(SYNC_7Z_HOLDER)}
    FSync: IReadWriteSync;
    FAccessCount: Integer;
    FTTLListener: IListenerTime;
    FTTLNotifier: INotifierTime;
{$ifend}
    F7zHolder: ISimple7zHolder;
    F7zDecompressor: ISimple7zDecompressor;
    F7zCompressor: ISimple7zCompressor;
    FFailed: Boolean;
  private
{$if defined(SYNC_7Z_HOLDER)}
    function CheckIfHasAccessAndReset: Boolean; inline;
    procedure HasAccess; inline;
    procedure OnTime;
{$ifend}
  private
    function CheckIfInitOrFailed: Boolean;
    procedure InternalLoad7z;
    procedure InternalUnload7z;
  private
    { I7zHolder }
    function CreateDecompressor: ISimple7zDecompressor;
    function CreateCompressor: ISimple7zCompressor;
  public
    constructor Create(
{$if defined(SYNC_7Z_HOLDER)}
      //const APerfCounterList: IInternalPerformanceCounterList;
      const ATTLNotifier: INotifierTime
{$ifend}
    );
    destructor Destroy; override;
  end;

implementation

uses
{$if defined(SYNC_7Z_HOLDER)}
  u_ListenerTime,
  u_Synchronizer,
{$ifend}
  u_Simple7z;

{ T7zHolder }

{$if defined(SYNC_7Z_HOLDER)}
function T7zHolder.CheckIfHasAccessAndReset: Boolean;
begin
  // check if failed or destroying
  Result := (InterlockedExchange(FAccessCount, 0) <> 0);
end;
{$ifend}

function T7zHolder.CheckIfInitOrFailed: Boolean;
begin
  Result := False;

  // check if failed or destroying
  if FFailed then begin
    Inc(Result);
    Exit;
  end;

{$if defined(SYNC_7Z_HOLDER)}
  HasAccess;

  if (nil = F7zHolder) then begin
    // need initialize
    FSync.BeginWrite;
    try
      if (nil = F7zHolder) then begin
        InternalLoad7z;
        if FFailed then begin
          Inc(Result);
        end;
      end;
    finally
      FSync.EndWrite;
    end;
  end;
{$ifend}
end;

constructor T7zHolder.Create(
{$if defined(SYNC_7Z_HOLDER)}
  const ATTLNotifier: INotifierTime
{$ifend}
);
begin
  inherited Create;
  FFailed := False;
{$if defined(SYNC_7Z_HOLDER)}
  FAccessCount := 0;
  FSync := MakeSyncSpinLock(Self, 4096); // MakeSyncRW_Var(Self, False);
  FTTLNotifier := ATTLNotifier;
  if (FTTLNotifier <> nil) then begin
    FTTLListener := TListenerTimeCheck.Create(Self.OnTime, 30000);
    FTTLNotifier.Add(FTTLListener);
  end;
{$else}
  InternalLoad7z;
{$ifend}
end;

function T7zHolder.CreateCompressor: ISimple7zCompressor;
begin
  if CheckIfInitOrFailed  then
    Exit;

  (*
  // make compressor
  Result := TSimple7zCompressor.Create(F7zHolder);
  *)
  Result := F7zCompressor;
end;

function T7zHolder.CreateDecompressor: ISimple7zDecompressor;
begin
  if CheckIfInitOrFailed then
    Exit;

  (*
  // make decompressor
  Result := TSimple7zDecompressor.Create(F7zHolder);
  *)
  Result := F7zDecompressor;
end;

destructor T7zHolder.Destroy;
begin
  FFailed := True;
  
{$if defined(SYNC_7Z_HOLDER)}
  if FTTLNotifier <> nil then begin
    FTTLNotifier.Remove(FTTLListener);
    FTTLListener := nil;
    FTTLNotifier := nil;
  end;

  FSync.BeginWrite;
  try
    InternalUnload7z;
  finally
    FSync.EndWrite;
  end;
{$else}
  InternalUnload7z;
{$ifend}

  inherited;
end;

{$if defined(SYNC_7Z_HOLDER)}
procedure T7zHolder.HasAccess;
begin
  InterlockedIncrement(FAccessCount);
end;
{$ifend}

procedure T7zHolder.InternalLoad7z;
begin
  F7zHolder := TSimple7zHolder.Create(nil);
  FFailed := (nil = F7zHolder.GetCreateObjectAddress);
  if (not FFailed) then begin
    F7zDecompressor := TSimple7zDecompressor.Create(F7zHolder);
    F7zCompressor := TSimple7zCompressor.Create(F7zHolder);
  end;
end;

procedure T7zHolder.InternalUnload7z;
begin
  F7zHolder := nil;
  F7zDecompressor := nil;
  F7zCompressor := nil;
end;

{$if defined(SYNC_7Z_HOLDER)}
procedure T7zHolder.OnTime;
begin
  if (not CheckIfHasAccessAndReset) then begin
    // seems no access
    FSync.BeginWrite;
    try
      // check again
      if CheckIfHasAccessAndReset then
        Exit;
      // abandoned
      InternalUnload7z;
    finally
      FSync.EndWrite;
    end;
  end;
end;
{$ifend}

end.