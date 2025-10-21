//
//  NodePathDetector.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 10/7/2025.
//

import Foundation

/// Utility for detecting Node.js and npm paths on the system
/// Handles common installation methods including nvm, Homebrew, and system installations
public struct NodePathDetector {

  /// Detects the path to the Node.js executable
  /// Checks common locations and nvm installations
  /// - Returns: Path to node executable, or nil if not found
  public static func detectNodePath() -> String? {
    // Common paths to check
    let commonPaths = [
      "/usr/local/bin/node",          // Homebrew Intel
      "/opt/homebrew/bin/node",       // Homebrew Apple Silicon
      "/usr/bin/node",                // System installation
      "\(NSHomeDirectory())/.nvm/versions/node/*/bin/node",  // nvm installations
    ]

    // First try which command
    if let path = findExecutable(command: "node") {
      return path
    }

    // Check common paths
    for pathPattern in commonPaths {
      if pathPattern.contains("*") {
        // Handle glob pattern (for nvm)
        if let path = findWithGlob(pattern: pathPattern) {
          return path
        }
      } else {
        if FileManager.default.fileExists(atPath: pathPattern) &&
           FileManager.default.isExecutableFile(atPath: pathPattern) {
          return pathPattern
        }
      }
    }

    return nil
  }

  /// Detects the path to the npm executable
  /// - Returns: Path to npm executable, or nil if not found
  public static func detectNpmPath() -> String? {
    // First try which command
    if let path = findExecutable(command: "npm") {
      return path
    }

    // If node is found, npm is usually in the same directory
    if let nodePath = detectNodePath() {
      let npmPath = (nodePath as NSString).deletingLastPathComponent + "/npm"
      if FileManager.default.fileExists(atPath: npmPath) &&
         FileManager.default.isExecutableFile(atPath: npmPath) {
        return npmPath
      }
    }

    return nil
  }

  /// Detects the npm global bin directory
  /// This is where globally installed packages (like @anthropic-ai/claude-agent-sdk) are located
  /// - Returns: Path to npm global bin directory, or nil if not found
  public static func detectNpmGlobalPath() -> String? {
    // Try to use npm config to get the global bin path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "npm config get prefix"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let prefix = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
          let binPath = "\(prefix)/bin"
          if FileManager.default.fileExists(atPath: binPath) {
            return binPath
          }
        }
      }
    } catch {
      // Failed to get npm prefix
    }

    // Fallback to common locations
    let commonPaths = [
      "\(NSHomeDirectory())/.nvm/versions/node/*/bin",
      "/usr/local/bin",
      "/opt/homebrew/bin",
    ]

    for pathPattern in commonPaths {
      if pathPattern.contains("*") {
        if let path = findWithGlob(pattern: pathPattern) {
          return path
        }
      } else {
        if FileManager.default.fileExists(atPath: pathPattern) {
          return pathPattern
        }
      }
    }

    return nil
  }

  /// Checks if the Claude Agent SDK is installed globally
  /// - Parameter configuration: Optional configuration with nodeExecutable path
  /// - Returns: true if the package is available
  public static func isAgentSDKInstalled(configuration: ClaudeCodeConfiguration? = nil) -> Bool {
    // 1. If nodeExecutable is specified in configuration, derive SDK path from it
    if let nodeExecutable = configuration?.nodeExecutable {
      // Node path: /path/to/node/v22.16.0/bin/node
      // SDK path:  /path/to/node/v22.16.0/lib/node_modules/@anthropic-ai/claude-agent-sdk
      let nodeBinDir = (nodeExecutable as NSString).deletingLastPathComponent
      let nodePrefix = (nodeBinDir as NSString).deletingLastPathComponent
      let packagePath = "\(nodePrefix)/lib/node_modules/@anthropic-ai/claude-agent-sdk"

      if FileManager.default.fileExists(atPath: packagePath) {
        return true
      }
      // If specified nodeExecutable doesn't have the SDK, don't fall through
      // This ensures we fail fast if user explicitly configured a node path
      return false
    }

    // 2. Fall back to automatic detection
    guard let npmGlobalPath = detectNpmGlobalPath() else {
      return false
    }

    // Check for the package in node_modules
    let packagePath = (npmGlobalPath as NSString).deletingLastPathComponent + "/lib/node_modules/@anthropic-ai/claude-agent-sdk"

    return FileManager.default.fileExists(atPath: packagePath)
  }

  /// Gets the path to the Claude Agent SDK installation
  /// - Returns: Path to the SDK, or nil if not found
  public static func getAgentSDKPath() -> String? {
    guard let npmGlobalPath = detectNpmGlobalPath() else {
      return nil
    }

    let packagePath = (npmGlobalPath as NSString).deletingLastPathComponent + "/lib/node_modules/@anthropic-ai/claude-agent-sdk"

    if FileManager.default.fileExists(atPath: packagePath) {
      return packagePath
    }

    return nil
  }

  // MARK: - Private Helpers

  /// Finds an executable using the 'which' command
  private static func findExecutable(command: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "which \(command)"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      return nil
    }

    return nil
  }

  /// Finds files matching a glob pattern
  /// Note: This is a simple implementation that only handles * in directory names
  private static func findWithGlob(pattern: String) -> String? {
    let components = pattern.components(separatedBy: "/")
    guard let starIndex = components.firstIndex(where: { $0.contains("*") }) else {
      return nil
    }

    // Build the base path up to the wildcard
    let basePath = components[0..<starIndex].joined(separator: "/")
    let wildcardComponent = components[starIndex]
    let remainingComponents = components[(starIndex + 1)...].joined(separator: "/")

    // List directories matching the wildcard
    guard let enumerator = FileManager.default.enumerator(atPath: basePath) else {
      return nil
    }

    for case let item as String in enumerator {
      // Check if this item matches our wildcard component
      if item.components(separatedBy: "/").first == wildcardComponent.replacingOccurrences(of: "*", with: item) {
        let fullPath = "\(basePath)/\(item)/\(remainingComponents)"
        if FileManager.default.fileExists(atPath: fullPath) {
          return fullPath
        }
      }
    }

    // Alternative: use shell expansion
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", "ls -d \(pattern) 2>/dev/null | head -1"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      return nil
    }

    return nil
  }
}
