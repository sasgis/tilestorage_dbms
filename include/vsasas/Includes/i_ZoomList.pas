unit i_ZoomList;

interface

const
  // зумы с 1 по этот включительно
  // при нумерации от 0 - определяет зум больше максимального
  c_Max_Supported_Zoom = 24;

type
  TZoomBits = LongWord;

  IZoomList = interface
    ['{64025C2A-34E4-42D2-AA80-EAF6D28FD5E2}']
    function Available: Boolean;
    function ZoomInList(const AZoom: Byte): Boolean;
    function GetHash: TZoomBits;
  end;

implementation

end.