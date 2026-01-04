#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Size Detector
# ==============================================================================
# Enforces Rule #10: "Five hundred's fine, eight's the line"
# - Warns at 500 lines (code) / 1000 lines (markdown)
# - Blocks at 800 lines (code) / 1500 lines (markdown)
# ==============================================================================

require_relative 'base_detector'

class SizeDetector < BaseDetector
  register_as :pre_tool_use, priority: 25, only: %w[Edit Write]

  # Thresholds
  CODE_WARN = 500
  CODE_BLOCK = 800
  MD_WARN = 1000
  MD_BLOCK = 1500

  def check(context)
    path = file_path(context)
    return allow if path.empty?
    return allow unless File.exist?(path)

    current_lines = File.readlines(path).count
    is_markdown = path.end_with?('.md')

    warn_limit = is_markdown ? MD_WARN : CODE_WARN
    block_limit = is_markdown ? MD_BLOCK : CODE_BLOCK

    # Calculate projected size after edit
    projected = calculate_projected_size(context, current_lines)

    if projected > block_limit
      return block(
        "File exceeds #{block_limit} lines (projected: #{projected})",
        rule: 'FILE_SIZE_LIMIT',
        details: {
          fix: 'Split file by responsibility before adding more content',
          current: current_lines,
          projected: projected,
          limit: block_limit
        }
      )
    end

    if projected > warn_limit
      return warn_result(
        "File approaching limit: #{projected}/#{block_limit} lines",
        rule: 'FILE_SIZE_WARNING',
        details: { current: current_lines, projected: projected }
      )
    end

    allow
  end

  private

  def calculate_projected_size(context, current)
    input = tool_input(context)

    if tool_name(context) == 'Write'
      # Write replaces entire file
      content = input['content'] || ''
      return content.lines.count
    end

    # Edit: calculate delta
    old_str = input['old_string'] || ''
    new_str = input['new_string'] || ''
    delta = new_str.lines.count - old_str.lines.count

    current + delta
  end
end
