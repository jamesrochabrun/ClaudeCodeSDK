//
//  BasicClientTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class BasicClientTests: XCTestCase {
  
  func testClientInitializationWithDebug() throws {
    // Test basic client initialization as shown in README
    let client = try ClaudeCodeClient(debug: true)

    XCTAssertNotNil(client)
    XCTAssertTrue(client.configuration.enableDebugLogging)
    XCTAssertEqual(client.configuration.command, "claude")
  }

  func testClientInitializationWithConfiguration() throws {
    // Test custom configuration initialization
    let configuration = ClaudeCodeConfiguration(
      command: "claude",
      workingDirectory: "/path/to/project",
      environment: ["API_KEY": "value"],
      enableDebugLogging: true,
      additionalPaths: ["/custom/bin"]
    )

    let client = try ClaudeCodeClient(configuration: configuration)

    XCTAssertNotNil(client)
    XCTAssertEqual(client.configuration.command, "claude")
    XCTAssertEqual(client.configuration.workingDirectory, "/path/to/project")
    XCTAssertEqual(client.configuration.environment["API_KEY"], "value")
    XCTAssertTrue(client.configuration.enableDebugLogging)
    XCTAssertEqual(client.configuration.additionalPaths, ["/custom/bin"])
  }

  func testClientConfigurationModificationAtRuntime() throws {
    // Test runtime configuration modification as shown in README
    let client = try ClaudeCodeClient()
    
    // Modify configuration at runtime
    client.configuration.enableDebugLogging = false
    client.configuration.workingDirectory = "/new/path"
    
    XCTAssertFalse(client.configuration.enableDebugLogging)
    XCTAssertEqual(client.configuration.workingDirectory, "/new/path")
  }
  
  func testDefaultConfiguration() {
    // Test default configuration values
    let config = ClaudeCodeConfiguration.default
    
    XCTAssertEqual(config.command, "claude")
    XCTAssertNil(config.workingDirectory)
    XCTAssertTrue(config.environment.isEmpty)
    XCTAssertFalse(config.enableDebugLogging)
    XCTAssertEqual(config.additionalPaths, [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "/bin",
      "/usr/sbin",
      "/sbin"
    ])
  }
  
  func testBackwardCompatibilityInitializer() throws {
    // Test convenience initializer for backward compatibility
    let client1 = try ClaudeCodeClient(workingDirectory: "/test/path", debug: true)

    XCTAssertEqual(client1.configuration.workingDirectory, "/test/path")
    XCTAssertTrue(client1.configuration.enableDebugLogging)

    // Test with empty working directory
    let client2 = try ClaudeCodeClient(workingDirectory: "", debug: false)

    XCTAssertNil(client2.configuration.workingDirectory)
    XCTAssertFalse(client2.configuration.enableDebugLogging)
  }
}