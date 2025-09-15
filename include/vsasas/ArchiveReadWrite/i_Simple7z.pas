unit i_Simple7z;

interface

uses
  i_BinaryData;

type
  // I7zInArchive
  ISimple7zDecompressor = interface
    ['{7228BC90-37B7-4A19-9CCA-830BD56098E1}']
    function DecompressBuffer(
      const ASize: Integer;
      const ABuffer: Pointer
    ): IBinaryData;
  end;

  // I7zOutArchive
  ISimple7zCompressor = interface
    ['{6960E2AC-0EA1-4B39-BE41-022BE092B9AE}']
    function CompressBuffer(
      const ASize: Integer;
      const ABuffer: Pointer
    ): IBinaryData;
  end;

  ISimple7zHolder = interface
    ['{08C809A0-3062-4D6D-BE23-AEF5A94A7F48}']
    function GetCreateObjectAddress: Pointer;
  end;

implementation

end.