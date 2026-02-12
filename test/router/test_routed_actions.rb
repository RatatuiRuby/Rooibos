# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRoutedActions < Minitest::Test
  module HistoryPanel
    Model = Data.define(:received_envelope)
    Init = -> { Model.new(received_envelope: nil) }
    Update = -> (msg, model) {
      if msg.routed?
        [model.with(received_envelope: msg.envelope), nil]
      else
        [model, nil]
      end
    }
  end

  def test_routed_action_synthesizes_message_routed_with_action_name_as_envelope
    test_class = Class.new do
      include Rooibos::Router

      route :history, to: TestRouterRoutedActions::HistoryPanel

      action go_back: TestRouterRoutedActions::HistoryPanel

      receive_events :backspace, :go_back
    end

    update = test_class.from_router
    model_class = Data.define(:history)
    model = model_class.new(history: HistoryPanel::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "backspace"), model)

    assert_equal :go_back, new_model.history.received_envelope,
      "action name should become envelope of synthesized Message::Routed"
  end

  def test_routed_action_with_positional_syntax
    test_class = Class.new do
      include Rooibos::Router

      route :history, to: TestRouterRoutedActions::HistoryPanel

      action :show_details, TestRouterRoutedActions::HistoryPanel

      receive_events :enter, :show_details
    end

    update = test_class.from_router
    model_class = Data.define(:history)
    model = model_class.new(history: HistoryPanel::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "enter"), model)

    assert_equal :show_details, new_model.history.received_envelope
  end

  def test_lambda_action_runs_directly
    called = false

    test_class = Class.new do
      include Rooibos::Router

      action :quit, -> { called = true; Rooibos::Command.exit }

      receive_events :q, :quit
    end

    update = test_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    assert called, "lambda action should run directly"
    assert_kind_of Rooibos::Command::Exit, command
  end

  def test_routed_action_does_not_run_handler_directly
    test_class = Class.new do
      include Rooibos::Router

      route :history, to: TestRouterRoutedActions::HistoryPanel

      action go_back: TestRouterRoutedActions::HistoryPanel

      receive_events :backspace, :go_back
    end

    update = test_class.from_router
    model_class = Data.define(:history)
    model = model_class.new(history: HistoryPanel::Init.call)

    new_model, _cmd = update.call(RatatuiRuby::Event::Key.new(code: "backspace"), model)

    assert_equal :go_back, new_model.history.received_envelope
  end
end
