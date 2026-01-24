# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestFragmentFirstAPI < Minitest::Test
  include Rooibos::TestHelper

  def test_fragment_first_api_calls_init
    init_called = false

    fragment = Module.new
    fragment.const_set(:Model, Data.define(:initialized))
    fragment.const_set(:Init, -> do
      init_called = true
      fragment::Model.new(initialized: true)
    end)
    fragment.const_set(:View, -> (model, tui) { tui.clear })
    fragment.const_set(:Update, -> (_msg, _model) { Rooibos::Command.exit })

    with_test_terminal do
      inject_key("q")
      Rooibos.run(fragment)
    end

    assert init_called, "Fragment Init should have been called"
  end

  def test_raises_invariant_error_when_both_fragment_and_model_provided
    fragment = Module.new
    fragment.const_set(:Model, Data.define(:value))
    fragment.const_set(:Init, -> { fragment::Model.new(value: 1) })
    fragment.const_set(:View, -> (model, tui) { tui.clear })
    fragment.const_set(:Update, -> (_msg, _model) { Rooibos::Command.exit })

    model = fragment::Model.new(value: 2)

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(fragment, model:)
      end
    end

    assert_match(/fragment.*model/i, error.message)
  end

  def test_raises_invariant_error_when_both_fragment_and_view_provided
    fragment = Module.new
    fragment.const_set(:Model, Data.define(:value))
    fragment.const_set(:Init, -> { fragment::Model.new(value: 1) })
    fragment.const_set(:View, -> (model, tui) { tui.clear })
    fragment.const_set(:Update, -> (_msg, _model) { Rooibos::Command.exit })

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(fragment, view: -> (_m, tui) { tui.clear })
      end
    end

    assert_match(/fragment.*view/i, error.message)
  end

  def test_raises_invariant_error_when_both_fragment_and_update_provided
    fragment = Module.new
    fragment.const_set(:Model, Data.define(:value))
    fragment.const_set(:Init, -> { fragment::Model.new(value: 1) })
    fragment.const_set(:View, -> (model, tui) { tui.clear })
    fragment.const_set(:Update, -> (_msg, _model) { Rooibos::Command.exit })

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(fragment, update: -> (_m, _mdl) { Rooibos::Command.exit })
      end
    end

    assert_match(/fragment.*update/i, error.message)
  end

  def test_raises_invariant_error_when_both_fragment_and_command_provided
    fragment = Module.new
    fragment.const_set(:Model, Data.define(:value))
    fragment.const_set(:Init, -> { fragment::Model.new(value: 1) })
    fragment.const_set(:View, -> (model, tui) { tui.clear })
    fragment.const_set(:Update, -> (_msg, _model) { Rooibos::Command.exit })

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos.run(fragment, command: Rooibos::Command.exit)
      end
    end

    assert_match(/fragment.*command/i, error.message)
  end
end
