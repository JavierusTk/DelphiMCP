unit AutomationDescribable;

{
  Automation Describable Interface

  PURPOSE:
  - Allow forms to self-describe their structure for AI automation
  - Provide hierarchical control tree
  - Support lazy loading for complex forms

  DESIGN PATTERN:
  - Forms implement this interface to expose automation-friendly structure
  - JSON format allows AI to understand form layout
  - Root parameter enables drill-down for complex hierarchies

  USAGE:
  - Implement in TForm descendants (optional)
  - Call DescribeAsJSON() to get full form structure
  - Call DescribeAsJSON('pnlDatos') to get specific panel details
  - If not implemented, RTTI-based introspection is used automatically

  JSON SCHEMA EXAMPLE:
  Returns hierarchical form structure with controls, state, and bounds information
}

interface

type
  {$M+}
  IAutomationDescribable = interface
    ['{8B7A5C9D-4E3F-2A1B-6C8D-9E0F1A2B3C4D}']

    // Self-describe structure as JSON
    // Root = '' returns overview (controls at top level only)
    // Root = 'controlName' returns detailed tree starting from that control
    function DescribeAsJSON(const Root: string = ''): string;

    // Get version of description format (for compatibility)
    function GetDescriptionVersion: Integer;
  end;
  {$M-}

implementation

end.
