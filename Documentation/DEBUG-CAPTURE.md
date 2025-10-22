# Debug Capture System Documentation

## Overview

The DelphiMCP framework includes a powerful debug output capture system that monitors Windows `OutputDebugString` messages from all processes or specific targets. This is invaluable for debugging, testing, and monitoring Delphi applications.

## How It Works

```
Windows Application
    ↓ OutputDebugString("Debug message")
Windows Kernel (DBWIN_BUFFER shared memory)
    ↓
Debug Monitor Thread (DebugView-style)
    ↓
TDebugCaptureSession (filtering, buffering)
    ↓
MCP Tool (get_debug_messages)
    ↓
Claude Code (AI analysis and display)
```

## Available Tools

### 1. `start_debug_capture`

Begin capturing debug output messages.

**Parameters**:
```json
{
  "buffersize": 10000,              // Max messages to keep (default: 10000)
  "allowedprocessids": [1234, 5678], // Only these PIDs (empty = all)
  "blockedprocessids": [9999],       // Never capture these PIDs
  "autoresolveprocessnames": true,   // Resolve PID → process name
  "filtercurrentprocess": false      // Filter out MCP server itself
}
```

**Returns**:
```json
{
  "sessionid": "abc123",
  "started": "2025-10-07T10:30:00Z"
}
```

**Example**:
```
Claude, start capturing debug output from all processes
```

### 2. `get_debug_messages`

Retrieve captured debug messages with filtering.

**Parameters**:
```json
{
  "sessionid": "abc123",                    // Required: from start_debug_capture
  "limit": 100,                             // Max messages (default: 100)
  "offset": 0,                              // Pagination offset (default: 0)
  "processid": 1234,                        // Filter by PID
  "processname": "YourApp.exe",            // Filter by process name
  "messagecontains": "[ERROR]",             // Substring filter
  "messageregex": "\\[MCP\\].*",           // Regex filter
  "sincetimestamp": "2025-10-07T10:30:00Z" // Only messages after this
}
```

**Returns**:
```json
{
  "sessionid": "abc123",
  "messages": [
    {
      "timestamp": "2025-10-07T10:30:15.123Z",
      "processid": 1234,
      "processname": "YourApp.exe",
      "message": "[MCP] Server thread started"
    }
  ],
  "total": 1543,
  "returned": 100
}
```

**Example**:
```
Claude, get the last 50 debug messages from YourApp.exe
```

### 3. `stop_debug_capture`

Stop capturing debug output and clean up session.

**Parameters**:
```json
{
  "sessionid": "abc123"  // Required
}
```

**Returns**:
```json
{
  "success": true,
  "stopped": "2025-10-07T11:00:00Z",
  "totalmessages": 1543
}
```

**Example**:
```
Claude, stop the debug capture session
```

### 4. `get_capture_status`

Get current capture session statistics.

**Parameters**:
```json
{
  "sessionid": "abc123"  // Required
}
```

**Returns**:
```json
{
  "sessionid": "abc123",
  "started": "2025-10-07T10:30:00Z",
  "paused": false,
  "totalmessages": 1543,
  "buffersize": 10000,
  "bufferusage": 0.1543,
  "processes": 5,
  "captureactive": true
}
```

**Example**:
```
Claude, check the status of the debug capture
```

### 5. `pause_resume_capture`

Pause or resume capture, optionally updating filters.

**Parameters**:
```json
{
  "sessionid": "abc123",          // Required
  "action": "pause",               // "pause" or "resume"
  "updateallowedprocessids": [],   // Update allowed PIDs (optional)
  "updateblockedprocessids": []    // Update blocked PIDs (optional)
}
```

**Returns**:
```json
{
  "success": true,
  "action": "pause",
  "sessionid": "abc123"
}
```

**Example**:
```
Claude, pause the debug capture temporarily
```

### 6. `get_process_summary`

Get statistics about processes generating debug output.

**Parameters**:
```json
{
  "sessionid": "abc123",           // Required
  "timewindowminutes": 10          // Time window (0 = all time, default: 0)
}
```

**Returns**:
```json
{
  "sessionid": "abc123",
  "processes": [
    {
      "processid": 1234,
      "processname": "YourApp.exe",
      "messagecount": 1200,
      "firstmessage": "2025-10-07T10:30:00Z",
      "lastmessage": "2025-10-07T11:00:00Z"
    },
    {
      "processid": 5678,
      "processname": "DelphiMCPserver.exe",
      "messagecount": 343,
      "firstmessage": "2025-10-07T10:29:00Z",
      "lastmessage": "2025-10-07T11:00:00Z"
    }
  ],
  "totalprocesses": 2,
  "totalmessages": 1543
}
```

**Example**:
```
Claude, show me which processes are generating debug output
```

## Common Use Cases

### 1. Monitor Application Startup

```
Claude, please:
1. Start capturing debug output
2. Execute the Internal "SYSTEM.STARTUP"
3. Wait for startup to complete
4. Get all debug messages from YourApp.exe
5. Show me any errors or warnings
```

### 2. Debug Feature Execution

```
Claude:
1. Start debug capture
2. Execute Internal "GESTION.CLIENTES"
3. Fill in form with test data
4. Click save
5. Get debug messages containing "[ERROR]" or "[WARNING]"
6. Stop capture
```

### 3. Monitor Performance Issues

```
Claude:
1. Start debug capture for YourApp.exe only
2. Execute the slow operation
3. Get debug messages with "[PERF]" or "[TIMING]"
4. Analyze timing patterns
```

### 4. Correlate UI Actions with Debug Output

```
Claude:
1. Start debug capture
2. Take screenshot of current form
3. Click the problematic button
4. Get debug messages from the last 10 seconds
5. Show correlation between UI action and debug output
```

### 5. Long-Running Monitor

```
Claude:
1. Start debug capture with 50000 message buffer
2. Every 5 minutes, get process summary
3. Alert if any process shows error patterns
4. Continue monitoring for 1 hour
```

## Filtering Strategies

### By Process

```json
// Only capture from specific application
{
  "allowedprocessids": [1234]
}

// Exclude noisy processes
{
  "blockedprocessids": [9999, 8888]
}
```

### By Content

```json
// Substring filter (case-insensitive)
{
  "messagecontains": "[ERROR]"
}

// Regex filter (powerful but slower)
{
  "messageregex": "\\[(ERROR|WARNING)\\].*timeout"
}
```

### By Time

```json
// Only messages since specific time
{
  "sincetimestamp": "2025-10-07T10:30:00Z"
}

// Combined with pagination
{
  "sincetimestamp": "2025-10-07T10:30:00Z",
  "limit": 100,
  "offset": 0
}
```

## Performance Considerations

### Buffer Management

- **Default buffer**: 10,000 messages
- **Memory per message**: ~200 bytes average
- **Total memory**: ~2 MB for 10,000 messages

**Recommendation**: Use 10,000-50,000 for most scenarios.

### Process Name Resolution

- **Enabled by default**: `autoresolveprocessnames=true`
- **Cost**: ~1-2ms per new PID
- **Benefit**: Easier filtering and analysis

**Recommendation**: Keep enabled unless capturing from hundreds of processes.

### Filtering Performance

| Filter Type | Performance | Use Case |
|-------------|-------------|----------|
| Process ID | Fast (~1µs) | Known target process |
| Process Name | Fast (~5µs) | Human-readable filtering |
| Substring | Medium (~50µs) | Simple text search |
| Regex | Slow (~500µs) | Complex pattern matching |

**Recommendation**: Use substring when possible, regex only when necessary.

## Integration with Target Applications

### Autonomous Bug Investigation

```
User: "The save button doesn't work"

Claude:
1. start_debug_capture
2. execute-internal code="GESTION.CLIENTES"
3. get-form-info form=active
4. set-control-value (fill test data)
5. click-button control="btnGuardar"
6. get_debug_messages messagecontains="[ERROR]"
7. take-screenshot
8. stop_debug_capture

Result: Found error "[ERROR] Validation failed: CIF required"
```

### Performance Analysis

```
User: "Why is the report so slow?"

Claude:
1. start_debug_capture
2. execute-internal code="GESTION.INFORMES.VENTAS"
3. execute-command command="RANGOFECHAS.PERIODO|ESTEMES"
4. click-button control="btnGenerar"
5. get_debug_messages messageregex="\\[PERF\\]|\\[SQL\\]"
6. stop_debug_capture

Result: Identified slow SQL query taking 15 seconds
```

## Troubleshooting

### No Messages Captured

**Symptom**: `get_debug_messages` returns empty array

**Solutions**:
1. Verify target app is using `OutputDebugString`
2. Check process filters (allowed/blocked)
3. Verify capture is not paused
4. Check time window filter

### Missing Process Names

**Symptom**: Process names show as "Unknown"

**Solutions**:
1. Enable `autoresolveprocessnames: true`
2. Run bridge with elevated permissions (some PIDs require admin)
3. Check process still exists (not terminated)

### High Memory Usage

**Symptom**: Bridge process using lots of RAM

**Solutions**:
1. Reduce `buffersize` parameter
2. Stop/restart capture periodically
3. Use more aggressive filtering
4. Paginate results (smaller `limit`)

### Slow Response

**Symptom**: `get_debug_messages` takes long time

**Solutions**:
1. Use `processid` or `processname` filters
2. Avoid complex regex patterns
3. Reduce `limit` parameter
4. Use `sincetimestamp` to skip old messages

## Security Considerations

### Process Access

- Debug capture can see output from **all processes** user has access to
- **Sensitive data** may appear in debug output
- **Production use**: Carefully filter processes

### Data Retention

- Messages stored in memory only (not persisted)
- Session ends when bridge stops or `stop_debug_capture` called
- **No disk logging** by default

### Multi-User

- Each session has unique ID
- Sessions are process-local (not shared across bridge instances)
- **No cross-session access**

## Advanced Techniques

### Continuous Monitoring

```pascal
// Pseudo-code for Claude Code autonomous monitoring
LOOP:
  1. start_debug_capture (if not started)
  2. WAIT 60 seconds
  3. get_debug_messages messagecontains="[CRITICAL]"
  4. IF messages found THEN alert user
  5. GOTO LOOP
```

### Correlation with Screenshots

```
1. start_debug_capture
2. take-screenshot target=active output=before.png
3. (perform action)
4. take-screenshot target=active output=after.png
5. get_debug_messages sincetimestamp=(timestamp of action)
6. Correlate visual changes with debug output
```

### Multi-Process Debugging

```
1. start_debug_capture (capture all processes)
2. Execute complex operation (spawns multiple processes)
3. get_process_summary
4. FOR EACH process:
     get_debug_messages processname=(process)
     Analyze messages
5. stop_debug_capture
```

## API Reference Summary

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `start_debug_capture` | Begin capture | buffersize, process filters |
| `get_debug_messages` | Retrieve messages | sessionid, filters, pagination |
| `stop_debug_capture` | End capture | sessionid |
| `get_capture_status` | Session stats | sessionid |
| `pause_resume_capture` | Pause/resume | sessionid, action |
| `get_process_summary` | Process stats | sessionid, timewindow |

## Examples for Claude Code

### Basic Capture

```
Claude, start capturing debug output, then execute the About dialog and show me any debug messages
```

### Filtered Capture

```
Claude, capture debug output from YourApp.exe only, filter for messages containing "MCP", and show me the results
```

### Time-Based Capture

```
Claude, start capture, wait 30 seconds, then show me all debug messages from the last 30 seconds
```

### Error Investigation

```
Claude, capture debug output, execute the failing operation, then show me any error or warning messages
```

---

**Version**: 2.1
**Last Updated**: 2025-10-07
**Status**: Production Ready
**Integration**: Fully compatible with DelphiMCP automation framework
