//
//  BackendTests.swift
//  ClaudeCodeSDKTests
//
//  Created by ClaudeCodeSDK on 10/8/2025.
//

import XCTest
@testable import ClaudeCodeSDK

final class BackendTests: XCTestCase {

	func testHeadlessBackendCreation() throws {
		let config = ClaudeCodeConfiguration(
			backend: .headless,
			command: "claude"
		)

		let backend = HeadlessBackend(configuration: config)
		XCTAssertNotNil(backend)
	}

	func testAgentSDKBackendCreation() throws {
		let config = ClaudeCodeConfiguration(
			backend: .agentSDK,
			nodeExecutable: "/usr/local/bin/node",
			sdkWrapperPath: "/path/to/wrapper.mjs"
		)

		let backend = AgentSDKBackend(configuration: config)
		XCTAssertNotNil(backend)
	}

	func testBackendFactoryHeadless() throws {
		let config = ClaudeCodeConfiguration(
			backend: .headless,
			command: "claude"
		)

		let backend = try BackendFactory.createBackend(for: config)
		XCTAssertTrue(backend is HeadlessBackend)
	}

	func testBackendFactoryAgentSDK() throws {
		// Skip if Agent SDK is not installed
		guard NodePathDetector.isAgentSDKInstalled() else {
			throw XCTSkip("Claude Agent SDK not installed")
		}

		let config = ClaudeCodeConfiguration(
			backend: .agentSDK
		)

		let backend = try BackendFactory.createBackend(for: config)
		XCTAssertTrue(backend is AgentSDKBackend)
	}

	func testBackendFactoryValidation() {
		// Headless should always be valid
		let headlessConfig = ClaudeCodeConfiguration(
			backend: .headless,
			command: "claude"
		)
		XCTAssertTrue(BackendFactory.validateConfiguration(headlessConfig))

		// Agent SDK validation depends on installation
		let agentSDKConfig = ClaudeCodeConfiguration(
			backend: .agentSDK
		)
		let isValid = BackendFactory.validateConfiguration(agentSDKConfig)

		// If Node.js is installed and Agent SDK is installed, should be valid
		if NodePathDetector.detectNodePath() != nil && NodePathDetector.isAgentSDKInstalled() {
			XCTAssertTrue(isValid)
		} else {
			XCTAssertFalse(isValid)
		}
	}

	func testBackendFactoryConfigurationError() {
		// Headless should have no errors
		let headlessConfig = ClaudeCodeConfiguration(
			backend: .headless
		)
		XCTAssertNil(BackendFactory.getConfigurationError(headlessConfig))

		// Agent SDK error message depends on system state
		let agentSDKConfig = ClaudeCodeConfiguration(
			backend: .agentSDK
		)
		let error = BackendFactory.getConfigurationError(agentSDKConfig)

		// Should either be nil (if valid) or have an error message
		if NodePathDetector.detectNodePath() != nil && NodePathDetector.isAgentSDKInstalled() {
			XCTAssertNil(error)
		} else {
			XCTAssertNotNil(error)
			if NodePathDetector.detectNodePath() == nil {
				XCTAssertTrue(error?.contains("Node.js") ?? false)
			} else {
				XCTAssertTrue(error?.contains("Agent SDK") ?? false)
			}
		}
	}

	func testClientBackendSwitching() throws {
		var config = ClaudeCodeConfiguration.default
		config.backend = .headless

		let client = try ClaudeCodeClient(configuration: config)
		XCTAssertEqual(client.configuration.backend, .headless)

		// Switch to Agent SDK (if available)
		if NodePathDetector.isAgentSDKInstalled() {
			client.configuration.backend = .agentSDK
			XCTAssertEqual(client.configuration.backend, .agentSDK)
		}
	}

	func testClientThrowingInitializer() {
		// Test that client initialization can throw
		do {
			let config = ClaudeCodeConfiguration(
				backend: .agentSDK,
				nodeExecutable: "/nonexistent/node"
			)

			_ = try ClaudeCodeClient(configuration: config)
			XCTFail("Should have thrown an error for invalid configuration")
		} catch {
			// Expected to throw
			XCTAssertTrue(error is ClaudeCodeError)
		}
	}

	func testBackwardCompatibilityInitializer() throws {
		// Test the backward compatibility initializer
		let client = try ClaudeCodeClient(workingDirectory: "/tmp", debug: true)

		XCTAssertEqual(client.configuration.workingDirectory, "/tmp")
		XCTAssertTrue(client.configuration.enableDebugLogging)
		XCTAssertEqual(client.configuration.backend, .headless) // Default backend
	}

	func testHeadlessBackendValidation() async throws {
		let config = ClaudeCodeConfiguration(
			backend: .headless,
			command: "claude"
		)

		let backend = HeadlessBackend(configuration: config)

		// Validation depends on whether claude is installed
		// Just verify it doesn't crash
		_ = try await backend.validateSetup()
	}

	func testAgentSDKBackendValidation() async throws {
		let config = ClaudeCodeConfiguration(
			backend: .agentSDK
		)

		let backend = AgentSDKBackend(configuration: config)

		// Validation depends on Node.js and Agent SDK installation
		let isValid = try await backend.validateSetup()

		// Should match the factory validation
		XCTAssertEqual(isValid, BackendFactory.validateConfiguration(config))
	}

	func testBackendCancellation() {
		let config = ClaudeCodeConfiguration(
			backend: .headless,
			command: "claude"
		)

		let backend = HeadlessBackend(configuration: config)

		// Should not crash when canceling without active tasks
		backend.cancel()
	}
}
