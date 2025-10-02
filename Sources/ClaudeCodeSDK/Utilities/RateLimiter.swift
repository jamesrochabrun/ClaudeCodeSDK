//
//  RateLimiter.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation
import OSLog

/// Token bucket algorithm implementation for rate limiting
public actor RateLimiter {
  private let capacity: Int
  private let refillRate: Double // tokens per second
  private var tokens: Double
  private var lastRefill: Date
  private let logger: Logger?
  
  /// Queue of waiting requests
  private var waitingRequests: [CheckedContinuation<Void, Error>] = []
  
  /// Create a rate limiter with specified capacity and refill rate
  /// - Parameters:
  ///   - capacity: Maximum number of tokens in the bucket
  ///   - refillRate: Number of tokens added per second
  public init(capacity: Int, refillRate: Double, logger: Logger? = nil) {
    self.capacity = capacity
    self.refillRate = refillRate
    self.tokens = Double(capacity)
    self.lastRefill = Date()
    self.logger = logger
  }
  
  /// Create a rate limiter with requests per minute
  public init(requestsPerMinute: Int, burstCapacity: Int? = nil, logger: Logger? = nil) {
    let capacity = burstCapacity ?? requestsPerMinute
    let refillRate = Double(requestsPerMinute) / 60.0
    
    self.capacity = capacity
    self.refillRate = refillRate
    self.tokens = Double(capacity)
    self.lastRefill = Date()
    self.logger = logger
  }
  
  /// Acquire a token, waiting if necessary
  public func acquire() async throws {
    // Refill tokens based on time passed
    refillTokens()
    
    // If we have tokens available, consume one
    if tokens >= 1 {
      tokens -= 1
      let log = "Rate limiter: Token acquired, \(Int(tokens)) remaining"
      logger?.debug("\(log)")
      return
    }
    
    // Calculate wait time
    let waitTime = (1.0 - tokens) / refillRate
    let log = "Rate limiter: No tokens available, waiting \(String(format: "%.1f", waitTime))s"
    logger?.info("\(log)")
    
    // Wait for token to be available
    try await withCheckedThrowingContinuation { continuation in
      waitingRequests.append(continuation)
    }
  }
  
  /// Try to acquire a token without waiting
  public func tryAcquire() -> Bool {
    refillTokens()
    
    if tokens >= 1 {
      tokens -= 1
      let log = "Rate limiter: Token acquired (try), \(Int(tokens)) remaining"
      logger?.debug("\(log)")
      return true
    }
    
    logger?.debug("Rate limiter: No tokens available (try)")
    return false
  }
  
  /// Get the current number of available tokens
  public func availableTokens() -> Int {
    refillTokens()
    return Int(tokens)
  }
  
  /// Reset the rate limiter to full capacity
  public func reset() {
    tokens = Double(capacity)
    lastRefill = Date()
    
    // Resume all waiting requests
    for continuation in waitingRequests {
      continuation.resume()
    }
    waitingRequests.removeAll()
    
    let log = "Rate limiter: Reset to full capacity (\(capacity) tokens)"
    logger?.info("\(log)")
  }
  
  private func refillTokens() {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastRefill)
    let tokensToAdd = elapsed * refillRate
    
    if tokensToAdd > 0 {
      tokens = min(Double(capacity), tokens + tokensToAdd)
      lastRefill = now
      
      // Process waiting requests if we have tokens
      processWaitingRequests()
    }
  }
  
  private func processWaitingRequests() {
    while !waitingRequests.isEmpty && tokens >= 1 {
      tokens -= 1
      let continuation = waitingRequests.removeFirst()
      continuation.resume()
    }
    
    // Schedule next check if we still have waiting requests
    if !waitingRequests.isEmpty {
      let nextTokenTime = (1.0 - tokens) / refillRate
      Task {
        try? await Task.sleep(nanoseconds: UInt64(nextTokenTime * 1_000_000_000))
        refillTokens()
      }
    }
  }
}

/// Rate-limited wrapper for ClaudeCode operations
public class RateLimitedClaudeCode: ClaudeCode {
  private var wrapped: ClaudeCode
  private let rateLimiter: RateLimiter
  
  public var configuration: ClaudeCodeConfiguration {
    get { wrapped.configuration }
    set { wrapped.configuration = newValue }
  }

  public var lastExecutedCommandInfo: ExecutedCommandInfo? {
    wrapped.lastExecutedCommandInfo
  }

  public init(
    wrapped: ClaudeCode,
    requestsPerMinute: Int,
    burstCapacity: Int? = nil
  ) {
    self.wrapped = wrapped
    self.rateLimiter = RateLimiter(
      requestsPerMinute: requestsPerMinute,
      burstCapacity: burstCapacity
    )
  }
  
  public func runWithStdin(
    stdinContent: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    try await rateLimiter.acquire()
    return try await wrapped.runWithStdin(
      stdinContent: stdinContent,
      outputFormat: outputFormat,
      options: options
    )
  }
  
  public func runSinglePrompt(
    prompt: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    try await rateLimiter.acquire()
    return try await wrapped.runSinglePrompt(
      prompt: prompt,
      outputFormat: outputFormat,
      options: options
    )
  }
  
  public func continueConversation(
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    try await rateLimiter.acquire()
    return try await wrapped.continueConversation(
      prompt: prompt,
      outputFormat: outputFormat,
      options: options
    )
  }
  
  public func resumeConversation(
    sessionId: String,
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    try await rateLimiter.acquire()
    return try await wrapped.resumeConversation(
      sessionId: sessionId,
      prompt: prompt,
      outputFormat: outputFormat,
      options: options
    )
  }
  
  public func listSessions() async throws -> [SessionInfo] {
    try await rateLimiter.acquire()
    return try await wrapped.listSessions()
  }
  
  public func cancel() {
    wrapped.cancel()
  }
  
  public func validateCommand(_ command: String) async throws -> Bool {
    try await rateLimiter.acquire()
    return try await wrapped.validateCommand(command)
  }
}
