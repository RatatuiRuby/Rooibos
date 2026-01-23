#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'
require 'json'

# Parse stories from file_browser_stories.md
def parse_stories(file_path)
  content = File.read(file_path)
  stories = []
  
  # Split by story headers and capture full content
  sections = content.split(/^## Story (-?\d+): (.+)$/)
  
  # sections[0] is preamble, then groups of [number, title, content]
  (1...sections.length).step(3) do |i|
    number = sections[i].to_i
    title = sections[i + 1].strip
    story_content = sections[i + 2]
    
    # Extract until next story or end
    story_content = story_content.split(/^---$/)[0].strip
    
    stories << { 
      number: number, 
      title: title,
      content: story_content
    }
  end
  
  stories.sort_by { |s| s[:number] }
end

# Parse tutorial steps from tutorial files
def parse_tutorial_steps(tutorial_dir)
  steps = []
  
  # Get all tutorial files in order
  tutorial_files = Dir.glob("#{tutorial_dir}/*.md").sort
  
  tutorial_files.each do |file|
    content = File.read(file)
    
    # Extract H1 title
    title_match = content.match(/^# (.+)$/)
    title = title_match ? title_match[1].strip : File.basename(file, '.md')
    
    # Store full content for display
    steps << {
      file: File.basename(file),
      title: title,
      content: content
    }
  end
  
  steps
end

# Main interactive mapping logic
def run_interactive_mapping(stories, tutorial_steps)
  results = {}
  tutorial_steps.each { |step| results[step[:title]] = Set.new }
  
  story_index = 0
  
  tutorial_steps.each do |step|
    while story_index < stories.length
      story = stories[story_index]
      
      # Display tutorial step EVERY time
      puts "\n" + "=" * 80
      puts "TUTORIAL STEP: #{step[:title]}"
      puts "=" * 80
      puts step[:content]
      puts "=" * 80
      puts "\n"
      
      # Display current story
      puts "-" * 80
      puts "Story #{story[:number]}: #{story[:title]}"
      puts "-" * 80
      puts story[:content]
      puts "-" * 80
      print "\nDoes the learner know enough by this step to implement this story? [y/n]: "
      
      answer = gets.chomp.downcase
      
      if answer == 'y'
        results[step[:title]].add(story)
        puts "✓ Added Story #{story[:number]} to '#{step[:title]}'"
        story_index += 1
        puts ""
      else
        puts "→ Moving to next tutorial step...\n"
        break
      end
    end
  end
  
  # Handle unallocated stories
  if story_index < stories.length
    results[:unallocated] = Set.new
    while story_index < stories.length
      results[:unallocated].add(stories[story_index])
      story_index += 1
    end
  end
  
  results
end

# Pretty print results
def print_results(results)
  puts "\n\n"
  puts "=" * 80
  puts "FINAL MAPPING RESULTS"
  puts "=" * 80
  
  results.each do |step_title, stories|
    puts "\n### #{step_title}"
    
    if stories.empty?
      puts "  (No stories)"
    else
      stories.to_a.sort_by { |s| s[:number] }.each do |story|
        puts "  - Story #{story[:number]}: #{story[:title]}"
      end
    end
  end
  
  # Summary
  puts "\n" + "=" * 80
  puts "SUMMARY"
  puts "=" * 80
  total_allocated = results.reject { |k, _| k == :unallocated }.values.sum(&:size)
  total_unallocated = results[:unallocated]&.size || 0
  puts "Total stories allocated: #{total_allocated}"
  puts "Total stories unallocated: #{total_unallocated}"
end

# Main execution
if __FILE__ == $0
  stories_file = "/Users/kerrick/Developer/ratatui_ruby-tea/doc/contributors/specs/file_browser_stories.md"
  tutorial_dir = "/Users/kerrick/Developer/ratatui_ruby-tea/doc/tutorial"
  
  puts "Parsing stories from #{stories_file}..."
  stories = parse_stories(stories_file)
  puts "Found #{stories.length} stories"
  
  puts "\nParsing tutorial steps from #{tutorial_dir}..."
  tutorial_steps = parse_tutorial_steps(tutorial_dir)
  puts "Found #{tutorial_steps.length} tutorial steps"
  
  puts "\n" + "=" * 80
  puts "Starting interactive mapping..."
  puts "=" * 80
  puts "Instructions: For each story, answer 'y' if the learner has enough"
  puts "knowledge from the current tutorial step to implement it, 'n' otherwise."
  puts "=" * 80
  
  results = run_interactive_mapping(stories, tutorial_steps)
  print_results(results)
end
