unit c_CompressBinaryData;

interface

// tile compression modes (as byte)

const
  tcm_none    = 0;
  tcm_zlib    = 1;
  tcm_gzip    = 2;
  tcm_7z_lzma = 3;
  tcm_max     = 3;

procedure CheckTileCompressionMode(var AValue: Integer);

implementation

procedure CheckTileCompressionMode(var AValue: Integer);
begin
  if (AValue < tcm_none) or (AValue > tcm_max) then
    AValue := tcm_none;
end;

end.