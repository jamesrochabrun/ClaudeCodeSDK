//
//  ClaudeCodeError.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

public enum ClaudeCodeError: Error {
  case executionFailed(String)
  case invalidOutput(String)
  case jsonParsingError(Error)
  case cancelled
  case notInstalled
  case timeout(TimeInterval)
  case rateLimitExceeded(retryAfter: TimeInterval?)
  case networkError(Error)
  case permissionDenied(String)
  case processLaunchFailed(String)
  
  public var localizedDescription: String {
    switch self {
    case .notInstalled:
      return "Claude Code is not installed. Please install with 'npm install -g @anthropic/claude-code'"
    case .executionFailed(let message):
      return "Execution failed: \(message)"
    case .invalidOutput(let message):
      return "Invalid output: \(message)"
    case .jsonParsingError(let error):
      return "JSON parsing error: \(error.localizedDescription)"
    case .cancelled:
      return "Operation cancelled"
    case .timeout(let duration):
      return "Operation timed out after \(Int(duration)) seconds"
    case .rateLimitExceeded(let retryAfter):
      if let retryAfter = retryAfter {
        return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
      }
      return "Rate limit exceeded"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    case .permissionDenied(let message):
      return "Permission denied: \(message)"
    case .processLaunchFailed(let message):
      return "Process failed to launch: \(message)"
    }
  }
}

// MARK: - Convenience Properties

extension ClaudeCodeError {
  /// Whether this error is due to rate limiting
  public var isRateLimitError: Bool {
    if case .rateLimitExceeded = self { return true }
    if case .executionFailed(let message) = self {
      return message.lowercased().contains("rate limit") ||
      message.lowercased().contains("too many requests")
    }
    return false
  }
  
  /// Whether this error is due to timeout
  public var isTimeoutError: Bool {
    if case .timeout = self { return true }
    if case .executionFailed(let message) = self {
      return message.lowercased().contains("timeout") ||
      message.lowercased().contains("timed out")
    }
    return false
  }
  
  /// Whether this error is retryable
  public var isRetryable: Bool {
    switch self {
    case .rateLimitExceeded, .timeout, .networkError, .cancelled:
      return true
    case .executionFailed(let message):
      // Check for transient errors
      let transientErrors = ["timeout", "timed out", "rate limit", "network", "connection"]
      return transientErrors.contains { message.lowercased().contains($0) }
    default:
      return false
    }
  }
  
  /// Whether this error indicates Claude Code is not installed
  public var isInstallationError: Bool {
    if case .notInstalled = self { return true }
    return false
  }
  
  /// Whether this error is due to permission issues
  public var isPermissionError: Bool {
    if case .permissionDenied = self { return true }
    if case .executionFailed(let message) = self {
      return message.lowercased().contains("permission") ||
      message.lowercased().contains("denied") ||
      message.lowercased().contains("unauthorized")
    }
    return false
  }
  
  /// Suggested retry delay in seconds (if applicable)
  public var suggestedRetryDelay: TimeInterval? {
    switch self {
    case .rateLimitExceeded(let retryAfter):
      return retryAfter ?? 60 // Default to 60 seconds if not specified
    case .timeout:
      return 5 // Quick retry for timeouts
    case .networkError:
      return 10 // Network errors might need a bit more time
    default:
      return isRetryable ? 5 : nil
    }
  }
}
