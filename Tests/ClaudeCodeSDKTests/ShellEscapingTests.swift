//
//  ShellEscapingTests.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/15/25.
//

import XCTest
@testable import ClaudeCodeSDK

final class ShellEscapingTests: XCTestCase {

  func testBasicShellEscaping() {
    let options = ClaudeCodeOptions()

    // Create a test with problematic characters
    var testOptions = options
    testOptions.appendSystemPrompt = "Hello { world }"

    let args = testOptions.toCommandArgs()

    // The args should contain the --append-system-prompt flag
    XCTAssertTrue(args.contains("--append-system-prompt"))

    // Find the index of the flag
    if let index = args.firstIndex(of: "--append-system-prompt") {
      // The next element should be the escaped value
      let escapedValue = args[index + 1]

      // Should be wrapped in single quotes
      XCTAssertTrue(escapedValue.hasPrefix("'"))
      XCTAssertTrue(escapedValue.hasSuffix("'"))

      print("Escaped value: \(escapedValue)")
    }
  }

  func testShellEscapingWithNewlines() {
    let options = ClaudeCodeOptions()

    var testOptions = options
    testOptions.appendSystemPrompt = """
    First line
    Second line with {braces}
    Third line
    """

    let args = testOptions.toCommandArgs()

    // Should still work with newlines
    XCTAssertTrue(args.contains("--append-system-prompt"))

    if let index = args.firstIndex(of: "--append-system-prompt") {
      let escapedValue = args[index + 1]

      // Should be properly wrapped
      XCTAssertTrue(escapedValue.hasPrefix("'"))
      XCTAssertTrue(escapedValue.hasSuffix("'"))

      print("Escaped value with newlines: \(escapedValue)")
    }
  }

  func testShellEscapingWithSingleQuotes() {
    let options = ClaudeCodeOptions()

    var testOptions = options
    testOptions.appendSystemPrompt = "It's a test with 'quotes'"

    let args = testOptions.toCommandArgs()

    XCTAssertTrue(args.contains("--append-system-prompt"))

    if let index = args.firstIndex(of: "--append-system-prompt") {
      let escapedValue = args[index + 1]

      // Should handle single quotes correctly
      XCTAssertTrue(escapedValue.contains("'\\''"))

      print("Escaped value with single quotes: \(escapedValue)")
    }
  }

  func testShellEscapingWithComplexJSON() {
    let options = ClaudeCodeOptions()

    var testOptions = options
    testOptions.appendSystemPrompt = """
    {"type":"result","data":{"value":123}}
    With unmatched { character
    """

    let args = testOptions.toCommandArgs()

    XCTAssertTrue(args.contains("--append-system-prompt"))

    if let index = args.firstIndex(of: "--append-system-prompt") {
      let escapedValue = args[index + 1]

      // Should be properly escaped
      XCTAssertTrue(escapedValue.hasPrefix("'"))
      XCTAssertTrue(escapedValue.hasSuffix("'"))

      print("Escaped value with JSON: \(escapedValue)")
    }
  }
}
