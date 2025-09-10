unit u_BinaryDataByMemStream;

interface

uses
  Classes,
  i_BinaryData,
  u_BaseInterfacedObject;

type
  TBinaryDataByMemStream = class(TBaseInterfacedObject, IBinaryData)
  private
    FMemStream: TMemoryStream;
  private
    function GetBuffer: Pointer;
    function GetSize: Integer;
  public
    constructor CreateFromStream(AStream: TStream);
    constructor CreateFromMem(
      const ASize: Integer;
      const ABuffer: Pointer
    ); deprecated;
    constructor CreateWithOwn(const AMemStream: TMemoryStream);
    constructor CreateFromFile(const AFilename: String);
    destructor Destroy; override;
  end;

implementation

uses
  SysUtils;

{ TBinaryDataByMemStream }

constructor TBinaryDataByMemStream.CreateFromFile(const AFilename: String);
begin
  inherited Create;
  FMemStream := TMemoryStream.Create;
  try
    FMemStream.LoadFromFile(AFilename);
  except
    FreeAndNil(FMemStream);
    raise;
  end;
end;

constructor TBinaryDataByMemStream.CreateFromMem(
  const ASize: Integer;
  const ABuffer: Pointer
);
var
  VMemStream: TMemoryStream;
begin
  VMemStream := TMemoryStream.Create;
  try
    VMemStream.WriteBuffer(ABuffer^, ASize);
    CreateWithOwn(VMemStream);
    VMemStream := nil;
  finally
    VMemStream.Free;
  end;
end;

constructor TBinaryDataByMemStream.CreateFromStream(AStream: TStream);
var
  VMemStream: TMemoryStream;
begin
  VMemStream := TMemoryStream.Create;
  try
    VMemStream.LoadFromStream(AStream);
    CreateWithOwn(VMemStream);
    VMemStream := nil;
  finally
    VMemStream.Free;
  end;
end;

constructor TBinaryDataByMemStream.CreateWithOwn(const AMemStream: TMemoryStream);
begin
  inherited Create;
  FMemStream := AMemStream;
end;

destructor TBinaryDataByMemStream.Destroy;
begin
  FreeAndNil(FMemStream);
  inherited;
end;

function TBinaryDataByMemStream.GetBuffer: Pointer;
begin
  Result := FMemStream.Memory;
end;

function TBinaryDataByMemStream.GetSize: Integer;
begin
  Result := FMemStream.Size;
end;

end.
