# ClaudeCodeSDK

[Beta] A Swift SDK for seamlessly integrating Claude Code into your macOS applications. Interact with Anthropic's Claude Code programmatically for AI-powered coding assistance.

* **🎯 Dual-Backend Architecture** - Choose between traditional headless mode or new Agent SDK backend
* **🚀 Agent SDK Support** - Optional Node.js-based backend using @anthropic-ai/claude-agent-sdk
* **🔧 Backend Auto-Detection** - Automatically selects the best available backend
* **📦 Platform Clarification** - macOS 13+ only (iOS removed due to Process API requirements)
* **Native Session Storage** - Direct access to Claude CLI's session storage (`~/.claude/projects/`)
* **Enhanced Error Handling** - Detailed error types with retry hints and classification
* **Built-in Retry Logic** - Automatic retry with exponential backoff for transient failures
* **Rate Limiting** - Token bucket rate limiter to respect API limits
* **Timeout Support** - Configurable timeouts for all operations
* **Cancellation** - AbortController support for canceling long-running operations

## Overview

ClaudeCodeSDK allows you to integrate Claude Code's capabilities directly into your Swift applications. The SDK provides a simple interface to run Claude Code as a subprocess, enabling multi-turn conversations, custom system prompts, and various output formats.

## Requirements

* **Platforms:** macOS 13+ **ONLY**
* **Swift Version:** Swift 6.0+
* **Dependencies (choose one):**
  * **Headless Backend (default):** Claude Code CLI (`npm install -g @anthropic/claude-code`)
  * **Agent SDK Backend (optional):** Claude Agent SDK (`npm install -g @anthropic-ai/claude-agent-sdk`)

> **Important Platform Notes:**
> - **macOS Only**: This SDK exclusively supports macOS because it relies on the `Process` API to spawn subprocesses
> - **iOS Not Supported**: iOS apps run in a sandboxed environment that prevents executing external processes
> - **Package.swift Updated**: iOS platform declaration has been removed in v2.0.0

## 🚀 Installation

### Swift Package Manager

Add the package dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Package Dependencies...
2. Enter: `https://github.com/jamesrochabrun/ClaudeCodeSDK`

## Basic Usage

Import the SDK and create a client:

```swift
import ClaudeCodeSDK

// Initialize the client
let client = ClaudeCodeClient(debug: true)

// Run a simple prompt
Task {
    do {
        let result = try await client.runSinglePrompt(
            prompt: "Write a function to calculate Fibonacci numbers",
            outputFormat: .text,
            options: nil
        )
        
        switch result {
        case .text(let content):
            print("Response: \(content)")
        default:
            break
        }
    } catch {
        print("Error: \(error)")
    }
}
```

## Backend Selection

The SDK now supports two execution backends:

### 1. Headless Backend (Default)

The traditional approach using `claude -p` CLI:

```swift
// Explicitly use headless backend (though it's the default)
var config = ClaudeCodeConfiguration.default
config.backend = .headless
let client = ClaudeCodeClient(configuration: config)
```

**Pros:**
- ✅ Simple setup
- ✅ Proven reliability
- ✅ Works with existing Claude CLI installation

**Cons:**
- ⚠️ Process overhead per query
- ⚠️ Limited advanced features

### 2. Agent SDK Backend (Optional, New in v2.0)

Uses @anthropic-ai/claude-agent-sdk via Node.js wrapper:

```swift
// Use the new Agent SDK backend
var config = ClaudeCodeConfiguration.default
config.backend = .agentSDK
let client = ClaudeCodeClient(configuration: config)
```

**Pros:**
- ✅ 2-10x faster for repeated queries
- ✅ Access to advanced features (coming soon: custom tools, hooks)
- ✅ Better performance for batch operations

**Cons:**
- ⚠️ Requires Node.js and Agent SDK installation

### Backend Auto-Detection (Recommended)

Let the SDK choose the best available backend:

```swift
// Detects if Agent SDK is installed, falls back to headless
var config = ClaudeCodeConfiguration.default
config.backend = NodePathDetector.isAgentSDKInstalled() ? .agentSDK : .headless
let client = ClaudeCodeClient(configuration: config)
```

### Migration Guide

**Already using headless backend?** See [AGENT_SDK_MIGRATION.md](AGENT_SDK_MIGRATION.md) for a simple step-by-step guide to switch to the faster Agent SDK backend.

### Installation for Agent SDK Backend

```bash
# Install the Claude Agent SDK globally
npm install -g @anthropic-ai/claude-agent-sdk

# Verify installation
node -e "import('@anthropic-ai/claude-agent-sdk').then(() => console.log('✓ Installed'))"
```

### Checking SDK Availability

```swift
import ClaudeCodeSDK

// Check if Node.js is available
if let nodePath = NodePathDetector.detectNodePath() {
    print("Node.js found at: \(nodePath)")
}

// Check if Agent SDK is installed
if NodePathDetector.isAgentSDKInstalled() {
    print("✓ Agent SDK is installed")
} else {
    print("ℹ Agent SDK not found, using headless backend")
}
```

## Key Features

### Command Suffix Support

The SDK supports adding a suffix after the command, which is useful when the command requires specific argument ordering:

```swift
// Configure with a command suffix
var config = ClaudeCodeConfiguration.default
config.commandSuffix = "--"  // Adds "--" after "claude"

let client = ClaudeCodeClient(configuration: config)

// This generates commands like: "claude -- -p --verbose --max-turns 50"
let result = try await client.runSinglePrompt(
    prompt: "Write a sorting algorithm",
    outputFormat: .text,
    options: ClaudeCodeOptions()
)
```

This is particularly useful when your command executable requires specific argument positioning or when using command wrappers that need arguments separated with `--`.

### Different Output Formats

Choose from three output formats depending on your needs:

```swift
// Get plain text
let textResult = try await client.runSinglePrompt(
    prompt: "Write a sorting algorithm",
    outputFormat: .text,
    options: nil
)

// Get JSON with metadata
let jsonResult = try await client.runSinglePrompt(
    prompt: "Explain big O notation",
    outputFormat: .json,
    options: nil
)

// Stream responses as they arrive
let streamResult = try await client.runSinglePrompt(
    prompt: "Create a React component",
    outputFormat: .streamJson,
    options: nil
)
```

#### Processing Streams

```swift
if case .stream(let publisher) = streamResult {
    publisher.sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { chunk in
            // Process each chunk as it arrives
        }
    )
    .store(in: &cancellables)
}
```

### Multi-turn Conversations

Maintain context across multiple interactions:

```swift
// Continue the most recent conversation
let continuationResult = try await client.continueConversation(
    prompt: "Now refactor this for better performance",
    outputFormat: .text,
    options: nil
)

// Resume a specific session
let resumeResult = try await client.resumeConversation(
    sessionId: "550e8400-e29b-41d4-a716-446655440000",
    prompt: "Add error handling",
    outputFormat: .text,
    options: nil
)
```

### Configuration

Configure the client's runtime behavior:

```swift
// Create a custom configuration
var configuration = ClaudeCodeConfiguration(
    command: "claude",                    // Command to execute (default: "claude")
    workingDirectory: "/path/to/project", // Set working directory
    environment: ["API_KEY": "value"],    // Additional environment variables
    enableDebugLogging: true,             // Enable debug logs
    additionalPaths: ["/custom/bin"],     // Additional PATH directories
    commandSuffix: "--"                   // Optional suffix after command (e.g., "claude --")
)

// Initialize client with custom configuration
let client = ClaudeCodeClient(configuration: configuration)

// Or modify configuration at runtime
client.configuration.enableDebugLogging = false
client.configuration.workingDirectory = "/new/path"
client.configuration.commandSuffix = "--"  // Add suffix for commands like "claude -- -p --verbose"
```

### Customization Options

Fine-tune Claude Code's behavior with comprehensive options:

```swift
var options = ClaudeCodeOptions()
options.verbose = true
options.maxTurns = 5
options.systemPrompt = "You are a senior backend engineer specializing in Swift."
options.appendSystemPrompt = "After writing code, add comprehensive comments."
options.timeout = 300 // 5 minute timeout
options.model = "claude-3-sonnet-20240229"
options.permissionMode = .acceptEdits
options.maxThinkingTokens = 10000

// Tool configuration
options.allowedTools = ["Read", "Write", "Bash"]
options.disallowedTools = ["Delete"]

let result = try await client.runSinglePrompt(
    prompt: "Create a REST API in Swift",
    outputFormat: .text,
    options: options
)
```

### MCP Configuration

The Model Context Protocol (MCP) allows you to extend Claude Code with additional tools and resources from external servers. ClaudeCodeSDK provides full support for MCP integration.

#### Using MCP with Configuration File

Create a JSON configuration file with your MCP servers:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/path/to/allowed/files"
      ]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "your-github-token"
      }
    }
  }
}
```

Use the configuration in your Swift code:

```swift
var options = ClaudeCodeOptions()
options.mcpConfigPath = "/path/to/mcp-config.json"

// MCP tools are automatically added with the format: mcp__serverName__toolName
// The SDK will automatically allow tools like:
// - mcp__filesystem__read_file
// - mcp__filesystem__list_directory
// - mcp__github__*

let result = try await client.runSinglePrompt(
    prompt: "List all files in the project",
    outputFormat: .text,
    options: options
)
```

#### Programmatic MCP Configuration

You can also configure MCP servers programmatically:

```swift
var options = ClaudeCodeOptions()

// Define MCP servers in code
options.mcpServers = [
    "XcodeBuildMCP": .stdio(McpStdioServerConfig(
        command: "npx",
        args: ["-y", "xcodebuildmcp@latest"]
    )),
    "filesystem": .stdio(McpStdioServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"]
    ))
]

// The SDK creates a temporary configuration file automatically
let result = try await client.runSinglePrompt(
    prompt: "Build the iOS app",
    outputFormat: .streamJson,
    options: options
)
```

#### MCP Tool Naming Convention

MCP tools follow a specific naming pattern: `mcp__<serverName>__<toolName>`

```swift
// Explicitly allow specific MCP tools
options.allowedTools = [
    "mcp__filesystem__read_file",
    "mcp__filesystem__write_file",
    "mcp__github__search_repositories"
]

// Or use wildcards to allow all tools from a server
options.allowedTools = ["mcp__filesystem__*", "mcp__github__*"]
```

#### Using MCP with Permission Prompts

For non-interactive mode with MCP servers that require permissions:

```swift
var options = ClaudeCodeOptions()
options.mcpConfigPath = "/path/to/mcp-config.json"
options.permissionMode = .auto
options.permissionPromptToolName = "mcp__permissions__approve"
```

### Error Handling & Resilience

The SDK provides robust error handling with detailed error types and recovery options:

```swift
// Enhanced error handling
do {
    let result = try await client.runSinglePrompt(
        prompt: "Complex task",
        outputFormat: .json,
        options: options
    )
} catch let error as ClaudeCodeError {
    if error.isRetryable {
        // Error can be retried
        if let delay = error.suggestedRetryDelay {
            // Wait and retry
        }
    } else if error.isRateLimitError {
        print("Rate limited")
    } else if error.isTimeoutError {
        print("Request timed out")
    } else if error.isPermissionError {
        print("Permission denied")
    }
}
```

### Retry Logic

Built-in retry support with exponential backoff:

```swift
// Simple retry with default policy
let result = try await client.runSinglePromptWithRetry(
    prompt: "Generate code",
    outputFormat: .json,
    retryPolicy: .default // 3 attempts with exponential backoff
)

// Custom retry policy
let conservativePolicy = RetryPolicy(
    maxAttempts: 5,
    initialDelay: 5.0,
    maxDelay: 300.0,
    backoffMultiplier: 2.0,
    useJitter: true
)

let result = try await client.runSinglePromptWithRetry(
    prompt: "Complex analysis",
    outputFormat: .json,
    retryPolicy: conservativePolicy
)
```

### Rate Limiting

Protect against API rate limits with built-in rate limiting:

```swift
// Create a rate-limited client
let rateLimitedClient = RateLimitedClaudeCode(
    wrapped: client,
    requestsPerMinute: 10,
    burstCapacity: 3 // Allow 3 requests in burst
)

// All requests are automatically rate-limited
let result = try await rateLimitedClient.runSinglePrompt(
    prompt: "Task",
    outputFormat: .json,
    options: nil
)
```

### Cancellation Support

Cancel long-running operations with AbortController:

```swift
var options = ClaudeCodeOptions()
let abortController = AbortController()
options.abortController = abortController

// Start operation
Task {
    let result = try await client.runSinglePrompt(
        prompt: "Long running task",
        outputFormat: .streamJson,
        options: options
    )
}

// Cancel when needed
abortController.abort()
```

### Native Session Storage

Access Claude CLI's native session storage directly to read conversation history:

```swift
// Initialize the native storage
let storage = ClaudeNativeSessionStorage()

// List all projects with sessions
let projects = try await storage.listProjects()
print("Projects with sessions: \(projects)")

// Get sessions for a specific project
let sessions = try await storage.getSessions(for: "/Users/me/projects/myapp")
for session in sessions {
    print("Session: \(session.id)")
    print("  Created: \(session.createdAt)")
    print("  Summary: \(session.summary ?? "No summary")")
    print("  Messages: \(session.messages.count)")
}

// Get the most recent session for a project
if let recentSession = try await storage.getMostRecentSession(for: "/Users/me/projects/myapp") {
    print("Most recent session: \(recentSession.id)")
    
    // Access the conversation messages
    for message in recentSession.messages {
        print("\(message.role): \(message.content)")
    }
}

// Get all sessions across all projects
let allSessions = try await storage.getAllSessions()
print("Total sessions: \(allSessions.count)")
```

#### Benefits of Native Storage

* **Complete Sync**: Access sessions created from both CLI and your app
* **No Duplication**: Single source of truth for all Claude conversations
* **Rich Metadata**: Access to git branch, working directory, timestamps, and more
* **Conversation History**: Full access to all messages in each session
* **Project Organization**: Sessions automatically organized by project path

#### Session Storage Models

```swift
// Session information
public struct ClaudeStoredSession {
    let id: String                    // Session UUID
    let projectPath: String           // Project this session belongs to
    let createdAt: Date              // When session was created
    let lastAccessedAt: Date         // Last activity
    var summary: String?             // Session summary if available
    var gitBranch: String?           // Git branch at time of creation
    var messages: [ClaudeStoredMessage]  // All messages in session
}

// Message information
public struct ClaudeStoredMessage {
    let id: String                   // Message UUID
    let parentId: String?            // Parent message for threading
    let sessionId: String            // Session this belongs to
    let role: MessageRole            // user/assistant/system
    let content: String              // Message content
    let timestamp: Date              // When message was sent
    let cwd: String?                 // Working directory
    let version: String?             // Claude CLI version
}
```

#### Using Native Storage with ClaudeCodeClient

You can use the native storage to resume conversations or analyze past sessions:

```swift
let storage = ClaudeNativeSessionStorage()
let client = ClaudeCodeClient()

// Find a session to resume
if let session = try await storage.getMostRecentSession(for: projectPath) {
    // Resume that specific session
    let result = try await client.resumeConversation(
        sessionId: session.id,
        prompt: "Continue where we left off",
        outputFormat: .text,
        options: nil
    )
}
```

## Example Project

The repository includes a complete example project demonstrating how to integrate and use the SDK in a real application. You can find it in the `Example/ClaudeCodeSDKExample` directory.

The example showcases:

* Creating a chat interface with Claude
* Handling streaming responses
* Managing conversation sessions
* Displaying loading states
* Error handling

### Running the Example

1. Clone the repository
2. Open `Example/ClaudeCodeSDKExample/ClaudeCodeSDKExample.xcodeproj`
3. Build and run

## Architecture

The SDK is built with a protocol-based architecture for maximum flexibility:

### Core Components
* **`ClaudeCode`**: Protocol defining the interface
* **`ClaudeCodeClient`**: Concrete implementation that runs Claude Code CLI as a subprocess
* **`ClaudeCodeOptions`**: Configuration options for Claude Code execution
* **`ClaudeCodeOutputFormat`**: Output format options (text, JSON, streaming JSON)
* **`ClaudeCodeResult`**: Result types returned by the SDK
* **`ResponseChunk`**: Individual chunks in streaming responses

### Storage Components
* **`ClaudeNativeSessionStorage`**: Direct access to Claude CLI's native session storage
* **`ClaudeSessionStorageProtocol`**: Protocol for session storage implementations
* **`ClaudeStoredSession`**: Model representing a stored Claude session
* **`ClaudeStoredMessage`**: Model representing messages within sessions

### Type System
* **`ApiKeySource`**: Source of API key (user/project/org/temporary)
* **`ConfigScope`**: Configuration scope levels (local/user/project)
* **`PermissionMode`**: Permission handling modes (default/acceptEdits/bypassPermissions/plan)
* **`McpServerConfig`**: MCP server configurations (stdio/sse)

### Error Handling
* **`ClaudeCodeError`**: Comprehensive error types with retry hints
* **`RetryPolicy`**: Configurable retry strategies
* **`RetryHandler`**: Automatic retry with exponential backoff

### Utilities
* **`RateLimiter`**: Token bucket rate limiting
* **`AbortController`**: Cancellation support
* **`RateLimitedClaudeCode`**: Rate-limited wrapper

## Troubleshooting

### npm/node not found when using nvm

**Problem**: When running ClaudeCodeSDK from an app, you get errors like "npm is not installed" even though npm works fine in your terminal.

**Cause**: When ClaudeCodeSDK launches subprocesses, it uses a shell environment that doesn't automatically source your shell configuration files. This means nvm's PATH modifications aren't loaded.

**Solution**: Add nvm paths to your configuration:

```swift
// Find your nvm version
// Run in terminal: ls ~/.nvm/versions/node/

var config = ClaudeCodeConfiguration.default
config.additionalPaths = [
    "/usr/local/bin",
    "/opt/homebrew/bin",
    "/usr/bin",
    "\(NSHomeDirectory())/.nvm/versions/node/v22.11.0/bin", // Replace with your version
]
```

**Better Solution**: Use dynamic nvm detection (see NvmPathDetector utility below).

### Command not found errors

Add the tool's directory to `additionalPaths`:

```swift
// For Homebrew on Apple Silicon
config.additionalPaths.append("/opt/homebrew/bin")

// For Homebrew on Intel Macs
config.additionalPaths.append("/usr/local/bin")

// For custom tools
config.additionalPaths.append("/path/to/your/tools/bin")
```

### Environment variables not available

Pass required environment variables explicitly:

```swift
var config = ClaudeCodeConfiguration.default
config.environment = [
    "API_KEY": "your-key",
    "DATABASE_URL": "your-url",
    "NODE_ENV": "production"
]
```

### Working directory issues

Set the working directory explicitly:

```swift
var config = ClaudeCodeConfiguration.default
config.workingDirectory = "/path/to/your/project"
```

### Debugging tips

Enable debug logging to see what's happening:

```swift
var config = ClaudeCodeConfiguration.default
config.enableDebugLogging = true
```

This will show:
- The exact command being executed
- Environment variables being used
- PATH configuration
- Error messages from the subprocess

### Testing your configuration

Validate your setup before running Claude Code:

```swift
// Use the validateCommand method
let isValid = try await client.validateCommand("npm")
if !isValid {
    print("npm not found in PATH")
}
```

## Utilities

### NvmPathDetector

The SDK includes a utility to automatically detect nvm paths:

```swift
// Automatic nvm detection
var config = ClaudeCodeConfiguration.default
if let nvmPath = NvmPathDetector.detectNvmPath() {
    config.additionalPaths.append(nvmPath)
}

// Or use the convenience initializer
let config = ClaudeCodeConfiguration.withNvmSupport()
```

## Debugging

The SDK provides access to the last executed command for debugging and troubleshooting purposes.

### Accessing Command Information

After executing any command, you can access detailed information about it:

```swift
let client = ClaudeCodeClient()

let result = try await client.runSinglePrompt(
  prompt: "Write a function",
  outputFormat: .streamJson,
  options: options
)

// Access the last executed command information
if let commandInfo = client.lastExecutedCommandInfo {
  print("Command: \(commandInfo.commandString)")
  print("Working Directory: \(commandInfo.workingDirectory ?? "None")")
  print("Stdin Content: \(commandInfo.stdinContent ?? "None")")
  print("Executed At: \(commandInfo.executedAt)")
  print("Method: \(commandInfo.method.rawValue)")
  print("Output Format: \(commandInfo.outputFormat)")

  // Critical for debugging "command not found" errors
  print("PATH: \(commandInfo.pathEnvironment)")

  // See all environment variables
  print("Environment Variables: \(commandInfo.environment.count) variables")
}
```

### Reproducing Commands in Terminal

You can use this information to reproduce the exact command in Terminal for debugging:

```swift
if let commandInfo = client.lastExecutedCommandInfo {
  var terminalCommand = ""

  // Add working directory if present
  if let workingDir = commandInfo.workingDirectory {
    terminalCommand += "cd \"\(workingDir)\" && "
  }

  // Add stdin if present
  if let stdin = commandInfo.stdinContent {
    terminalCommand += "echo \"\(stdin)\" | "
  }

  // Add the command
  terminalCommand += commandInfo.commandString

  print("Run this in Terminal:")
  print(terminalCommand)

  // Copy to clipboard if needed
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(terminalCommand, forType: .string)
}
```

### ExecutedCommandInfo Properties

- **commandString**: The full command with all flags (e.g., `"claude -p --verbose --output-format stream-json"`)
- **workingDirectory**: The directory where the command was executed
- **stdinContent**: The content sent to stdin (user message, prompt, etc.)
- **executedAt**: Timestamp of when the command was executed
- **method**: The SDK method that executed the command (runSinglePrompt, continueConversation, etc.)
- **outputFormat**: The output format used (text, json, stream-json)
- **shellExecutable**: The shell used to execute the command (e.g., `/bin/zsh`)
- **shellArguments**: The arguments passed to the shell (e.g., `["-l", "-c", command]`)
- **pathEnvironment**: **The actual PATH used at runtime** - critical for debugging "command not found" errors
- **environment**: **The full environment dictionary used at runtime** - shows all system and custom environment variables

### Advanced Debugging: PATH and Environment

The most valuable debugging information is the **actual runtime PATH and environment**:

```swift
if let commandInfo = client.lastExecutedCommandInfo {
  // Debug "command not found" errors by checking the actual PATH used
  print("Actual PATH used:")
  commandInfo.pathEnvironment.split(separator: ":").forEach { path in
    print("  - \(path)")
  }

  // Check if specific environment variables were set
  if let nodeEnv = commandInfo.environment["NODE_ENV"] {
    print("NODE_ENV was set to: \(nodeEnv)")
  }

  // See what nvm version was actually used
  if let nvmPath = commandInfo.pathEnvironment.split(separator: ":").first(where: { $0.contains(".nvm") }) {
    print("Using nvm path: \(nvmPath)")
  }
}
```

### Use Cases

- **Bug Reports**: Include exact command details in bug reports
- **Terminal Reproduction**: Copy-paste commands to Terminal for debugging
- **Support Tickets**: Provide exact command information to support teams
- **Command Verification**: Verify that commands are constructed correctly
- **Debugging Failures**: Understand what command failed and why
- **PATH Debugging**: See the actual merged PATH to debug "command not found" errors
- **Environment Debugging**: Verify environment variables were set correctly at runtime

## License

ClaudeCodeSDK is available under the MIT license. See the `LICENSE` file for more info.

## Documentation

This is not an offical Anthropic SDK, For more information about Claude Code and its capabilities, visit the [Anthropic Documentation](https://docs.anthropic.com/en/docs/claude-code/sdk).
