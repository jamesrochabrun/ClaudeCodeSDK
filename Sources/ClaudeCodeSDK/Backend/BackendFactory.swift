//
//  BackendFactory.swift
//  ClaudeCodeSDK
//
//  Created by ClaudeCodeSDK on 10/8/2025.
//

import Foundation

/// Factory for creating backend instances based on configuration
internal struct BackendFactory {

	/// Creates the appropriate backend based on configuration
	/// - Parameter configuration: The configuration to use
	/// - Returns: A backend instance
	/// - Throws: ClaudeCodeError if backend creation fails
	static func createBackend(
		for configuration: ClaudeCodeConfiguration
	) throws -> ClaudeCodeBackend {
		switch configuration.backend {
		case .headless:
			return HeadlessBackend(configuration: configuration)

		case .agentSDK:
			// Validate Agent SDK setup
			guard NodePathDetector.detectNodePath() != nil || configuration.nodeExecutable != nil else {
				throw ClaudeCodeError.invalidConfiguration(
					"Node.js not found. Please install Node.js or specify nodeExecutable in configuration."
				)
			}

			if !NodePathDetector.isAgentSDKInstalled() {
				throw ClaudeCodeError.invalidConfiguration(
					"Claude Agent SDK is not installed. Run: npm install -g @anthropic-ai/claude-agent-sdk"
				)
			}

			return AgentSDKBackend(configuration: configuration)
		}
	}

	/// Validates that a backend can be created with the given configuration
	/// - Parameter configuration: The configuration to validate
	/// - Returns: true if valid, false otherwise
	static func validateConfiguration(_ configuration: ClaudeCodeConfiguration) -> Bool {
		switch configuration.backend {
		case .headless:
			// Headless just needs the command to be available
			return true

		case .agentSDK:
			// Check Node.js availability
			guard NodePathDetector.detectNodePath() != nil || configuration.nodeExecutable != nil else {
				return false
			}

			// Check Agent SDK installation
			return NodePathDetector.isAgentSDKInstalled()
		}
	}

	/// Gets a human-readable error message for configuration issues
	/// - Parameter configuration: The configuration to check
	/// - Returns: An error message if invalid, nil if valid
	static func getConfigurationError(_ configuration: ClaudeCodeConfiguration) -> String? {
		switch configuration.backend {
		case .headless:
			return nil

		case .agentSDK:
			if NodePathDetector.detectNodePath() == nil && configuration.nodeExecutable == nil {
				return "Node.js not found. Please install Node.js or specify nodeExecutable in configuration."
			}

			if !NodePathDetector.isAgentSDKInstalled() {
				return "Claude Agent SDK is not installed. Run: npm install -g @anthropic-ai/claude-agent-sdk"
			}

			return nil
		}
	}
}
