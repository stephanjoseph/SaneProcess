#!/usr/bin/env ruby
# frozen_string_literal: true

# Skill Loader for SaneProcess
# Manages domain-specific knowledge that gets injected into Claude's context
#
# Usage:
#   ruby skill_loader.rb list              # Show available skills
#   ruby skill_loader.rb load <name>       # Load a skill into context
#   ruby skill_loader.rb unload <name>     # Remove a skill from context
#   ruby skill_loader.rb unload --all      # Remove all skills
#   ruby skill_loader.rb status            # Show what's currently loaded
#   ruby skill_loader.rb show <name>       # Preview a skill's content

require 'json'
require 'fileutils'

class SkillLoader
  # Where things live
  SKILLS_DIR = File.expand_path('../../skills', __FILE__)
  CLAUDE_DIR = File.expand_path('../../.claude', __FILE__)
  CONTEXT_FILE = File.join(CLAUDE_DIR, 'mac_context.md')
  ACTIVE_FILE = File.join(CLAUDE_DIR, 'active_skills.json')

  # Markers in mac_context.md to identify skill section
  SKILLS_START = '<!-- SKILLS START - Auto-generated, do not edit below -->'
  SKILLS_END = '<!-- SKILLS END -->'

  def initialize
    FileUtils.mkdir_p(CLAUDE_DIR)
  end

  # ─────────────────────────────────────────────────────────────
  # Commands
  # ─────────────────────────────────────────────────────────────

  def list
    puts "\n📚 Available Skills:\n\n"

    available_skills.each do |skill|
      lines = count_lines(skill[:path])
      status = active_skills.include?(skill[:name]) ? '✅' : '  '
      puts "  #{status} #{skill[:name].ljust(25)} (#{lines} lines)"
    end

    active = active_skills
    if active.any?
      puts "\n🧠 Currently loaded: #{active.join(', ')}"
    else
      puts "\n💡 No skills loaded. Use: ruby skill_loader.rb load <name>"
    end
    puts
  end

  def load(names)
    if names.empty?
      puts '❌ Usage: ruby skill_loader.rb load <skill-name> [skill-name2 ...]'
      return
    end

    loaded = []
    names.each do |name|
      skill = find_skill(name)
      if skill.nil?
        puts "❌ Skill not found: #{name}"
        puts "   Available: #{available_skills.map { |s| s[:name] }.join(', ')}"
        next
      end

      if active_skills.include?(name)
        puts "⚠️  Already loaded: #{name}"
        next
      end

      add_active_skill(name)
      loaded << name
      puts "✅ Loaded: #{name} (#{count_lines(skill[:path])} lines)"
    end

    if loaded.any?
      inject_skills
      total = count_lines(CONTEXT_FILE)
      puts "\n📝 Context updated: #{CONTEXT_FILE}"
      puts "   Total lines: #{total}"
    end
  end

  def unload(args)
    if args.include?('--all')
      clear_active_skills
      inject_skills
      puts '✅ All skills unloaded'
      return
    end

    if args.empty?
      puts '❌ Usage: ruby skill_loader.rb unload <skill-name> [--all]'
      return
    end

    args.each do |name|
      if active_skills.include?(name)
        remove_active_skill(name)
        puts "✅ Unloaded: #{name}"
      else
        puts "⚠️  Not loaded: #{name}"
      end
    end

    inject_skills
    puts "\n📝 Context updated"
  end

  def status
    active = active_skills
    if active.empty?
      puts "\n🧠 No skills currently loaded.\n\n"
      return
    end

    puts "\n🧠 Active Skills:\n\n"
    total_lines = 0

    active.each do |name|
      skill = find_skill(name)
      lines = skill ? count_lines(skill[:path]) : 0
      total_lines += lines
      puts "   • #{name} (#{lines} lines)"
    end

    base_lines = count_base_context_lines
    puts "\n   Base context: #{base_lines} lines"
    puts "   Skills added: #{total_lines} lines"
    puts "   Total context: #{base_lines + total_lines} lines\n\n"
  end

  def show(name)
    if name.nil?
      puts '❌ Usage: ruby skill_loader.rb show <skill-name>'
      return
    end

    skill = find_skill(name)
    if skill.nil?
      puts "❌ Skill not found: #{name}"
      return
    end

    puts "\n#{File.read(skill[:path])}\n"
  end

  # ─────────────────────────────────────────────────────────────
  # Skill Discovery
  # ─────────────────────────────────────────────────────────────

  def available_skills
    Dir.glob(File.join(SKILLS_DIR, '*.md')).map do |path|
      { name: File.basename(path, '.md'), path: path }
    end.sort_by { |s| s[:name] }
  end

  def find_skill(name)
    available_skills.find { |s| s[:name] == name }
  end

  # ─────────────────────────────────────────────────────────────
  # Active Skills Tracking
  # ─────────────────────────────────────────────────────────────

  def active_skills
    return [] unless File.exist?(ACTIVE_FILE)

    JSON.parse(File.read(ACTIVE_FILE))['skills'] || []
  rescue JSON::ParserError
    []
  end

  def add_active_skill(name)
    skills = active_skills
    skills << name unless skills.include?(name)
    save_active_skills(skills)
  end

  def remove_active_skill(name)
    skills = active_skills.reject { |s| s == name }
    save_active_skills(skills)
  end

  def clear_active_skills
    save_active_skills([])
  end

  def save_active_skills(skills)
    File.write(ACTIVE_FILE, JSON.pretty_generate({ skills: skills }))
  end

  # ─────────────────────────────────────────────────────────────
  # Context Injection
  # ─────────────────────────────────────────────────────────────

  def inject_skills
    # Read base context (everything before SKILLS_START marker)
    base_content = read_base_context

    # Build skills section
    skills_content = build_skills_section

    # Write combined content
    File.write(CONTEXT_FILE, base_content + skills_content)
  end

  def read_base_context
    return '' unless File.exist?(CONTEXT_FILE)

    content = File.read(CONTEXT_FILE)

    # Remove existing skills section if present
    if content.include?(SKILLS_START)
      content = content.split(SKILLS_START).first.rstrip
    end

    content + "\n\n"
  end

  def build_skills_section
    skills = active_skills
    return '' if skills.empty?

    sections = [SKILLS_START, '', '## Loaded Skills', '']

    skills.each do |name|
      skill = find_skill(name)
      next unless skill

      content = File.read(skill[:path])
      sections << content
      sections << ''
      sections << '---'
      sections << ''
    end

    sections << SKILLS_END
    sections.join("\n")
  end

  def count_base_context_lines
    return 0 unless File.exist?(CONTEXT_FILE)

    content = File.read(CONTEXT_FILE)
    if content.include?(SKILLS_START)
      content = content.split(SKILLS_START).first
    end
    content.lines.count
  end

  def count_lines(path)
    return 0 unless File.exist?(path)

    File.read(path).lines.count
  end
end

# ─────────────────────────────────────────────────────────────
# CLI Entry Point
# ─────────────────────────────────────────────────────────────

if __FILE__ == $PROGRAM_NAME
  loader = SkillLoader.new
  command = ARGV.shift || 'status'

  case command
  when 'list', 'ls', 'l'
    loader.list
  when 'load', 'add'
    loader.load(ARGV)
  when 'unload', 'remove', 'rm'
    loader.unload(ARGV)
  when 'status', 's'
    loader.status
  when 'show', 'preview'
    loader.show(ARGV.first)
  when 'help', '-h', '--help'
    puts <<~HELP

      Skill Loader - Manage domain knowledge for Claude

      Commands:
        list              Show available skills
        load <name>       Load a skill into context
        unload <name>     Remove a skill from context
        unload --all      Remove all skills
        status            Show what's currently loaded
        show <name>       Preview a skill's content

      Examples:
        ruby skill_loader.rb list
        ruby skill_loader.rb load swift-concurrency
        ruby skill_loader.rb load swiftui-performance crash-analysis
        ruby skill_loader.rb status
        ruby skill_loader.rb unload --all

    HELP
  else
    puts "Unknown command: #{command}"
    puts "Run 'ruby skill_loader.rb help' for usage"
  end
end
