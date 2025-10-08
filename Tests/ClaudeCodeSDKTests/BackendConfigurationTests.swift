//
//  BackendConfigurationTests.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/7/2025.
//

import XCTest
@testable import ClaudeCodeSDK

final class BackendConfigurationTests: XCTestCase {

  func testDefaultConfiguration() {
    let config = ClaudeCodeConfiguration.default

    // Default should use headless backend
    XCTAssertEqual(config.backend, .headless,
                  "Default configuration should use headless backend")

    // Should have default command
    XCTAssertEqual(config.command, "claude",
                  "Default command should be 'claude'")

    // Should not have node executable specified
    XCTAssertNil(config.nodeExecutable,
                "Default should not specify node executable")

    // Should not have SDK wrapper path specified
    XCTAssertNil(config.sdkWrapperPath,
                "Default should not specify SDK wrapper path")

    // Should have default paths
    XCTAssertFalse(config.additionalPaths.isEmpty,
                  "Should have default additional paths")

    // Should not enable debug logging by default
    XCTAssertFalse(config.enableDebugLogging,
                  "Debug logging should be disabled by default")
  }

  func testHeadlessBackendConfiguration() {
    let config = ClaudeCodeConfiguration(
      backend: .headless,
      command: "claude",
      workingDirectory: "/tmp/test",
      enableDebugLogging: true
    )

    XCTAssertEqual(config.backend, .headless)
    XCTAssertEqual(config.command, "claude")
    XCTAssertEqual(config.workingDirectory, "/tmp/test")
    XCTAssertTrue(config.enableDebugLogging)
  }

  func testAgentSDKBackendConfiguration() {
    let config = ClaudeCodeConfiguration(
      backend: .agentSDK,
      command: "claude",
      nodeExecutable: "/usr/local/bin/node",
      sdkWrapperPath: "/path/to/wrapper.mjs",
      workingDirectory: "/tmp/test"
    )

    XCTAssertEqual(config.backend, .agentSDK)
    XCTAssertEqual(config.nodeExecutable, "/usr/local/bin/node")
    XCTAssertEqual(config.sdkWrapperPath, "/path/to/wrapper.mjs")
    XCTAssertEqual(config.workingDirectory, "/tmp/test")
  }

  func testBackendTypeRawValues() {
    // Verify BackendType enum values
    XCTAssertEqual(BackendType.headless.rawValue, "headless")
    XCTAssertEqual(BackendType.agentSDK.rawValue, "agentSDK")
  }

  func testBackendTypeCodable() throws {
    // Test encoding
    let headless = BackendType.headless
    let encoder = JSONEncoder()
    let headlessData = try encoder.encode(headless)
    let headlessString = String(data: headlessData, encoding: .utf8)
    XCTAssertEqual(headlessString, "\"headless\"")

    let agentSDK = BackendType.agentSDK
    let agentSDKData = try encoder.encode(agentSDK)
    let agentSDKString = String(data: agentSDKData, encoding: .utf8)
    XCTAssertEqual(agentSDKString, "\"agentSDK\"")

    // Test decoding
    let decoder = JSONDecoder()
    let decodedHeadless = try decoder.decode(BackendType.self, from: headlessData)
    XCTAssertEqual(decodedHeadless, .headless)

    let decodedAgentSDK = try decoder.decode(BackendType.self, from: agentSDKData)
    XCTAssertEqual(decodedAgentSDK, .agentSDK)
  }

  func testCustomPathConfiguration() {
    var config = ClaudeCodeConfiguration.default

    // Add custom paths
    config.additionalPaths.append("/custom/bin")
    config.additionalPaths.append("/another/path")

    XCTAssertTrue(config.additionalPaths.contains("/custom/bin"))
    XCTAssertTrue(config.additionalPaths.contains("/another/path"))

    // Should still have default paths
    XCTAssertTrue(config.additionalPaths.contains("/usr/local/bin"))
    XCTAssertTrue(config.additionalPaths.contains("/opt/homebrew/bin"))
  }

  func testEnvironmentVariables() {
    let env = ["API_KEY": "test123", "NODE_ENV": "production"]
    let config = ClaudeCodeConfiguration(
      environment: env
    )

    XCTAssertEqual(config.environment["API_KEY"], "test123")
    XCTAssertEqual(config.environment["NODE_ENV"], "production")
  }

  func testCommandSuffix() {
    let config = ClaudeCodeConfiguration(
      commandSuffix: "--"
    )

    XCTAssertEqual(config.commandSuffix, "--")
  }

  func testDisallowedTools() {
    let config = ClaudeCodeConfiguration(
      disallowedTools: ["Delete", "Bash"]
    )

    XCTAssertNotNil(config.disallowedTools)
    XCTAssertEqual(config.disallowedTools?.count, 2)
    XCTAssertTrue(config.disallowedTools?.contains("Delete") ?? false)
    XCTAssertTrue(config.disallowedTools?.contains("Bash") ?? false)
  }

  func testBackendMutability() {
    var config = ClaudeCodeConfiguration.default

    // Should be able to change backend at runtime
    XCTAssertEqual(config.backend, .headless)

    config.backend = .agentSDK
    XCTAssertEqual(config.backend, .agentSDK)

    config.backend = .headless
    XCTAssertEqual(config.backend, .headless)
  }

  func testNodeExecutableMutability() {
    var config = ClaudeCodeConfiguration.default

    XCTAssertNil(config.nodeExecutable)

    config.nodeExecutable = "/usr/local/bin/node"
    XCTAssertEqual(config.nodeExecutable, "/usr/local/bin/node")

    config.nodeExecutable = nil
    XCTAssertNil(config.nodeExecutable)
  }

  func testComprehensiveConfiguration() {
    // Test all configuration options together
    let config = ClaudeCodeConfiguration(
      backend: .agentSDK,
      command: "custom-claude",
      nodeExecutable: "/custom/node",
      sdkWrapperPath: "/custom/wrapper.mjs",
      workingDirectory: "/workspace",
      environment: ["KEY": "value"],
      enableDebugLogging: true,
      additionalPaths: ["/custom/path"],
      commandSuffix: "---",
      disallowedTools: ["DangerousTool"]
    )

    XCTAssertEqual(config.backend, .agentSDK)
    XCTAssertEqual(config.command, "custom-claude")
    XCTAssertEqual(config.nodeExecutable, "/custom/node")
    XCTAssertEqual(config.sdkWrapperPath, "/custom/wrapper.mjs")
    XCTAssertEqual(config.workingDirectory, "/workspace")
    XCTAssertEqual(config.environment["KEY"], "value")
    XCTAssertTrue(config.enableDebugLogging)
    XCTAssertTrue(config.additionalPaths.contains("/custom/path"))
    XCTAssertEqual(config.commandSuffix, "---")
    XCTAssertEqual(config.disallowedTools, ["DangerousTool"])
  }
}
