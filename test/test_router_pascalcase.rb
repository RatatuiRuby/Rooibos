# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "test_helper"

class TestRouterPascalCase < Minitest::Test
  Command = RatatuiRuby::Tea::Command

  # Test that Router DSL uses PascalCase Update instead of SCREAMING_CASE UPDATE
  def test_router_uses_pascalcase_update_constant
    # ARRANGE: Create a child fragment with PascalCase Update
    child_fragment = Module.new
    child_model = Data.define(:value)
    child_fragment.const_set(:Model, child_model)
    child_fragment.const_set(:Init, -> { child_model.new(value: 0) })
    child_fragment.const_set(:Update, -> (message, model) do
      case message
      in [:increment]
        [model.with(value: model.value + 1), nil]
      else
        [model, nil]
      end
    end)

    # Create parent using Router DSL
    parent = Module.new
    parent.extend RatatuiRuby::Tea::Router::ClassMethods
    parent.route :child, to: child_fragment

    parent_model = Data.define(:child)
    parent.const_set(:Model, parent_model)
    parent.const_set(:Update, parent.from_router)

    # ACT: Send a routed message
    model = parent_model.new(child: child_fragment.const_get(:Init).())
    new_model, _cmd = parent.const_get(:Update).call([:child, :increment], model)

    # ASSERT: Child Update was called (value incremented)
    assert_equal 1, new_model.child.value
  end
end
