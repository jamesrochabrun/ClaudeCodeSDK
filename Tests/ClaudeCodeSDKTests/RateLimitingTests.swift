//
//  RateLimitingTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK Tests
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class RateLimitingTests: XCTestCase {
  
  func testRateLimiterInitialization() async {
    // Test rate limiter initialization
    let limiter = RateLimiter(requestsPerMinute: 10, burstCapacity: 3)
    
    // RateLimiter doesn't expose these properties directly
    // We can only test available tokens
    let available = await limiter.availableTokens()
    XCTAssertEqual(available, 3) // Should start with full burst capacity
  }
  
  func testRateLimiterTokenConsumption() async throws {
    // Test token consumption
    let limiter = RateLimiter(requestsPerMinute: 60, burstCapacity: 3)
    
    // Should be able to consume burst capacity immediately
    let result1 = await limiter.tryAcquire()
    XCTAssertTrue(result1)
    let result2 = await limiter.tryAcquire()
    XCTAssertTrue(result2)
    let result3 = await limiter.tryAcquire()
    XCTAssertTrue(result3)
    
    // Fourth request should fail (no tokens left)
    let result4 = await limiter.tryAcquire()
    XCTAssertFalse(result4)
  }
  
  func testRateLimiterWaitForToken() async throws {
    // Test waiting for token
    let limiter = RateLimiter(requestsPerMinute: 60, burstCapacity: 1)
    
    // Consume the only token
    let consumed = await limiter.tryAcquire()
    XCTAssertTrue(consumed)
    
    // Measure wait time
    let startTime = Date()
    try await limiter.acquire()
    let endTime = Date()
    
    let waitTime = endTime.timeIntervalSince(startTime)
    
    // With 60 requests per minute, refill interval is 1 second
    // Wait time should be approximately 1 second (with some tolerance)
    XCTAssertGreaterThan(waitTime, 0.9)
    XCTAssertLessThan(waitTime, 1.2)
  }
  
  func testRateLimitedClaudeCodeWrapper() {
    // Test the RateLimitedClaudeCode wrapper from README
    let mockClient = MockClaudeCode()
    let rateLimitedClient = RateLimitedClaudeCode(
      wrapped: mockClient,
      requestsPerMinute: 10,
      burstCapacity: 3
    )
    
    XCTAssertNotNil(rateLimitedClient)
    // RateLimitedClaudeCode doesn't expose limiter directly
    // Just verify it was created successfully
  }
  
  func testRateLimiterRefillRate() async {
    // Test refill rate by consuming tokens and waiting
    let limiter1 = RateLimiter(requestsPerMinute: 60, burstCapacity: 2)
    
    // Consume all tokens
    _ = await limiter1.tryAcquire()
    _ = await limiter1.tryAcquire()
    
    // Should have 0 tokens
    let available1 = await limiter1.availableTokens()
    XCTAssertEqual(available1, 0)
    
    // Wait ~1 second for one token to refill
    try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
    
    // Should have 1 token refilled
    let available2 = await limiter1.availableTokens()
    XCTAssertGreaterThanOrEqual(available2, 1)
  }
  
  func testRateLimiterCancellation() async throws {
    // Test cancellation during wait
    let limiter = RateLimiter(requestsPerMinute: 1, burstCapacity: 1)
    
    // Consume the token
    _ = await limiter.tryAcquire()
    
    // Start waiting in a task
    let waitTask = Task {
      try await limiter.acquire()
    }
    
    // Cancel the task
    waitTask.cancel()
    
    // Should throw cancellation error
    do {
      try await waitTask.value
      XCTFail("Expected cancellation error")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }
}

// Mock implementation for testing
private class MockClaudeCode: ClaudeCode {
  var configuration: ClaudeCodeConfiguration = .default
  var lastExecutedCommandInfo: ExecutedCommandInfo?

  func runWithStdin(stdinContent: String, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult {
    return .text("Mock response")
  }

  func runSinglePrompt(prompt: String, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult {
    return .text("Mock response")
  }

  func continueConversation(prompt: String?, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult {
    return .text("Mock response")
  }

  func resumeConversation(sessionId: String, prompt: String?, outputFormat: ClaudeCodeOutputFormat, options: ClaudeCodeOptions?) async throws -> ClaudeCodeResult {
    return .text("Mock response")
  }

  func listSessions() async throws -> [SessionInfo] {
    return []
  }

  func cancel() {
    // No-op
  }

  func validateCommand(_ command: String) async throws -> Bool {
    // Mock implementation - always returns true
    return true
  }
}