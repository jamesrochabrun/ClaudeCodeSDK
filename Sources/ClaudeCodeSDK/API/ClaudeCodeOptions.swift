//
//  ClaudeCodeOptions.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

// MARK: - ClaudeCodeOptions

/// Configuration options for Claude Code execution
/// Matches the TypeScript SDK Options interface
public struct ClaudeCodeOptions {
  /// Abort controller for cancellation support
  public var abortController: AbortController?
  
  /// List of tools allowed for Claude to use
  public var allowedTools: [String]?
  
  /// Text to append to system prompt
  public var appendSystemPrompt: String?
  
  /// System prompt
  public var systemPrompt: String?
  
  /// List of tools denied for Claude to use
  public var disallowedTools: [String]?
  
  /// Maximum thinking tokens
  public var maxThinkingTokens: Int?
  
  /// Maximum number of turns allowed
  public var maxTurns: Int?
  
  /// MCP server configurations
  public var mcpServers: [String: McpServerConfiguration]?
  
  /// Permission mode for operations
  public var permissionMode: PermissionMode?
  
  /// Tool for handling permission prompts in non-interactive mode
  public var permissionPromptToolName: String?
  
  /// Continue flag for conversation continuation
  public var `continue`: Bool?
  
  /// Resume session ID
  public var resume: String?
  
  /// Model to use
  public var model: String?
  
  /// Timeout in seconds for command execution
  public var timeout: TimeInterval?
  
  /// Path to MCP configuration file
  /// Alternative to mcpServers for file-based configuration
  public var mcpConfigPath: String?
  
  // Internal properties maintained for compatibility
  /// Run in non-interactive mode (--print/-p flag)
  internal var printMode: Bool = true
  
  /// Enable verbose logging
  public var verbose: Bool = false

  // MARK: - Additional Directories

  /// Additional working directories for Claude to access
  /// CLI flag: --add-dir (repeatable)
  public var additionalDirectories: [String]?

  // MARK: - Agent Configuration

  /// Specify an agent for the current session
  /// CLI flag: --agent
  public var agent: String?

  /// Custom subagents configuration
  /// CLI flag: --agents (JSON)
  public var agents: [String: SubagentDefinition]?

  // MARK: - Output Configuration

  /// JSON schema for validated output matching the schema
  /// CLI flag: --json-schema
  public var jsonSchema: String?

  /// Specify available tools ("", "default", or comma-separated list like "Bash,Edit,Read")
  /// CLI flag: --tools
  public var tools: String?

  /// Input format for print mode
  /// CLI flag: --input-format
  public var inputFormat: InputFormat?

  // MARK: - Model Configuration

  /// Fallback model when primary is overloaded (print mode only)
  /// CLI flag: --fallback-model
  public var fallbackModel: String?

  // MARK: - Session Management

  /// Specific session ID to use (must be a valid UUID)
  /// CLI flag: --session-id
  public var sessionId: String?

  /// Create a new session ID when resuming instead of reusing the original
  /// CLI flag: --fork-session
  public var forkSession: Bool?

  // MARK: - Streaming Options

  /// Include partial streaming events in output
  /// Requires --print and --output-format=stream-json
  /// CLI flag: --include-partial-messages
  public var includePartialMessages: Bool?

  // MARK: - Settings Configuration

  /// Path to a settings JSON file or a JSON string
  /// CLI flag: --settings
  public var settings: String?

  /// Setting sources to load
  /// CLI flag: --setting-sources
  public var settingSources: [SettingSource]?

  /// Only use MCP servers from --mcp-config, ignoring all other MCP configurations
  /// CLI flag: --strict-mcp-config
  public var strictMcpConfig: Bool?

  /// Load system prompt from a file (print mode only)
  /// CLI flag: --system-prompt-file
  public var systemPromptFile: String?

  // MARK: - Beta & Debug

  /// Beta headers to include in API requests (API key users only)
  /// CLI flag: --betas (repeatable)
  public var betas: [String]?

  /// Enable debug mode with optional category filtering
  /// Examples: "api,mcp" or "!statsig,!file"
  /// CLI flag: --debug
  public var debug: String?

  // MARK: - Permission & Safety

  /// Skip all permission prompts (use with caution!)
  /// CLI flag: --dangerously-skip-permissions
  public var dangerouslySkipPermissions: Bool?

  // MARK: - Browser & IDE Integration

  /// Enable or disable Chrome browser integration
  /// CLI flag: --chrome / --no-chrome
  public var chrome: Bool?

  /// Connect to IDE on startup if exactly one valid IDE is available
  /// CLI flag: --ide
  public var ide: Bool?

  // MARK: - Plugins & Logging

  /// Plugin directories to load for this session only
  /// CLI flag: --plugin-dir (repeatable)
  public var pluginDirectories: [String]?

  /// Enable verbose LSP logging for debugging language server issues
  /// CLI flag: --enable-lsp-logging
  public var enableLspLogging: Bool?

  public init() {
    // Default initialization
  }

  /// Properly escapes a string for safe shell usage
  /// Uses single quotes which protect against most special characters
  /// Single quotes inside the string are escaped as '\''
  private func shellEscape(_ string: String) -> String {
    // Replace single quotes with '\'' (end quote, escaped quote, start quote)
    let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
    // Wrap in single quotes
    return "'\(escaped)'"
  }

  /// Convert options to command line arguments
  internal func toCommandArgs() -> [String] {
    var args: [String] = []
    
    // Add print mode flag for non-interactive mode
    if printMode {
      args.append("-p")
    }
    
    if verbose {
      args.append("--verbose")
    }
    
    if let maxTurns = maxTurns {
      args.append("--max-turns")
      args.append("\(maxTurns)")
    }
    
    if let maxThinkingTokens = maxThinkingTokens {
      args.append("--max-thinking-tokens")
      args.append("\(maxThinkingTokens)")
    }
    
    if let allowedTools = allowedTools, !allowedTools.isEmpty {
      args.append("--allowedTools")
      // Escape the joined string in quotes to prevent shell expansion
      let toolsList = allowedTools.joined(separator: ",")
      args.append("\"\(toolsList)\"")
    }
    
    if let disallowedTools = disallowedTools, !disallowedTools.isEmpty {
      args.append("--disallowedTools")
      // Escape the joined string in quotes to prevent shell expansion
      let toolsList = disallowedTools.joined(separator: ",")
      args.append("\"\(toolsList)\"")
    }
    
    if let permissionPromptToolName = permissionPromptToolName {
      args.append("--permission-prompt-tool")
      args.append(permissionPromptToolName)
    }
    
    if let systemPrompt = systemPrompt {
      args.append("--system-prompt")
      args.append(shellEscape(systemPrompt))
    }

    if let appendSystemPrompt = appendSystemPrompt {
      args.append("--append-system-prompt")
      args.append(shellEscape(appendSystemPrompt))
    }
    
    if let permissionMode = permissionMode {
      args.append("--permission-mode")
      args.append(permissionMode.rawValue)
    }
    
    if let model = model {
      args.append("--model")
      args.append(model)
    }
    
    // Handle MCP configuration
    if let mcpConfigPath = mcpConfigPath {
      // Use file-based configuration
      args.append("--mcp-config")
      args.append(mcpConfigPath)
    } else if let mcpServers = mcpServers, !mcpServers.isEmpty {
      // Create temporary file with MCP configuration
      let tempDir = FileManager.default.temporaryDirectory
      let configFile = tempDir.appendingPathComponent("mcp-config-\(UUID().uuidString).json")

      let config = ["mcpServers": mcpServers]
      if let jsonData = try? JSONEncoder().encode(config),
         (try? jsonData.write(to: configFile)) != nil {
        args.append("--mcp-config")
        args.append(configFile.path)
      }
    }

    // MARK: - Additional Directories (repeatable)

    if let additionalDirectories = additionalDirectories {
      for dir in additionalDirectories {
        args.append("--add-dir")
        args.append(dir)
      }
    }

    // MARK: - Agent Configuration

    if let agent = agent {
      args.append("--agent")
      args.append(agent)
    }

    if let agents = agents, !agents.isEmpty {
      args.append("--agents")
      if let jsonData = try? JSONEncoder().encode(agents),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        args.append(shellEscape(jsonString))
      }
    }

    // MARK: - Output Configuration

    if let jsonSchema = jsonSchema {
      args.append("--json-schema")
      args.append(shellEscape(jsonSchema))
    }

    if let tools = tools {
      args.append("--tools")
      args.append(tools)
    }

    if let inputFormat = inputFormat {
      args.append("--input-format")
      args.append(inputFormat.rawValue)
    }

    // MARK: - Model Configuration

    if let fallbackModel = fallbackModel {
      args.append("--fallback-model")
      args.append(fallbackModel)
    }

    // MARK: - Session Management

    if let sessionId = sessionId {
      args.append("--session-id")
      args.append(sessionId)
    }

    if forkSession == true {
      args.append("--fork-session")
    }

    // MARK: - Streaming Options

    if includePartialMessages == true {
      args.append("--include-partial-messages")
    }

    // MARK: - Settings Configuration

    if let settings = settings {
      args.append("--settings")
      args.append(shellEscape(settings))
    }

    if let settingSources = settingSources, !settingSources.isEmpty {
      args.append("--setting-sources")
      args.append(settingSources.map { $0.rawValue }.joined(separator: ","))
    }

    if strictMcpConfig == true {
      args.append("--strict-mcp-config")
    }

    if let systemPromptFile = systemPromptFile {
      args.append("--system-prompt-file")
      args.append(systemPromptFile)
    }

    // MARK: - Beta & Debug

    if let betas = betas {
      for beta in betas {
        args.append("--betas")
        args.append(beta)
      }
    }

    if let debug = debug {
      args.append("--debug")
      args.append(debug)
    }

    // MARK: - Permission & Safety

    if dangerouslySkipPermissions == true {
      args.append("--dangerously-skip-permissions")
    }

    // MARK: - Browser & IDE Integration

    if let chrome = chrome {
      args.append(chrome ? "--chrome" : "--no-chrome")
    }

    if ide == true {
      args.append("--ide")
    }

    // MARK: - Plugins & Logging (repeatable)

    if let pluginDirectories = pluginDirectories {
      for dir in pluginDirectories {
        args.append("--plugin-dir")
        args.append(dir)
      }
    }

    if enableLspLogging == true {
      args.append("--enable-lsp-logging")
    }

    return args
  }
}
