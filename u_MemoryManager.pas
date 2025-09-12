unit u_MemoryManager;

interface

{$IFDEF RELEASE}
{$IF CompilerVersion < 24}
uses
  FastMM4;
{$ELSE}
uses
  FastMM5;
{$IFEND}
{$ENDIF}

implementation

end.
