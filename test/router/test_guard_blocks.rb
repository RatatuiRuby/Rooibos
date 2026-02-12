# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterGuardBlocks < Minitest::Test
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
end
