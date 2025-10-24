# Claude Agent SDK Architecture Investigation Report

**Date:** October 24, 2025
**Investigator:** James Rochabrun
**Agent SDK Version:** 0.1.26 (updated from 0.1.10)
**CLI Version:** 2.0.26 (bundled within SDK)

---

## Executive Summary

This report documents the internal architecture of the `@anthropic-ai/claude-agent-sdk` TypeScript package, specifically how it integrates with the Claude Code CLI and handles system prompts. The investigation revealed a multi-layer subprocess architecture that explains why Claude maintains its "Claude Code" identity even when no explicit system prompt is configured.

---

## Key Findings

### 1. Multi-Layer Subprocess Architecture

The Agent SDK employs a **three-layer subprocess chain**:

```
Swift Application (Claw)
    ↓ spawns Node.js process
sdk-wrapper.mjs (custom Node.js bridge)
    ↓ imports and calls
@anthropic-ai/claude-agent-sdk (TypeScript SDK)
    ↓ spawns subprocess
node cli.js [args] (bundled Claude Code CLI)
    ↓ makes API calls
Anthropic API
```

**Code Reference:** `sdk.mjs:6495-6503`
```javascript
const spawnCommand = isNative ? pathToClaudeCodeExecutable : executable;
const spawnArgs = isNative ? [...executableArgs, ...args] :
                  [...executableArgs, pathToClaudeCodeExecutable, ...args];
this.child = spawn(spawnCommand, spawnArgs, {
  cwd,
  stdio: ["pipe", "pipe", stderrMode],
  signal: this.abortController.signal,
  env
});
```

### 2. The cli.js Component

**Location:** `/Users/jamesrochabrun/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk/cli.js`

**Characteristics:**
- **Size:** 9.5 MB
- **Format:** Minified/bundled Node.js executable
- **Version:** 2.0.26
- **Purpose:** Complete Claude Code CLI implementation
- **Line Length:** ~65,000 characters (single-line minified)

**Key Insight:** This is the ACTUAL Claude Code CLI, not a stub or wrapper. It contains the full system prompt and all Claude Code functionality.

### 3. System Prompt Behavior

**Default Behavior (No Custom System Prompt):**

When no `systemPrompt` is provided in options:

1. Swift → Node.js: No `systemPrompt` in JSON config
2. sdk-wrapper.mjs: `sdkOptions.systemPrompt` remains undefined
3. Agent SDK: Does NOT pass `--system-prompt` to cli.js
4. cli.js: Uses built-in default system prompt

**Code Reference:** `sdk.mjs:6412-6415`
```javascript
if (typeof customSystemPrompt === "string")
  args.push("--system-prompt", customSystemPrompt);
if (appendSystemPrompt)
  args.push("--append-system-prompt", appendSystemPrompt);
```

**Result:** Claude responds with "I'm Claude Code, an AI assistant built by Anthropic..." because cli.js has this baked into its default configuration.

### 4. Why Claude Code Identity Persists

**The "Claude Code" persona comes from cli.js's built-in default system prompt**, NOT from the Agent SDK wrapper or our custom configuration.

This explains why:
- ✅ No explicit system prompt needed for coding behavior
- ✅ Claude knows about file system tools and development workflows
- ✅ Responses are tailored for software development
- ✅ Tool usage instructions are pre-configured

### 5. Debug Logging Mystery Solved

**Why stderr from sdk-wrapper.mjs doesn't appear:**

**Code Reference:** `sdk.mjs:6498-6501`
```javascript
const stderrMode = env.DEBUG || stderr ? "pipe" : "ignore";
this.child = spawn(spawnCommand, spawnArgs, {
  cwd,
  stdio: ["pipe", "pipe", stderrMode],  // ← stderr set to "ignore"!
  signal: this.abortController.signal,
  env
});
```

**Explanation:** The subprocess's stderr is set to `"ignore"` mode unless:
- `env.DEBUG` is set to a truthy value, OR
- `stderr` option is explicitly provided

This is why our debug logs in sdk-wrapper.mjs (lines 63-72) don't appear in the console output.

**Solution:** Set `DEBUG=1` in environment variables to enable stderr capture.

---

## Architecture Flow Diagram

```
┌─────────────────────────────────────────────┐
│ Swift (AgentSDKBackend.swift)               │
│ - Creates JSON config                        │
│ - Spawns: node sdk-wrapper.mjs '<json>'     │
└─────────────┬───────────────────────────────┘
              │ JSON via command-line arg
              ↓
┌─────────────────────────────────────────────┐
│ sdk-wrapper.mjs                              │
│ - Parses JSON config                         │
│ - Calls query({ prompt, options })           │
└─────────────┬───────────────────────────────┘
              │ Function call
              ↓
┌─────────────────────────────────────────────┐
│ @anthropic-ai/claude-agent-sdk (sdk.mjs)    │
│ - Builds CLI args from options               │
│ - Spawns: node cli.js [args]                │
│ - stdio: ["pipe", "pipe", "ignore"]          │
└─────────────┬───────────────────────────────┘
              │ Subprocess spawn
              ↓
┌─────────────────────────────────────────────┐
│ cli.js (Claude Code CLI)                     │
│ - Reads --system-prompt (if provided)        │
│ - Falls back to built-in default             │
│ - Makes API calls to Anthropic               │
│ - Streams JSONL responses back               │
└─────────────┬───────────────────────────────┘
              │ HTTPS API calls
              ↓
┌─────────────────────────────────────────────┐
│ Anthropic API                                │
│ - Processes requests with system prompt      │
│ - Returns streaming responses                │
└─────────────────────────────────────────────┘
```

---

## Code Pointers

### Critical Source Locations

1. **Subprocess Spawn Logic**
   - File: `sdk.mjs`
   - Lines: 6495-6503
   - Purpose: Spawns cli.js as subprocess with configured stdio

2. **System Prompt Argument Construction**
   - File: `sdk.mjs`
   - Lines: 6412-6415
   - Purpose: Conditionally adds --system-prompt to CLI args

3. **Stderr Configuration**
   - File: `sdk.mjs`
   - Line: 6498
   - Purpose: Determines if stderr is captured or ignored

4. **Default Path Resolution**
   - File: `sdk.mjs`
   - Lines: 14149-14154
   - Purpose: Auto-detects cli.js location if not specified

```javascript
let pathToClaudeCodeExecutable = rest.pathToClaudeCodeExecutable;
if (!pathToClaudeCodeExecutable) {
  const filename = fileURLToPath(import.meta.url);
  const dirname = join(filename, "..");
  pathToClaudeCodeExecutable = join(dirname, "cli.js");
}
```

5. **Custom System Prompt Handling in Swift Bridge**
   - File: `sdk-wrapper.mjs`
   - Lines: 119-129
   - Purpose: Maps Swift options to SDK options, handles claude_code preset

```javascript
// System prompt handling
if (options.systemPrompt) {
  sdkOptions.systemPrompt = options.systemPrompt;
} else if (options.appendSystemPrompt) {
  // If only appendSystemPrompt is provided, use the preset with append
  sdkOptions.systemPrompt = {
    type: 'preset',
    preset: 'claude_code',
    append: options.appendSystemPrompt
  };
}
// If neither provided, sdkOptions.systemPrompt remains undefined
// → SDK doesn't pass --system-prompt to cli.js
// → cli.js uses its built-in default
```

---

## Implications for Claw Integration

### ✅ What Works Well

1. **Default Behavior is Correct**
   - No need to explicitly set system prompt for coding functionality
   - cli.js provides optimal Claude Code experience out of the box

2. **Approval Server Integration**
   - `permissionPromptToolName` correctly passed through all layers
   - MCP-based approval flow works as expected

3. **Performance**
   - Agent SDK is 2-10x faster than headless mode
   - Subprocess overhead is minimal

### ⚠️ Potential Concerns

1. **Debug Visibility**
   - stderr is silenced by default
   - Troubleshooting requires DEBUG=1 environment variable

2. **System Prompt Customization**
   - To use custom system prompt, must explicitly set in options
   - Appending to default requires understanding of cli.js behavior

3. **Version Dependencies**
   - cli.js is bundled with Agent SDK
   - Updating SDK updates the entire Claude Code CLI
   - No independent versioning

---

## Recommendations

### For Development

1. **Enable Debug Mode for Development Builds**
   ```swift
   // In AgentSDKBackend.swift
   env["DEBUG"] = "1"  // Enable stderr capture
   ```

2. **Document System Prompt Behavior**
   - Clarify that empty systemPrompt = Claude Code default
   - Provide examples for custom system prompts if needed

3. **Monitor Agent SDK Updates**
   - Current: 0.1.26
   - Check for updates regularly: `npm view @anthropic-ai/claude-agent-sdk version`
   - Update: `npm update -g @anthropic-ai/claude-agent-sdk`

### For Production

1. **Pin Agent SDK Version**
   - Consider locking to specific version for stability
   - Test updates in staging before production deployment

2. **Error Handling**
   - Implement robust error handling for subprocess failures
   - Handle cli.js not found scenarios gracefully

3. **Logging Strategy**
   - Decide if DEBUG mode should be enabled in production
   - Consider conditional stderr capture based on build configuration

---

## Version History

| Date | Agent SDK | CLI Version | Notes |
|------|-----------|-------------|-------|
| Oct 24, 2025 | 0.1.26 | 2.0.26 | Current (post-update) |
| Oct 23, 2025 | 0.1.10 | 2.0.10 | Initial investigation |

---

## References

- **Agent SDK npm:** https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk
- **Documentation:** https://docs.claude.com/en/api/agent-sdk/
- **System Prompts:** https://docs.claude.com/en/api/agent-sdk/modifying-system-prompts
- **Local Installation:** `~/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk/`

---

## Appendix: Verification Commands

```bash
# Check installed version
npm list @anthropic-ai/claude-agent-sdk -g --depth=0

# Check latest available version
npm view @anthropic-ai/claude-agent-sdk version

# Update to latest
npm update -g @anthropic-ai/claude-agent-sdk

# Verify cli.js exists
ls -lh ~/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk/cli.js

# Check cli.js version
head -n 5 ~/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk/cli.js
```

---

**Report Generated:** October 24, 2025
**Purpose:** Technical reference for Claw development team
**Status:** Complete ✅
