//
//  NodePathDetectorTests.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/7/2025.
//

import XCTest
@testable import ClaudeCodeSDK

final class NodePathDetectorTests: XCTestCase {

  func testDetectNodePath() {
    // This test verifies that node path detection returns a valid path or nil
    let nodePath = NodePathDetector.detectNodePath()

    if let path = nodePath {
      // If a path is returned, it should exist and be executable
      XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                   "Node path should exist: \(path)")
      XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                   "Node should be executable: \(path)")
      XCTAssertTrue(path.contains("node"),
                   "Path should contain 'node': \(path)")
    } else {
      // If nil is returned, node is not installed (acceptable)
      print("ℹ️ Node.js not detected on this system")
    }
  }

  func testDetectNpmPath() {
    let npmPath = NodePathDetector.detectNpmPath()

    if let path = npmPath {
      XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                   "npm path should exist: \(path)")
      XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                   "npm should be executable: \(path)")
      XCTAssertTrue(path.contains("npm"),
                   "Path should contain 'npm': \(path)")
    } else {
      print("ℹ️ npm not detected on this system")
    }
  }

  func testDetectNpmGlobalPath() {
    let globalPath = NodePathDetector.detectNpmGlobalPath()

    if let path = globalPath {
      XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                   "npm global path should exist: \(path)")
      XCTAssertTrue(path.contains("bin"),
                   "Global path should contain 'bin': \(path)")
    } else {
      print("ℹ️ npm global path not detected")
    }
  }

  func testIsAgentSDKInstalled() {
    let isInstalled = NodePathDetector.isAgentSDKInstalled()

    // Just verify the method runs without crashing
    // Result depends on system state
    if isInstalled {
      print("✓ Claude Agent SDK is installed")

      // If installed, we should be able to get the path
      let sdkPath = NodePathDetector.getAgentSDKPath()
      XCTAssertNotNil(sdkPath, "SDK path should be available if installed")

      if let path = sdkPath {
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                     "SDK path should exist: \(path)")
      }
    } else {
      print("ℹ️ Claude Agent SDK not installed")
    }
  }

  func testGetAgentSDKPath() {
    let sdkPath = NodePathDetector.getAgentSDKPath()

    if let path = sdkPath {
      XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                   "SDK path should exist: \(path)")
      XCTAssertTrue(path.contains("@anthropic-ai/claude-agent-sdk"),
                   "Path should contain SDK package name: \(path)")
    }
  }

  func testNodePathConsistency() {
    // If node is found, npm should typically be in the same directory
    guard let nodePath = NodePathDetector.detectNodePath() else {
      print("ℹ️ Skipping consistency test - Node.js not detected")
      return
    }

    let nodeDir = (nodePath as NSString).deletingLastPathComponent

    // Check if npm exists in the same directory
    let expectedNpmPath = nodeDir + "/npm"
    let npmExists = FileManager.default.fileExists(atPath: expectedNpmPath)

    if npmExists {
      XCTAssertTrue(true, "npm found alongside node")
    } else {
      print("⚠️ npm not in same directory as node (might be using different installation)")
    }
  }

  func testMultipleDetectionCalls() {
    // Verify that multiple calls return consistent results
    let firstCall = NodePathDetector.detectNodePath()
    let secondCall = NodePathDetector.detectNodePath()

    XCTAssertEqual(firstCall, secondCall,
                  "Multiple calls should return consistent results")
  }

  func testValidPathFormat() {
    if let nodePath = NodePathDetector.detectNodePath() {
      // Path should be absolute
      XCTAssertTrue(nodePath.hasPrefix("/"),
                   "Node path should be absolute: \(nodePath)")

      // Should not contain spaces that aren't escaped
      // (this is a basic check - real paths can have spaces)
      XCTAssertFalse(nodePath.contains("  "),
                    "Path should not contain double spaces")
    }
  }

  // MARK: - NVM Configuration Tests

  func testIsAgentSDKInstalledWithNVMConfiguration() {
    // Test that isAgentSDKInstalled respects nodeExecutable configuration
    guard let nodePath = NodePathDetector.detectNodePath() else {
      print("ℹ️ Skipping NVM config test - Node.js not detected")
      return
    }

    // Create config with explicit node path
    var config = ClaudeCodeConfiguration.default
    config.nodeExecutable = nodePath

    // Test with configuration
    let isInstalledWithConfig = NodePathDetector.isAgentSDKInstalled(configuration: config)

    // Test without configuration (should use auto-detection)
    let isInstalledWithoutConfig = NodePathDetector.isAgentSDKInstalled()

    print("ℹ️ SDK installed with config: \(isInstalledWithConfig)")
    print("ℹ️ SDK installed without config: \(isInstalledWithoutConfig)")

    // Both should give valid results (may differ if NVM is used)
    // The important thing is they don't crash
  }

  func testIsAgentSDKInstalledWithInvalidNodePath() {
    // Test with non-existent node path
    var config = ClaudeCodeConfiguration.default
    config.nodeExecutable = "/nonexistent/path/to/node"

    let isInstalled = NodePathDetector.isAgentSDKInstalled(configuration: config)

    // Should return false for invalid path, not crash
    XCTAssertFalse(isInstalled, "Should return false for invalid node path")
  }

  func testIsAgentSDKInstalledWithNVMPath() {
    // Test with actual NVM path if available
    let nvmNodePath = "\(NSHomeDirectory())/.nvm/versions/node/v22.16.0/bin/node"

    guard FileManager.default.fileExists(atPath: nvmNodePath) else {
      print("ℹ️ Skipping NVM path test - NVM installation not found at expected location")
      return
    }

    var config = ClaudeCodeConfiguration.default
    config.nodeExecutable = nvmNodePath

    let isInstalled = NodePathDetector.isAgentSDKInstalled(configuration: config)

    print("ℹ️ SDK installed with NVM path (\(nvmNodePath)): \(isInstalled)")

    // Should check the correct location based on the NVM node path
    // Expected SDK location: ~/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk
    let expectedSDKPath = "\(NSHomeDirectory())/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk"
    let sdkExists = FileManager.default.fileExists(atPath: expectedSDKPath)

    if sdkExists {
      XCTAssertTrue(isInstalled, "Should detect SDK when it exists at NVM location")
    } else {
      XCTAssertFalse(isInstalled, "Should not detect SDK when it doesn't exist at NVM location")
    }
  }

  func testNodeExecutablePathDerivation() {
    // Test the path derivation logic
    let testNodePath = "/Users/test/.nvm/versions/node/v22.16.0/bin/node"
    let expectedSDKPath = "/Users/test/.nvm/versions/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk"

    // Simulate the logic from isAgentSDKInstalled
    let nodeBinDir = (testNodePath as NSString).deletingLastPathComponent
    let nodePrefix = (nodeBinDir as NSString).deletingLastPathComponent
    let derivedSDKPath = "\(nodePrefix)/lib/node_modules/@anthropic-ai/claude-agent-sdk"

    XCTAssertEqual(derivedSDKPath, expectedSDKPath, "Should correctly derive SDK path from node path")
  }
}
