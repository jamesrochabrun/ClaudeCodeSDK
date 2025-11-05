//
//  ClaudeCodeBackend.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/7/2025.
//

import Foundation

/// Defines the type of backend implementation
public enum BackendType: String, Codable, Sendable {
  /// Traditional headless mode using `claude -p` CLI
  case headless

  /// Node.js-based wrapper around @anthropic-ai/claude-agent-sdk
  case agentSDK
}

/// Protocol defining the interface for Claude Code execution backends
/// This abstraction allows switching between different implementation strategies
/// while maintaining a consistent API.
internal protocol ClaudeCodeBackend: Sendable {

  /// Executes a single prompt and returns the result
  /// - Parameters:
  ///   - prompt: The prompt text to send
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func runSinglePrompt(
    prompt: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult

  /// Runs with stdin content (for pipe functionality)
  /// - Parameters:
  ///   - stdinContent: The content to pipe to stdin
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func runWithStdin(
    stdinContent: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult

  /// Continues the most recent conversation
  /// - Parameters:
  ///   - prompt: Optional prompt text for the continuation
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func continueConversation(
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult

  /// Resumes a specific conversation by session ID
  /// - Parameters:
  ///   - sessionId: The session ID to resume
  ///   - prompt: Optional prompt text for the resumed session
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func resumeConversation(
    sessionId: String,
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult

  /// Gets a list of recent sessions
  /// - Returns: List of session information
  func listSessions() async throws -> [SessionInfo]

  /// Cancels any current operations
  func cancel()

  /// Validates if the backend is properly configured and available
  /// - Returns: true if the backend is ready to use
  func validateSetup() async throws -> Bool

  /// Debug information about the last command executed
  /// - Returns: Information about the last executed command, or nil if no commands have been executed
  var lastExecutedCommandInfo: ExecutedCommandInfo? { get }
}
