<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Task: Update Tests and Docs for Runtime Refactoring

## Signature Changes
- [x] Update RBS signatures for new Runtime.run signature
- [x] Add with_argv helper to ratatui_ruby test_helper
- [x] Update Rooibos.run wrapper signature

## Test Updates  
- [x] Update test_fragment_first_api.rb - change fragment: to positional
- [x] Fix argv/env tests to use with_argv/with_env helpers
- [x] Fix all Command.custom tests to use Ractor-shareable callables
- [ ] Fix test_init_triggers_update_before_first_event - still failing
- [ ] Fix test_fragment_first_api_passes_argv_and_env_to_init - ENV hash comparison issue
- [ ] Update test_snapshots.rb - change all Rooibos.run calls (15+ occurrences)
- [ ] Update test_fractal_dashboard.rb - change Rooibos.run calls
- [ ] Update all other test files using Rooibos.run
- [ ] Add test for fps: parameter

## Example Updates
- [ ] Update verify_readme_usage/app.rb
- [ ] Update app_fractal_dashboard Init callables (remove argv/env params)

## Current Status
**3 failures, 1 error**: Making final fixes
- test_init_triggers_update_before_first_event - still needs investigation
- test_fragment_first_api_passes_argv_and_env_to_init - ENV not being passed correctly
- test_cancelled_wait_acknowledges_cancellation - intermittent
- test_custom_accepts_block - fixing Command.custom wrapper pattern

Restructuring Command.custom tests to demonstrate automatic shareability handling.
