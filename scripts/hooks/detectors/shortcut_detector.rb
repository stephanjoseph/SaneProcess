#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Shortcut Detector
# ==============================================================================
# Wraps the existing ShortcutDetectors module for registry integration.
# Detects bypass attempts and lazy patterns.
# ==============================================================================

require_relative 'base_detector'
require_relative '../shortcut_detectors'

class ShortcutDetector < BaseDetector
  include ShortcutDetectors
  register_as :pre_tool_use, priority: 30

  def check(context)
    if edit_tool?(context)
      return check_edit_shortcuts(context)
    end

    if bash_tool?(context)
      return check_bash_shortcuts(context)
    end

    allow
  end

  private

  def check_edit_shortcuts(context)
    text = content(context)

    if detect_casual_self_rating(text)
      return block(
        'Improper self-rating format detected',
        rule: 'CASUAL_RATING',
        details: { fix: 'Use proper format with SOP Compliance: X/10 and Performance: X/10' }
      )
    end

    allow
  end

  def check_bash_shortcuts(context)
    cmd = command(context)

    # Lazy commit check
    if detect_lazy_commit(cmd)
      return block(
        'Incomplete commit workflow (missing status/diff)',
        rule: 'LAZY_COMMIT',
        details: { fix: 'Run git status and git diff before committing' }
      )
    end

    # File write bypass (only block if there are blocking requirements)
    if detect_bash_file_write(cmd) && has_blocking_requirements?
      return block(
        'Bash file write bypass detected',
        rule: 'BASH_FILE_WRITE',
        details: { fix: 'Use Edit tool instead of Bash for file modifications' }
      )
    end

    # Table bypass
    if detect_bash_table_bypass(cmd)
      return block(
        'Markdown table creation via Bash detected',
        rule: 'BASH_TABLE_BYPASS',
        details: { fix: 'Use plain text lists instead of tables' }
      )
    end

    # Size bypass
    size_violation = detect_bash_size_bypass(cmd)
    if size_violation
      return block(
        "Bash size bypass: #{size_violation[:file]} has #{size_violation[:lines]} lines (limit: #{size_violation[:limit]})",
        rule: 'BASH_SIZE_BYPASS',
        details: size_violation
      )
    end

    allow
  end

  def has_blocking_requirements?
    return true if requested?('saneloop') && !saneloop_active?
    return true if requested?('plan') && !satisfied?('plan')
    return true if requested?('research') && !satisfied?('research')

    false
  end
end
