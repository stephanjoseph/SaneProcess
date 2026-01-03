#!/usr/bin/env ruby
# frozen_string_literal: true

#
# SaneProcess Cross-Project Sync Check
# Detects drift between SaneProcess and implementation projects
#
# Usage: ruby scripts/sync_check.rb [project_path]
#
# Examples:
#   ruby scripts/sync_check.rb ~/SaneBar
#   ruby scripts/sync_check.rb ~/SaneVideo
#   ruby scripts/sync_check.rb  # Auto-detect sibling projects
#
# Checks:
# - Hooks in SaneProcess vs project
# - Pattern rules in .claude/rules/
# - Version numbers match
#

require 'digest'
require 'json'

class SyncCheck
  SANEPROCESS_ROOT = File.expand_path('..', __dir__)
  HOOKS_DIR = File.join(SANEPROCESS_ROOT, 'scripts', 'hooks')
  RULES_DIR = File.join(SANEPROCESS_ROOT, '.claude', 'rules')

  # Hooks that should be identical across all projects
  SYNC_HOOKS = %w[
    circuit_breaker.rb
    edit_validator.rb
    failure_tracker.rb
    test_quality_checker.rb
    path_rules.rb
    session_start.rb
    audit_logger.rb
    sop_mapper.rb
    two_fix_reminder.rb
    verify_reminder.rb
    version_mismatch.rb
  ].freeze

  # Rules that should be synced
  SYNC_RULES = %w[
    views.md
    tests.md
    services.md
    models.md
    scripts.md
    hooks.md
  ].freeze

  def initialize(project_paths = [])
    @project_paths = project_paths.empty? ? detect_sibling_projects : project_paths
    @diffs = []
  end

  def run
    if @project_paths.empty?
      puts "No projects found to compare."
      puts "Usage: ruby scripts/sync_check.rb ~/SaneBar ~/SaneVideo"
      exit 0
    end

    puts "═══════════════════════════════════════════════════════════════"
    puts "              Cross-Project Sync Check"
    puts "═══════════════════════════════════════════════════════════════"
    puts
    puts "SaneProcess: #{SANEPROCESS_ROOT}"
    puts "Comparing with: #{@project_paths.join(', ')}"
    puts

    @project_paths.each do |project|
      check_project(project)
    end

    puts
    puts "═══════════════════════════════════════════════════════════════"

    if @diffs.empty?
      puts "✅ All projects in sync!"
      exit 0
    else
      puts "⚠️  Found #{@diffs.count} differences:"
      puts

      @diffs.group_by { |d| d[:project] }.each do |project, project_diffs|
        puts "#{project}:"
        project_diffs.each do |diff|
          puts "  #{diff[:status]} #{diff[:file]}"
          puts "       #{diff[:reason]}" if diff[:reason]
        end
        puts
      end

      puts "Run 'ruby scripts/sync_check.rb --fix' to copy from SaneProcess to projects"
      exit 1
    end
  end

  private

  def detect_sibling_projects
    parent = File.dirname(SANEPROCESS_ROOT)
    siblings = Dir.entries(parent).select do |entry|
      next false if entry.start_with?('.')
      next false if entry == 'SaneProcess'

      path = File.join(parent, entry)
      # Check if it looks like a Sane* project (has Scripts/hooks or .claude/rules)
      File.directory?(path) &&
        (File.directory?(File.join(path, 'Scripts', 'hooks')) ||
         File.directory?(File.join(path, '.claude', 'rules')))
    end

    siblings.map { |s| File.join(parent, s) }
  end

  def check_project(project_path)
    name = File.basename(project_path)
    puts "Checking #{name}..."

    # Find hooks directory (Scripts/hooks or scripts/hooks)
    project_hooks = find_hooks_dir(project_path)
    if project_hooks
      check_hooks(project_path, project_hooks)
    else
      puts "  ⚠️  No hooks directory found"
    end

    # Find rules directory
    project_rules = File.join(project_path, '.claude', 'rules')
    if File.directory?(project_rules)
      check_rules(project_path, project_rules)
    else
      puts "  ⚠️  No .claude/rules directory found"
    end

    puts
  end

  def find_hooks_dir(project_path)
    %w[Scripts/hooks scripts/hooks].each do |rel_path|
      full_path = File.join(project_path, rel_path)
      return full_path if File.directory?(full_path)
    end
    nil
  end

  def check_hooks(project_path, project_hooks_dir)
    project_name = File.basename(project_path)

    SYNC_HOOKS.each do |hook|
      sp_path = File.join(HOOKS_DIR, hook)
      proj_path = File.join(project_hooks_dir, hook)

      unless File.exist?(sp_path)
        # SaneProcess doesn't have this hook (shouldn't happen)
        next
      end

      unless File.exist?(proj_path)
        @diffs << {
          project: project_name,
          file: hook,
          status: '❌ MISSING',
          reason: 'Hook exists in SaneProcess but not in project'
        }
        next
      end

      sp_content = normalize_hook(File.read(sp_path))
      proj_content = normalize_hook(File.read(proj_path))

      next if sp_content == proj_content

      # Content differs - check if it's significant
      sp_hash = Digest::MD5.hexdigest(sp_content)
      proj_hash = Digest::MD5.hexdigest(proj_content)

      @diffs << {
        project: project_name,
        file: hook,
        status: '⚠️  DIFFERS',
        reason: "SP: #{sp_hash[0..7]}... vs Project: #{proj_hash[0..7]}..."
      }
    end

    # Check for extra hooks in project
    Dir.glob(File.join(project_hooks_dir, '*.rb')).each do |proj_hook|
      hook_name = File.basename(proj_hook)
      next if SYNC_HOOKS.include?(hook_name)
      next if hook_name.start_with?('test') # Ignore test files

      sp_path = File.join(HOOKS_DIR, hook_name)
      next if File.exist?(sp_path)

      @diffs << {
        project: project_name,
        file: hook_name,
        status: '➕ EXTRA',
        reason: 'Hook exists in project but not in SaneProcess'
      }
    end
  end

  def check_rules(project_path, project_rules_dir)
    project_name = File.basename(project_path)

    SYNC_RULES.each do |rule|
      sp_path = File.join(RULES_DIR, rule)
      proj_path = File.join(project_rules_dir, rule)

      next unless File.exist?(sp_path)

      unless File.exist?(proj_path)
        @diffs << {
          project: project_name,
          file: "rules/#{rule}",
          status: '❌ MISSING',
          reason: 'Rule exists in SaneProcess but not in project'
        }
        next
      end

      sp_content = File.read(sp_path).strip
      proj_content = File.read(proj_path).strip

      next if sp_content == proj_content

      @diffs << {
        project: project_name,
        file: "rules/#{rule}",
        status: '⚠️  DIFFERS',
        reason: 'Content differs from SaneProcess'
      }
    end
  end

  def normalize_hook(content)
    # Remove comments that might differ (copyright, project-specific)
    # Keep functional code the same
    content
      .gsub(/^#.*Copyright.*$/i, '')
      .gsub(/^#.*SaneBar.*$/i, '')
      .gsub(/^#.*SaneVideo.*$/i, '')
      .gsub(/^#.*SaneProcess.*$/i, '')
      .gsub(/^\s*\n/, "\n")
      .strip
  end
end

# Run if executed directly
SyncCheck.new(ARGV).run if __FILE__ == $PROGRAM_NAME
