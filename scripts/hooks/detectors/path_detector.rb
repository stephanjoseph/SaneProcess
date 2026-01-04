#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Path Detector
# ==============================================================================
# Blocks access to dangerous system paths and sensitive locations.
# Applies to: Read, Edit, Write, Bash (for file operations)
# ==============================================================================

require_relative 'base_detector'

class PathDetector < BaseDetector
  register_as :pre_tool_use, priority: 5  # High priority - security check

  # Hard blocked paths (never allow)
  BLOCKED_PATHS = [
    '/var', '/etc', '/usr', '/System', '/Library', '/private',
    '~/.ssh', '~/.aws', '~/.gnupg', '~/.config',
    '~/.claude_hook_secret'
  ].freeze

  # Warn but allow (cross-project access)
  WARN_PATHS = ['~/'].freeze

  def check(context)
    path = extract_path(context)
    return allow if path.nil? || path.empty?

    expanded = File.expand_path(path)

    # Check hard blocks
    BLOCKED_PATHS.each do |blocked|
      blocked_expanded = File.expand_path(blocked)
      if expanded.start_with?(blocked_expanded)
        return block(
          "Blocked path: #{path}",
          rule: 'DANGEROUS_PATH',
          details: { fix: 'Use project-local paths only', blocked_pattern: blocked }
        )
      end
    end

    # Check cross-project warnings
    project_dir = ENV['CLAUDE_PROJECT_DIR'] || Dir.pwd
    if !expanded.start_with?(project_dir) && expanded.start_with?(File.expand_path('~'))
      return warn_result(
        "Cross-project access: #{path}",
        rule: 'CROSS_PROJECT',
        details: { project: project_dir }
      )
    end

    allow
  end

  private

  def extract_path(context)
    # Edit/Write/Read use file_path
    path = file_path(context)
    return path unless path.empty?

    # Bash might have paths in command
    if bash_tool?(context)
      cmd = command(context)
      # Extract path from common patterns
      match = cmd.match(/(?:cat|head|tail|sed|echo\s*>)\s+["']?([^\s"']+)/)
      return match[1] if match
    end

    nil
  end
end
