#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# SaneLoop Detector
# ==============================================================================
# Blocks Edit/Write when:
# 1. User explicitly requested SaneLoop but it's not active
# 2. Significant task detected (3+ files) without SaneLoop or plan
# ==============================================================================

require_relative 'base_detector'

class SaneLoopDetector < BaseDetector
  register_as :pre_tool_use, priority: 15, only: %w[Edit Write NotebookEdit]

  SIGNIFICANT_TASK_THRESHOLD = 3

  def check(context)
    # Check 1: Explicit SaneLoop request
    if requested?('saneloop') && !saneloop_active?
      return block(
        'SaneLoop required but not active',
        rule: 'SANELOOP_REQUIRED',
        details: { fix: 'Start SaneLoop: ./scripts/SaneMaster.rb saneloop start "Task"' }
      )
    end

    # Check 2: Significant task detection
    if significant_task? && !saneloop_active? && !satisfied?('plan')
      return block(
        "Significant task (#{unique_files_count}+ files) requires SaneLoop or plan",
        rule: 'SIGNIFICANT_TASK',
        details: {
          fix: 'Start SaneLoop or show plan for approval',
          files_edited: unique_files_count
        }
      )
    end

    allow
  end

  private

  def significant_task?
    unique_files_count >= SIGNIFICANT_TASK_THRESHOLD
  end

  def unique_files_count
    edits = state[:edits] || {}
    (edits[:unique_files] || []).length
  end
end
