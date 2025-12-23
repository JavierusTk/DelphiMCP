/// MCP Backend Interface
// - Common interface for MCP server backends (Indy, mORMot)
// - Allows conditional compilation to switch between HTTP implementations
unit MCP.Backend.Intf;

interface

type
  /// Abstract interface for MCP HTTP server backends
  // - Implemented by both Indy and mORMot backends
  // - Provides a common Start/Stop lifecycle API
  IMCPHttpBackend = interface
    ['{7A8B9C0D-1E2F-3A4B-5C6D-7E8F9A0B1C2D}']
    /// Start the HTTP server
    procedure Start;
    /// Stop the HTTP server
    procedure Stop;
    /// Returns true if server is currently active
    function GetActive: Boolean;
    /// Port number property
    function GetPort: Word;
    procedure SetPort(Value: Word);
    property Active: Boolean read GetActive;
    property Port: Word read GetPort write SetPort;
  end;

  /// Procedure type for tool registration callback
  // - Called during server initialization to register bridge tools
  TRegisterToolsProc = procedure;

implementation

end.
