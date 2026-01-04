#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Table Detector
# ==============================================================================
# Blocks markdown tables in user-facing output per project rules.
# Tables in code comments and documentation files are OK.
# ==============================================================================

require_relative 'base_detector'

class TableDetector < BaseDetector
  register_as :pre_tool_use, priority: 35, only: %w[Edit Write]

  # Regex patterns for markdown tables
  TABLE_HEADER_SEP = /\|[-:]+\|/
  TABLE_ROW = /^\s*\|.*\|.*\|/m

  # Allowed file extensions (documentation)
  DOC_EXTENSIONS = %w[.md .markdown .rst .txt].freeze

  def check(context)
    path = file_path(context)
    text = content(context)

    return allow if text.empty?
    return allow if documentation_file?(path)
    return allow unless contains_table?(text)

    block(
      'Markdown table detected in non-documentation file',
      rule: 'NO_TABLES',
      details: {
        fix: 'Use plain text lists instead of markdown tables',
        file: path
      }
    )
  end

  private

  def documentation_file?(path)
    return false if path.nil? || path.empty?

    DOC_EXTENSIONS.any? { |ext| path.downcase.end_with?(ext) }
  end

  def contains_table?(text)
    return false if text.nil? || text.empty?

    lines = text.split("\n")

    # Check for header separator pattern
    return true if lines.any? { |line| line.match?(TABLE_HEADER_SEP) }

    # Check for table rows (2+ pipes)
    table_rows = lines.count { |line| line.match?(TABLE_ROW) && line.count('|') >= 3 }
    table_rows >= 2
  end
end
