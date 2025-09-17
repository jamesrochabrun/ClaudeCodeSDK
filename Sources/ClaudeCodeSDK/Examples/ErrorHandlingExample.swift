//
//  ErrorHandlingExample.swift
//  ClaudeCodeSDK
//
//  Example demonstrating error handling, retry logic, and rate limiting
//

import Foundation

// MARK: - Basic Error Handling

func basicErrorHandling() async throws {
    let client = ClaudeCodeClient()

    do {
        let result = try await client.runSinglePrompt(
            prompt: "Write a hello world function",
            outputFormat: .json,
            options: nil
        )
        print("Success: \(result)")
    } catch let error as ClaudeCodeError {
        switch error {
        case .notInstalled:
            print("Please install Claude Code first")
        case .timeout(let duration):
            print("Request timed out after \(duration) seconds")
        case .rateLimitExceeded(let retryAfter):
            print("Rate limited. Retry after: \(retryAfter ?? 60) seconds")
        case .permissionDenied(let message):
            print("Permission denied: \(message)")
        case .processLaunchFailed(let message):
            print("Failed to launch Claude process: \(message)")
            print("Check your command arguments and configuration")
        default:
            print("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Timeout Example

func timeoutExample() async throws {
    let client = ClaudeCodeClient()
    
    var options = ClaudeCodeOptions()
    options.timeout = 30 // 30 second timeout
    
    do {
        let result = try await client.runSinglePrompt(
            prompt: "Analyze this large codebase...",
            outputFormat: .json,
            options: options
        )
        print("Completed: \(result)")
    } catch ClaudeCodeError.timeout(let duration) {
        print("Operation timed out after \(duration) seconds")
    }
}

// MARK: - Retry Logic Example

func retryExample() async {
    let client = ClaudeCodeClient()
    
    // Use default retry policy (3 attempts with exponential backoff)
    do {
        let result = try await client.runSinglePromptWithRetry(
            prompt: "Generate a REST API",
            outputFormat: .json,
            retryPolicy: .default
        )
        print("Success after retries: \(result)")
    } catch {
        print("Failed after all retry attempts: \(error)")
    }
    
    // Use conservative retry policy for rate-limited operations
    do {
        let result = try await client.runSinglePromptWithRetry(
            prompt: "Complex analysis task",
            outputFormat: .json,
            retryPolicy: .conservative
        )
        print("Success with conservative retry: \(result)")
    } catch {
        print("Failed with conservative retry: \(error)")
    }
}

// MARK: - Combined Example with Smart Error Handling

func smartErrorHandling() async throws {
    let client = ClaudeCodeClient()
    var options = ClaudeCodeOptions()
    options.timeout = 60
    
    var attempts = 0
    let maxAttempts = 3
    
    while attempts < maxAttempts {
        attempts += 1
        
        do {
            let result = try await client.runSinglePrompt(
                prompt: "Complex task",
                outputFormat: .json,
                options: options
            )
            print("Success: \(result)")
            break // Success, exit loop
            
        } catch let error as ClaudeCodeError {
            print("Attempt \(attempts) failed: \(error.localizedDescription)")
            
            // Check if error is retryable
            if error.isRetryable && attempts < maxAttempts {
                if let delay = error.suggestedRetryDelay {
                    print("Waiting \(delay) seconds before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } else {
                // Non-retryable error or max attempts reached
                print("Giving up after \(attempts) attempts")
                throw error
            }
        }
    }
}

// MARK: - Abort Controller Example

func abortExample() async {
    let client = ClaudeCodeClient()

    var options = ClaudeCodeOptions()
    let abortController = AbortController()
    options.abortController = abortController

    // Start a long-running task
    Task {
        do {
            let result = try await client.runSinglePrompt(
                prompt: "Very long running task...",
                outputFormat: .streamJson,
                options: options
            )
            print("Task completed: \(result)")
        } catch ClaudeCodeError.cancelled {
            print("Task was cancelled")
        }
    }

    // Cancel after 5 seconds
    Task {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        print("Aborting task...")
        abortController.abort()
    }
}

// MARK: - Process Launch Failure Example

func processLaunchFailureExample() async {
    let client = ClaudeCodeClient()

    // Example 1: Handle malformed command arguments
    var badOptions = ClaudeCodeOptions()
    badOptions.printMode = true
    // Simulate a bad configuration that might cause shell parsing errors
    badOptions.systemPrompt = "System prompt with \"unescaped quotes\" and bad syntax"

    do {
        let result = try await client.runSinglePrompt(
            prompt: "Test prompt",
            outputFormat: .streamJson,
            options: badOptions
        )

        // This code won't be reached if process fails to launch
        if case .stream(_) = result {
            print("Got stream publisher")
        }
    } catch ClaudeCodeError.processLaunchFailed(let message) {
        // This error is now properly thrown instead of returning a dead stream
        print("Process failed to launch: \(message)")

        // Check for specific error patterns
        if message.contains("syntax error") || message.contains("parse error") {
            print("Command syntax error detected. Review your configuration.")
        } else if message.contains("bad option") {
            print("Invalid command option detected.")
        }
    } catch {
        print("Other error: \(error)")
    }

    // Example 2: Handle with resumeConversation
    do {
        let result = try await client.resumeConversation(
            sessionId: "some-session",
            prompt: "Continue",
            outputFormat: .streamJson,
            options: badOptions
        )
        print("Resume succeeded: \(result)")
    } catch ClaudeCodeError.processLaunchFailed(let message) {
        // Now properly catches process launch failures
        print("Failed to resume conversation - process launch failed: \(message)")
    } catch {
        print("Resume failed with error: \(error)")
    }
}
