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

    // Execute query using the SDK
    const result = query({
      prompt,
      options: sdkOptions
    });

    // Stream results as JSONL (same format as headless mode)
    for await (const message of result) {
      // Output each message as a JSON line
      console.log(JSON.stringify(message));
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
