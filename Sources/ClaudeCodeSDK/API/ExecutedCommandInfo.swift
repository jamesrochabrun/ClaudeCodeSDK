//
//  ExecutedCommandInfo.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

/// Information about an executed command for debugging purposes
public struct ExecutedCommandInfo: Sendable {
  /// The full command string with all flags (as passed to Process)
  /// Example: "claude -p --verbose --allowedTools \"Read,Write\" --output-format stream-json"
  public let commandString: String

  /// The working directory where the command was executed
  public let workingDirectory: String?

  /// The content sent to stdin (user message, typically)
  public let stdinContent: String?

  /// When the command was executed
  public let executedAt: Date

  /// The method that executed the command
  public let method: ExecutionMethod

  /// The type of method that executed a Claude Code command
  public enum ExecutionMethod: String, Sendable {
    case runSinglePrompt
    case continueConversation
    case resumeConversation
    case runWithStdin
    case listSessions
  }
}
