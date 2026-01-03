#!/usr/bin/env ruby
# frozen_string_literal: true

#
# SaneProcess Memory Audit
# Finds unfixed bugs and unresolved issues in Memory MCP
#
# Usage: ruby scripts/memory_audit.rb [memory_file]
#
# Examples:
#   ruby scripts/memory_audit.rb ~/.claude/memory.json
#   ruby scripts/memory_audit.rb ~/SaneBar/.claude/memory.json
#   ruby scripts/memory_audit.rb  # Uses default path
#
# Checks:
# - BUG-* entities without FIXED or N/A status
# - Entities with "must sync" or "TODO" observations
# - Stale entities (no activity in 30+ days)
#

require 'json'
require 'date'

class MemoryAudit
  DEFAULT_MEMORY_PATHS = [
    File.expand_path('.claude/memory.json'),           # Current project
    File.expand_path('~/.claude/memory.json'),         # Global (rare)
    File.expand_path('~/SaneBar/.claude/memory.json'), # SaneBar
    File.expand_path('~/SaneVideo/.claude/memory.json'), # SaneVideo
  ].freeze

  # Patterns that indicate unresolved work
  UNRESOLVED_PATTERNS = [
    /must sync/i,
    /needs? sync/i,
    /TODO/,
    /FIXME/,
    /not yet/i,
    /pending/i,
    /awaiting/i,
    /blocked/i,
  ].freeze

  # Patterns that indicate resolved
  RESOLVED_PATTERNS = [
    /FIXED/i,
    /RESOLVED/i,
    /CLOSED/i,
    /N\/A/i,
    /NOT APPLICABLE/i,
    /COMPLETED/i,
    /DONE/i,
  ].freeze

  def initialize(memory_path = nil)
    @memory_path = memory_path || find_memory_file
    @issues = []
  end

  def run
    puts "═══════════════════════════════════════════════════════════════"
    puts "                  Memory MCP Audit"
    puts "═══════════════════════════════════════════════════════════════"
    puts

    unless @memory_path && File.exist?(@memory_path)
      puts "❌ Memory file not found."
      puts "   Checked: #{DEFAULT_MEMORY_PATHS.join(', ')}"
      puts
      puts "Usage: ruby scripts/memory_audit.rb path/to/memory.json"
      exit 1
    end

    puts "Memory file: #{@memory_path}"
    puts

    graph = load_memory
    return unless graph

    audit_bugs(graph)
    audit_unresolved(graph)
    audit_stale(graph)
    print_health_metrics(graph)

    puts
    puts "═══════════════════════════════════════════════════════════════"

    if @issues.empty?
      puts "✅ Memory is clean - no unfixed bugs or unresolved work!"
      exit 0
    else
      puts "⚠️  Found #{@issues.count} issues:"
      puts

      @issues.group_by { |i| i[:type] }.each do |type, type_issues|
        puts "#{type} (#{type_issues.count}):"
        type_issues.each do |issue|
          puts "  - #{issue[:entity]}"
          puts "    #{issue[:reason]}"
        end
        puts
      end

      exit 1
    end
  end

  private

  def find_memory_file
    DEFAULT_MEMORY_PATHS.find { |p| File.exist?(p) }
  end

  def load_memory
    content = File.read(@memory_path)
    JSON.parse(content)
  rescue JSON::ParserError => e
    puts "❌ Invalid JSON in memory file: #{e.message}"
    nil
  rescue Errno::ENOENT
    puts "❌ Memory file not found: #{@memory_path}"
    nil
  end

  def audit_bugs(graph)
    entities = graph['entities'] || []

    bug_entities = entities.select { |e| e['name']&.match?(/^BUG-/i) }

    puts "Found #{bug_entities.count} BUG-* entities"

    bug_entities.each do |entity|
      name = entity['name']
      observations = entity['observations'] || []
      all_text = observations.join(' ')

      # Check if it's resolved
      is_resolved = RESOLVED_PATTERNS.any? { |p| all_text.match?(p) }

      unless is_resolved
        @issues << {
          type: '🐛 UNFIXED BUGS',
          entity: name,
          reason: "No FIXED/N/A status found. Observations: #{observations.first(2).join('; ')}..."
        }
      end
    end
  end

  def audit_unresolved(graph)
    entities = graph['entities'] || []

    entities.each do |entity|
      name = entity['name']
      observations = entity['observations'] || []

      # Skip BUG entities (already checked)
      next if name.match?(/^BUG-/i)

      observations.each do |obs|
        UNRESOLVED_PATTERNS.each do |pattern|
          next unless obs.match?(pattern)

          # Check if there's also a resolution
          all_text = observations.join(' ')
          is_resolved = RESOLVED_PATTERNS.any? { |p| all_text.match?(p) }

          unless is_resolved
            @issues << {
              type: '📋 UNRESOLVED WORK',
              entity: name,
              reason: "Found '#{pattern.source}' without resolution: #{obs[0..100]}..."
            }
          end
          break # Only report once per entity
        end
      end
    end
  end

  def audit_stale(graph)
    entities = graph['entities'] || []
    cutoff = Date.today - 30

    entities.each do |entity|
      name = entity['name']
      observations = entity['observations'] || []

      # Look for date patterns in observations
      dates = observations.flat_map do |obs|
        obs.scan(/\d{4}-\d{2}-\d{2}/).map { |d| Date.parse(d) rescue nil }.compact
      end

      next if dates.empty?

      most_recent = dates.max
      next unless most_recent < cutoff

      @issues << {
        type: '⏰ STALE ENTITIES',
        entity: name,
        reason: "Last activity: #{most_recent} (#{(Date.today - most_recent).to_i} days ago)"
      }
    end
  end

  def print_health_metrics(graph)
    entities = graph['entities'] || []
    relations = graph['relations'] || []

    total_observations = entities.sum { |e| (e['observations'] || []).count }
    avg_observations = entities.empty? ? 0 : (total_observations.to_f / entities.count).round(1)

    # Estimate tokens (rough: ~4 chars per token)
    json_size = JSON.generate(graph).length
    est_tokens = (json_size / 4.0).round

    puts
    puts "Health Metrics:"
    puts "  Entities: #{entities.count} #{warn_if(entities.count, 60, 80)}"
    puts "  Relations: #{relations.count}"
    puts "  Total observations: #{total_observations}"
    puts "  Avg observations/entity: #{avg_observations} #{warn_if(avg_observations, 15, 25)}"
    puts "  Est. tokens: #{est_tokens} #{warn_if(est_tokens, 8000, 12_000)}"
  end

  def warn_if(value, warning_threshold, critical_threshold)
    return '🔴 CRITICAL' if value >= critical_threshold
    return '🟡 WARNING' if value >= warning_threshold

    '✅'
  end
end

# Run if executed directly
MemoryAudit.new(ARGV[0]).run if __FILE__ == $PROGRAM_NAME
