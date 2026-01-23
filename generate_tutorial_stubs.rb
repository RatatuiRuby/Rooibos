#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

# Parse tutorial structure from documentation_plan.md
TUTORIAL_FILES = {
  "index.md" => { title: "Tutorial: Build a File Browser", story: nil },
  "01_project_setup.md" => { title: "Project Setup", story: "-4" },
  "02_hello_world.md" => { title: "Hello World", story: "-3" },
  "03_static_file_list.md" => { title: "Static File List", story: "-2" },
  "04_arrow_navigation.md" => { title: "Arrow Navigation", story: "-1" },
  "05_real_files.md" => { title: "Real Files", story: "0" },
  "06_safe_refactoring.md" => { title: "Safe Refactoring", story: "4a" },
  "07_red_first_tdd.md" => { title: "Red-First TDD", story: "4b" },
  "08_file_metadata.md" => { title: "File Metadata", story: "5" },
  "09_text_preview.md" => { title: "Text Preview", story: "6" },
  "10_directory_tree.md" => { title: "Directory Tree", story: "7" },
  "11_pane_focus.md" => { title: "Pane Focus", story: "8" },
  "12_sorting.md" => { title: "Sorting", story: "9" },
  "13_filtering.md" => { title: "Filtering", story: "10" },
  "14_toggle_hidden.md" => { title: "Toggle Hidden Files", story: "11" },
  "15_text_input_widget.md" => { title: "Text Input Widget", story: "12" },
  "16_rename_files.md" => { title: "Rename Files", story: "13" },
  "17_confirmation_dialogs.md" => { title: "Confirmation Dialogs", story: "14" },
  "18_progress_indicators.md" => { title: "Progress Indicators", story: "15" },
  "19_atomic_operations.md" => { title: "Atomic Operations", story: "16" },
  "20_external_editor.md" => { title: "External Editor", story: "17" },
  "21_modal_overlays.md" => { title: "Modal Overlays", story: "18" },
  "22_error_handling.md" => { title: "Error Handling", story: "19" },
  "23_terminal_capabilities.md" => { title: "Terminal Capabilities", story: "23" },
  "24_mouse_events.md" => { title: "Mouse Events", story: "20" },
  "25_resize_events.md" => { title: "Resize Events", story: "21" },
  "26_loading_states.md" => { title: "Loading States", story: "22" },
  "27_performance.md" => { title: "Performance", story: "24" },
  "28_color_schemes.md" => { title: "Color Schemes", story: "26" },
  "29_configuration.md" => { title: "Configuration", story: "27" },
  "30_going_further.md" => { title: "Going Further", story: nil },
}

# Parse stories from file_browser_stories.md
stories_content = File.read("doc/contributors/specs/file_browser_stories.md")

# Extract each story
stories = {}
current_story = nil
current_content = []

stories_content.each_line do |line|
  if line =~ /^## Story (-?\d+[ab]?): (.+)$/
    # Save previous story
    if current_story
      stories[current_story] = current_content.join
    end

    current_story = $1
    current_content = [line]
  elsif current_story
    current_content << line

    # Stop at the next story or end of stories section
    if line =~ /^---$/ && current_content.size > 5
      # Check if next section is another story or implementation notes
      peek_ahead = stories_content.lines[stories_content.lines.index(line) + 1]
      if peek_ahead && !peek_ahead.start_with?("## Story")
        stories[current_story] = current_content.join
        break if peek_ahead.start_with?("## Implementation Notes")
      end
    end
  end
end

# Save last story
stories[current_story] = current_content.join if current_story

# Create tutorial directory
FileUtils.mkdir_p("doc/tutorial")

# Generate stub files
TUTORIAL_FILES.each do |filename, meta|
  filepath = "doc/tutorial/#{filename}"

  # Determine previous/next files
  files_list = TUTORIAL_FILES.keys
  current_index = files_list.index(filename)
  prev_file = (current_index > 0) ? files_list[current_index - 1] : nil
  next_file = (current_index < files_list.size - 1) ? files_list[current_index + 1] : nil

  prev_title = prev_file ? TUTORIAL_FILES[prev_file][:title] : nil
  next_title = next_file ? TUTORIAL_FILES[next_file][:title] : nil

  # Get story content if applicable
  story_section = ""
  if meta[:story]
    story_key = meta[:story]
    if stories[story_key]
      story_section = "\n## User Stories\n\n#{stories[story_key]}\n"
    end
  end

  # Generate stub content
  content = <<~MARKDOWN
    <!--
      SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
      SPDX-License-Identifier: CC-BY-SA-4.0
    -->

    # #{meta[:title]}


    By the end of this guide, you will:

    - TODO: Write learning objectives

    > ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).
    #{story_section}
    ---

    #{prev_file ? "[**Previous:** #{prev_title}](./#{prev_file})" : ''} | #{next_file ? "[**Next:** #{next_title}](./#{next_file})" : ''}
  MARKDOWN

  File.write(filepath, content)
  puts "Created #{filepath}"
end

puts "\nDone! Created #{TUTORIAL_FILES.size} tutorial stub files."
