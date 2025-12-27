//
//  SettingSource.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 12/26/25.
//

import Foundation

/// Setting sources for Claude Code configuration
/// Used with the --setting-sources CLI flag
public enum SettingSource: String, Codable, Sendable, CaseIterable {
  /// User-level settings
  case user = "user"

  /// Project-level settings
  case project = "project"

  /// Local settings
  case local = "local"
}
