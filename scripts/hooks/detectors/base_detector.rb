#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Base Detector
# ==============================================================================
# Foundation for all enforcement detectors. Extends HookRegistry::Detector
# with common utilities for state access and context helpers.
#
# Usage:
#   class MyDetector < BaseDetector
#     register_as :pre_tool_use, priority: 10
#     def check(context)
#       return allow if passes_check?(context)
#       block('Failed check', rule: 'RULE_NAME')
#     end
#   end
# ==============================================================================

require_relative '../core/hook_registry'
require_relative '../core/state_manager'

class BaseDetector < HookRegistry::Detector
  # Common tool classifications
  EDIT_TOOLS = %w[Edit Write NotebookEdit].freeze
  RESEARCH_TOOLS = %w[Read Grep Glob WebSearch WebFetch Task].freeze
  MCP_TOOLS_PREFIX = 'mcp__'.freeze

  protected

  # State access helpers
  def state
    @state ||= StateManager.to_h
  end

  def requirements
    state[:requirements] || {}
  end

  def requested?(key)
    (requirements[:requested] || []).include?(key.to_s)
  end

  def satisfied?(key)
    (requirements[:satisfied] || []).include?(key.to_s)
  end

  def research_progress
    state[:research] || {}
  end

  def saneloop_state
    state[:saneloop] || {}
  end

  def saneloop_active?
    saneloop_state[:active] == true
  end

  # Context helpers
  def tool_name(context)
    context[:tool_name] || ''
  end

  def tool_input(context)
    context[:tool_input] || {}
  end

  def file_path(context)
    tool_input(context)['file_path'] || ''
  end

  def command(context)
    tool_input(context)['command'] || ''
  end

  def content(context)
    tool_input(context)['new_string'] || tool_input(context)['content'] || ''
  end

  def prompt(context)
    tool_input(context)['prompt'] || ''
  end

  # Tool type checks
  def edit_tool?(context)
    EDIT_TOOLS.include?(tool_name(context))
  end

  def research_tool?(context)
    name = tool_name(context)
    RESEARCH_TOOLS.include?(name) || name.start_with?(MCP_TOOLS_PREFIX)
  end

  def bash_tool?(context)
    tool_name(context) == 'Bash'
  end

  def task_tool?(context)
    tool_name(context) == 'Task'
  end
end
