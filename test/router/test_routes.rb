# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestRouterRoutes < Minitest::Test
  include Rooibos::TestHelper

  module FakeChild
    Update = -> (msg, model) { [model, nil] }
  end

  module OtherFakeChild
    Update = -> (msg, model) { [model, nil] }
  end

  def test_from_router_resolves_route_by_fragment_module
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterRoutes::FakeChild
      forward_events :enter, to: TestRouterRoutes::FakeChild, as: :increment
    end

    update = test_class.from_router

    assert_respond_to update, :call,
      "from_router succeeds when forward targets an unambiguous fragment module"
  end

  def test_from_router_resolves_route_by_symbol
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterRoutes::FakeChild
      forward_events :enter, to: :child, as: :increment
    end

    update = test_class.from_router

    assert_respond_to update, :call,
      "from_router succeeds when forward targets an unambiguous prefix symbol"
  end

  def test_from_router_resolves_route_by_captured_route
    captured_route = nil
    test_class = Class.new do
      include Rooibos::Router
      captured_route = route :child, to: TestRouterRoutes::FakeChild
      forward_events :enter, to: captured_route, as: :increment
    end

    update = test_class.from_router

    assert_respond_to update, :call,
      "from_router succeeds when forward targets a captured Route"
  end

  def test_from_router_raises_when_ambiguous_by_fragment_module
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterRoutes::FakeChild
      route :other, to: TestRouterRoutes::FakeChild
      forward_events :enter, to: TestRouterRoutes::FakeChild, as: :increment
    end

    assert_raises(Rooibos::Error::Invariant) do
      test_class.from_router
    end
  end

  def test_from_router_raises_when_ambiguous_by_prefix
    test_class = Class.new do
      include Rooibos::Router
      route :child, to: TestRouterRoutes::FakeChild
      route :child, to: TestRouterRoutes::OtherFakeChild
      forward_events :enter, to: :child, as: :increment
    end

    assert_raises(Rooibos::Error::Invariant) do
      test_class.from_router
    end
  end
end
