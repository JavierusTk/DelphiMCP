# Contributing to DelphiMCP

Thank you for your interest in contributing to DelphiMCP! We welcome contributions from the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Reporting Issues](#reporting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing Requirements](#testing-requirements)
- [Commit Message Format](#commit-message-format)
- [Branch Naming Conventions](#branch-naming-conventions)
- [Code Review Process](#code-review-process)
- [Community](#community)

---

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- **Be respectful** - Treat everyone with respect and consideration
- **Be collaborative** - Work together and help each other
- **Be professional** - Keep discussions focused and constructive
- **Be inclusive** - Welcome contributors of all backgrounds and skill levels

We do not tolerate harassment, discrimination, or inappropriate behavior of any kind.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Delphi 12** (RAD Studio 12) or later installed
- **Windows 10/11** development environment
- **Git** for version control
- **Delphi-MCP-Server** framework (see README.md for setup)
- Familiarity with Delphi/Object Pascal programming
- Understanding of the Model Context Protocol (MCP) - https://modelcontextprotocol.io/

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/DelphiMCP.git
   cd DelphiMCP
   ```

   *Replace `YOUR-USERNAME` with your GitHub username*

3. **Configure Delphi-MCP-Server path**:
   - See `Packages/CONFIGURATION.md` for path setup
   - Update paths in `Packages/DelphiMCP.dpk` and `Source/MCPserver/DelphiMCPserver.dpr`

4. **Build the project**:
   ```bash
   # Open in Delphi IDE
   # Or use command line:
   msbuild Packages/DelphiMCP.dproj /t:Build /p:Config=Release
   ```

5. **Verify compilation** - Ensure no errors

---

## How to Contribute

There are many ways to contribute to DelphiMCP:

### 1. Reporting Bugs
- Use GitHub Issues to report bugs
- Check existing issues first to avoid duplicates
- Provide detailed information (see "Reporting Issues" below)

### 2. Suggesting Features
- Open a GitHub Issue with the "Feature Request" label
- Explain the use case and proposed solution
- Discuss alternatives you've considered

### 3. Improving Documentation
- Fix typos, clarify explanations, add examples
- Update documentation when code changes
- Add tutorials or guides

### 4. Writing Code
- Fix bugs, implement features, optimize performance
- Follow code style guidelines
- Add tests and documentation
- Submit a pull request

### 5. Helping Others
- Answer questions in GitHub Issues
- Help troubleshoot problems
- Review pull requests
- Share your experience using DelphiMCP

---

## Reporting Issues

When reporting issues, please include:

### For Bug Reports

**Use the bug report template** (see `.github/ISSUE_TEMPLATE/bug_report.md`)

Required information:
- **Delphi Version**: e.g., RAD Studio 12.0, 12.1
- **Windows Version**: e.g., Windows 10 22H2, Windows 11
- **DelphiMCP Version**: e.g., 2.1.0
- **Delphi-MCP-Server Version**: if known

**Steps to Reproduce**:
1. Clear, numbered steps
2. Include code snippets if applicable
3. Attach relevant configuration files (settings.ini, etc.)

**Expected Behavior**:
- What you expected to happen

**Actual Behavior**:
- What actually happened
- Include full error messages
- Attach screenshots if relevant

**Additional Context**:
- Debug output (OutputDebugString messages)
- Log files
- Named pipe status
- Related issues or PRs

### For Feature Requests

**Use the feature request template**

Include:
- **Problem Statement**: What problem does this solve?
- **Proposed Solution**: How should it work?
- **Alternatives Considered**: What other approaches did you consider?
- **Use Cases**: Real-world scenarios where this would help
- **Breaking Changes**: Would this break existing functionality?

---

## Submitting Pull Requests

### Before You Start

1. **Check existing issues** - Is someone already working on this?
2. **Open an issue first** (for major changes) - Discuss the approach before implementing
3. **Keep PRs focused** - One feature or fix per PR
4. **Start small** - If you're new, start with documentation or small bug fixes

### Pull Request Process

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make your changes**:
   - Write clear, focused commits
   - Follow code style guidelines
   - Add documentation for new features
   - Update CHANGELOG.md if applicable

3. **Test thoroughly**:
   - Ensure project compiles without errors or warnings
   - Test with the example application
   - Verify your changes work as expected
   - Test edge cases

4. **Update documentation**:
   - Update README.md if needed
   - Update relevant documentation in `Documentation/`
   - Add code comments for complex logic
   - Update CHANGELOG.md with your changes

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**:
   - Use a clear, descriptive title
   - Fill out the PR template completely
   - Reference related issues: "Fixes #123" or "Relates to #456"
   - Describe what changed and why
   - Include testing notes

7. **Respond to feedback**:
   - Address review comments promptly
   - Push new commits to update the PR
   - Use `git commit --amend` for minor fixes (then force push)
   - Be open to suggestions and alternative approaches

### Pull Request Requirements

Before your PR can be merged:

- ✅ **Compiles successfully** - No errors or warnings
- ✅ **Tests pass** - All existing tests still work
- ✅ **Documentation updated** - Reflects your changes
- ✅ **Code style followed** - Consistent with existing code
- ✅ **Commit messages formatted** - Follow guidelines below
- ✅ **No merge conflicts** - Rebase on latest main if needed
- ✅ **Reviewed and approved** - By at least one maintainer

---

## Code Style Guidelines

### Delphi/Object Pascal Conventions

**Follow standard Delphi naming conventions**:

```pascal
// Unit names: PascalCase with dot notation
unit MCPServer.Tool.MyTool;

// Class names: T prefix + PascalCase
type
  TMyCustomTool = class(TMCPToolBase)

// Interface names: I prefix + PascalCase
type
  IMCPTool = interface

// Method names: PascalCase
procedure ExecuteTool;
function GetToolName: string;

// Private fields: F prefix + PascalCase
private
  FToolName: string;
  FEnabled: Boolean;

// Parameters and local variables: PascalCase (or aCamelCase for params)
procedure SetValue(const AValue: string);
var
  LocalValue: string;

// Constants: All caps with underscores or PascalCase
const
  DEFAULT_TIMEOUT = 5000;
  MaxRetries = 3;
```

### Formatting

**Indentation**:
- Use **2 spaces** per indent level (Delphi standard)
- Do not use tabs

**Line length**:
- Aim for **80-100 characters** per line
- Break long lines at logical points

**Blank lines**:
- One blank line between methods
- One blank line between logical sections
- No multiple consecutive blank lines

**Example**:
```pascal
procedure TMyTool.ExecuteWithParams(Params: TJSONObject; out Response: TJSONObject);
var
  ToolName: string;
  Result: Boolean;
begin
  // Validate parameters
  if not Assigned(Params) then
    raise EMCPException.Create('Parameters required');

  // Extract tool name
  ToolName := Params.GetValue<string>('name', '');
  if ToolName.IsEmpty then
    raise EMCPException.Create('Tool name is required');

  // Execute tool
  try
    Result := InternalExecute(ToolName, Params);

    // Build response
    Response := TJSONObject.Create;
    Response.AddPair('success', TJSONBool.Create(Result));
    Response.AddPair('tool', ToolName);
  except
    on E: Exception do
    begin
      // Log error and re-raise
      LogError('Tool execution failed: ' + E.Message);
      raise;
    end;
  end;
end;
```

### Comments

**Use comments for**:
- Complex algorithms or logic
- Non-obvious decisions or workarounds
- Public interface documentation
- TODO items (with issue number if applicable)

**Good comments**:
```pascal
// Check if pipe is still connected (may have been closed by target app)
if not IsConnected then
  Reconnect;

// TODO(#123): Implement retry logic for transient failures

/// <summary>
/// Executes an MCP tool via named pipe communication
/// </summary>
/// <param name="ToolName">Name of the tool to execute</param>
/// <param name="Params">JSON parameters for the tool</param>
/// <returns>JSON response from the tool execution</returns>
function ExecuteTool(const ToolName: string; Params: TJSONObject): TJSONObject;
```

**Avoid**:
```pascal
// Bad: Stating the obvious
i := i + 1;  // Increment i

// Bad: Commented-out code (remove it or explain why it's kept)
// OldMethod();
```

### File Organization

**Unit structure**:
```pascal
unit MCPServer.Tool.MyTool;

interface

uses
  System.SysUtils,
  System.JSON,
  MCPServer.Types;

type
  TMyTool = class(TMCPToolBase)
  private
    FEnabled: Boolean;
  protected
    function InternalExecute: Boolean; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

procedure RegisterMyTool;

implementation

// Implementation here

initialization
  // Optional: Auto-registration

end.
```

**Uses clause**:
- Group logically: System units, VCL units, third-party, project units
- One unit per line for readability
- Alphabetical order within each group (optional but nice)

```pascal
uses
  // System units
  System.Classes,
  System.JSON,
  System.SysUtils,
  // Framework units
  MCPServer.Types,
  MCPServer.Logger,
  // Project units
  MCPServer.Tool.Base;
```

---

## Testing Requirements

### Before Submitting a PR

**Compilation**:
- ✅ Compiles with **zero errors**
- ✅ Compiles with **zero warnings** (or justify any warnings)
- ✅ Test both **Debug** and **Release** configurations

**Functionality**:
- ✅ Test your changes with the example application
- ✅ Verify existing functionality still works
- ✅ Test edge cases (empty inputs, nil values, errors)
- ✅ Test with a real MCP client (Claude Code)

**Integration**:
- ✅ Test named pipe communication
- ✅ Verify JSON serialization/deserialization
- ✅ Test error handling and error messages
- ✅ Check debug output (OutputDebugString)

### Manual Testing Checklist

For changes to core components:

1. **Build and run DelphiMCPserver.exe**
2. **Verify server starts** - Check console output
3. **Test basic tools** - `mcp_hello`, `mcp_echo`, `mcp_time`
4. **Test debug capture** - If applicable
5. **Test with target application** - If applicable
6. **Connect Claude Code** - Verify tool discovery
7. **Execute tools from Claude** - Test functionality
8. **Check error handling** - Try invalid inputs
9. **Review debug output** - Look for errors or warnings
10. **Test cleanup** - Shutdown gracefully

### Automated Testing (Future)

We plan to add:
- Unit tests for core components
- Integration tests for pipe communication
- Mock MCP client for testing
- CI/CD pipeline for automated testing

Contributions to testing infrastructure are welcome!

---

## Commit Message Format

We use **Conventional Commits** format for clear, structured commit history.

### Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring (no functionality change)
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (build, dependencies, etc.)
- `style`: Code style changes (formatting, no logic change)
- `ci`: CI/CD configuration changes

### Scope (optional but recommended)

- `core`: Core framework components
- `tools`: Tool implementations
- `debug`: Debug capture system
- `proxy`: Dynamic proxy
- `pipe`: Named pipe client
- `docs`: Documentation
- `example`: Example applications
- `build`: Build system

### Examples

**Good commit messages**:
```
feat(tools): Add new screenshot capture tool

Implements a new tool for capturing screenshots of the target application.
Supports full screen, active window, and specific control capture.

Closes #42

---

fix(pipe): Handle connection timeout gracefully

Previously, pipe connection failures would crash the server.
Now logs error and allows retry on next tool invocation.

Fixes #67

---

docs(readme): Update quick start guide with troubleshooting

Added common issues section and clarified path configuration steps.

---

refactor(core): Extract JSON serialization to helper class

Reduces code duplication across tool implementations.
No functional changes.

---

chore(deps): Update Delphi-MCP-Server to v1.2.0

Required for new resource management features.
```

**Less ideal** (but acceptable):
```
fix: pipe timeout bug
docs: update readme
feat: add screenshot tool
```

### Commit Message Tips

- **Use imperative mood**: "Add feature" not "Added feature"
- **First line is 50 characters** (soft limit, 72 hard limit)
- **Body wraps at 72 characters**
- **Reference issues**: Use "Fixes #123", "Closes #456", "Relates to #789"
- **Explain why, not just what**: Context helps reviewers

---

## Branch Naming Conventions

Use descriptive branch names that indicate the purpose:

### Format

```
<type>/<short-description>
```

### Types

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Testing improvements
- `chore/` - Maintenance tasks

### Examples

```
feature/screenshot-capture
fix/pipe-timeout-handling
docs/improve-setup-guide
refactor/extract-json-helpers
test/add-pipe-unit-tests
chore/update-dependencies
```

### Tips

- **Use kebab-case** (lowercase with hyphens)
- **Be descriptive but concise**
- **Reference issue number** if applicable: `fix/pipe-timeout-67`
- **Delete branches** after merge

---

## Code Review Process

### For Contributors

**What to expect**:
- Reviews typically within **48-72 hours**
- Constructive feedback focused on code quality
- Suggestions for improvements
- Requests for clarification or testing

**How to respond**:
- Address all review comments (or explain why not)
- Push new commits or amend existing ones
- Mark conversations as resolved when addressed
- Ask questions if feedback is unclear
- Be open to alternative approaches

### For Reviewers

**What to check**:
- ✅ Code compiles without errors/warnings
- ✅ Follows code style guidelines
- ✅ Logic is correct and efficient
- ✅ Error handling is appropriate
- ✅ Documentation is updated
- ✅ Tests pass (when available)
- ✅ No security issues or vulnerabilities
- ✅ Commit messages are well-formatted

**Review guidelines**:
- Be respectful and constructive
- Explain the reasoning behind suggestions
- Acknowledge good work and improvements
- Focus on code quality, not personal style preferences
- Approve when requirements are met

---

## Community

### Getting Help

- **GitHub Issues**: Ask questions, report problems
- **Discussions**: General questions, ideas, showcase projects
- **Documentation**: Check docs first - most questions are answered there

### Staying Updated

- **Watch the repository** for notifications
- **Star the project** to show support
- **Follow releases** for updates and changelogs

### Recognition

We recognize and appreciate all contributions:
- Contributors listed in release notes
- Significant contributions acknowledged in README.md
- Active contributors may be invited as maintainers

---

## License

By contributing to DelphiMCP, you agree that your contributions will be licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

See [LICENSE](LICENSE) file for details.

---

## Questions?

If you have questions about contributing:

1. Check this guide and other documentation
2. Search existing GitHub Issues
3. Open a new issue with the "Question" label
4. Reach out to maintainers via GitHub

---

**Thank you for contributing to DelphiMCP!** 🎉

Your contributions help make this framework better for the entire Delphi community.
