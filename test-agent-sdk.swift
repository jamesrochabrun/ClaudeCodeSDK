#!/usr/bin/env swift

import Foundation

// Simple inline test to verify Agent SDK backend works
// Run: swift test-agent-sdk.swift

print("🧪 Testing Agent SDK Backend\n")

// Check if we have the SDK wrapper
let wrapperPath = "./Resources/sdk-wrapper.mjs"
let fileExists = FileManager.default.fileExists(atPath: wrapperPath)
print("1. SDK Wrapper exists: \(fileExists ? "✅" : "❌")")

// Check Node.js
let nodeCheck = Process()
nodeCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
nodeCheck.arguments = ["node", "--version"]
let nodePipe = Pipe()
nodeCheck.standardOutput = nodePipe

do {
	try nodeCheck.run()
	nodeCheck.waitUntilExit()
	let nodeData = nodePipe.fileHandleForReading.readDataToEndOfFile()
	let nodeVersion = String(data: nodeData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
	print("2. Node.js version: \(nodeVersion) \(nodeCheck.terminationStatus == 0 ? "✅" : "❌")")
} catch {
	print("2. Node.js check failed: ❌")
}

// Check Agent SDK
let sdkCheck = Process()
sdkCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
sdkCheck.arguments = ["npm", "list", "-g", "@anthropic-ai/claude-agent-sdk"]
let sdkPipe = Pipe()
sdkCheck.standardOutput = sdkPipe
sdkCheck.standardError = Pipe()

do {
	try sdkCheck.run()
	sdkCheck.waitUntilExit()
	let sdkData = sdkPipe.fileHandleForReading.readDataToEndOfFile()
	let sdkOutput = String(data: sdkData, encoding: .utf8) ?? ""

	if sdkOutput.contains("claude-agent-sdk") {
		// Extract version
		if let versionMatch = sdkOutput.range(of: "@\\d+\\.\\d+\\.\\d+", options: .regularExpression) {
			let version = String(sdkOutput[versionMatch])
			print("3. Agent SDK: \(version) ✅")
		} else {
			print("3. Agent SDK: installed ✅")
		}
	} else {
		print("3. Agent SDK: not installed ❌")
		print("\n   Install with: npm install -g @anthropic-ai/claude-agent-sdk")
	}
} catch {
	print("3. Agent SDK check failed: ❌")
}

print("\n✅ All checks complete!")
print("\nTo use Agent SDK backend:")
print("  var config = ClaudeCodeConfiguration.default")
print("  config.backend = .agentSDK")
print("  let client = try ClaudeCodeClient(configuration: config)")
