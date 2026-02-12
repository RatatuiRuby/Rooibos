# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterAction < Minitest::Test
  module Counter
    Model = Data.define(:count)
    Init = -> { Model.new(count: 0) }
    Update = -> (msg, model) {
      return model unless msg.routed? && msg.envelope == :increment
      model.with(count: model.count + 1)
    }
  end

  def test_action_referenced_by_receive_events_handles_message
    router_class = Class.new do
      include Rooibos::Router

      action :quit, -> { Rooibos::Command.exit }
      receive_events :q, :quit
    end

    update = router_class.from_router
    model = Ractor.make_shareable({})
    key_message = RatatuiRuby::Event::Key.new(code: "q")

    _model, cmd = update.call(key_message, model)

    assert_kind_of Rooibos::Command::Exit, cmd,
      "action handler should produce exit command when triggered by receive_events"
  end

  def test_action_keyword_syntax_works
    router_class = Class.new do
      include Rooibos::Router

      action close: -> { Rooibos::Command.exit }
      receive_events :c, :close
    end

    update = router_class.from_router
    model = Ractor.make_shareable({})
    key_message = RatatuiRuby::Event::Key.new(code: "c")

    _model, cmd = update.call(key_message, model)

    assert_kind_of Rooibos::Command::Exit, cmd,
      "keyword syntax action should work identically to positional syntax"
  end

  def test_routed_action_dispatches_to_fragment
    counter_module = Counter

    router_class = Class.new do
      include Rooibos::Router

      route :counter, to: counter_module
      action increment: counter_module
      receive_events :i, :increment
    end

    model = Data.define(:counter).new(counter: Counter::Init.call)
    update = router_class.from_router
    key_message = RatatuiRuby::Event::Key.new(code: "i")

    new_model, _cmd = update.call(key_message, model)

    assert_equal 1, new_model.counter.count,
      "routed action should dispatch to fragment and increment count"
  end

  def test_undefined_action_raises_at_definition_time
    error = assert_raises(ArgumentError) do
      Class.new do
        include Rooibos::Router

        receive_events :q, :nonexistent
      end
    end

    assert_match(/Unknown action/, error.message)
  end
end
