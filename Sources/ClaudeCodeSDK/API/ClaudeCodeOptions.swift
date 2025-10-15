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
    
    return args
  }
}
