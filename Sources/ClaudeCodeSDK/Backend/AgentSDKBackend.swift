//
//  AgentSDKBackend.swift
//  ClaudeCodeSDK
//
//  Created by ClaudeCodeSDK on 10/8/2025.
//

@preconcurrency import Combine
import Foundation
import os.log

/// Backend implementation using the Claude Agent SDK via Node.js wrapper
internal final class AgentSDKBackend: ClaudeCodeBackend, @unchecked Sendable {
	private var task: Process?
	private var cancellables = Set<AnyCancellable>()
	private var logger: Logger?
	private let decoder = JSONDecoder()
	private let configuration: ClaudeCodeConfiguration

	init(configuration: ClaudeCodeConfiguration) {
		self.configuration = configuration

		if configuration.enableDebugLogging {
			self.logger = Logger(subsystem: "com.yourcompany.AgentSDKBackend", category: "ClaudeCode")
			logger?.info("Initializing Agent SDK backend")
		}

		decoder.keyDecodingStrategy = .convertFromSnakeCase
	}

	// MARK: - ClaudeCodeBackend Protocol

	func runSinglePrompt(
		prompt: String,
		outputFormat: ClaudeCodeOutputFormat,
		options: ClaudeCodeOptions?
	) async throws -> ClaudeCodeResult {
		guard outputFormat == .streamJson else {
			throw ClaudeCodeError.invalidConfiguration("Agent SDK backend only supports stream-json output format")
		}

		return try await executeSDKCommand(
			prompt: prompt,
			options: options,
			continueSession: false,
			sessionId: nil
		)
	}

	func runWithStdin(
		stdinContent: String,
		outputFormat: ClaudeCodeOutputFormat,
		options: ClaudeCodeOptions?
	) async throws -> ClaudeCodeResult {
		guard outputFormat == .streamJson else {
			throw ClaudeCodeError.invalidConfiguration("Agent SDK backend only supports stream-json output format")
		}

		return try await executeSDKCommand(
			prompt: stdinContent,
			options: options,
			continueSession: false,
			sessionId: nil
		)
	}

	func continueConversation(
		prompt: String?,
		outputFormat: ClaudeCodeOutputFormat,
		options: ClaudeCodeOptions?
	) async throws -> ClaudeCodeResult {
		guard outputFormat == .streamJson else {
			throw ClaudeCodeError.invalidConfiguration("Agent SDK backend only supports stream-json output format")
		}

		return try await executeSDKCommand(
			prompt: prompt,
			options: options,
			continueSession: true,
			sessionId: nil
		)
	}

	func resumeConversation(
		sessionId: String,
		prompt: String?,
		outputFormat: ClaudeCodeOutputFormat,
		options: ClaudeCodeOptions?
	) async throws -> ClaudeCodeResult {
		guard outputFormat == .streamJson else {
			throw ClaudeCodeError.invalidConfiguration("Agent SDK backend only supports stream-json output format")
		}

		return try await executeSDKCommand(
			prompt: prompt,
			options: options,
			continueSession: true,
			sessionId: sessionId
		)
	}

	func listSessions() async throws -> [SessionInfo] {
		// Agent SDK doesn't directly support session listing
		// Return empty array for now
		logger?.warning("Agent SDK backend does not support session listing")
		return []
	}

	func cancel() {
		task?.terminate()
		task = nil

		for cancellable in cancellables {
			cancellable.cancel()
		}
		cancellables.removeAll()
	}

	func validateSetup() async throws -> Bool {
		// Check if Node.js is available
		guard let nodePath = configuration.nodeExecutable ?? NodePathDetector.detectNodePath() else {
			logger?.error("Node.js not found in PATH")
			return false
		}

		// Check if SDK wrapper exists
		guard let wrapperPath = configuration.sdkWrapperPath ?? getDefaultWrapperPath() else {
			logger?.error("SDK wrapper not found")
			return false
		}

		// Verify files exist
		guard FileManager.default.fileExists(atPath: nodePath) else {
			logger?.error("Node executable not found at: \(nodePath)")
			return false
		}

		guard FileManager.default.fileExists(atPath: wrapperPath) else {
			logger?.error("SDK wrapper not found at: \(wrapperPath)")
			return false
		}

		// Check if Agent SDK is installed
		if !NodePathDetector.isAgentSDKInstalled(configuration: configuration) {
			logger?.error("Claude Agent SDK is not installed. Run: npm install -g @anthropic-ai/claude-agent-sdk")
			return false
		}

		logger?.info("Agent SDK backend validation successful")
		return true
	}

	// MARK: - Private Helpers

	private func getDefaultWrapperPath() -> String? {
		// PRIORITY 1: Use Bundle.module to locate the bundled resource
		// This works both in development and when bundled in an app
		if let resourcePath = Bundle.module.path(forResource: "sdk-wrapper", ofType: "mjs") {
			logger?.debug("Found SDK wrapper via Bundle.module: \(resourcePath)")
			return resourcePath
		}

		// PRIORITY 2: Fallback to #file approach for development/testing
		let currentFile = #file
		let currentFileNS = currentFile as NSString
		let dir1 = currentFileNS.deletingLastPathComponent as NSString
		let dir2 = dir1.deletingLastPathComponent as NSString
		let resourcesPath = dir2.deletingLastPathComponent
		let wrapperPath = "\(resourcesPath)/Resources/sdk-wrapper.mjs"

		if FileManager.default.fileExists(atPath: wrapperPath) {
			logger?.debug("Found SDK wrapper via #file fallback: \(wrapperPath)")
			return wrapperPath
		}

		// PRIORITY 3: Try relative to working directory
		if let workingDir = configuration.workingDirectory {
			let relativePath = "\(workingDir)/Resources/sdk-wrapper.mjs"
			if FileManager.default.fileExists(atPath: relativePath) {
				logger?.debug("Found SDK wrapper via working directory: \(relativePath)")
				return relativePath
			}
		}

		logger?.error("SDK wrapper not found in Bundle.module or fallback paths")
		return nil
	}

	private func executeSDKCommand(
		prompt: String?,
		options: ClaudeCodeOptions?,
		continueSession: Bool,
		sessionId: String?
	) async throws -> ClaudeCodeResult {
		// Get Node.js path
		guard let nodePath = configuration.nodeExecutable ?? NodePathDetector.detectNodePath() else {
			throw ClaudeCodeError.notInstalled
		}

		// Get SDK wrapper path
		guard let wrapperPath = configuration.sdkWrapperPath ?? getDefaultWrapperPath() else {
			throw ClaudeCodeError.invalidConfiguration("SDK wrapper not found")
		}

		// Build configuration JSON for the wrapper
		var config: [String: Any] = [:]

		if let prompt = prompt {
			config["prompt"] = prompt
		}

		// Map options to SDK format
		if let options = options {
			var sdkOptions: [String: Any] = [:]

			if let model = options.model {
				sdkOptions["model"] = model
			}
			if let maxTurns = options.maxTurns {
				sdkOptions["maxTurns"] = maxTurns
			}
			if let systemPrompt = options.systemPrompt {
				sdkOptions["systemPrompt"] = systemPrompt
			}
			if let appendSystemPrompt = options.appendSystemPrompt {
				sdkOptions["appendSystemPrompt"] = appendSystemPrompt
			}
			if let allowedTools = options.allowedTools {
				sdkOptions["allowedTools"] = allowedTools
			}
			if let permissionMode = options.permissionMode {
				sdkOptions["permissionMode"] = permissionMode.rawValue
			}
			if let mcpServers = options.mcpServers {
				// Convert MCP servers to SDK format
				var mcpConfig: [String: [String: Any]] = [:]
				for (key, value) in mcpServers {
					switch value {
					case .stdio(let config):
						var serverConfig: [String: Any] = ["command": config.command]
						if let args = config.args {
							serverConfig["args"] = args
						}
						if let env = config.env {
							serverConfig["env"] = env
						}
						mcpConfig[key] = serverConfig
					case .sse(let config):
						var serverConfig: [String: Any] = [
							"type": "sse",
							"url": config.url
						]
						if let headers = config.headers {
							serverConfig["headers"] = headers
						}
						mcpConfig[key] = serverConfig
					}
				}
				sdkOptions["mcpServers"] = mcpConfig
			}

			config["options"] = sdkOptions
		}

		if continueSession {
			config["continue"] = true
		}
		if let sessionId = sessionId {
			config["sessionId"] = sessionId
		}

		// Convert config to JSON string
		let jsonData = try JSONSerialization.data(withJSONObject: config, options: [])
		guard let configJson = String(data: jsonData, encoding: .utf8) else {
			throw ClaudeCodeError.invalidConfiguration("Failed to create config JSON")
		}

		// Build the command
		let command = "\(nodePath) \(wrapperPath) '\(configJson.replacingOccurrences(of: "'", with: "'\\''"))'"

		logger?.info("Executing SDK command: \(command)")

		// Execute the command
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/bin/zsh")
		process.arguments = ["-l", "-c", command]

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

		// Store for cancellation
		self.task = process

		// Handle streaming output
		return try await handleStreamJsonOutput(
			process: process,
			outputPipe: outputPipe,
			errorPipe: errorPipe,
			command: command,
			abortController: options?.abortController,
			timeout: options?.timeout
		)
	}

	// MARK: - Stream JSON Output Handling

	private func handleStreamJsonOutput(
		process: Process,
		outputPipe: Pipe,
		errorPipe: Pipe,
		command: String,
		abortController: AbortController? = nil,
		timeout: TimeInterval? = nil
	) async throws -> ClaudeCodeResult {
		// Create a publisher for streaming JSON
		let subject = PassthroughSubject<ResponseChunk, Error>()
		let publisher = subject.eraseToAnyPublisher()

		// Create a stream buffer
		let streamBuffer = StreamBuffer()

		// Capture values to avoid capturing self in @Sendable closures
		let decoder = self.decoder
		let logger = self.logger

		// Configure handlers for readability
		outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
			let data = fileHandle.availableData
			guard !data.isEmpty else {
				// End of file
				fileHandle.readabilityHandler = nil
				Task {
					// Process any remaining data
					if !(await streamBuffer.isEmpty()) {
						if let outputString = await streamBuffer.getString() {
							AgentSDKBackend.processJsonLine(
								outputString,
								subject: subject,
								decoder: decoder,
								logger: logger
							)
						}
					}
					subject.send(completion: .finished)
				}
				return
			}

			Task {
				// Append to buffer
				await streamBuffer.append(data)

				// Parse the data as JSON line by line
				guard let outputString = await streamBuffer.getString() else { return }

				// Split by newlines
				let lines = outputString.components(separatedBy: .newlines)

				// Process all complete lines except the last one (which may be incomplete)
				if lines.count > 1 {
					// Reset buffer to only contain the potentially incomplete last line
					if !lines.last!.isEmpty {
						if let lastLineData = lines.last!.data(using: .utf8) {
							await streamBuffer.set(lastLineData)
						}
					} else {
						await streamBuffer.set(Data())
					}

					// Process all complete lines
					for i in 0..<lines.count-1 where !lines[i].isEmpty {
						AgentSDKBackend.processJsonLine(
							lines[i],
							subject: subject,
							decoder: decoder,
							logger: logger
						)
					}
				}
			}
		}

		// Configure handler for termination
		process.terminationHandler = { process in
			Task {
				// Process any remaining data
				if !(await streamBuffer.isEmpty()) {
					if let outputString = await streamBuffer.getString() {
						AgentSDKBackend.processJsonLine(
							outputString,
							subject: subject,
							decoder: decoder,
							logger: logger
						)
					}
				}

				if process.terminationStatus != 0 {
					let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
					if let errorString = String(data: errorData, encoding: .utf8) {
						logger?.error("Process terminated with error: \(errorString)")
						subject.send(completion: .failure(ClaudeCodeError.executionFailed(errorString)))
					} else {
						subject.send(completion: .failure(ClaudeCodeError.executionFailed("Unknown error")))
					}
				} else {
					// Clean completion if not already completed
					subject.send(completion: .finished)
				}

				// Clean up
				outputPipe.fileHandleForReading.readabilityHandler = nil
			}
		}

		// Set up abort controller handling
		if let abortController = abortController {
			abortController.signal.onAbort { [weak self] in
				self?.task?.terminate()
			}
		}

		// Set up timeout handling
		if let timeout = timeout {
			Task {
				try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
				if !Task.isCancelled && process.isRunning {
					logger?.warning("Process timed out after \(timeout) seconds")
					process.terminate()
				}
			}
		}

		// Start the process
		do {
			try process.run()
			self.task = process
		} catch {
			logger?.error("Failed to start process: \(error.localizedDescription)")
			throw ClaudeCodeError.processLaunchFailed(error.localizedDescription)
		}

		// Check if process failed immediately after launch
		try await Task.sleep(nanoseconds: 100_000_000) // 100ms

		if !process.isRunning {
			let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
			let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Process exited immediately"

			logger?.error("Process terminated immediately: \(errorString)")
			throw ClaudeCodeError.processLaunchFailed(errorString)
		}

		// Return the publisher only if process is running
		return .stream(publisher)
	}

	// MARK: - Stream Buffer

	actor StreamBuffer {
		private var buffer = Data()

		func append(_ data: Data) {
			buffer.append(data)
		}

		func set(_ data: Data) {
			buffer = data
		}

		func isEmpty() -> Bool {
			return buffer.isEmpty
		}

		func getString() -> String? {
			return String(data: buffer, encoding: .utf8)
		}
	}

	// MARK: - JSON Processing

	private static func processJsonLine(
		_ line: String,
		subject: PassthroughSubject<ResponseChunk, Error>,
		decoder: JSONDecoder,
		logger: Logger?
	) {
		guard !line.isEmpty else { return }

		logger?.debug("Processing SDK JSON line: \(line.prefix(10000))...")

		guard let lineData = line.data(using: .utf8) else {
			logger?.error("Could not convert line to data: \(line.prefix(50))...")
			return
		}

		let jsonObject: Any
		do {
			jsonObject = try JSONSerialization.jsonObject(with: lineData)
		} catch {
			logger?.error("Error parsing JSON data: \(error)")
			return
		}

		guard let json = jsonObject as? [String: Any],
					let typeString = json["type"] as? String else {
			logger?.error("Invalid JSON structure or missing 'type' field")
			return
		}

		do {
			switch typeString {
			case "system":
				if let subtypeString = json["subtype"] as? String, subtypeString == "init" {
					let initMessage = try decoder.decode(InitSystemMessage.self, from: lineData)
					logger?.info("Received SDK init message with session ID: \(initMessage.sessionId)")
					subject.send(.initSystem(initMessage))
				} else {
					let resultMessage = try decoder.decode(ResultMessage.self, from: lineData)
					logger?.info("Received SDK result message: cost=\(resultMessage.totalCostUsd), turns=\(resultMessage.numTurns)")
					subject.send(.result(resultMessage))
				}

			case "user":
				let userMessage = try decoder.decode(UserMessage.self, from: lineData)
				logger?.debug("Received SDK user message for session: \(userMessage.sessionId)")
				subject.send(.user(userMessage))

			case "assistant":
				let assistantMessage = try decoder.decode(AssistantMessage.self, from: lineData)
				logger?.debug("Received SDK assistant message for session: \(assistantMessage.sessionId)")
				subject.send(.assistant(assistantMessage))

			case "result":
				let resultMessage = try decoder.decode(ResultMessage.self, from: lineData)
				logger?.info("Received SDK result message: cost=\(resultMessage.totalCostUsd), turns=\(resultMessage.numTurns)")
				subject.send(.result(resultMessage))

			default:
				logger?.warning("Unknown SDK message type: \(typeString)")
			}
		} catch {
			logger?.error("Error parsing SDK JSON: \(error.localizedDescription)")
		}
	}
}
