#!/usr/bin/env ruby
# frozen_string_literal: true

# Syncs global memory entities to all project memory files
# Global entities are stored in ~/.claude/global-memory.json
# They get copied to each project's .claude/memory.json

require 'json'
require 'fileutils'

GLOBAL_MEMORY = File.expand_path('~/.claude/global-memory.json')
SANE_APPS_ROOT = File.expand_path('~/SaneApps/apps')
INFRA_ROOT = File.expand_path('~/SaneApps/infra')

# All projects that should receive global memories
PROJECTS = %w[
  SaneBar
  SaneClip
  SaneVideo
  SaneSync
  SaneHosts
  SaneScript
  SaneAI
].map { |p| File.join(SANE_APPS_ROOT, p) } + [
  File.join(INFRA_ROOT, 'SaneProcess')
]

def load_json(path)
  return { 'entities' => [], 'relations' => [] } unless File.exist?(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError
  { 'entities' => [], 'relations' => [] }
end

def save_json(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(data))
end

def sync_global_to_project(global_entities, project_path)
  memory_path = File.join(project_path, '.claude', 'memory.json')
  project_name = File.basename(project_path)

  project_memory = load_json(memory_path)
  project_entities = project_memory['entities'] || []

  # Get names of existing entities
  existing_names = project_entities.map { |e| e['name'] }

  # Add global entities that don't exist yet
  added = 0
  updated = 0

  global_entities.each do |global_entity|
    name = global_entity['name']

    if existing_names.include?(name)
      # Update existing
      idx = project_entities.find_index { |e| e['name'] == name }
      if project_entities[idx] != global_entity
        project_entities[idx] = global_entity
        updated += 1
      end
    else
      # Add new
      project_entities << global_entity
      added += 1
    end
  end

  if added > 0 || updated > 0
    project_memory['entities'] = project_entities
    save_json(memory_path, project_memory)
    warn "  #{project_name}: +#{added} added, ~#{updated} updated"
  else
    warn "  #{project_name}: up to date"
  end
end

def main
  unless File.exist?(GLOBAL_MEMORY)
    warn "Creating global memory file: #{GLOBAL_MEMORY}"
    save_json(GLOBAL_MEMORY, { 'entities' => [], 'relations' => [] })
    warn "Add global entities there, then run this script again."
    exit 0
  end

  global_memory = load_json(GLOBAL_MEMORY)
  global_entities = global_memory['entities'] || []

  if global_entities.empty?
    warn "No global entities to sync."
    warn "Add entities to #{GLOBAL_MEMORY}"
    exit 0
  end

  warn "Syncing #{global_entities.length} global entities to #{PROJECTS.length} projects..."

  PROJECTS.each do |project_path|
    next unless File.directory?(project_path)
    sync_global_to_project(global_entities, project_path)
  end

  warn "\nDone."
end

main
