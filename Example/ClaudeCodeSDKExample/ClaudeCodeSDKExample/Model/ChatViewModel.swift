//
//  ChatViewModel.swift
//  ClaudeCodeSDKExample
//
//  Created by James Rochabrun on 5/20/25.
//

import Combine
import ClaudeCodeSDK
import Foundation
import os.log
import SwiftAnthropic

@Observable
@MainActor
public class ChatViewModel {
  
  private let claudeClient: ClaudeCode
  private let logger = Logger(subsystem: "com.yourcompany.ClaudeChat", category: "ChatViewModel")
  private var cancellables = Set<AnyCancellable>()
  private var currentSessionId: String?
  private var currentMessageId: UUID?
  
  // MARK: - Published Properties
  
  /// All messages in the conversation
  var messages: [ChatMessage] = []
  
  let allowedTools = ["Task", "Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep" ]
  /// Loading state
  public var isLoading: Bool = false
  
  /// Error state
  public var error: Error?
  
  /// Sessions list
  var sessions: [SessionInfo] = []
  
  /// MCP configuration enabled
  var isMCPEnabled: Bool = false
  
  /// MCP config path
  var mcpConfigPath: String = ""
  
  
  // MARK: - Initialization
  
  public init(claudeClient: ClaudeCode) {
    self.claudeClient = claudeClient
  }
  
  // MARK: - Public Methods
  
  /// Sends a new message to Claude
  /// - Parameter text: The message text to send
  public func sendMessage(_ text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    // Add user message to the list
    let userMessage = ChatMessage(role: .user, content: text)
    messages.append(userMessage)
    
    // Clear any previous errors
    error = nil
    
    // Add a placeholder for assistant's response
    let assistantId = UUID()
    currentMessageId = assistantId
    
    let placeholderMessage = ChatMessage(
      id: assistantId,
      role: .assistant,
      content: "",
      isComplete: false
    )
    messages.append(placeholderMessage)
    
    // Set loading state
    isLoading = true
    
    // Determine if we need to continue or start a new conversation
    Task {
      do {
        if let sessionId = currentSessionId {
          try await continueConversation(sessionId: sessionId, prompt: text, messageId: assistantId)
        } else {
          try await startNewConversation(prompt: text, messageId: assistantId)
        }
      } catch {
        await MainActor.run {
          self.handleError(error)
        }
      }
    }
  }
  
  /// Clears the conversation history and starts a new session
  public func clearConversation() {
    messages = []
    currentSessionId = nil
    currentMessageId = nil
    error = nil
  }
  
  /// Cancels any ongoing requests
  public func cancelRequest() {
    claudeClient.cancel()
    isLoading = false
  }
  
  /// Lists all available sessions
  public func listSessions() {
    Task {
      do {
        let fetchedSessions = try await claudeClient.listSessions()
        await MainActor.run {
          self.sessions = fetchedSessions
          logger.info("Fetched \(fetchedSessions.count) sessions")
        }
      } catch {
        await MainActor.run {
          self.error = error
          logger.error("Failed to list sessions: \(error)")
        }
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func startNewConversation(prompt: String, messageId: UUID) async throws {
    var options = ClaudeCodeOptions()
    options.allowedTools = allowedTools
    options.verbose = true
    
    // Add MCP config if enabled
    if self.isMCPEnabled && !self.mcpConfigPath.isEmpty {
      options.mcpConfigPath = self.mcpConfigPath
      // Add MCP tools to allowed tools if using MCP
      var updatedAllowedTools = self.allowedTools
      
      // Generate MCP tool patterns from the configuration file
      let mcpToolPatterns = MCPToolFormatter.generateAllowedToolPatterns(fromConfigPath: self.mcpConfigPath)
      updatedAllowedTools.append(contentsOf: mcpToolPatterns)
      
      options.allowedTools = updatedAllowedTools
      
      self.logger.info("MCP enabled with config: \(self.mcpConfigPath)")
      self.logger.info("MCP servers found: \(MCPToolFormatter.extractServerNames(fromConfigPath: self.mcpConfigPath))")
      self.logger.info("Allowed tools: \(updatedAllowedTools)")
    }
    
    let result = try await claudeClient.runSinglePrompt(
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processStreamResult(result, messageId: messageId)
  }
  
  private func continueConversation(sessionId: String, prompt: String, messageId: UUID) async throws {
    var options = ClaudeCodeOptions()
    options.allowedTools = allowedTools
    options.verbose = true
    
    // Add MCP config if enabled
    if isMCPEnabled && !mcpConfigPath.isEmpty {
      options.mcpConfigPath = mcpConfigPath
      // Add MCP tools to allowed tools if using MCP
      var updatedAllowedTools = allowedTools
      
      // Generate MCP tool patterns from the configuration file
      let mcpToolPatterns = MCPToolFormatter.generateAllowedToolPatterns(fromConfigPath: mcpConfigPath)
      updatedAllowedTools.append(contentsOf: mcpToolPatterns)
      
      options.allowedTools = updatedAllowedTools
    }
    
    let result = try await claudeClient.resumeConversation(
      sessionId: sessionId,
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processStreamResult(result, messageId: messageId)
  }
  
  private func processStreamResult(_ result: ClaudeCodeResult, messageId: UUID) async {
    switch result {
    case .stream(let publisher):
      var contentBuffer = ""
      
      await withCheckedContinuation { continuation in
        publisher
          .receive(on: DispatchQueue.main)
          .sink(
            receiveCompletion: { [weak self] completion in
              guard let self = self else { return }
              
              switch completion {
              case .finished:
                // Ensure message is marked as complete
                self.updateAssistantMessage(messageId: messageId, content: contentBuffer, isComplete: true)
                self.isLoading = false
              case .failure(let error):
                self.handleError(error)
              }
              
              continuation.resume()
            },
            receiveValue: { [weak self] chunk in
              guard let self = self else { return }
              
              switch chunk {
              case .initSystem(let initMessage):
                
                if currentSessionId == nil {  // Only update if not already in a conversation
                  self.currentSessionId = initMessage.sessionId
                  logger.debug("Started new session: \(initMessage.sessionId)")
                } else {
                  logger.debug("Continuing with new session ID: \(initMessage.sessionId)")
                }
                
              case .assistant(let message):
                // Handle different content types
                for content in message.message.content {
                  
                  switch content {
                  case .text(let textContent, _):
                    contentBuffer = textContent
                    self.updateAssistantMessage(messageId: messageId, content: contentBuffer, isComplete: isLoading)
                    
                  case .toolUse(let toolUse):
                    var toolMessage = "TOOL USE: \(toolUse.name). \n"
                    toolMessage += toolUse.input.formattedDescription()
                    self.addToolUseMessage(toolName: toolUse.name, content: toolMessage)
                    
                  case .toolResult(let toolResult):
                    // Format differently based on success or error
                    self.addToolResultMessage(content: toolResult.content, isError: toolResult.isError == true)
                    
                  case .thinking(let thinking):
                    // Optionally handle thinking content
                    let thinkingMessage = "THINKING: \(thinking.thinking)"
                    self.addThinkingMessage(content: thinkingMessage)
                    
                  case .serverToolUse:
                    // TODO: Add this although it is not supported
                    break
                    
                  case .webSearchToolResult(let searchResult):
                    let webSearchMessage = "WEB SEARCH RESULT: Found \(searchResult.content.count) results"
                    self.addWebSearchResultMessage(content: webSearchMessage)
                  }
                }
                if contentBuffer.isEmpty {
                  logger.error("No processable content found in assistant message")
                }
                
              case .user(let userMessage):
                
                //  Log the user message received from the stream
                logger.info("Received user message in stream for session: \(userMessage.sessionId)")
                
                // Process user message content if needed
                for content in userMessage.message.content {
                  switch content {
                  case .text(let textContent, _):
                    logger.debug("User text content: \(textContent)")
                    // Update the assistant message with the user text content
                    contentBuffer = "USER: \(textContent)"
                    self.updateAssistantMessage(messageId: messageId, content: contentBuffer, isComplete: false)
                    
                  case .toolResult(let toolResult):
                    
                    // Handle tool results in user message
                    let resultPrefix = toolResult.isError == true ? "⚠️ USER TOOL ERROR: " : "USER TOOL RESULT: "
                    let toolResultMessage = "\(resultPrefix)\(toolResult.content)"
                    logger.debug("\(toolResultMessage)")
                    // Add a new tool result message
                    self.addToolResultMessage(content: toolResult.content, isError: toolResult.isError == true)
                    
                  default:
                    logger.debug("Received other content type in user message")
                    break
                  }
                }
              case .result(let resultMessage):
                // Save the session ID for continuations
                self.currentSessionId = resultMessage.sessionId
                logger.info("Completed response for session: \(resultMessage.sessionId)")
                
                // Ensure we have the final content in case we missed it
                if let finalContent = resultMessage.result, !finalContent.isEmpty {
                  contentBuffer = resultMessage.description()
                  self.updateAssistantMessage(messageId: messageId, content: finalContent, isComplete: true)
                }
              }
            }
          )
          .store(in: &self.cancellables)
      }
      
    default:
      await MainActor.run {
        logger.error("Expected stream result but got a different format")
        error = NSError(domain: "ChatViewModel", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])
        isLoading = false
      }
    }
  }
  
  private func updateAssistantMessage(messageId: UUID, content: String, isComplete: Bool) {
    if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
      let updatedMessage = ChatMessage(
        id: messageId,
        role: .assistant,
        content: content,
        isComplete: isComplete,
        messageType: .text
      )
      self.messages[index] = updatedMessage
    } else {
      logger.error("⚠️ Message with ID \(messageId) not found in messages array")
    }
  }
  
  private func addToolUseMessage(toolName: String, content: String) {
    let message = ChatMessage(
      role: .toolUse,
      content: content,
      messageType: .toolUse,
      toolName: toolName
    )
    messages.append(message)
  }
  
  private func addToolResultMessage(content: MessageResponse.Content.ToolResultContent, isError: Bool) {
    // Convert ToolResultContent to String based on its case
    var contentString: String = ""
    switch content {
    case .string(let stringValue):
      contentString = stringValue
    case .items(let items):
      for index in items.indices {
        contentString += "Item \(index) \n \(items[index].temporaryDescription)\n\n "
      }
    }
    
    let message = ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: contentString,
      messageType: isError ? .toolError : .toolResult
    )
    messages.append(message)
  }
  
  private func addThinkingMessage(content: String) {
    let message = ChatMessage(
      role: .thinking,
      content: content,
      messageType: .thinking
    )
    messages.append(message)
  }
  
  private func addWebSearchResultMessage(content: String) {
    let message = ChatMessage(
      role: .assistant,
      content: content,
      messageType: .webSearch
    )
    messages.append(message)
  }
  
  private func handleError(_ error: Error) {
    logger.error("Error: \(error.localizedDescription)")
    self.error = error
    self.isLoading = false
    
    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId,
       let index = messages.firstIndex(where: { $0.id == currentMessageId && !$0.isComplete }) {
      messages.remove(at: index)
    }
  }
}

extension ContentItem {
  var temporaryDescription: String {
    var result = "ContentItem:\n"
    
    if let title = self.title {
      result += "  Title: \"\(title)\"\n"
    }
    
    if let url = self.url {
      result += "  URL: \(url)\n"
    }
    
    if let type = self.type {
      result += "  Type: \(type)\n"
    }
    
    if let pageAge = self.pageAge {
      result += "  Age: \(pageAge)\n"
    }
    
    if let text = self.text {
      // Limit text length for readability
      let truncatedText = text.count > 100 ? "\(text.prefix(100))..." : text
      result += "  Text: \"\(truncatedText)\"\n"
    }
    
    if let _ = self.encryptedContent {
      // Just indicate presence rather than showing the whole encrypted content
      result += "  Encrypted Content: [Present]\n"
    }
    
    return result
  }
}

