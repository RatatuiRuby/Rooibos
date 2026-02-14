<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Configuration


By the end of this guide, you will:

- TODO: Write learning objectives

> ⚠️ **This page is a stub.** Help us write it! See the [Documentation Plan](../contributors/documentation_plan.md) and [Style Guide](../contributors/documentation_style.md).

## User Stories

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

---

[**Previous:** Color Schemes](./29_color_schemes.md) | [**Next:** Going Further](./31_going_further.md)
