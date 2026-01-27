<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# File Browser User Stories

**Project:** File Browser TUI Application  
**Format:** Mike Cohn's User Stories Applied (2004)  
**Approach:** Incremental delivery of value, starting with walking skeleton

---

## Story -4: Project Setup

**As a** developer  
**I want to** set up a new Ruby project with proper dependencies  
**So that** I have a foundation to build the file browser

### Acceptance Criteria
- Project directory exists with proper structure
- Dependencies are installed
- Application can be started without errors

### Notes
- Absolute starting point for the tutorial
- Establishes project foundation

---

## Story -3: Hello World + Quit

**As a** terminal user  
**I want to** launch a minimal TUI application that I can quit  
**So that** I can verify the application runs

### Acceptance Criteria
- Application displays "Hello, File Browser!" text
- Application displays "Press 'q' to quit" instruction
- Pressing 'q' or Ctrl+C exits the application cleanly

### Notes
- First runnable TUI application
- Demonstrates basic rendering and quit functionality

---

## Story -2: Static File List

**As a** terminal user  
**I want to** see a list of example files displayed  
**So that** I can understand the basic file browser interface

### Acceptance Criteria
- Application displays a list of example filenames
- One file is visually highlighted
- Application can be quit with 'q'

### Notes
- Uses hardcoded example data ("README.md", "Gemfile", "lib/", "test/")
- No navigation yet - always highlights first item

---

## Story -1: Arrow Key Navigation

**As a** terminal user  
**I want to** navigate through the file list with arrow keys  
**So that** I can select different files

### Acceptance Criteria
- Up/Down arrow keys change which file is highlighted
- 'j'/'k' vim keys also work for navigation
- Selection wraps at top/bottom of list
- Visual highlight follows selection

### Notes
- Still using hardcoded file list
- Adds interactive navigation

---

## Story 0: Real Files

**As a** terminal user  
**I want to** see my actual files instead of example data  
**So that** the file browser is useful for real work

### Acceptance Criteria
- Application shows actual files from the current directory
- File list reflects real filesystem contents
- Can navigate through real files with arrow keys
- All previous keyboard shortcuts still work

### Notes
- **Critical transition** - from example data to real filesystem
- Transforms toy example into functional tool
- After this story, Story 1 is COMPLETE

---

## Story 1: Walking Skeleton - View Current Directory

_Note: If you started with negative-numbered stories, this happened in Story 0._

**As a** terminal user  
**I want to** see a list of files in my current directory  
**So that** I know what files exist without using `ls`

### Acceptance Criteria
- Application launches and displays current directory path
- Files and directories are listed with names
- Application can be quit with `q` or Ctrl+C
- Basic TUI layout renders (single pane, no borders yet)

### Notes
- This is our tracer bullet - proves we can render TUI and read filesystem
- No navigation, no preview, just a static list
- Tests the entire stack: TUI rendering, file I/O, event handling

---

## Story 2: Basic Navigation - Move Through List

_Note: If you started with negative-numbered stories, this happened in Story 0._

**As a** terminal user  
**I want to** move up and down through the file list with arrow keys  
**So that** I can select different files

### Acceptance Criteria
- Arrow up/down keys move selection
- Selected item is visually highlighted
- Selection wraps at top/bottom of list
- `j`/`k` vim keys also work
- `Home`/`g` jumps to first item
- `End`/`G` jumps to last item

### Notes
- Introduces state management (current selection index)
- Introduces keyboard event handling
- Still single pane, but now interactive

---

## Story 3: Enter Directories

**As a** terminal user  
**I want to** press Enter on a directory to navigate into it  
**So that** I can explore subdirectories

### Acceptance Criteria
- Enter key on directory changes current directory
- File list updates to show new directory contents
- Current path display updates
- Enter on regular file does nothing (for now)
- Backspace or `←`/`h` goes to parent directory
- `→`/`l` enters directory (same as Enter)
- `~` jumps to home directory
- `/` jumps to root directory
- `R` refreshes current view

### Notes
- Introduces directory traversal
- Introduces path state management
- Introduces distinguishing files from directories

---

## Story 4: Three-Pane Layout

**As a** terminal user  
**I want to** see a directory tree, file list, and preview pane  
**So that** I have better context while browsing

### Acceptance Criteria
- Screen divided into three panes with borders
- Left pane shows directory tree (current path only, not expanded yet)
- Center pane shows file list (existing functionality)
- Right pane shows "Preview" placeholder
- Title bar shows application name
- Status bar shows current path and item count

### Notes
- Major UI refactoring
- Introduces layout management
- Introduces box-drawing characters
- Preview pane is empty for now

---

## Story 5: File Metadata Display

**As a** terminal user  
**I want to** see file sizes and modification dates  
**So that** I can make informed decisions about files

### Acceptance Criteria
- File list shows: name, size, modification date
- Sizes displayed in human-readable format (KB, MB, GB)
- Dates displayed in consistent format
- Columns aligned properly
- Directories show "-" for size

### Notes
- Introduces file metadata reading
- Introduces formatting utilities
- Introduces column layout

---

## Story 6: Text File Preview

**As a** terminal user  
**I want to** see a preview of text files in the preview pane  
**So that** I can verify file contents before opening

### Acceptance Criteria
- When text file is selected, preview pane shows first ~20 lines
- Preview updates as selection changes
- Binary files show "Binary file" message
- Preview pane scrolls if content is long
- File type is detected (text vs binary)
- `Space` toggles preview pane visibility
- `PgUp`/`PgDn` pages through preview content (when focused)

### Notes
- Introduces file reading
- Introduces text detection
- Introduces preview scrolling
- Limit to first 1000 lines for performance

---

## Story 7: Directory Tree Expansion

**As a** terminal user  
**I want to** expand and collapse directories in the tree pane  
**So that** I can see the directory structure at a glance

### Acceptance Criteria
- Directories show expand/collapse indicator (▶/▼)
- Arrow right/left or `l`/`h` expands/collapses
- Tree shows nested structure with indentation
- Expanded state persists during session
- Tree scrolls if structure is large

### Notes
- Introduces tree data structure
- Introduces recursive directory reading
- Introduces tree rendering logic
- Major complexity increase

---

## Story 8: Pane Focus Switching

**As a** terminal user  
**I want to** switch focus between panes with Tab  
**So that** I can navigate the tree or scroll the preview

### Acceptance Criteria
- Tab key cycles focus: tree → list → preview → tree
- Active pane has visual indicator (highlighted border)
- Keyboard shortcuts work in context of focused pane
- Arrow keys navigate within focused pane
- `PgUp`/`PgDn` pages by visible height

### Notes
- Introduces focus management
- Introduces context-sensitive key handling
- Introduces cached layout pattern (store pane dimensions for dynamic paging)
- Preview pane becomes interactive (scrollable)

---

## Story 9: Sort Files

**As a** terminal user  
**I want to** sort files by name, size, or date  
**So that** I can find files more easily

### Acceptance Criteria
- `s` key cycles through sort options
- Sort options: name (asc/desc), size (asc/desc), date (asc/desc), type
- Status bar shows current sort order
- Directories can be sorted first or mixed with files
- Sort persists during session

### Notes
- Introduces sorting logic
- Introduces sort state management
- Introduces status bar messaging

---

## Story 10: Filter Files by Name

**As a** terminal user  
**I want to** filter the file list by typing a pattern  
**So that** I can quickly find specific files

### Acceptance Criteria
- `f` key opens filter input
- User types pattern (supports * and ? wildcards)
- File list updates to show only matching items
- Status bar shows filter pattern and match count
- Esc clears filter
- Filter is case-insensitive

### Notes
- Introduces text input mode
- Introduces filtering logic
- Introduces wildcard matching
- Introduces mode switching (normal vs input)

---

## Story 11: Toggle Hidden Files

**As a** terminal user  
**I want to** show or hide files starting with `.`  
**So that** I can reduce clutter or see configuration files

### Acceptance Criteria
- `.` key toggles hidden file visibility
- Hidden files are dimmed/grayed when shown
- Status bar indicates when hidden files are shown
- Preference persists during session
- Default is to hide hidden files

### Notes
- Introduces filtering by file attribute
- Introduces visual styling variations
- Simple toggle state

---

## Story 12: Create New Directory

**As a** terminal user  
**I want to** create a new directory  
**So that** I can organize files

### Acceptance Criteria
- `n` key prompts for directory name
- User types name and presses Enter to create
- Directory is created in current location
- File list refreshes to show new directory
- Error message shown if creation fails
- Esc cancels operation

### Notes
- First file operation
- Introduces filesystem mutation
- Introduces input validation
- Introduces error handling

---

## Story 13: Rename Files and Directories

**As a** terminal user  
**I want to** rename the selected file or directory  
**So that** I can fix typos or improve organization

### Acceptance Criteria
- `r` key prompts for new name
- Input pre-populated with current name
- Enter confirms rename
- File list updates to show new name
- Error shown if name conflicts or is invalid
- Esc cancels operation

### Notes
- Introduces pre-populated input
- Introduces conflict detection
- Introduces name validation

---

## Story 14: Delete Files and Directories

**As a** terminal user  
**I want to** delete the selected file or directory  
**So that** I can remove unwanted items

### Acceptance Criteria
- `d` key prompts for confirmation
- Confirmation dialog shows item name and size
- `Y` confirms deletion, `N` cancels
- Warning message for directory deletion
- File list refreshes after deletion
- Error shown if deletion fails

### Notes
- Introduces confirmation dialogs
- Introduces destructive operations
- Introduces modal UI elements
- Critical to get right - no undo!

---

## Story 15: Copy Files and Directories

**As a** terminal user  
**I want to** copy files to another location  
**So that** I can duplicate content

### Acceptance Criteria
- `c` key prompts for destination path
- User types destination and presses Enter
- File/directory copied to destination
- Progress indicator for large operations
- Error shown if copy fails
- File list refreshes if copying to current directory

### Notes
- Introduces path input
- Introduces progress indicators
- Introduces recursive directory copying
- Performance considerations for large files

---

## Story 16: Move Files and Directories

**As a** terminal user  
**I want to** move files to another location  
**So that** I can reorganize my filesystem

### Acceptance Criteria
- `m` key prompts for destination path
- User types destination and presses Enter
- File/directory moved to destination
- File list refreshes to remove moved item
- Error shown if move fails
- Handles cross-filesystem moves

### Notes
- Similar to copy but removes source
- May need to fall back to copy+delete for cross-filesystem
- Introduces atomic operation handling

---

## Story 17: Open in External Editor

**As a** terminal user  
**I want to** open the selected file in my $EDITOR  
**So that** I can edit files

### Acceptance Criteria
- `e` key opens file in $EDITOR
- File browser suspends while editor runs
- File browser resumes when editor closes
- File list refreshes to show any changes
- Error shown if $EDITOR not set or fails

### Notes
- Introduces external process spawning
- Introduces suspend/resume cycle
- Introduces environment variable reading
- Tests integration with external tools

---

## Story 18: Help Overlay

**As a** terminal user  
**I want to** see a list of keyboard shortcuts  
**So that** I can learn how to use the application

### Acceptance Criteria
- `?` key shows help overlay
- Help displays all keyboard shortcuts organized by category
- Help overlay is modal (blocks other input)
- Any key closes help overlay
- Help is scrollable if content is long

### Notes
- Introduces modal overlays
- Introduces help content management
- Critical for discoverability

---

## Story 19: Error Handling and Messages

**As a** terminal user  
**I want to** see clear error messages when operations fail  
**So that** I understand what went wrong and how to fix it

### Acceptance Criteria
- Permission errors show specific message and suggestion
- File not found errors are handled gracefully
- Invalid input shows validation errors
- Errors displayed in status bar or dialog
- Errors auto-dismiss after 5 seconds or on next action
- Error messages are actionable, not generic

### Notes
- Introduces comprehensive error handling
- Introduces error message system
- Introduces auto-dismiss timers
- Polish pass on all error paths

---

## Story 20: Mouse Support

**As a** terminal user with mouse-enabled terminal  
**I want to** use my mouse to click and scroll  
**So that** I have an alternative to keyboard navigation

### Acceptance Criteria
- Click on pane to focus it
- Click on item to select it
- Click on expand/collapse indicators
- Mouse wheel scrolls in focused pane
- All functionality remains keyboard-accessible
- Mouse events don't break text selection

### Notes
- Optional enhancement
- Introduces mouse event handling
- Must not compromise keyboard experience
- Terminal capability detection

---

## Story 21: Terminal Resize Handling

**As a** terminal user  
**I want to** resize my terminal window  
**So that** the application adapts to the new size

### Acceptance Criteria
- Application detects terminal resize events
- Layout adjusts proportionally to new size
- Content reflows to fit new dimensions
- Selection and scroll position preserved
- No flickering during resize
- Graceful degradation at small sizes (hide panes)

### Notes
- Introduces resize event handling
- Introduces responsive layout logic
- Introduces graceful degradation
- Performance critical - must be smooth

---

## Story 22: Loading States for Large Directories

**As a** terminal user  
**I want to** see a loading indicator for large directories  
**So that** I know the application is working

### Acceptance Criteria
- Loading indicator shown when reading large directories
- Spinner animation with item count
- User can cancel loading with Esc
- Partial results shown as they load
- Performance remains responsive during load

### Notes
- Introduces async loading
- Introduces loading indicators
- Introduces cancellation
- Performance optimization for 10,000+ files

---

## Story 23: Visual Polish and Theming

**As a** terminal user  
**I want to** see a polished, professional interface  
**So that** the application is pleasant to use

### Acceptance Criteria
- Consistent color scheme throughout:
  - Directories: Blue (bold)
  - Regular files: Default terminal color
  - Executable files: Green
  - Hidden files: Dim/gray when shown
  - Selected item: Inverted colors or highlighted background
  - Error messages: Red
  - Success messages: Green
  - Information messages: Yellow
- File type icons (📁 📄 🔗) where appropriate
- Smooth animations for state transitions
- Proper spacing and alignment
- Visual hierarchy clear
- Works in both light and dark terminal themes

### Notes
- Polish pass on all UI elements
- Introduces color management
- Introduces Unicode symbols
- Introduces animation system
- Final aesthetic improvements
- Implements all color requirements from specification section 2.2

---

## Story 24: Performance Optimization

**As a** terminal user  
**I want to** experience fast, responsive performance  
**So that** the application doesn't slow me down

### Acceptance Criteria
- Startup time under 500ms
- Keyboard input response under 50ms
- Directory listing under 200ms for typical directories
- Preview rendering under 100ms
- No memory leaks during extended use
- Efficient rendering (only redraw changed areas)

### Notes
- Performance profiling and optimization
- Introduces benchmarking
- Introduces efficient rendering strategies
- May require caching and memoization

---

## Story 25: Comprehensive Test Coverage

**As a** developer  
**I want to** have comprehensive test coverage  
**So that** I can refactor confidently

### Acceptance Criteria
- Unit tests for all core logic
- Integration tests for file operations
- UI tests for rendering and interaction
- Test coverage above 80%
- Tests run in CI
- Tests are fast (under 5 seconds total)
- All public methods have YARD documentation
- README with architecture overview
- CONTRIBUTING guide with development setup

### Notes
- Testing infrastructure
- Introduces test helpers
- Introduces mocking for filesystem
- Critical for maintainability
- Includes code documentation requirements from specification section 6.5

---

## Story 26: Configurable Color Schemes

**As a** user with color blindness  
**I want to** configure the color scheme  
**So that** I can distinguish different file types

### Acceptance Criteria
- Configuration file for color preferences (~/.config/file_browser/colors.yml)
- Multiple built-in themes:
  - Default (current colors)
  - High contrast (black/white with bold)
  - Colorblind-friendly (uses patterns + colors)
  - Monochrome (no colors, uses bold/dim/underline)
- Colors can be customized per file type
- Theme selection persists between sessions
- Theme can be changed via command-line flag
- Preview of theme before applying

### Notes
- Addresses specification section 2.3 (Accessibility)
- Introduces configuration file system
- May be deferred to 1.1 release
- Should validate color values

---

## Story 27: Configuration Management

**As a** power user  
**I want to** save my preferences  
**So that** my settings persist between sessions

### Acceptance Criteria
- Config file in ~/.config/file_browser/config.yml
- Configurable preferences:
  - Default sort order
  - Hidden files visibility default
  - Color scheme/theme
  - Default editor (overrides $EDITOR)
  - Pane width ratios
  - Mouse support enabled/disabled
- Config file created on first run with defaults
- Invalid config handled gracefully with warnings
- Command-line flags override config file
- `--config-path` flag to use alternate config location

### Notes
- Addresses specification section 5.3 (Configuration)
- Introduces YAML parsing
- May be deferred to 1.1 release
- Should have schema validation

---

## Future Enhancements (Deferred)

**As a** product owner  
**I want to** track future enhancement ideas  
**So that** we have a roadmap for post-1.0 releases

### Deferred Features

The following features are explicitly deferred to future versions:

- **Bookmarks/Favorites:** Quick access to frequently used directories
- **Multi-file Selection:** Select multiple files with Space, operate on batch
- **File Content Search:** Integrate grep for searching within files
- **Git Integration:** Show file status (modified, untracked, etc.)
- **Trash/Recycle Bin:** Soft delete instead of permanent deletion
- **Dual-Pane Mode:** Side-by-side panes for easier copying
- **Archive Preview:** View contents of zip, tar, etc.
- **Image Preview:** ASCII art representation of images
- **Custom File Type Icons:** User-defined icons for extensions
- **External Tool Integration:** Diff, merge, etc.
- **Plugins/Extensions:** Allow third-party extensions
- **Remote Filesystem Support:** SFTP, S3, etc.

### Notes
- These align with specification section 9 (Future Enhancements)
- Not stories yet - just ideas for future planning
- May become stories in 1.1, 1.2, etc.
- Community feedback will help prioritize

---

## Implementation Notes

### Story Sequencing

Stories are ordered to:
1. **Start with tutorial foundation** (Stories -4 to 0) - teaches Rooibos concepts incrementally
2. **Build walking skeleton** (Story 1) - proves end-to-end integration with real files
3. **Build core navigation** (Stories 2-3) - essential functionality
4. **Add UI structure** (Stories 4-6) - professional appearance
5. **Enable exploration** (Stories 7-8) - power user features
6. **Add organization** (Stories 9-11) - finding and filtering
7. **Enable modification** (Stories 12-17) - file operations
8. **Improve usability** (Stories 18-19) - help and errors
9. **Add enhancements** (Stories 20-21) - mouse and resize
10. **Optimize and polish** (Stories 22-24) - performance and aesthetics
11. **Ensure quality** (Story 25) - testing and documentation
12. **Advanced features** (Stories 26-27) - color schemes and configuration
13. **Future planning** - deferred enhancements

### Story Sizing

- Stories -4 to -1: Extra Small (tutorial foundation)
- Story 0: Small (critical transition)
- Stories 1-3: Small
- Stories 4-8: Medium
- Stories 9-17: Small-Medium
- Stories 18-21: Medium
- Stories 22-24: Large
- Story 25: Ongoing (parallel with all stories)
- Story 26: Medium
- Story 27: Small-Medium

### Dependencies

- Story -3 depends on Story -4 (need project setup)
- Story -2 depends on Story -3 (need runnable app)
- Story -1 depends on Story -2 (need model and state)
- Story 0 depends on Story -1 (need navigation working with fake data)
- Story 1 depends on Story 0 (Story 0 completes Story 1)
- Story 4 depends on Stories 1-3 (need basic functionality before layout)
- Story 6 depends on Story 4 (need preview pane)
- Story 8 depends on Story 4 (need multiple panes)
- Stories 12-17 can be done in any order after Story 11
- Story 21 depends on Story 4 (need layout to resize)
- Story 24 should be done after most features complete