//
//  ErrorHandlingTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class ErrorHandlingTests: XCTestCase {
  
  func testErrorTypes() {
    // Test all error types from README example
    let notInstalledError = ClaudeCodeError.notInstalled
    let invalidConfigError = ClaudeCodeError.executionFailed("Invalid API key")
    let executionFailedError = ClaudeCodeError.executionFailed("Command failed")
    let timeoutError = ClaudeCodeError.timeout(30.0)
    let cancelledError = ClaudeCodeError.cancelled
    let rateLimitError = ClaudeCodeError.rateLimitExceeded(retryAfter: 60.0)
    let networkError = ClaudeCodeError.networkError(NSError(domain: "network", code: -1009))
    let permissionError = ClaudeCodeError.permissionDenied("Access denied")
    let processLaunchError = ClaudeCodeError.processLaunchFailed("Invalid command arguments")

    // Test error descriptions
    XCTAssertEqual(notInstalledError.localizedDescription, "Claude Code is not installed. Please install with 'npm install -g @anthropic/claude-code'")
    XCTAssertTrue(invalidConfigError.localizedDescription.contains("Invalid API key"))
    XCTAssertTrue(executionFailedError.localizedDescription.contains("Command failed"))
    XCTAssertTrue(timeoutError.localizedDescription.contains("timed out"))
    XCTAssertEqual(cancelledError.localizedDescription, "Operation cancelled")
    XCTAssertTrue(rateLimitError.localizedDescription.contains("Rate limit exceeded"))
    XCTAssertTrue(networkError.localizedDescription.contains("Network error"))
    XCTAssertTrue(permissionError.localizedDescription.contains("Access denied"))
    XCTAssertTrue(processLaunchError.localizedDescription.contains("Process failed to launch"))
  }
  
  func testErrorProperties() {
    // Test error convenience properties
    let rateLimitError = ClaudeCodeError.rateLimitExceeded(retryAfter: 60.0)
    XCTAssertTrue(rateLimitError.isRateLimitError)
    XCTAssertTrue(rateLimitError.isRetryable)
    XCTAssertFalse(rateLimitError.isTimeoutError)
    XCTAssertFalse(rateLimitError.isPermissionError)
    XCTAssertFalse(rateLimitError.isInstallationError)
    XCTAssertNotNil(rateLimitError.suggestedRetryDelay)
    
    let timeoutError = ClaudeCodeError.timeout(30.0)
    XCTAssertTrue(timeoutError.isTimeoutError)
    XCTAssertTrue(timeoutError.isRetryable)
    XCTAssertFalse(timeoutError.isRateLimitError)
    XCTAssertNotNil(timeoutError.suggestedRetryDelay)
    XCTAssertEqual(timeoutError.suggestedRetryDelay, 5.0)
    
    let permissionError = ClaudeCodeError.permissionDenied("Access denied")
    XCTAssertTrue(permissionError.isPermissionError)
    XCTAssertFalse(permissionError.isRetryable)
    
    let installError = ClaudeCodeError.notInstalled
    XCTAssertTrue(installError.isInstallationError)
    XCTAssertFalse(installError.isRetryable)
    
    let networkError = ClaudeCodeError.networkError(NSError(domain: "network", code: -1009))
    XCTAssertTrue(networkError.isRetryable)
    
    let cancelledError = ClaudeCodeError.cancelled
    XCTAssertTrue(cancelledError.isRetryable) // Actually cancelled is retryable according to the code
  }
  
  func testSuggestedRetryDelay() {
    // Test suggested retry delay calculation
    let rateLimitError = ClaudeCodeError.rateLimitExceeded(retryAfter: 30.0)
    
    if let delay = rateLimitError.suggestedRetryDelay {
      XCTAssertEqual(delay, 30.0)
    } else {
      XCTFail("Expected suggested retry delay")
    }
    
    // Test with nil retry after
    let rateLimitErrorNoDate = ClaudeCodeError.rateLimitExceeded(retryAfter: nil)
    XCTAssertEqual(rateLimitErrorNoDate.suggestedRetryDelay, 60.0) // Default is 60 seconds
  }
  
  func testErrorUsagePatternFromReadme() {
    // Test the error handling pattern from README
    let errors: [ClaudeCodeError] = [
      .rateLimitExceeded(retryAfter: 60.0),
      .timeout(30.0),
      .permissionDenied("Access denied"),
      .networkError(NSError(domain: "network", code: -1009))
    ]

    for error in errors {
      // Test the README pattern
      if error.isRetryable {
        if let delay = error.suggestedRetryDelay {
          XCTAssertGreaterThan(delay, 0)
        }
      } else if error.isRateLimitError {
        XCTAssertTrue(error.isRetryable) // Rate limit should be retryable
      } else if error.isTimeoutError {
        XCTAssertTrue(error.isRetryable) // Timeout should be retryable
      } else if error.isPermissionError {
        XCTAssertFalse(error.isRetryable) // Permission errors not retryable
      }
    }
  }

  func testProcessLaunchFailure() {
    // Test process launch failure error
    let launchError = ClaudeCodeError.processLaunchFailed("zsh: bad option: -invalid")

    // Test error description
    XCTAssertTrue(launchError.localizedDescription.contains("Process failed to launch"))
    XCTAssertTrue(launchError.localizedDescription.contains("bad option"))

    // Process launch failures should not be retryable by default
    // (since they're usually due to malformed commands)
    XCTAssertFalse(launchError.isRetryable)

    // Test specific error patterns
    let syntaxError = ClaudeCodeError.processLaunchFailed("syntax error near unexpected token")
    XCTAssertTrue(syntaxError.localizedDescription.contains("syntax error"))

    let parseError = ClaudeCodeError.processLaunchFailed("parse error in command")
    XCTAssertTrue(parseError.localizedDescription.contains("parse error"))
  }
}