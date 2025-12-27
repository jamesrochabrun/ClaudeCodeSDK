//
//  InputFormat.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 12/26/25.
//

import Foundation

/// Input format for Claude Code
/// Used with the --input-format CLI flag
public enum InputFormat: String, Codable, Sendable {
  /// Plain text input (default)
  case text = "text"

  /// Stream JSON input
  case streamJson = "stream-json"
}
