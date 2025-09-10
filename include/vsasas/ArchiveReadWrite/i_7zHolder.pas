unit i_7zHolder;

interface

uses
  i_Simple7z;

type
  I7zHolder = interface
    ['{E027C05D-FE6F-49EC-A337-30B93E43FE79}']
    function CreateDecompressor: ISimple7zDecompressor;
    function CreateCompressor: ISimple7zCompressor;
  end;

implementation

end.