import ClaudeCodeSDK
import Foundation

print("🧪 ClaudeCodeSDK Dual-Backend Test\n")
print(String(repeating: "=", count: 60))

// Test 1: Default Configuration
print("\n✅ Test 1: Default Configuration")
do {
	let client = try ClaudeCodeClient()
	print("   Backend: \(client.configuration.backend.rawValue)")
	print("   Command: \(client.configuration.command)")
	print("   ✓ Client created successfully with headless backend")
} catch {
	print("   ✗ Failed: \(error)")
}

// Test 2: Explicit Headless Backend
print("\n✅ Test 2: Explicit Headless Backend")
do {
	var config = ClaudeCodeConfiguration.default
	config.backend = .headless
	let client = try ClaudeCodeClient(configuration: config)
	print("   Backend: \(client.configuration.backend.rawValue)")
	print("   ✓ Headless backend created successfully")
} catch {
	print("   ✗ Failed: \(error)")
}

// Test 3: Agent SDK Backend (will fail if not installed)
print("\n✅ Test 3: Agent SDK Backend")
do {
	var config = ClaudeCodeConfiguration.default
	config.backend = .agentSDK
	let client = try ClaudeCodeClient(configuration: config)
	print("   Backend: \(client.configuration.backend.rawValue)")
	print("   ✓ Agent SDK backend created successfully")
} catch {
	print("   ✗ Expected failure (Agent SDK not installed):")
	print("   \(error)")
}

// Test 4: Backend Validation (via client creation)
print("\n✅ Test 4: Backend Validation via Client Creation")
do {
	let headlessConfig = ClaudeCodeConfiguration(backend: .headless)
	_ = try ClaudeCodeClient(configuration: headlessConfig)
	print("   ✓ Headless backend validated successfully")
} catch {
	print("   ✗ Headless validation failed: \(error)")
}

do {
	let agentSDKConfig = ClaudeCodeConfiguration(backend: .agentSDK)
	_ = try ClaudeCodeClient(configuration: agentSDKConfig)
	print("   ✓ Agent SDK backend validated successfully")
} catch {
	print("   ✓ Agent SDK validation failed (expected): \(error)")
}

// Test 5: Backend Switching
print("\n✅ Test 5: Runtime Backend Switching")
do {
	let client = try ClaudeCodeClient()
	print("   Initial backend: \(client.configuration.backend.rawValue)")

	// Try to switch (will fail if Agent SDK not installed, but shouldn't crash)
	print("   Attempting to switch to agentSDK...")
	client.configuration.backend = .agentSDK
	print("   Current backend: \(client.configuration.backend.rawValue)")

	// If switch failed, it should have reverted
	if client.configuration.backend == .headless {
		print("   ✓ Switch failed gracefully, reverted to headless")
	} else {
		print("   ✓ Switch succeeded (Agent SDK is installed!)")
	}
} catch {
	print("   ✗ Failed: \(error)")
}

// Test 6: Node Path Detection
print("\n✅ Test 6: Node.js Detection")
if let nodePath = NodePathDetector.detectNodePath() {
	print("   ✓ Node.js found: \(nodePath)")
} else {
	print("   ✗ Node.js not found")
}

if let npmPath = NodePathDetector.detectNpmPath() {
	print("   ✓ npm found: \(npmPath)")
}

print("   Agent SDK installed: \(NodePathDetector.isAgentSDKInstalled())")

if let sdkPath = NodePathDetector.getAgentSDKPath() {
	print("   ✓ Agent SDK path: \(sdkPath)")
}

print("\n" + String(repeating: "=", count: 60))
print("✅ All tests completed!\n")
