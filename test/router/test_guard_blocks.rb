# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterGuardBlocks < Minitest::Test
  include Rooibos::TestHelper
  def test_only_block_runs_handlers_when_guard_passes
    j_called = false
    k_called = false

    test_class = Class.new do
      include Rooibos::Router

      only when: -> (_msg, model) { model[:focused] } do
        receive_events :j, -> (_msg, model) { j_called = true; model }
        receive_events :k, -> (_msg, model) { k_called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "j"),
      Ractor.make_shareable({ focused: true }, copy: true))
    assert j_called

    update.call(RatatuiRuby::Event::Key.new(code: "k"),
      Ractor.make_shareable({ focused: true }, copy: true))
    assert k_called
  end

  def test_only_block_skips_handlers_when_guard_fails
    j_called = false
    k_called = false

    test_class = Class.new do
      include Rooibos::Router

      only when: -> (_msg, model) { model[:focused] } do
        receive_events :j, -> (_msg, model) { j_called = true; model }
        receive_events :k, -> (_msg, model) { k_called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "j"),
      Ractor.make_shareable({ focused: false }, copy: true))
    refute j_called

    update.call(RatatuiRuby::Event::Key.new(code: "k"),
      Ractor.make_shareable({ focused: false }, copy: true))
    refute k_called
  end

  def test_only_block_with_if_alias
    called = false

    test_class = Class.new do
      include Rooibos::Router

      only if: -> (_msg, model) { model[:active] } do
        receive_events :x, -> (_msg, model) { called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ active: false }, copy: true))
    refute called

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ active: true }, copy: true))
    assert called
  end

  def test_skip_block_skips_handlers_when_guard_passes
    called = false

    test_class = Class.new do
      include Rooibos::Router

      skip when: -> (_msg, model) { model[:locked] } do
        receive_events :d, -> (_msg, model) { called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "d"),
      Ractor.make_shareable({ locked: true }, copy: true))
    refute called
  end

  def test_skip_block_runs_handlers_when_guard_fails
    called = false

    test_class = Class.new do
      include Rooibos::Router

      skip when: -> (_msg, model) { model[:locked] } do
        receive_events :d, -> (_msg, model) { called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "d"),
      Ractor.make_shareable({ locked: false }, copy: true))
    assert called
  end

  def test_skip_block_applies_to_multiple_handlers
    delete_called = false
    edit_called = false

    test_class = Class.new do
      include Rooibos::Router

      skip when: -> (_msg, model) { model[:readonly] } do
        receive_events :d, -> (_msg, model) { delete_called = true; model }
        receive_events :e, -> (_msg, model) { edit_called = true; model }
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "d"),
      Ractor.make_shareable({ readonly: true }, copy: true))
    update.call(RatatuiRuby::Event::Key.new(code: "e"),
      Ractor.make_shareable({ readonly: true }, copy: true))

    refute delete_called
    refute edit_called
  end

  def test_nested_only_blocks_combine_guards
    called = false

    test_class = Class.new do
      include Rooibos::Router

      only when: -> (_msg, model) { model[:level1] } do
        only when: -> (_msg, model) { model[:level2] } do
          receive_events :x, -> (_msg, model) { called = true; model }
        end
      end
    end

    update = test_class.from_router

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ level1: true, level2: false }, copy: true))
    refute called, "should skip when inner guard fails"

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ level1: false, level2: true }, copy: true))
    refute called, "should skip when outer guard fails"

    update.call(RatatuiRuby::Event::Key.new(code: "x"),
      Ractor.make_shareable({ level1: true, level2: true }, copy: true))
    assert called, "should run when both guards pass"
  end

  module TrackingChild
    Model = Data.define(:messages)
    Init = -> { Model.new(messages: []) }
    Update = -> (msg, model) { [model.with(messages: model.messages + [msg]), nil] }
  end

  def test_only_block_scopes_forward_declarations
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterGuardBlocks::TrackingChild

      only when: -> (_msg, model) { model.active } do
        forward_events :j, to: :child, as: :move_down
        forward_events :k, to: :child, as: :move_up
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child, :active)

    inactive_model = model_class.new(child: TrackingChild::Init.call, active: false)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "j"), inactive_model)
    assert_equal 0, new_model.child.messages.size

    active_model = model_class.new(child: TrackingChild::Init.call, active: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "j"), active_model)
    assert_equal 1, new_model2.child.messages.size
  end

  def test_only_block_scopes_otherwise_declaration
    test_class = Class.new do
      include Rooibos::Router

      route :child, to: TestRouterGuardBlocks::TrackingChild

      only when: -> (_msg, model) { model.focused } do
        otherwise route_to: :child
      end
    end

    update = test_class.from_router
    model_class = Data.define(:child, :focused)

    unfocused = model_class.new(child: TrackingChild::Init.call, focused: false)
    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), unfocused)
    assert_equal 0, new_model.child.messages.size

    focused = model_class.new(child: TrackingChild::Init.call, focused: true)
    new_model2, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "x"), focused)
    assert_equal 1, new_model2.child.messages.size
  end

  # --- Ractor shareability ---
  #
  # The runtime validates that the Update is Ractor-shareable.
  # These tests use with_test_terminal to exercise that validation.

  module CountingLeaf
    LeafModel = Data.define(:count)
    Init = -> { LeafModel.new(count: 0) }
    Update = -> (_msg, model) { model.with(count: model.count + 1) }
  end

  # Single-level: `only when:` + `otherwise route_to:` with no inner guard.
  module GuardedOuter
    include Rooibos::Router

    OuterModel = Data.define(:nested, :active)
    Init = -> { OuterModel.new(nested: CountingLeaf::Init.call, active: true) }
    View = -> (_model, tui) { tui.clear }

    route :nested, to: CountingLeaf

    ACTIVE_GUARD = -> (_, model) { model.active }

    receive_events :q, -> (_, model) { [model, Rooibos::Command.exit] }

    only when: ACTIVE_GUARD do
      otherwise route_to: :nested
    end

    Update = from_router
  end

  def test_guarded_otherwise_is_ractor_shareable
    result = with_test_terminal do
      inject_key("a") # Not handled by outer → otherwise → nested
      inject_key("q")
      Rooibos::Runtime.run(GuardedOuter)
    end

    assert_equal 1, result.nested.count,
      "nested fragment should receive the forwarded message when guard passes"
  end

  # Nested: `only when:` + `otherwise route_to: ... when:` — the exact
  # pattern from the Sidekiq TUI where an outer guard gates a mode and
  # inner guards dispatch to different nested fragments.
  module NestedGuardOuter
    include Rooibos::Router

    OuterModel = Data.define(:nested, :mode)
    Init = -> { OuterModel.new(nested: CountingLeaf::Init.call, mode: :filtering) }
    View = -> (_model, tui) { tui.clear }

    route :nested, to: CountingLeaf

    receive_events :q, -> (_, model) { [model, Rooibos::Command.exit] }

    OUTER_GUARD = -> (_, model) { model.mode == :filtering }
    INNER_GUARD = -> (_, model) { true }

    only when: OUTER_GUARD do
      otherwise route_to: :nested, when: INNER_GUARD
    end

    Update = from_router
  end

  def test_nested_guard_otherwise_is_ractor_shareable
    result = with_test_terminal do
      inject_key("a")
      inject_key("q")
      Rooibos::Runtime.run(NestedGuardOuter)
    end

    assert_equal 1, result.nested.count,
      "nested fragment should receive the forwarded message through nested guards"
  end
end
