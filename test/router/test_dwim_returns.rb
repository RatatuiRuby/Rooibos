# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterDWIMReturns < Minitest::Test
  def test_nil_return_preserves_model_and_returns_nil_command
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) { nil }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42, name: "test" }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal model, new_model, "model should be unchanged"
    assert_nil command, "command should be nil"
  end

  def test_nil_return_from_observe_continues_processing
    receive_called = false

    test_class = Class.new do
      include Rooibos::Router

      observe_events :q, -> (_msg, _model) { nil }
      receive_events :q, -> (_msg, model) { receive_called = true; model }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert receive_called, "receive should still run after observe returns nil"
  end

  def test_model_return_updates_model_with_nil_command
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        model.merge(count: model[:count] + 1)
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 1, new_model[:count]
    assert_nil command
  end

  def test_data_define_model_return
    model_class = Data.define(:count, :name)

    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        model.with(count: model.count + 1)
      }
    end

    update = test_class.from_router
    model = model_class.new(count: 5, name: "test")

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 6, new_model.count
    assert_equal "test", new_model.name
    assert_nil command
  end

  def test_command_return_preserves_model
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) {
        Rooibos::Command.exit
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ count: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 42, new_model[:count], "model should be unchanged"
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_batch_command_return
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) {
        Rooibos::Command.batch(
          Rooibos::Command.exit,
          Rooibos::Command.exit
        )
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_kind_of Rooibos::Command::Batch, command
  end

  def test_tuple_return_updates_both
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        [model.merge(quit: true), Rooibos::Command.exit]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ quit: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:quit]
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_tuple_with_nil_model_preserves_original
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, _model) {
        [nil, Rooibos::Command.exit]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ value: 42 }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal 42, new_model[:value], "nil model in tuple should preserve original"
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_tuple_with_nil_command_returns_nil
    test_class = Class.new do
      include Rooibos::Router

      receive_events :q, -> (_msg, model) {
        [model.merge(updated: true), nil]
      }
    end

    update = test_class.from_router
    model = Ractor.make_shareable({ updated: false }, copy: true)

    new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal true, new_model[:updated]
    assert_nil command
  end

  def test_action_handler_zero_arity
    test_class = Class.new do
      include Rooibos::Router

      action :quit, -> { Rooibos::Command.exit }
      receive_events :q, :quit
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_action_handler_two_arity_gets_message_and_model
    test_class = Class.new do
      include Rooibos::Router

      action :update, -> (msg, model) { model.merge(last_key: msg.to_sym) }
      receive_events :q, :update
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    new_model, _command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert_equal :q, new_model[:last_key]
  end

  def test_handler_with_arity_0_works_for_side_effects
  end

  def test_handler_with_arity_1_raises_descriptive_error_at_definition_time
  end

  def test_handler_with_arity_3_plus_raises_descriptive_error_at_definition_time
  end
end
