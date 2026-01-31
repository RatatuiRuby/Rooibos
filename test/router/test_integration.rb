# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRouterIntegration < Minitest::Test
  include Rooibos::TestHelper

  # Message processing order contract
  def test_observe_runs_before_intercept
    skip "TODO"
  end

  # Class variables for message capture (accessible from Ractor-shareable lambdas)
  @@all_messages = []

  def setup
    @@all_messages = []
  end

  def teardown
    @@all_messages = []
  end

  # Commands defined at class level for Ractor-shareability
  ObserveCmd = Rooibos::Command.wait(0.01, :from_observe)
  KeymapCmd = Rooibos::Command.wait(0.01, :from_keymap)

  # Router defined at class level
  class ObserveTestRouter
    include Rooibos::Router

    observe_all -> (msg, model) { [model, ObserveCmd] }

    keymap do |map|
      map.key :q, -> { KeymapCmd }
    end
  end

  # Update defined at class level for Ractor-shareability
  ObserveTestUpdate = -> (msg, m) do
    TestRouterIntegration.class_variable_get(:@@all_messages) << msg

    case msg
    when RatatuiRuby::Event::Key
      ObserveTestRouter.from_router.call(msg, m)
    when -> (x) { x.respond_to?(:type) && x.type == :timer }
      # Timer response - count it and quit after both
      new_count = m[:count] + 1
      if new_count >= 2
        [m.merge(count: new_count), Rooibos::Command.exit]
      else
        [m.merge(count: new_count), nil]
      end
    else
      [m, nil]
    end
  end

  ClearView = -> (_m, t) { t.clear }

  # CRITICAL: observe + keymap returning commands must NOT cause Command::Batch
  # Batch would cause unexpected Message::Batch to be sent to app developers
  def test_observe_commands_do_not_cause_batch
    # Router with observe AND keymap both returning commands
    router_class = Class.new do
      include Rooibos::Router

      observe_all -> (msg, model) { [model, Rooibos::Command.custom(:from_observe)] }

      keymap do |map|
        map.key :q, -> { Rooibos::Command.custom(:from_keymap) }
      end
    end

    update = router_class.from_router
    model = Ractor.make_shareable({}, copy: true)

    _new_model, command = update.call(RatatuiRuby::Event::Key.new(code: "q"), model)

    # MUST NOT return a Batch command (causes unexpected Message::Batch)
    refute_kind_of Rooibos::Command::Batch, command,
      "observe + keymap should NOT return a Batch (causes unexpected Message::Batch)"

    # MUST NOT return a raw Array (app devs shouldn't be able to do this either)
    refute_kind_of Array, command,
      "observe + keymap should NOT return raw Array"

    # Should have a commands accessor with exactly 2 commands
    assert_respond_to command, :commands,
      "should return a command wrapper with .commands accessor"
    assert_equal 2, command.commands.size,
      "Should have exactly 2 commands (observe + keymap)"

    # Commands should be in declaration order: observe first, then keymap
    assert_equal :from_observe, command.commands[0].callable,
      "First command should be from observe"
    assert_equal :from_keymap, command.commands[1].callable,
      "Second command should be from keymap"
  end

  def test_intercept_runs_before_keymap
    skip "TODO"
  end

  def test_keymap_runs_before_mousemap
    skip "TODO"
  end

  def test_mousemap_runs_before_forward
    skip "TODO"
  end

  def test_forward_runs_before_otherwise
    skip "TODO"
  end

  def test_full_pipeline_order_with_all_handlers
    skip "TODO"
  end
end
