//
//  SubagentDefinition.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 12/26/25.
//

import Foundation

/// Definition for a custom subagent
/// Used with the --agents CLI flag to define custom agents dynamically
///
/// Example usage:
/// ```swift
/// var options = ClaudeCodeOptions()
/// options.agents = [
///   "code-reviewer": SubagentDefinition(
///     description: "Expert code reviewer. Use proactively after code changes.",
///     prompt: "You are a senior code reviewer. Focus on code quality, security, and best practices.",
///     tools: ["Read", "Grep", "Glob", "Bash"],
///     model: "sonnet"
///   )
/// ]
/// ```
public struct SubagentDefinition: Codable, Sendable, Equatable {

  /// Natural language description of when the subagent should be invoked
  public let description: String

  /// The system prompt that guides the subagent's behavior
  public let prompt: String

  /// Array of specific tools the subagent can use
  /// If nil, inherits all tools from parent
  public let tools: [String]?

  /// Model alias to use: "sonnet", "opus", or "haiku"
  /// If nil, uses the default subagent model
  public let model: String?

  public init(
    description: String,
    prompt: String,
    tools: [String]? = nil,
    model: String? = nil
  ) {
    self.description = description
    self.prompt = prompt
    self.tools = tools
    self.model = model
  }
}
