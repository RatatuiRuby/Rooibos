<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# File Browser Application Specification

**Version:** 1.0  
**Status:** Final  
**Date:** 2026-01-22  
**Author:** Business Analysis Team

## Executive Summary

This document specifies the requirements for a professional-grade terminal-based file browser application. The application provides efficient keyboard-driven navigation and file management capabilities optimized for terminal users who value speed, clarity, and reliability.

## 1. Purpose and Scope

### 1.1 Purpose

The File Browser enables users to navigate directory structures, view file metadata, preview file contents, and perform common file operations entirely within a terminal interface.

### 1.2 Target Users

- Software developers navigating project directories
- System administrators managing server filesystems
- Power users who prefer keyboard-driven workflows
- Anyone working in terminal-only environments (SSH sessions, containers)

### 1.3 Scope

**In Scope:**
- Directory tree navigation
- File and directory listing with metadata
- Text file preview
- File and directory operations (create, rename, delete, copy, move)
- Search and filtering
- Keyboard-driven interface
- Error handling and user feedback

**Out of Scope:**
- File editing (users should use their preferred editor)
- Binary file manipulation
- Network filesystem operations
- Archive extraction/creation
- File permissions modification
- Symbolic link creation

## 2. User Interface Requirements

### 2.1 Layout

The application uses a three-pane layout optimized for terminal displays:

**Left Pane: Directory Tree (25% width)**
- Hierarchical view of directory structure
- Expandable/collapsible directories
- Visual indicators for directory state (expanded/collapsed)
- Current location indicator

**Center Pane: File List (40% width)**
- Detailed listing of current directory contents
- Sortable columns (name, size, modified date, type)
- Visual distinction between files and directories
- Selection indicator

**Right Pane: Preview (35% width)**
- File content preview for text files
- Metadata display for all file types
- Scrollable content area

**Status Bar (Bottom)**
- Current path
- Item count (files/directories)
- Selected item information
- Operation status messages

**Path Bar (Top)**
- Current path
- Help hint

### 2.2 Visual Design

**Color Scheme:**
- Directories: Blue (bold)
- Regular files: Default terminal color
- Executable files: Green
- Hidden files: Dim/gray
- Selected item: Inverted colors or highlighted background
- Error messages: Red
- Success messages: Green
- Information messages: Yellow

**Typography:**
- Monospace font (terminal default)
- Box-drawing characters for tree structure
- Unicode symbols for file type indicators (📁 📄 🔗)

**Spacing:**
- Single-line spacing between items
- Borders around content panes using box-drawing characters
- Path bar and status bar are unbordered text rows
- Padding: 1 space inside pane borders

### 2.3 Accessibility

- High contrast color scheme
- Clear visual hierarchy
- Keyboard-only operation (no mouse required)
- Screen reader compatible (plain text output)
- Configurable color scheme for color blindness

## 3. Functional Requirements

### 3.1 Navigation

**FR-NAV-001: Directory Tree Navigation**
- User can expand/collapse directories in tree pane
- User can navigate up/down through tree items
- User can jump to parent directory
- User can jump to home directory
- User can jump to root directory

**FR-NAV-002: File List Navigation**
- User can navigate up/down through file list
- User can page up/down through long lists
- User can jump to first/last item
- User can navigate to parent directory (..)

**FR-NAV-003: Preview Pane Scrolling**
- User can scroll preview content up/down
- User can page up/down in preview
- User can jump to top/bottom of preview

**FR-NAV-004: Focus Management**
- User can switch focus between panes (tree, list, preview)
- Active pane is visually indicated
- Keyboard shortcuts work in context of active pane

### 3.2 File Operations

**FR-FILE-001: View File Information**
- Display file name, size, modification date, permissions
- Display file type (regular, directory, symlink)
- Display line count for text files
- Display human-readable file sizes (KB, MB, GB)

**FR-FILE-002: Preview Text Files**
- Display first N lines of text files in preview pane
- Support UTF-8 encoded files
- Handle large files gracefully (don't load entire file)
- Display "Binary file" message for non-text files

**FR-FILE-003: Create Directory**
- User can create new directory in current location
- Prompt for directory name
- Validate directory name (no invalid characters)
- Display success/error message
- Refresh view to show new directory

**FR-FILE-004: Rename File/Directory**
- User can rename selected file or directory
- Pre-populate input with current name
- Validate new name (no invalid characters, no conflicts)
- Display success/error message
- Update view to reflect new name

**FR-FILE-005: Delete File/Directory**
- User can delete selected file or directory
- Require confirmation before deletion
- Display clear warning for directory deletion
- Display success/error message
- Refresh view after deletion

**FR-FILE-006: Copy File/Directory**
- User can copy selected file or directory
- Prompt for destination path
- Validate destination (exists, writable)
- Display progress for large operations
- Display success/error message

**FR-FILE-007: Move File/Directory**
- User can move selected file or directory
- Prompt for destination path
- Validate destination (exists, writable, no conflicts)
- Display success/error message
- Update view to reflect new location

**FR-FILE-008: Open File in External Editor**
- User can open selected file in $EDITOR
- Suspend file browser while editor is running
- Resume file browser when editor closes
- Refresh view to show any changes

### 3.3 Search and Filtering

**FR-SEARCH-001: Filter by Name**
- User can enter filter pattern
- Display only items matching pattern
- Support wildcards (* and ?)
- Case-insensitive matching
- Clear filter to show all items

**FR-SEARCH-002: Show/Hide Hidden Files**
- User can toggle visibility of hidden files (starting with .)
- Persist preference during session
- Visual indicator of current filter state

**FR-SEARCH-003: Sort Options**
- User can sort by name (ascending/descending)
- User can sort by size (ascending/descending)
- User can sort by modification date (ascending/descending)
- User can sort by type (directories first/last)
- Visual indicator of current sort order

### 3.4 Error Handling

**FR-ERROR-001: Permission Errors**
- Display clear message when directory cannot be read
- Display clear message when file cannot be accessed
- Suggest resolution (check permissions)
- Allow user to continue browsing accessible areas

**FR-ERROR-002: File System Errors**
- Handle missing files gracefully (deleted externally)
- Handle renamed files gracefully
- Handle full disk scenarios
- Display specific error messages, not generic failures

**FR-ERROR-003: Invalid Input**
- Validate user input before operations
- Display specific validation errors
- Highlight invalid characters in input
- Provide examples of valid input

### 3.5 Performance

**FR-PERF-001: Large Directories**
- Handle directories with 10,000+ items
- Use pagination or virtual scrolling
- Maintain responsive UI during loading
- Display loading indicator for slow operations

**FR-PERF-002: Large Files**
- Preview large files without loading entire content
- Limit preview to first 1,000 lines
- Display file size warning for very large files
- Maintain responsive UI during preview loading

**FR-PERF-003: Startup Time**
- Launch in under 500ms on modern hardware
- Initial directory scan in under 200ms
- Responsive to user input immediately

## 4. Event Handling

### 4.1 Keyboard Shortcuts

#### 4.1.1 Navigation Shortcuts

| Key | Action |
|-----|--------|
| `↑` / `k` | Move selection up |
| `↓` / `j` | Move selection down |
| `←` / `h` | Collapse directory or move to parent |
| `→` / `l` | Expand directory or enter directory |
| `PgUp` | Page up |
| `PgDn` | Page down |
| `Home` / `g` | Jump to first item |
| `End` / `G` | Jump to last item |
| `Backspace` | Go to parent directory |
| `~` | Go to home directory |
| `/` | Go to root directory |
| `Tab` | Switch focus between panes |

#### 4.1.2 Operation Shortcuts

| Key | Action |
|-----|--------|
| `Enter` | Open file in editor or enter directory |
| `Space` | Toggle preview pane |
| `n` | Create new directory |
| `r` | Rename selected item |
| `d` | Delete selected item |
| `c` | Copy selected item |
| `m` | Move selected item |
| `e` | Open in external editor |
| `f` | Filter by name |
| `.` | Toggle hidden files |
| `s` | Cycle sort options |
| `R` | Refresh current view |
| `?` | Show help overlay |
| `q` / `Ctrl+C` | Quit application |

#### 4.1.3 Preview Pane Shortcuts (when focused)

| Key | Action |
|-----|--------|
| `↑` / `k` | Scroll preview up |
| `↓` / `j` | Scroll preview down |
| `PgUp` | Page up in preview |
| `PgDn` | Page down in preview |
| `Home` / `g` | Jump to top of preview |
| `End` / `G` | Jump to bottom of preview |

### 4.2 Mouse Events

The application provides optional mouse support for users whose terminals support mouse events. All functionality remains fully accessible via keyboard.

**EV-MOUSE-001: Pane Focus**
- User can click on a pane to focus it
- Visual feedback indicates which pane has focus
- Click events do not interfere with terminal text selection

**EV-MOUSE-002: Item Selection**
- User can click on an item in the file list to select it
- User can click on a directory in the tree to select it
- Selected item is highlighted immediately
- Preview updates to show selected item

**EV-MOUSE-003: Directory Expansion**
- User can click on expand/collapse indicator (▶/▼) to toggle directory
- User can double-click on directory name to expand/collapse
- Visual feedback shows expansion state change

**EV-MOUSE-004: Scrolling**
- User can scroll with mouse wheel in any pane
- Scroll wheel moves selection in file list and tree
- Scroll wheel scrolls content in preview pane
- Scroll speed is configurable (default: 3 lines per wheel event)

**EV-MOUSE-005: Button Actions**
- User can click on buttons in dialogs (Yes/No, OK/Cancel)
- Hover state provides visual feedback
- Click activates button action

**EV-MOUSE-006: Drag and Drop (Future Enhancement)**
- Explicitly deferred to future version
- Would enable drag files to move/copy between directories

### 4.3 Responsive Design with Resize Events

The application must gracefully handle terminal resize events and adapt the layout dynamically.

**EV-RESIZE-001: Minimum Size Handling**
- Application must function at minimum terminal size of 80x24
- If terminal is smaller, display warning message
- Suggest increasing terminal size for optimal experience
- Allow user to continue at their own risk

**EV-RESIZE-002: Dynamic Layout Adjustment**
- Pane widths adjust proportionally when terminal width changes
- Pane heights adjust proportionally when terminal height changes
- Maintain 25% / 40% / 35% ratio for panes when possible
- Status bar and path bar always visible

**EV-RESIZE-003: Content Reflow**
- File list reflows to fit new width
- Preview content reflows to fit new width
- Long filenames truncate with ellipsis (...) when space limited
- Column headers adjust to available space

**EV-RESIZE-004: Graceful Degradation**
- At narrow widths (< 120 columns), hide preview pane automatically
- At very narrow widths (< 80 columns), hide tree pane
- Display single-pane file list as fallback
- Restore panes when terminal size increases

**EV-RESIZE-005: Preserve State**
- Current selection remains selected after resize
- Scroll position maintained when possible
- Expanded directories remain expanded
- Active pane focus preserved

**EV-RESIZE-006: Performance**
- Resize events processed within 50ms
- No flickering or visual artifacts during resize
- Smooth transition between layout states
- Debounce rapid resize events (100ms window)

**EV-RESIZE-007: Orientation Changes**
- Handle extreme aspect ratios (very wide or very tall)
- Adjust pane layout for optimal readability
- Maintain usability across all reasonable terminal sizes
- Test with common terminal sizes: 80x24, 120x40, 200x60, 300x100


## 5. Data Requirements

### 5.1 File Metadata

For each file/directory, the application must track:
- Full path
- Name
- Type (file, directory, symlink)
- Size (bytes)
- Modification timestamp
- Permissions (read/write/execute)
- Hidden status (name starts with .)

### 5.2 Application State

The application must maintain:
- Current working directory
- Selected item in file list
- Expanded directories in tree view
- Current sort order
- Current filter pattern
- Hidden files visibility preference
- Active pane focus
- Preview scroll position

### 5.3 Configuration

User preferences (future enhancement):
- Default sort order
- Default hidden files visibility
- Color scheme preference
- Preview pane default state (visible/hidden)
- Default editor command

## 6. Non-Functional Requirements

### 6.1 Performance

- **Response Time:** All keyboard interactions must respond within 50ms
- **Startup Time:** Application must launch in under 500ms
- **Memory Usage:** Must not exceed 50MB for typical usage (1,000 files)
- **CPU Usage:** Must not exceed 5% CPU during idle state

### 6.2 Reliability

- **Error Recovery:** Application must not crash on invalid input
- **Data Integrity:** File operations must be atomic (complete or rollback)
- **Graceful Degradation:** Continue functioning when individual operations fail

### 6.3 Usability

- **Learnability:** New users should accomplish basic navigation within 2 minutes
- **Efficiency:** Expert users should navigate faster than GUI file browsers
- **Error Prevention:** Confirm destructive operations before execution
- **Help Accessibility:** Help overlay accessible via single keystroke

### 6.4 Compatibility

- **Terminal Support:** Must work on any terminal supporting ANSI escape codes
- **Operating Systems:** Must work on macOS, Linux, and BSD systems
- **Ruby Version:** Must work on Ruby 3.0 or newer
- **Terminal Size:** Must adapt to terminal sizes from 80x24 to 300x100

### 6.5 Maintainability

- **Code Quality:** All code must follow Ruby style guidelines
- **Test Coverage:** Minimum 80% test coverage for core functionality
- **Documentation:** All public interfaces must be documented
- **Error Messages:** All error messages must be actionable and specific

## 7. User Scenarios

### 7.1 Scenario: Quick File Lookup

**Actor:** Software Developer  
**Goal:** Find and open a specific file in a project

**Steps:**
1. Launch file browser in project directory
2. Use filter to narrow down files by name
3. Navigate to matching file
4. Press Enter to open in editor
5. Edit file and save
6. Return to file browser (auto-refreshed)

**Expected Outcome:** File located and opened in under 10 seconds

### 7.2 Scenario: Directory Cleanup

**Actor:** System Administrator  
**Goal:** Remove old log files from a directory

**Steps:**
1. Navigate to log directory
2. Sort by modification date (oldest first)
3. Review old files in preview pane
4. Select and delete obsolete files
5. Confirm each deletion
6. Verify cleanup in refreshed view

**Expected Outcome:** Safe, confirmed deletion of unwanted files

### 7.3 Scenario: Project Organization

**Actor:** Developer  
**Goal:** Reorganize project files into new directory structure

**Steps:**
1. Create new directories for organization
2. Move files into appropriate directories
3. Rename files for consistency
4. Verify structure in tree view
5. Confirm all files moved correctly

**Expected Outcome:** Reorganized project with clear structure

### 7.4 Scenario: File Investigation

**Actor:** DevOps Engineer  
**Goal:** Investigate which files changed recently

**Steps:**
1. Navigate to application directory
2. Sort by modification date (newest first)
3. Preview recently modified files
4. Identify unexpected changes
5. Open suspicious files in editor for review

**Expected Outcome:** Quick identification of recent file changes

## 8. Success Criteria

The File Browser application will be considered successful when:

1. **Adoption:** Users choose it over `ls`, `cd`, and GUI file browsers for daily work
2. **Efficiency:** Users navigate filesystems 2x faster than with traditional CLI commands
3. **Reliability:** Zero data loss incidents in production use
4. **Satisfaction:** 90% of users rate the experience as "good" or "excellent"
5. **Performance:** Maintains responsive UI with directories containing 10,000+ files

## 9. Future Enhancements

The following features are explicitly deferred to future versions:

- Bookmarks/favorites for frequently accessed directories
- Multi-file selection and batch operations
- File content search (grep integration)
- Git integration (show file status)
- Trash/recycle bin instead of permanent deletion
- Configurable keyboard shortcuts
- Themes and color scheme customization
- Dual-pane mode for easier file copying
- Archive preview (zip, tar, etc.)
- Image preview (ASCII art representation)
- File type icons and custom colors
- Integration with external tools (diff, etc.)

## 10. Appendix

### 10.1 Terminology

- **Pane:** A distinct rectangular region of the interface
- **Focus:** The currently active pane that receives keyboard input
- **Selection:** The currently highlighted item in a list
- **Preview:** Read-only display of file contents
- **Filter:** Temporary reduction of visible items based on criteria
- **Sort:** Reordering of items based on a property

### 10.2 References

- IBM Common User Access (CUA) Guidelines
- Modern TUI Design Patterns (lazygit, btop, gh-dash)
- Ruby Standard Library: Pathname, File, Dir
- Terminal Capabilities: ANSI escape codes, box-drawing characters

### 10.3 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-22 | Business Analysis Team | Initial specification |

### 10.4 Screenshots

#### Default View - Directory Listing

```
~/projects/myapp                                                      ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files                          │ Preview                    │
│                      │                                │                            │
│ 📁 myapp             │ Name          Size    Modified │ README.md                  │
│ ├─ 📁 app            │ ──────────────────────────────│                            │
│ │  ├─ 📁 models      │ ..            -      -         │ # My Application           │
│ │  ├─ 📁 views       │ 📁 app        -      2024-01-15│                            │
│ │  └─ 📁 controllers │ 📁 config     -      2024-01-10│ A sample application       │
│ ├─ 📁 config         │ 📁 lib        -      2024-01-12│ demonstrating the file     │
│ ├─ 📁 lib            │ 📁 test       -      2024-01-20│ browser capabilities.      │
│ ├─ 📁 test           │ 📄 Gemfile    1.2KB  2024-01-18│                            │
│ ├─ 📄 Gemfile        │ 📄 README.md  3.4KB  2024-01-22│ ## Features                │
│ ├─ 📄 README.md      │ 📄 Rakefile   856B   2024-01-10│                            │
│ └─ 📄 Rakefile       │                                │ - Fast navigation          │
│                      │                                │ - File preview             │
│                      │                                │ - Search and filter        │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
~/projects/myapp │ 8 items (5 dirs, 3 files) │ README.md - 3.4KB
```

#### File Preview - Source Code

```
~/projects/myapp/app/models                                           ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files                          │ Preview                    │
│                      │                                │                            │
│ 📁 myapp             │ Name          Size    Modified │ user.rb                    │
│ ├─ 📁 app            │ ──────────────────────────────│                            │
│ │  ├─ 📁 models ▼    │ ..            -      -         │ class User                 │
│ │  │  ├─ 📄 user.rb  │ 📄 user.rb    2.1KB  2024-01-20│   include ActiveModel::... │
│ │  │  └─ 📄 post.rb  │ 📄 post.rb    1.8KB  2024-01-19│                            │
│ │  ├─ 📁 views       │                                │   attr_accessor :name, ... │
│ │  └─ 📁 controllers │                                │                            │
│ ├─ 📁 config         │                                │   validates :name,         │
│ ├─ 📁 lib            │                                │     presence: true         │
│ ├─ 📁 test           │                                │                            │
│ ├─ 📄 Gemfile        │                                │   validates :email,        │
│ ├─ 📄 README.md      │                                │     presence: true,        │
│ └─ 📄 Rakefile       │                                │     format: { with: URI... │
│                      │                                │                            │
│                      │                                │   def full_name            │
│                      │                                │     "#{first_name} #{la... │
│                      │                                │   end                      │
│                      │                                │ end                        │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
~/projects/myapp/app/models │ 2 items │ user.rb - 2.1KB - 45 lines
```

#### Filter Active - Searching for Files

```
~/projects/myapp                                                      ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files (filter: *test*)         │ Preview                    │
│                      │                                │                            │
│ 📁 myapp             │ Name              Size Modified│ user_test.rb               │
│ ├─ 📁 app            │ ──────────────────────────────│                            │
│ ├─ 📁 config         │ 📁 test           -    2024-..│ require 'test_helper'      │
│ ├─ 📁 lib            │ 📄 user_test.rb   1.5KB 2024-..│                            │
│ ├─ 📁 test ▼         │ 📄 post_test.rb   1.2KB 2024-..│ class UserTest < Minite... │
│ │  ├─ 📄 test_help.. │ 📄 test_helper.rb 892B  2024-..│   def test_valid_user      │
│ │  ├─ 📄 user_test.. │                                │     user = User.new(       │
│ │  └─ 📄 post_test.. │                                │       name: "John Doe",    │
│ ├─ 📄 Gemfile        │                                │       email: "john@exa...  │
│ ├─ 📄 README.md      │                                │     )                      │
│ └─ 📄 Rakefile       │                                │     assert user.valid?     │
│                      │                                │   end                      │
│                      │                                │                            │
│                      │                                │   def test_invalid_wit...  │
│                      │                                │     user = User.new        │
│                      │                                │     refute user.valid?     │
│                      │                                │   end                      │
│                      │                                │ end                        │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
Filter: *test* │ 3 matches │ Press Esc to clear filter
```

#### Delete Confirmation Dialog

```
~/projects/myapp/test                                                 ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files                          │ Preview                    │
│                      │                                │                            │
│ 📁 myapp             │ Name              Size Modified│ old_test.rb                │
│ ├─ 📁 app            │ ──────────────────────────────│                            │
│ ├─ 📁 config         │ ..                -    -       │ # Deprecated test file     │
│ ├─ 📁 lib            │ 📄 test_helper.rb 892B  2024-..│ # TODO: Remove this        │
│ ├─ 📁 test ▼         │ 📄 user_test.rb   1.5KB 2024-..│                            │
│ │  ├─ 📄 test_help.. │ 📄 post_test.rb   1.2KB 2024-..│                            │
│ │  ├─ 📄 user_test.. │ 📄 old_test.rb    456B  2023-..│                            │
│ │  ├─ 📄 post_test.. │    ┌────────────────────────┐ │                            │
│ │  └─ 📄 old_test.rb │    │ Delete File?           │ │                            │
│ ├─ 📄 Gemfile        │    │                        │ │                            │
│ ├─ 📄 README.md      │    │ old_test.rb (456B)     │ │                            │
│ └─ 📄 Rakefile       │    │                        │ │                            │
│                      │    │ This cannot be undone. │ │                            │
│                      │    │                        │ │                            │
│                      │    │  [Y] Yes   [N] No      │ │                            │
│                      │    └────────────────────────┘ │                            │
│                      │                                │                            │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
~/projects/myapp/test │ 4 items │ old_test.rb - 456B
```

#### Help Overlay

```
~/projects/myapp                                                      ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ ┌─ Keyboard Shortcuts ───────┐│ Preview                    │
│                      │ │                             ││                            │
│ 📁 myapp             │ │ Navigation:                 ││ README.md                  │
│ ├─ 📁 app            │ │  ↑/k      Move up           ││                            │
│ ├─ 📁 config         │ │  ↓/j      Move down         ││ # My Application           │
│ ├─ 📁 lib            │ │  ←/h      Collapse/parent   ││                            │
│ ├─ 📁 test           │ │  →/l      Expand/enter      ││ A sample application       │
│ ├─ 📄 Gemfile        │ │  PgUp/Dn  Page up/down      ││ demonstrating the file     │
│ ├─ 📄 README.md      │ │  Home/g   First item        ││ browser capabilities.      │
│ └─ 📄 Rakefile       │ │  End/G    Last item         ││                            │
│                      │ │  Tab      Switch pane       ││ ## Features                │
│                      │ │                             ││                            │
│                      │ │ Operations:                 ││ - Fast navigation          │
│                      │ │  Enter    Open/enter        ││ - File preview             │
│                      │ │  n        New directory     ││ - Search and filter        │
│                      │ │  r        Rename            ││                            │
│                      │ │  d        Delete            ││                            │
│                      │ │  c        Copy              ││                            │
│                      │ │  m        Move              ││                            │
│                      │ │  e        Edit in $EDITOR   ││                            │
│                      │ │  f        Filter            ││                            │
│                      │ │  .        Toggle hidden     ││                            │
│                      │ │  s        Sort options      ││                            │
│                      │ │  R        Refresh           ││                            │
│                      │ │  q/Ctrl+C Quit              ││                            │
│                      │ │                             ││                            │
│                      │ │ Press any key to close...   ││                            │
│                      │ └─────────────────────────────┘│                            │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
~/projects/myapp │ 8 items (5 dirs, 3 files) │ README.md - 3.4KB
```

#### Error State - Permission Denied

```
~/restricted                                                          ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files                          │ Preview                    │
│                      │                                │                            │
│ 📁 home              │ Name          Size    Modified │                            │
│ ├─ 📁 user           │ ──────────────────────────────│                            │
│ ├─ 📁 restricted ▼   │ ..            -      -         │                            │
│ │  └─ 📁 secret      │ 📁 secret     -      -         │                            │
│ └─ 📁 public         │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
⚠ Error: Permission denied - Cannot read directory /restricted/secret
```

#### Loading State - Large Directory

```
~/large-project/node_modules                                          ? for help
┌──────────────────────┬────────────────────────────────┬────────────────────────────┐
│ Directory Tree       │ Files                          │ Preview                    │
│                      │                                │                            │
│ 📁 large-project     │ Name          Size    Modified │                            │
│ ├─ 📁 src            │ ──────────────────────────────│                            │
│ ├─ 📁 node_modules ▼ │ ..            -      -         │                            │
│ │  ├─ 📁 @babel      │                                │                            │
│ │  ├─ 📁 @types      │     Loading directory...       │                            │
│ │  ├─ 📁 eslint      │                                │                            │
│ │  └─ ...            │     ⣾ 1,247 items found        │                            │
│ ├─ 📁 public         │                                │                            │
│ ├─ 📄 package.json   │                                │                            │
│ └─ 📄 README.md      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
│                      │                                │                            │
└──────────────────────┴────────────────────────────────┴────────────────────────────┘
~/large-project/node_modules │ Loading... │ Press Esc to cancel
```

