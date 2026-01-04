#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# Research Detector
# ==============================================================================
# Blocks Edit/Write until all 5 mandatory research categories are complete
# via Task agents. Individual tool calls don't count - must use subagents.
#
# Categories: memory, docs, web, github, local
# ==============================================================================

require_relative 'base_detector'

class ResearchDetector < BaseDetector
  register_as :pre_tool_use, priority: 20, only: %w[Edit Write NotebookEdit]

  CATEGORIES = %i[memory docs web github local].freeze

  def check(context)
    return allow unless requested?('research') || big_task?
    return allow if satisfied?('research')
    return allow if all_research_done_via_tasks?

    missing = missing_categories
    block(
      "Research incomplete: missing #{missing.join(', ')}",
      rule: 'RESEARCH_VIA_TASKS',
      details: {
        fix: 'Run 5 parallel Task agents for research before editing',
        missing: missing,
        progress: research_status
      }
    )
  end

  private

  def big_task?
    requirements[:is_big_task] == true
  end

  def all_research_done_via_tasks?
    progress = research_progress
    CATEGORIES.all? do |cat|
      entry = progress[cat]
      entry && entry[:completed_at] && entry[:via_task] == true
    end
  end

  def missing_categories
    progress = research_progress
    CATEGORIES.reject do |cat|
      entry = progress[cat]
      entry && entry[:completed_at] && entry[:via_task] == true
    end
  end

  def research_status
    progress = research_progress
    CATEGORIES.map do |cat|
      entry = progress[cat]
      if entry && entry[:completed_at]
        via = entry[:via_task] ? '(Task)' : '(direct)'
        "#{cat}: ✓ #{via}"
      else
        "#{cat}: ✗"
      end
    end.join(', ')
  end
end
