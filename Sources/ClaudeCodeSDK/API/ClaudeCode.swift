//
//  ClaudeCode.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation
/// Protocol that defines the interface for interacting with Claude Code.
/// This allows for dependency injection and easier testing with mocks.
/// Documentation: https://docs.anthropic.com/en/docs/claude-code/sdk
public protocol ClaudeCode {
  
  /// Configuration settings for the Claude Code client.
  /// Controls command execution, environment variables, and debug options.
  /// Can be modified at runtime to adjust client behavior.
  var configuration: ClaudeCodeConfiguration { get set }
  
  /// Runs Claude Code using stdin as input (for pipe functionality)
  /// - Parameters:
  ///   - stdinContent: The content to pipe to Claude Code's stdin
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func runWithStdin(
    stdinContent: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult
  
  /// Runs a single prompt and returns the result
  /// - Parameters:
  ///   - prompt: The prompt text to send to Claude Code
  ///   - outputFormat: The desired output format
  ///   - options: Additional configuration options
  /// - Returns: The result in the specified format
  func runSinglePrompt(
    prompt: String,
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
  
  /// Validates if a command is available in the configured PATH
  /// - Parameter command: The command to check (e.g., "npm", "node")
  /// - Returns: true if the command is found in PATH, false otherwise
  func validateCommand(_ command: String) async throws -> Bool

  /// Debug information about the last command executed
  /// Returns nil if no command has been executed yet
  var lastExecutedCommandInfo: ExecutedCommandInfo? { get }
}
