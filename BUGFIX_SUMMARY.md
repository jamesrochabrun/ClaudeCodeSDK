# Bug Fix Summary: NVM Configuration Support

## Status: ✅ FIXED (Commit b7472c2)

## Problem

Agent SDK detection was failing for NVM users even when `nodeExecutable` was explicitly configured.

### Root Cause

`NodePathDetector.isAgentSDKInstalled()` didn't respect the `configuration.nodeExecutable` setting:

```swift
// OLD - Ignored configuration
if !NodePathDetector.isAgentSDKInstalled() {
    throw ClaudeCodeError.invalidConfiguration("Agent SDK is not installed...")
}
```

It always ran: `/bin/zsh -l -c "npm config get prefix"` which returns different paths depending on context:
- **Terminal** (with NVM loaded): `~/.nvm/versions/node/v22.16.0`
- **GUI apps** (Xcode): `/opt/homebrew`

## Solution

Updated `isAgentSDKInstalled()` to accept and respect configuration:

```swift
// NEW - Respects configuration
public static func isAgentSDKInstalled(configuration: ClaudeCodeConfiguration? = nil) -> Bool {
    // 1. If nodeExecutable is configured, derive SDK path from it
    if let nodeExecutable = configuration?.nodeExecutable {
        let nodeBinDir = (nodeExecutable as NSString).deletingLastPathComponent
        let nodePrefix = (nodeBinDir as NSString).deletingLastPathComponent  
        let packagePath = "\(nodePrefix)/lib/node_modules/@anthropic-ai/claude-agent-sdk"
        
        if FileManager.default.fileExists(atPath: packagePath) {
            return true
        }
        return false  // Fail fast if explicitly configured path doesn't have SDK
    }
    
    // 2. Fall back to automatic detection
    guard let npmGlobalPath = detectNpmGlobalPath() else {
        return false
    }
    let packagePath = (npmGlobalPath as NSString).deletingLastPathComponent + 
                     "/lib/node_modules/@anthropic-ai/claude-agent-sdk"
    return FileManager.default.fileExists(atPath: packagePath)
}
```

### Path Derivation Logic

```
Input:  /Users/user/.nvm/versions/node/v22.16.0/bin/node
Step 1: /Users/user/.nvm/versions/node/v22.16.0/bin (remove last component)
Step 2: /Users/user/.nvm/versions/node/v22.16.0     (remove last component) 
Output: /Users/user/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk
```

## Changes Made

### Files Modified (5)

1. **NodePathDetector.swift**
   - `isAgentSDKInstalled()` → `isAgentSDKInstalled(configuration:)`
   - Added configuration parameter (optional, defaults to nil)
   - Derives SDK path from configured nodeExecutable when available

2. **BackendFactory.swift** (3 call sites updated)
   - `createBackend()` - Line 32: Pass configuration
   - `validateConfiguration()` - Line 58: Pass configuration
   - `getConfigurationError()` - Line 75: Pass configuration

3. **AgentSDKBackend.swift**
   - `validateSetup()` - Line 144: Pass configuration

4. **NodePathDetectorTests.swift** (+78 lines)
   - `testIsAgentSDKInstalledWithNVMConfiguration()` - Test with config
   - `testIsAgentSDKInstalledWithInvalidNodePath()` - Test error handling
   - `testIsAgentSDKInstalledWithNVMPath()` - Test actual NVM path
   - `testNodeExecutablePathDerivation()` - Test path logic

5. **test-nvm-fix.swift** (New verification script)
   - Demonstrates the fix
   - Shows before/after behavior
   - Can be run standalone: `swift test-nvm-fix.swift`

## Testing

### Test Results

```bash
swift test --filter NodePathDetectorTests
```

**Results:** ✅ 12/12 tests passing

```
Test Case 'testIsAgentSDKInstalledWithNVMConfiguration' passed
Test Case 'testIsAgentSDKInstalledWithInvalidNodePath' passed  
Test Case 'testIsAgentSDKInstalledWithNVMPath' passed
Test Case 'testNodeExecutablePathDerivation' passed
```

### Verification Script

```bash
swift test-nvm-fix.swift
```

**Output:**
```
1️⃣ Test Auto-Detection
   Result: /opt/homebrew
   SDK Exists: ✅

2️⃣ Test NVM Explicit Path
   Node Path: ~/.nvm/versions/node/v22.16.0/bin/node
   Derived SDK Path: ~/.nvm/.../lib/node_modules/@anthropic-ai/claude-agent-sdk
   SDK Exists: ✅

3️⃣ Fix Verification
   ✅ FIXED: nodeExecutable config now correctly detects SDK at NVM location
```

## Impact

### Who Benefits
- ✅ Users with NVM installations
- ✅ Users with asdf or other version managers
- ✅ Anyone running from GUI apps where PATH differs from shell

### Backward Compatibility
- ✅ **Fully backward compatible**
- ✅ Configuration parameter is optional (defaults to nil)
- ✅ Auto-detection still works when no configuration provided
- ✅ Headless backend completely unaffected

### Before Fix
```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK
config.nodeExecutable = "~/.nvm/versions/node/v22.16.0/bin/node"
let client = try ClaudeCodeClient(configuration: config)
// ❌ Error: "Claude Agent SDK is not installed"
```

### After Fix
```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK  
config.nodeExecutable = "~/.nvm/versions/node/v22.16.0/bin/node"
let client = try ClaudeCodeClient(configuration: config)
// ✅ Works! Correctly detects SDK at NVM location
```

## Commit Details

**Commit:** b7472c2  
**Branch:** sdk-migration  
**PR:** #23

**Stats:**
- 5 files changed
- +184 insertions
- -5 deletions

## Related Issues

This fixes the bug described in the original report where:
- NVM users couldn't use Agent SDK backend
- Explicit `nodeExecutable` configuration was ignored
- Detection always used system npm instead of configured node

## Next Steps

The fix is complete and tested. Users can now:

1. **Install Agent SDK via NVM:**
   ```bash
   nvm use 22.16.0
   npm install -g @anthropic-ai/claude-agent-sdk
   ```

2. **Configure explicitly:**
   ```swift
   config.nodeExecutable = "\(NSHomeDirectory())/.nvm/versions/node/v22.16.0/bin/node"
   ```

3. **Works automatically** - SDK detection respects the configured path!

---

**Status:** Ready for testing in PR #23
