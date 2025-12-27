//
//  OptionsTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class OptionsTests: XCTestCase {
  
  func testOptionsInitialization() {
    // Test default options initialization
    let options = ClaudeCodeOptions()
    
    XCTAssertNil(options.abortController)
    XCTAssertNil(options.allowedTools)
    XCTAssertNil(options.appendSystemPrompt)
    XCTAssertNil(options.systemPrompt)
    XCTAssertNil(options.disallowedTools)
    XCTAssertNil(options.maxThinkingTokens)
    XCTAssertNil(options.maxTurns)
    XCTAssertNil(options.mcpServers)
    XCTAssertNil(options.permissionMode)
    XCTAssertNil(options.permissionPromptToolName)
    XCTAssertNil(options.continue)
    XCTAssertNil(options.resume)
    XCTAssertNil(options.model)
    XCTAssertNil(options.timeout)
    XCTAssertNil(options.mcpConfigPath)
    XCTAssertFalse(options.verbose)
  }
  
  func testOptionsToCommandArgs() {
    // Test comprehensive options configuration as shown in README
    var options = ClaudeCodeOptions()
    options.verbose = true
    options.maxTurns = 5
    options.systemPrompt = "You are a senior backend engineer specializing in Swift."
    options.appendSystemPrompt = "After writing code, add comprehensive comments."
    options.timeout = 300 // 5 minute timeout
    options.model = "claude-3-sonnet-20240229"
    options.permissionMode = .acceptEdits
    options.maxThinkingTokens = 10000
    
    // Tool configuration
    options.allowedTools = ["Read", "Write", "Bash"]
    options.disallowedTools = ["Delete"]
    
    let args = options.toCommandArgs()
    
    // Verify all arguments are present
    XCTAssertTrue(args.contains("-p")) // printMode is always true internally
    XCTAssertTrue(args.contains("--verbose"))
    XCTAssertTrue(args.contains("--max-turns"))
    XCTAssertTrue(args.contains("5"))
    XCTAssertTrue(args.contains("--system-prompt"))
    XCTAssertTrue(args.contains("'You are a senior backend engineer specializing in Swift.'"))
    XCTAssertTrue(args.contains("--append-system-prompt"))
    XCTAssertTrue(args.contains("'After writing code, add comprehensive comments.'"))
    XCTAssertTrue(args.contains("--model"))
    XCTAssertTrue(args.contains("claude-3-sonnet-20240229"))
    XCTAssertTrue(args.contains("--permission-mode"))
    XCTAssertTrue(args.contains("acceptEdits"))
    XCTAssertTrue(args.contains("--max-thinking-tokens"))
    XCTAssertTrue(args.contains("10000"))
    XCTAssertTrue(args.contains("--allowedTools"))
    XCTAssertTrue(args.contains("\"Read,Write,Bash\""))
    XCTAssertTrue(args.contains("--disallowedTools"))
    XCTAssertTrue(args.contains("\"Delete\""))
  }
  
  func testPermissionModeValues() {
    // Test all permission mode values
    XCTAssertEqual(PermissionMode.default.rawValue, "default")
    XCTAssertEqual(PermissionMode.acceptEdits.rawValue, "acceptEdits")
    XCTAssertEqual(PermissionMode.bypassPermissions.rawValue, "bypassPermissions")
    XCTAssertEqual(PermissionMode.plan.rawValue, "plan")
  }
  
  func testContinueAndResumeOptions() {
    // Test continue and resume options
    var options = ClaudeCodeOptions()
    options.continue = true
    options.resume = "550e8400-e29b-41d4-a716-446655440000"
    
    // These are handled separately in the client methods, not in toCommandArgs
    let args = options.toCommandArgs()
    
    // Verify these don't appear in command args (they're added by specific methods)
    XCTAssertFalse(args.contains("--continue"))
    XCTAssertFalse(args.contains("--resume"))
  }
  
  func testTimeoutOption() {
    // Test timeout option
    var options = ClaudeCodeOptions()
    options.timeout = 600 // 10 minutes
    
    // Timeout is handled at the process level, not in command args
    let args = options.toCommandArgs()
    XCTAssertFalse(args.contains("--timeout"))
  }
}