# Migrating from Headless to Agent SDK Backend

A simple guide for existing ClaudeCodeSDK users who want to switch to the faster Agent SDK backend.

---

## Why Migrate?

The Agent SDK backend offers:
- **2-10x faster** for repeated queries (session reuse)
- **Better session management**
- **Advanced features** like custom tools and hooks
- **Direct TypeScript SDK access** without CLI overhead

## Prerequisites

### 1. Check Your Current Setup

You're currently using the **headless backend** if your code looks like this:

```swift
let client = try ClaudeCodeClient()
// OR
var config = ClaudeCodeConfiguration.default
config.backend = .headless  // This is the default
```

### 2. Install Required Dependencies

The Agent SDK backend requires:

**Node.js 18+** (you likely already have this for the headless backend):
```bash
node --version  # Should show v18.0.0 or higher
```

**Agent SDK** (new requirement):
```bash
npm install -g @anthropic-ai/claude-agent-sdk
```

**Verify installation:**
```bash
npm list -g @anthropic-ai/claude-agent-sdk
# Should show: @anthropic-ai/claude-agent-sdk@x.x.x
```

---

## Migration Steps

### Step 1: Update Your Configuration (ONE LINE!)

**Before (Headless):**
```swift
let client = try ClaudeCodeClient()
```

**After (Agent SDK):**
```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK  // 👈 Only change needed!

let client = try ClaudeCodeClient(configuration: config)
```

That's it! The client API remains exactly the same.

---

### Step 2: Update Output Format

**IMPORTANT:** Agent SDK only supports **streaming output**.

**Before (Headless):**
```swift
// Headless supports: .text, .json, .streamJson
let result = try await client.runSinglePrompt(
    prompt: "Hello",
    outputFormat: .json,  // ❌ Won't work with Agent SDK
    options: nil
)
```

**After (Agent SDK):**
```swift
// Agent SDK only supports: .streamJson
let result = try await client.runSinglePrompt(
    prompt: "Hello",
    outputFormat: .streamJson,  // ✅ Required for Agent SDK
    options: nil
)
```

---

### Step 3: Handle Streaming Results

If you were using `.json` or `.text` with headless, you need to handle streaming:

**Before (Headless with .json):**
```swift
let result = try await client.runSinglePrompt(
    prompt: "Write a function",
    outputFormat: .json,
    options: nil
)

if case .json(let data) = result {
    print("Response: \(String(data: data, encoding: .utf8) ?? "")")
}
```

**After (Agent SDK with .streamJson):**
```swift
let result = try await client.runSinglePrompt(
    prompt: "Write a function",
    outputFormat: .streamJson,
    options: nil
)

if case .stream(let publisher) = result {
    for await message in publisher.values {
        print(message)  // Each chunk as it arrives
    }
}
```

---

## Complete Examples

### Example 1: Basic Migration

**Headless (Before):**
```swift
import ClaudeCodeSDK

func askClaude() async throws {
    let client = try ClaudeCodeClient()

    let result = try await client.runSinglePrompt(
        prompt: "What is Swift?",
        outputFormat: .json,
        options: nil
    )

    if case .json(let data) = result {
        print(String(data: data, encoding: .utf8) ?? "")
    }
}
```

**Agent SDK (After):**
```swift
import ClaudeCodeSDK

func askClaude() async throws {
    var config = ClaudeCodeConfiguration.default
    config.backend = .agentSDK  // 👈 Add this

    let client = try ClaudeCodeClient(configuration: config)

    let result = try await client.runSinglePrompt(
        prompt: "What is Swift?",
        outputFormat: .streamJson,  // 👈 Change this
        options: nil
    )

    // 👇 Handle streaming
    if case .stream(let publisher) = result {
        for await message in publisher.values {
            print(message)
        }
    }
}
```

---

### Example 2: With Options

**Headless (Before):**
```swift
var options = ClaudeCodeOptions()
options.model = "claude-sonnet-4-20250514"
options.maxTokens = 2000
options.systemPrompt = "You are helpful"

let client = try ClaudeCodeClient()

let result = try await client.runSinglePrompt(
    prompt: "Explain async/await",
    outputFormat: .json,
    options: options
)
```

**Agent SDK (After):**
```swift
var options = ClaudeCodeOptions()
options.model = "claude-sonnet-4-20250514"
options.maxTokens = 2000
options.systemPrompt = "You are helpful"

var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK  // 👈 Add this

let client = try ClaudeCodeClient(configuration: config)

let result = try await client.runSinglePrompt(
    prompt: "Explain async/await",
    outputFormat: .streamJson,  // 👈 Change this
    options: options
)

// 👇 Handle streaming
if case .stream(let publisher) = result {
    for await message in publisher.values {
        print(message)
    }
}
```

**All your options work the same!** Model, tokens, system prompts, MCP servers, tools - everything is compatible.

---

### Example 3: Conversation Continuation

**Works identically for both backends:**

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK  // Or .headless

let client = try ClaudeCodeClient(configuration: config)

// First message
let result1 = try await client.runSinglePrompt(
    prompt: "My name is James",
    outputFormat: .streamJson,
    options: nil
)

if case .stream(let publisher) = result1 {
    for await message in publisher.values {
        print(message)
    }
}

// Continue conversation
let result2 = try await client.continueConversation(
    prompt: "What's my name?",
    outputFormat: .streamJson,
    options: nil
)

if case .stream(let publisher) = result2 {
    for await message in publisher.values {
        print(message)
    }
}
```

---

## Validation & Troubleshooting

### Validate Your Setup

Run this code to check if everything is configured correctly:

```swift
import ClaudeCodeSDK

func validateSetup() async {
    var config = ClaudeCodeConfiguration.default
    config.backend = .agentSDK

    do {
        let client = try ClaudeCodeClient(configuration: config)
        print("✅ Agent SDK backend ready!")

        let isValid = try await client.validateSetup()
        print("Setup valid: \(isValid)")

    } catch ClaudeCodeError.invalidConfiguration(let message) {
        print("❌ Setup failed: \(message)")
    } catch {
        print("❌ Error: \(error)")
    }
}
```

### Common Errors

**Error: "Node.js not found"**
```bash
# Install Node.js
brew install node
# OR download from: https://nodejs.org
```

**Error: "Agent SDK is not installed"**
```bash
npm install -g @anthropic-ai/claude-agent-sdk
```

**Error: "Agent SDK backend only supports stream-json output format"**
```swift
// Change this:
outputFormat: .json  // ❌

// To this:
outputFormat: .streamJson  // ✅
```

---

## Runtime Backend Switching

You can switch backends at runtime without creating a new client:

```swift
var config = ClaudeCodeConfiguration.default
config.backend = .headless

let client = try ClaudeCodeClient(configuration: config)

// Use headless
let result1 = try await client.runSinglePrompt(
    prompt: "Test",
    outputFormat: .json,
    options: nil
)

// Switch to Agent SDK
client.configuration.backend = .agentSDK

// Now using Agent SDK (automatically validates and switches)
let result2 = try await client.runSinglePrompt(
    prompt: "Test",
    outputFormat: .streamJson,  // Remember to use .streamJson
    options: nil
)
```

**Note:** If validation fails, the client gracefully reverts to the previous backend.

---

## What's Compatible?

### ✅ Fully Compatible (No Changes Needed)

- `ClaudeCodeOptions` - All properties work the same
- `model`, `maxTokens`, `temperature`
- `systemPrompt`, `appendSystemPrompt`
- `mcpServers` configuration
- `tools` and custom tools
- `timeout` and `abortController`
- `continueConversation()` and `resumeConversation()`
- All MCP server types (stdio, SSE)

### ⚠️ Differences

| Feature | Headless | Agent SDK |
|---------|----------|-----------|
| Output formats | `.text`, `.json`, `.streamJson` | `.streamJson` only |
| Session listing | ✅ `listSessions()` | ❌ Returns empty array |
| Process overhead | Higher (spawns CLI each time) | Lower (session reuse) |
| Speed | Baseline | 2-10x faster |

---

## Quick Migration Checklist

- [ ] Install Agent SDK: `npm install -g @anthropic-ai/claude-agent-sdk`
- [ ] Update config: `config.backend = .agentSDK`
- [ ] Change output format to `.streamJson`
- [ ] Update result handling to process streams
- [ ] Test with `validateSetup()`
- [ ] Run your existing workflows

---

## Need Help?

**Quick test tool:**
```bash
cd /path/to/ClaudeCodeSDK
swift run QuickTest
```

This will validate both backends and show you what's working.

**Documentation:**
- Full migration guide: `MIGRATION.md`
- Architecture details: `CLAUDE_AGENT_SDK_MIGRATION_ANALYSIS.md`
- Report issues: [GitHub Issues](https://github.com/jamesrochabrun/ClaudeCodeSDK/issues)

---

## Summary

**To migrate from headless to Agent SDK, you need to change just TWO things:**

1. **Set backend:** `config.backend = .agentSDK`
2. **Use streaming:** `outputFormat: .streamJson`

Everything else stays the same! Your options, MCP servers, tools, and workflow all work identically.

**Benefits:**
- ✅ 2-10x faster performance
- ✅ Better session management
- ✅ Access to advanced SDK features
- ✅ Same familiar API

**Installation:**
```bash
npm install -g @anthropic-ai/claude-agent-sdk
```

**Code change:**
```swift
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK  // That's it!
```

Happy coding! 🚀
