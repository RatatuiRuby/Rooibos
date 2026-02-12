# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRoute < Minitest::Test
  include Rooibos::TestHelper

  module FakeChild
    Update = -> (msg, model) { [model, nil] }
  end

  def test_from_router_returns_callable
    test_class = Class.new do
      include Rooibos::Router
    end

    update = test_class.from_router

    assert update.respond_to?(:call)
  end

  def test_route_returns_route
    returned = nil
    Class.new do
      include Rooibos::Router
      returned = route :child, to: TestRouterRoute::FakeChild
    end

    assert_kind_of Data, returned,
      "route should return a Route object that can be captured"
  end

  def test_route_without_destination_raises_argument_error
  end

  def test_duplicate_route_names_raise_descriptive_error
  end

  def test_forward_to_undefined_route_raises_descriptive_error
  end

  def test_route_with_non_callable_accessor_raises_argument_error
  end

  def test_route_accessor_wrong_arity_raises_descriptive_error
  end

  def test_route_read_accessor_validates_ractor_shareable_in_debug_mode
  end

  def test_route_write_accessor_validates_ractor_shareable_in_debug_mode
  end

  def test_route_accessor_allows_non_ractor_shareable_with_suppress_debug_mode
  end
end
