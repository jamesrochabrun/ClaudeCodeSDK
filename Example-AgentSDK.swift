#!/usr/bin/env swift

// Example: Using the Agent SDK Backend
// This demonstrates the simplest possible migration from headless to Agent SDK
//
// Run: swift Example-AgentSDK.swift
// (Make sure you have: npm install -g @anthropic-ai/claude-agent-sdk)

import Foundation

// Add the ClaudeCodeSDK directory to the import path when running as a script
// In a real project, you'd import it normally: import ClaudeCodeSDK

print("🚀 Agent SDK Backend Example\n")

// STEP 1: Check if Agent SDK is available
print("Checking Agent SDK installation...")

let npmCheck = Process()
npmCheck.executableURL = URL(fileURLWithPath: "/usr/bin/env")
npmCheck.arguments = ["npm", "list", "-g", "@anthropic-ai/claude-agent-sdk"]
npmCheck.standardOutput = Pipe()
npmCheck.standardError = Pipe()

do {
	try npmCheck.run()
	npmCheck.waitUntilExit()

	if npmCheck.terminationStatus == 0 {
		print("✅ Agent SDK is installed\n")

		print("To use the Agent SDK backend in your code:")
		print("─────────────────────────────────────────────\n")

		print("""
		import ClaudeCodeSDK

		// Configure for Agent SDK
		var config = ClaudeCodeConfiguration.default
		config.backend = .agentSDK  // 👈 Just add this line!

		let client = try ClaudeCodeClient(configuration: config)

		// Run a prompt (use .streamJson for Agent SDK)
		let result = try await client.runSinglePrompt(
		    prompt: "Explain what Swift is",
		    outputFormat: .streamJson,
		    options: nil
		)

		// Handle the streaming response
		if case .stream(let publisher) = result {
		    for await message in publisher.values {
		        print(message)
		    }
		}
		""")

		print("\n─────────────────────────────────────────────")
		print("\n📚 See AGENT_SDK_MIGRATION.md for complete examples")

	} else {
		print("❌ Agent SDK is NOT installed\n")
		print("Install it with:")
		print("  npm install -g @anthropic-ai/claude-agent-sdk\n")
	}

} catch {
	print("❌ Error checking npm: \(error)")
}

print("\n💡 Quick comparison:")
print("┌──────────────┬─────────────────┬─────────────────┐")
print("│ Feature      │ Headless        │ Agent SDK       │")
print("├──────────────┼─────────────────┼─────────────────┤")
print("│ Setup        │ .headless       │ .agentSDK       │")
print("│ Speed        │ Baseline        │ 2-10x faster    │")
print("│ Output       │ .json/.text     │ .streamJson     │")
print("│ Sessions     │ Full support    │ Full support    │")
print("│ MCP Servers  │ ✅              │ ✅              │")
print("└──────────────┴─────────────────┴─────────────────┘")
