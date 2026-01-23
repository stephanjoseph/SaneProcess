#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# PostToolUse Entry Point
# ==============================================================================
# Entry point for all PostToolUse tracking. Runs after tool execution to:
#   - Track research progress
#   - Log tool usage
#   - Update state
#
# PostToolUse hooks cannot block (tool already executed), only log/track.
# ==============================================================================

require_relative '../core/state_manager'
require_relative '../core/hook_registry'
require_relative '../actions/logger'

# Helper: Determine outcome from output
def determine_outcome(output)
  return 'unknown' if output.nil?

  # Convert to string if needed (Claude Code sends Hash for tool_response)
  text = output.is_a?(Hash) ? output.to_s : output.to_s
  return 'unknown' if text.empty?
  return 'blocked' if text.match?(/BLOCKED|exit 2|error:/i)
  return 'warning' if text.match?(/WARNING/i)

  'success'
end

# Helper: Track research tools
def track_research(tool, input, output)
  category = research_category(tool)
  return unless category

  # Update research progress in state
  StateManager.update(:research) do |r|
    r[category] ||= {}
    r[category][:completed_at] = Time.now.iso8601
    r[category][:tool] = tool
    r[category][:via_task] = false  # Direct tool call, not via Task
    r
  end
end

def research_category(tool)
  case tool
  when 'mcp__memory__read_graph', 'mcp__memory__search_nodes'
    :memory
  when /^mcp__apple-docs__/, /^mcp__context7__/
    :docs
  when 'WebSearch', 'WebFetch'
    :web
  when /^mcp__github__/
    :github
  when 'Read', 'Grep', 'Glob'
    :local
  end
end

# Helper: Track edits
def track_edit(tool, input)
  file = input['file_path']
  return unless file

  StateManager.update(:edits) do |e|
    e[:count] = (e[:count] || 0) + 1
    e[:unique_files] ||= []
    e[:unique_files] << file unless e[:unique_files].include?(file)
    e[:last_file] = file
    e
  end
end

# === Main execution ===
begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError, Errno::ENOENT
  exit 0
end

tool_name = input['tool_name'] || ''
tool_input = input['tool_input'] || {}
tool_output = input['tool_response'] || input['tool_output'] || ''

# Log tool execution
Logger.log_tool(
  tool: tool_name,
  input: tool_input,
  outcome: determine_outcome(tool_output)
)

# Track research if applicable
track_research(tool_name, tool_input, tool_output)

# Track edits
track_edit(tool_name, tool_input) if %w[Edit Write NotebookEdit].include?(tool_name)

exit 0
