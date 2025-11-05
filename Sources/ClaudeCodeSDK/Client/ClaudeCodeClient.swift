//
//  ClaudeCodeClient.swift
//  ClaudeCodeSDK
//
//  Refactored to use backend abstraction (Phase 2)
//
import Foundation
import os.log

/// Concrete implementation of ClaudeCodeSDK that uses pluggable backends
public final class ClaudeCodeClient: ClaudeCode, @unchecked Sendable {
	private var backend: ClaudeCodeBackend
	private var logger: Logger?

	/// Configuration for the client - can be updated at any time
	public var configuration: ClaudeCodeConfiguration {
		didSet {
			// Recreate backend if type or working directory changed
			if oldValue.backend != self.configuration.backend ||
			   oldValue.workingDirectory != self.configuration.workingDirectory {
				do {
					backend = try BackendFactory.createBackend(for: self.configuration)
					logger?.info("Backend recreated - type: \(self.configuration.backend.rawValue), workingDir: \(self.configuration.workingDirectory ?? "none")")
				} catch {
					logger?.error("Failed to create backend: \(error.localizedDescription)")
					// Keep the old backend if creation fails
					configuration = oldValue
				}
			}
		}
	}

	/// Debug information about the last command executed
	public var lastExecutedCommandInfo: ExecutedCommandInfo? {
		return backend.lastExecutedCommandInfo
	}

	/// Initializes the client with a configuration
	/// - Parameter configuration: The configuration to use
	/// - Throws: ClaudeCodeError if backend creation fails
	public init(configuration: ClaudeCodeConfiguration = .default) throws {
		self.configuration = configuration

		if configuration.enableDebugLogging {
			self.logger = Logger(subsystem: "com.yourcompany.ClaudeCodeClient", category: "ClaudeCode")
			logger?.info("Initializing Claude Code client with backend: \(configuration.backend.rawValue)")
		}

		// Create the appropriate backend
		self.backend = try BackendFactory.createBackend(for: configuration)

		logger?.info("Claude Code client initialized successfully")
	}

	/// Convenience initializer for backward compatibility
	public convenience init(workingDirectory: String = "", debug: Bool = false) throws {
		var config = ClaudeCodeConfiguration.default
		config.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
		config.enableDebugLogging = debug
		try self.init(configuration: config)
	}

	// MARK: - Protocol Implementation

	public func runWithStdin(
		stdinContent: String,
		outputFormat: ClaudeCodeOutputFormat,
		options: ClaudeCodeOptions?
	) async throws -> ClaudeCodeResult {
		logger?.debug("Running with stdin (backend: \(self.configuration.backend.rawValue))")
		return try await backend.runWithStdin(
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
		logger?.debug("Running single prompt (backend: \(self.configuration.backend.rawValue))")
		return try await backend.runSinglePrompt(
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
		logger?.debug("Continuing conversation (backend: \(self.configuration.backend.rawValue))")
		return try await backend.continueConversation(
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
		logger?.debug("Resuming conversation \(sessionId) (backend: \(self.configuration.backend.rawValue))")
		return try await backend.resumeConversation(
			sessionId: sessionId,
			prompt: prompt,
			outputFormat: outputFormat,
			options: options
		)
	}

	public func listSessions() async throws -> [SessionInfo] {
		logger?.debug("Listing sessions (backend: \(self.configuration.backend.rawValue))")
		return try await backend.listSessions()
	}

	public func cancel() {
		logger?.info("Canceling operations")
		backend.cancel()
	}

	public func validateCommand(_ command: String) async throws -> Bool {
		logger?.info("Validating command: \(command)")

		// Use backend-specific validation
		if configuration.backend == .agentSDK {
			// For Agent SDK, validate the setup instead
			return try await backend.validateSetup()
		} else {
			// For headless, use the traditional command validation
			let checkCommand = "which \(command)"

			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/bin/zsh")
			process.arguments = ["-l", "-c", checkCommand]

			if let workingDirectory = configuration.workingDirectory {
				process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
			}

			var env = ProcessInfo.processInfo.environment

			// Add additional paths to PATH
			if !configuration.additionalPaths.isEmpty {
				let additionalPathString = configuration.additionalPaths.joined(separator: ":")
				if let currentPath = env["PATH"] {
					env["PATH"] = "\(currentPath):\(additionalPathString)"
				} else {
					env["PATH"] = "\(additionalPathString):/bin"
				}
			}

			// Apply custom environment variables
			for (key, value) in configuration.environment {
				env[key] = value
			}

			process.environment = env

			let outputPipe = Pipe()
			let errorPipe = Pipe()
			process.standardOutput = outputPipe
			process.standardError = errorPipe

			do {
				try process.run()
				process.waitUntilExit()

				// 'which' returns 0 if command is found, non-zero otherwise
				let isValid = process.terminationStatus == 0

				if isValid {
					let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
					if let path = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
						logger?.info("Command '\(command)' found at: \(path)")
					}
				} else {
					logger?.warning("Command '\(command)' not found in PATH")

					// Log current PATH for debugging
					if configuration.enableDebugLogging {
						let pathCheckCommand = "echo $PATH"
						let pathProcess = Process()
						pathProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
						pathProcess.arguments = ["-l", "-c", pathCheckCommand]
						pathProcess.environment = env

						let pathPipe = Pipe()
						pathProcess.standardOutput = pathPipe

						try pathProcess.run()
						pathProcess.waitUntilExit()

						let pathData = pathPipe.fileHandleForReading.readDataToEndOfFile()
						if let currentPath = String(data: pathData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
							logger?.debug("Current PATH: \(currentPath)")
						}
					}
				}

				return isValid
			} catch {
				logger?.error("Error validating command '\(command)': \(error.localizedDescription)")
				throw ClaudeCodeError.executionFailed("Failed to validate command: \(error.localizedDescription)")
			}
		}
	}
}
