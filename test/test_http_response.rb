# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"

class TestHttpResponse < Minitest::Test
  def test_http_predicate_returns_true
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :users, status: 200, body: "", headers: {}, error: nil
    )

    assert msg.http?, "HttpResponse should return true for http?"
  end

  def test_success_predicate_for_2xx_status
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :users, status: 200, body: "", headers: {}, error: nil
    )

    assert msg.success?, "200 response should be success?"
  end

  def test_error_predicate_when_error_present
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :users, status: nil, body: nil, headers: nil, error: "Connection failed"
    )

    assert msg.error?, "Response with error should be error?"
  end

  def test_deconstruct_keys_for_pattern_matching
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :users, status: 200, body: '{"data":[]}', headers: {}, error: nil
    )

    case msg
    in { type: :http, envelope: :users, status: 200, body: }
      assert_equal '{"data":[]}', body
    else
      flunk "Pattern match failed"
    end
  end

  def test_to_sym
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :api, status: 200, body: "OK", headers: {}, error: nil
    )
    assert_equal :message_http, msg.to_sym
  end

  def test_symbol_equality
    msg = Rooibos::Message::HttpResponse.new(
      envelope: :api, status: 200, body: "OK", headers: {}, error: nil
    )
    assert_operator msg, :==, :message_http
    refute_operator msg, :==, :message_timer
  end
end
