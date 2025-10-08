//
//  SDKWrapperTests.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/7/2025.
//

import XCTest
@testable import ClaudeCodeSDK

final class SDKWrapperTests: XCTestCase {

  func testSDKWrapperExists() {
    // Verify the wrapper script exists in Resources
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    XCTAssertTrue(FileManager.default.fileExists(atPath: wrapperPath),
                 "SDK wrapper script should exist at: \(wrapperPath)")
  }

  func testSDKWrapperIsExecutable() {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    guard FileManager.default.fileExists(atPath: wrapperPath) else {
      XCTFail("Wrapper script not found")
      return
    }

    // Check if file is executable
    XCTAssertTrue(FileManager.default.isExecutableFile(atPath: wrapperPath),
                 "SDK wrapper should be executable")
  }

  func testSDKWrapperSyntax() throws {
    // Skip this test if Node.js is not available
    guard NodePathDetector.detectNodePath() != nil else {
      throw XCTSkip("Node.js not available, skipping syntax check")
    }

    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    // Use node --check to validate syntax without executing
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "node --check \(wrapperPath)"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    XCTAssertEqual(process.terminationStatus, 0,
                  "SDK wrapper should have valid JavaScript syntax")
  }

  func testSDKWrapperHasShebang() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)
    let firstLine = content.components(separatedBy: .newlines).first ?? ""

    XCTAssertTrue(firstLine.hasPrefix("#!/usr/bin/env node"),
                 "SDK wrapper should have proper shebang")
  }

  func testSDKWrapperHasImport() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("import { query }"),
                 "SDK wrapper should import query function")
    XCTAssertTrue(content.contains("@anthropic-ai/claude-agent-sdk"),
                 "SDK wrapper should import from correct package")
  }

  func testSDKWrapperHasMainFunction() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("async function main()"),
                 "SDK wrapper should have main function")
    XCTAssertTrue(content.contains("main().catch"),
                 "SDK wrapper should call main and handle errors")
  }

  func testSDKWrapperHasOptionMapping() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    // Check for key option mappings
    XCTAssertTrue(content.contains("function mapOptions"),
                 "SDK wrapper should have mapOptions function")
    XCTAssertTrue(content.contains("options.model"),
                 "Should map model option")
    XCTAssertTrue(content.contains("options.maxTurns"),
                 "Should map maxTurns option")
    XCTAssertTrue(content.contains("options.allowedTools"),
                 "Should map allowedTools option")
    XCTAssertTrue(content.contains("options.permissionMode"),
                 "Should map permissionMode option")
  }

  func testSDKWrapperErrorHandling() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("try {"),
                 "SDK wrapper should have error handling")
    XCTAssertTrue(content.contains("} catch (error) {"),
                 "SDK wrapper should catch errors")
    XCTAssertTrue(content.contains("console.error"),
                 "SDK wrapper should log errors")
    XCTAssertTrue(content.contains("process.exit(1)"),
                 "SDK wrapper should exit with error code on failure")
  }

  func testSDKWrapperJSONOutput() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("JSON.parse"),
                 "SDK wrapper should parse JSON input")
    XCTAssertTrue(content.contains("JSON.stringify"),
                 "SDK wrapper should stringify JSON output")
    XCTAssertTrue(content.contains("console.log(JSON.stringify(message))"),
                 "SDK wrapper should output messages as JSON")
  }

  func testSDKWrapperConfigValidation() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("if (!configJson)"),
                 "Should validate config presence")
    XCTAssertTrue(content.contains("if (!prompt)"),
                 "Should validate prompt presence")
  }

  func testSDKWrapperSystemPromptHandling() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    // Check for system prompt handling
    XCTAssertTrue(content.contains("options.systemPrompt"),
                 "Should handle systemPrompt option")
    XCTAssertTrue(content.contains("options.appendSystemPrompt"),
                 "Should handle appendSystemPrompt option")
  }

  func testSDKWrapperMCPSupport() throws {
    let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"

    let content = try String(contentsOfFile: wrapperPath, encoding: .utf8)

    XCTAssertTrue(content.contains("options.mcpServers"),
                 "Should support MCP servers configuration")
  }
}
