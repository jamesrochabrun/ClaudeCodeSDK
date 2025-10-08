//
//  ClaudeCodeConfiguration.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

/// Configuration for ClaudeCodeClient
public struct ClaudeCodeConfiguration {
  /// The backend type to use for execution
  /// - headless: Traditional CLI-based approach (default)
  /// - agentSDK: Node.js wrapper around @anthropic-ai/claude-agent-sdk
  public var backend: BackendType

  /// The command to execute (default: "claude")
  /// Used for headless backend
  public var command: String

  /// Path to Node.js executable (optional, auto-detected if not provided)
  /// Used for agentSDK backend
  public var nodeExecutable: String?

  /// Path to sdk-wrapper.mjs script (optional, uses bundled resource if not provided)
  /// Used for agentSDK backend
  public var sdkWrapperPath: String?

  /// The working directory for command execution
  public var workingDirectory: String?

  /// Additional environment variables
  public var environment: [String: String]

  /// Enable debug logging
  public var enableDebugLogging: Bool

  /// Additional paths to add to PATH environment variable
  public var additionalPaths: [String]

  /// Optional suffix to append after the command (e.g., "--" for "airchat --")
  public var commandSuffix: String?

  /// List of tools that should be disallowed for Claude to use
  public var disallowedTools: [String]?
  
  /// Default configuration (uses headless backend for backward compatibility)
  public static var `default`: ClaudeCodeConfiguration {
    ClaudeCodeConfiguration(
      backend: .headless,
      command: "claude",
      nodeExecutable: nil,
      sdkWrapperPath: nil,
      workingDirectory: nil,
      environment: [:],
      enableDebugLogging: false,
      additionalPaths: [
        "/usr/local/bin",     // Homebrew on Intel Macs, common Unix tools
        "/opt/homebrew/bin",  // Homebrew on Apple Silicon
        "/usr/bin",           // System binaries
        "/bin",               // Core system binaries
        "/usr/sbin",          // System administration binaries
        "/sbin"               // Essential system binaries
      ],
      commandSuffix: nil,
      disallowedTools: nil
    )
  }
  
  public init(
    backend: BackendType = .headless,
    command: String = "claude",
    nodeExecutable: String? = nil,
    sdkWrapperPath: String? = nil,
    workingDirectory: String? = nil,
    environment: [String: String] = [:],
    enableDebugLogging: Bool = false,
    additionalPaths: [String] = [
      "/usr/local/bin",     // Homebrew on Intel Macs, common Unix tools
      "/opt/homebrew/bin",  // Homebrew on Apple Silicon
      "/usr/bin",           // System binaries
      "/bin",               // Core system binaries
      "/usr/sbin",          // System administration binaries
      "/sbin"               // Essential system binaries
    ],
    commandSuffix: String? = nil,
    disallowedTools: [String]? = nil
  ) {
    self.backend = backend
    self.command = command
    self.nodeExecutable = nodeExecutable
    self.sdkWrapperPath = sdkWrapperPath
    self.workingDirectory = workingDirectory
    self.environment = environment
    self.enableDebugLogging = enableDebugLogging
    self.additionalPaths = additionalPaths
    self.commandSuffix = commandSuffix
    self.disallowedTools = disallowedTools
  }
}
