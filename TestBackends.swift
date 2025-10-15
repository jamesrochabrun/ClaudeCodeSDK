#!/usr/bin/env swift
//
//  TestBackends.swift
//  Manual test script for dual-backend architecture
//
//  Run with: swift TestBackends.swift
//

import Foundation

// This script tests the dual-backend architecture
// You'll need to build the package first: swift build

print("🧪 ClaudeCodeSDK Backend Testing\n")

// Test 1: Check if claude CLI is available
print("📋 Step 1: Checking for claude CLI...")
let whichClaude = Process()
whichClaude.executableURL = URL(fileURLWithPath: "/bin/zsh")
whichClaude.arguments = ["-l", "-c", "which claude"]
let claudePipe = Pipe()
whichClaude.standardOutput = claudePipe
whichClaude.standardError = Pipe()

try? whichClaude.run()
whichClaude.waitUntilExit()

if whichClaude.terminationStatus == 0 {
	let data = claudePipe.fileHandleForReading.readDataToEndOfFile()
	if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
		print("   ✅ claude CLI found at: \(path)")
	}
} else {
	print("   ❌ claude CLI not found")
	print("   Install with: npm install -g @anthropic-ai/claude-code")
}

// Test 2: Check if Node.js is available
print("\n📋 Step 2: Checking for Node.js...")
let whichNode = Process()
whichNode.executableURL = URL(fileURLWithPath: "/bin/zsh")
whichNode.arguments = ["-l", "-c", "which node"]
let nodePipe = Pipe()
whichNode.standardOutput = nodePipe
whichNode.standardError = Pipe()

try? whichNode.run()
whichNode.waitUntilExit()

if whichNode.terminationStatus == 0 {
	let data = nodePipe.fileHandleForReading.readDataToEndOfFile()
	if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
		print("   ✅ Node.js found at: \(path)")

		// Check Node version
		let nodeVersion = Process()
		nodeVersion.executableURL = URL(fileURLWithPath: "/bin/zsh")
		nodeVersion.arguments = ["-l", "-c", "node --version"]
		let versionPipe = Pipe()
		nodeVersion.standardOutput = versionPipe
		try? nodeVersion.run()
		nodeVersion.waitUntilExit()
		let versionData = versionPipe.fileHandleForReading.readDataToEndOfFile()
		if let version = String(data: versionData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
			print("   📦 Node version: \(version)")
		}
	}
} else {
	print("   ❌ Node.js not found")
	print("   Install from: https://nodejs.org/")
}

// Test 3: Check if Agent SDK is installed
print("\n📋 Step 3: Checking for Claude Agent SDK...")
let npmList = Process()
npmList.executableURL = URL(fileURLWithPath: "/bin/zsh")
npmList.arguments = ["-l", "-c", "npm list -g @anthropic-ai/claude-agent-sdk --depth=0"]
let npmPipe = Pipe()
npmList.standardOutput = npmPipe
npmList.standardError = Pipe()

try? npmList.run()
npmList.waitUntilExit()

if npmList.terminationStatus == 0 {
	print("   ✅ Claude Agent SDK installed")
	let data = npmPipe.fileHandleForReading.readDataToEndOfFile()
	if let output = String(data: data, encoding: .utf8) {
		// Extract version if possible
		if let versionLine = output.split(separator: "\n").first(where: { $0.contains("claude-agent-sdk") }) {
			print("   📦 \(versionLine)")
		}
	}
} else {
	print("   ❌ Claude Agent SDK not installed")
	print("   Install with: npm install -g @anthropic-ai/claude-agent-sdk")
}

// Test 4: Check if sdk-wrapper.mjs exists
print("\n📋 Step 4: Checking for sdk-wrapper.mjs...")
let wrapperPath = "/Users/jamesrochabrun/Desktop/git/ClaudeCodeSDK/Resources/sdk-wrapper.mjs"
if FileManager.default.fileExists(atPath: wrapperPath) {
	print("   ✅ sdk-wrapper.mjs found at: \(wrapperPath)")

	// Check if executable
	if FileManager.default.isExecutableFile(atPath: wrapperPath) {
		print("   ✅ sdk-wrapper.mjs is executable")
	} else {
		print("   ⚠️  sdk-wrapper.mjs is not executable")
		print("   Run: chmod +x \(wrapperPath)")
	}
} else {
	print("   ❌ sdk-wrapper.mjs not found")
}

// Summary
print("\n" + String(repeating: "=", count: 60))
print("📊 SUMMARY\n")

var canUseHeadless = whichClaude.terminationStatus == 0
var canUseAgentSDK = whichNode.terminationStatus == 0 && npmList.terminationStatus == 0

print("Backend Availability:")
print("  • Headless Backend: \(canUseHeadless ? "✅ Ready" : "❌ Not Available")")
print("  • Agent SDK Backend: \(canUseAgentSDK ? "✅ Ready" : "❌ Not Available")")

print("\n🚀 Next Steps:\n")

if canUseHeadless {
	print("1. Test Headless Backend:")
	print("   swift run TestHeadlessBackend")
} else {
	print("1. Install claude CLI:")
	print("   npm install -g @anthropic-ai/claude-code")
}

if canUseAgentSDK {
	print("\n2. Test Agent SDK Backend:")
	print("   swift run TestAgentSDKBackend")
} else {
	print("\n2. Install Agent SDK:")
	print("   npm install -g @anthropic-ai/claude-agent-sdk")
}

print("\n3. Run the example:")
print("   cd Example/ClaudeCodeSDKExample && open ClaudeCodeSDKExample.xcodeproj")

print("\n" + String(repeating: "=", count: 60))
