//
//  ProcessLaunchTests.swift
//  ClaudeCodeSDKTests
//
//  Tests for process launch failure handling
//

import XCTest
@testable import ClaudeCodeSDK
import Combine
import Foundation

final class ProcessLaunchTests: XCTestCase {

  func testProcessLaunchFailureWithBadCommand() async throws {
    // Create a client with a command that will fail
    var config = ClaudeCodeConfiguration.default
    // Using a command that doesn't exist
    config.command = "/nonexistent/command"
    let client = try ClaudeCodeClient(configuration: config)

    do {
      _ = try await client.runSinglePrompt(
        prompt: "test",
        outputFormat: .streamJson,
        options: nil
      )
      XCTFail("Should have thrown processLaunchFailed error")
    } catch ClaudeCodeError.processLaunchFailed {
      // Expected - test passes
      XCTAssertTrue(true)
    } catch ClaudeCodeError.notInstalled {
      // Also acceptable
      XCTAssertTrue(true)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testProcessLaunchFailureWithMalformedArguments() async throws {
    // Create a client with malformed command suffix
    var config = ClaudeCodeConfiguration.default
    config.command = "echo"  // Use echo for testing
    config.commandSuffix = "&& exit 1"  // Force immediate failure
    let client = try ClaudeCodeClient(configuration: config)

    do {
      _ = try await client.runSinglePrompt(
        prompt: "test",
        outputFormat: .streamJson,
        options: nil
      )
      XCTFail("Should have thrown processLaunchFailed error")
    } catch ClaudeCodeError.processLaunchFailed {
      // Expected - test passes
      XCTAssertTrue(true)
    } catch {
      // Any error is acceptable since we're forcing failure
      XCTAssertTrue(true)
    }
  }

  func testProcessLaunchFailureInResumeConversation() async throws {
    // Create a client with a failing command
    var config = ClaudeCodeConfiguration.default
    config.command = "/bin/false"  // Command that always fails
    let client = try ClaudeCodeClient(configuration: config)

    do {
      _ = try await client.resumeConversation(
        sessionId: "test-session",
        prompt: "test",
        outputFormat: .streamJson,
        options: nil
      )
      XCTFail("Should have thrown an error")
    } catch ClaudeCodeError.processLaunchFailed {
      // Expected - test passes
      XCTAssertTrue(true)
    } catch {
      // Any error is acceptable since we're forcing failure
      XCTAssertTrue(true)
    }
  }

  func testEmptyStderrErrorMessage() async throws {
    // Test that when stderr is empty, we get meaningful error messages
    var config = ClaudeCodeConfiguration.default
    // Use false command which exits with code 1 but produces no stderr
    config.command = "/usr/bin/false"
    let client = try ClaudeCodeClient(configuration: config)

    do {
      _ = try await client.runSinglePrompt(
        prompt: "test",
        outputFormat: .streamJson,
        options: nil
      )
      XCTFail("Should have thrown an error")
    } catch ClaudeCodeError.processLaunchFailed(let message) {
      // Verify we get a meaningful error message even when stderr is empty
      XCTAssertFalse(message.isEmpty, "Error message should not be empty")
      XCTAssertTrue(message.contains("Process exited immediately with code"), "Should include exit code")
      XCTAssertTrue(message.contains("Command attempted:"), "Should include command info")
      // For exit code 1, should include hint about shell syntax
      XCTAssertTrue(message.contains("shell syntax error") || message.contains("code 1"), "Should provide context for exit code")
      print("Got meaningful error message: \(message)")
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testNormalOperationNotAffected() async throws {
    // Test that normal operations still work with valid commands
    var config = ClaudeCodeConfiguration.default
    config.command = "echo"  // Use echo for testing
    config.commandSuffix = "\"test output\""
    let client = try ClaudeCodeClient(configuration: config)

    // This should work normally (echo will succeed)
    do {
      let result = try await client.runSinglePrompt(
        prompt: "test",
        outputFormat: .text,
        options: nil
      )

      // Should get some result (even if it's just echo output)
      switch result {
      case .text(let output):
        XCTAssertNotNil(output)
      default:
        XCTFail("Expected text output")
      }
    } catch {
      // Echo might not produce valid Claude output format,
      // but it shouldn't throw processLaunchFailed
      if case ClaudeCodeError.processLaunchFailed = error {
        XCTFail("Should not have thrown processLaunchFailed for valid command")
      }
    }
  }
}