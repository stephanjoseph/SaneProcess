#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# SaneTools Gaming Detection Module
# ==============================================================================
# Detects patterns suggesting attempts to game the enforcement system.
# Extracted from sanetools_checks.rb per Rule #10 (file size limits).
#
# Usage:
#   require_relative 'sanetools_gaming'
#   include SaneToolsGaming
# ==============================================================================

require 'time'
require_relative 'core/state_manager'

module SaneToolsGaming
  GAMING_THRESHOLDS = {
    rapid_research_seconds: 30,      # All research in < 30s is suspicious
    repeated_errors_count: 3,        # Same error 3x suggests brute force
    research_to_edit_seconds: 5,     # Gap too short = no real review
    error_rate_threshold: 0.7        # 70%+ failure rate is suspicious
  }.freeze

  def check_gaming_patterns(tool_name, edit_tools, research_categories)
    return nil unless edit_tools.include?(tool_name)

    warnings = []

    # Check 1: All research completed suspiciously fast
    if (w = check_rapid_research(research_categories))
      warnings << w
    end

    # Check 2: Same timestamp across all research (atomic completion)
    if (w = check_timestamp_gaming)
      warnings << w
    end

    # Check 3: High error rate then sudden success
    if (w = check_error_stuffing)
      warnings << w
    end

    return nil if warnings.empty?

    # Log gaming attempts to patterns for future sessions
    log_gaming_attempt(warnings)

    # VULN-037 FIX: Block on ANY gaming pattern detection
    # Gaming = cheating. No warnings, no second chances.
    # If research timestamps are identical or suspiciously fast, the research is fake.
    "GAMING DETECTION BLOCKED\n" \
    "Research gaming patterns detected.\n" \
    "Patterns: #{warnings.join('; ')}\n" \
    "This suggests automated or scripted research completion.\n" \
    "Genuine research takes time and produces varied timestamps.\n" \
    "Reset research with: StateManager.reset(:research)"
  end

  def check_rapid_research(research_categories)
    research = StateManager.get(:research)
    timestamps = []

    research_categories.keys.each do |cat|
      info = research[cat]
      next unless info.is_a?(Hash) && info[:completed_at]

      begin
        timestamps << Time.parse(info[:completed_at])
      rescue ArgumentError
        # Invalid timestamp format - skip this category
        next
      end
    end

    return nil if timestamps.length < 4

    span = timestamps.max - timestamps.min
    if span < GAMING_THRESHOLDS[:rapid_research_seconds]
      return "All 4 research categories in #{span.round}s (expected: >30s)"
    end

    nil
  end

  def check_timestamp_gaming
    research = StateManager.get(:research)
    timestamps = []

    research.each do |_cat, info|
      next unless info.is_a?(Hash) && info[:completed_at]
      timestamps << info[:completed_at]
    end

    completed = timestamps.compact.length
    unique = timestamps.compact.uniq.length

    # If 3+ categories have identical timestamp, suspicious
    if completed >= 3 && unique == 1
      return "#{completed} research categories at identical timestamp"
    end

    nil
  end

  def check_error_stuffing
    action_log = StateManager.get(:action_log) || []
    return nil if action_log.length < 10

    recent = action_log.last(10)
    errors = recent.count { |a| a[:error_sig] || a['error_sig'] }
    error_rate = errors.to_f / recent.length

    if error_rate >= GAMING_THRESHOLDS[:error_rate_threshold]
      last_action = recent.last
      tool = last_action[:tool] || last_action['tool']
      success = last_action[:success] || last_action['success']

      if tool == 'Task' && success
        return "#{(error_rate * 100).round}% error rate, then Task 'succeeded'"
      end
    end

    nil
  end

  def log_gaming_attempt(warnings)
    StateManager.update(:patterns) do |patterns|
      patterns[:weak_spots] ||= {}
      patterns[:weak_spots]['gaming'] = (patterns[:weak_spots]['gaming'] || 0) + 1
      patterns[:gaming_log] ||= []
      patterns[:gaming_log] << {
        timestamp: Time.now.iso8601,
        warnings: warnings
      }
      patterns[:gaming_log] = patterns[:gaming_log].last(10)
      patterns
    end
  rescue StandardError
    # Don't fail on logging errors
  end
end
