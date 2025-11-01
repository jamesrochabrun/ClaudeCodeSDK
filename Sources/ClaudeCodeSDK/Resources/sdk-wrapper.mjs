#!/usr/bin/env node

/**
 * Node.js wrapper for @anthropic-ai/claude-agent-sdk
 *
 * This script bridges Swift and the TypeScript Claude Agent SDK by:
 * 1. Receiving configuration via command-line arguments
 * 2. Executing queries using the SDK
 * 3. Streaming results as JSONL (compatible with headless mode format)
 *
 * Usage:
 *   node sdk-wrapper.mjs '<json-config>'
 *
 * Config format:
 * {
 *   "prompt": "string",
 *   "options": {
 *     "model": "sonnet",
 *     "maxTurns": 50,
 *     "allowedTools": ["Read", "Bash"],
 *     "permissionMode": "default",
 *     ...
 *   }
 * }
 */

import { query } from '@anthropic-ai/claude-agent-sdk';

// Parse command-line arguments
async function main() {
  try {
    // Get config from first argument
    const configJson = process.argv[2];

    if (!configJson) {
      console.error('Error: No configuration provided');
      console.error('Usage: node sdk-wrapper.mjs \'<json-config>\'');
      process.exit(1);
    }

    // Parse configuration
    let config;
    try {
      config = JSON.parse(configJson);
    } catch (error) {
      console.error('Error: Invalid JSON configuration');
      console.error(error.message);
      process.exit(1);
    }

    // Extract prompt and options
    const { prompt, options = {} } = config;

    if (!prompt) {
      console.error('Error: No prompt provided in configuration');
      process.exit(1);
    }

    // Map Swift options to SDK options
    const sdkOptions = mapOptions(options);

    // DEBUG: Log configuration being passed to Agent SDK
    console.error('[SDK-WRAPPER] ===== AGENT SDK CONFIGURATION DEBUG =====');
    console.error('[SDK-WRAPPER] Prompt length:', prompt?.length || 0);
    console.error('[SDK-WRAPPER] Permission mode:', sdkOptions.permissionMode || 'NOT SET');
    console.error('[SDK-WRAPPER] Permission prompt tool:', sdkOptions.permissionPromptToolName || 'NOT SET');
    console.error('[SDK-WRAPPER] Allowed tools:', JSON.stringify(sdkOptions.allowedTools || []));
    console.error('[SDK-WRAPPER] MCP servers:', sdkOptions.mcpServers ? Object.keys(sdkOptions.mcpServers) : 'NOT SET');
    console.error('[SDK-WRAPPER] MCP config path:', options.mcpConfigPath || 'NOT SET');
    console.error('[SDK-WRAPPER] Model:', sdkOptions.model || 'default');
    console.error('[SDK-WRAPPER] Max turns:', sdkOptions.maxTurns || 'default');
    console.error('[SDK-WRAPPER] ==========================================');

    // Execute query using the SDK
    const result = query({
      prompt,
      options: sdkOptions
    });

    // Track if any tools were used during the conversation
    let toolsWereUsed = false;

    // Stream results as JSONL (same format as headless mode)
    for await (const message of result) {
      // Output each message as a JSON line
      console.log(JSON.stringify(message));

      // Check if this message contains tool usage
      if (message.type === 'assistant' && message.message?.content) {
        for (const content of message.message.content) {
          if (content.type === 'tool_use' || content.type === 'tool_result') {
            toolsWereUsed = true;
          }
        }
      }
    }

    // Smart exit: If NO tools were used, exit immediately to avoid 5s delay
    // If tools WERE used, let natural cleanup happen (safer for MCP/tool cleanup)
    if (!toolsWereUsed) {
      console.error('[SDK-WRAPPER] No tools used - exiting immediately to avoid delay');
      process.exit(0);
    } else {
      console.error('[SDK-WRAPPER] Tools were used - allowing natural cleanup');
      // Let event loop drain naturally (gives MCP servers time to cleanup)
    }

  } catch (error) {
    // Output error in a format that Swift can parse
    const errorMessage = {
      type: 'error',
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      }
    };
    console.error(JSON.stringify(errorMessage));
    process.exit(1);
  }
}

/**
 * Maps Swift options to SDK options
 * Handles differences in naming and structure between the two APIs
 */
function mapOptions(options) {
  const sdkOptions = {};

  // Direct mappings
  if (options.model) sdkOptions.model = options.model;
  if (options.maxTurns) sdkOptions.maxTurns = options.maxTurns;
  if (options.maxThinkingTokens) sdkOptions.maxThinkingTokens = options.maxThinkingTokens;
  if (options.allowedTools) sdkOptions.allowedTools = options.allowedTools;
  if (options.disallowedTools) sdkOptions.disallowedTools = options.disallowedTools;
  if (options.permissionMode) sdkOptions.permissionMode = options.permissionMode;
  if (options.permissionPromptToolName) sdkOptions.permissionPromptToolName = options.permissionPromptToolName;
  if (options.resume) sdkOptions.resume = options.resume;
  if (options.continue) sdkOptions.continue = options.continue;

  // System prompt handling
  if (options.systemPrompt) {
    sdkOptions.systemPrompt = options.systemPrompt;
  } else if (options.appendSystemPrompt) {
    // If only appendSystemPrompt is provided, use the preset with append
    sdkOptions.systemPrompt = {
      type: 'preset',
      preset: 'claude_code',
      append: options.appendSystemPrompt
    };
  }

  // MCP servers configuration
  if (options.mcpServers) {
    sdkOptions.mcpServers = options.mcpServers;
    console.error('[SDK-WRAPPER] MCP servers configured:', Object.keys(options.mcpServers));
  }

  // MCP config path (alternative to mcpServers)
  if (options.mcpConfigPath) {
    sdkOptions.mcpConfigPath = options.mcpConfigPath;
    console.error('[SDK-WRAPPER] MCP config path set:', options.mcpConfigPath);
  }

  // Abort controller handling
  if (options.timeout) {
    // SDK doesn't have direct timeout, but we can handle it at the wrapper level
    // For now, just pass it through and let the calling Swift code handle timeouts
  }

  // Additional options that SDK supports
  if (options.cwd) sdkOptions.cwd = options.cwd;
  if (options.env) sdkOptions.env = options.env;
  if (options.forkSession !== undefined) sdkOptions.forkSession = options.forkSession;
  if (options.resumeSessionAt) sdkOptions.resumeSessionAt = options.resumeSessionAt;
  if (options.includePartialMessages !== undefined) {
    sdkOptions.includePartialMessages = options.includePartialMessages;
  }

  return sdkOptions;
}

// Run the main function
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
