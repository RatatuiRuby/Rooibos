# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"
require "socket"
require "ostruct"

class TestCommandHttp < Minitest::Test
  include RatatuiRuby::TestHelper

  # Models for documentarian tests
  HttpModel = Data.define(:status, :body, :method_used, :error)

  # Parser that returns mutable data (for testing Ractor validation)
  MutableResultParser = Ractor.make_shareable(-> (body, _h = nil, _s = nil) { { parsed: body } })

  # Parser that returns shareable/frozen data (for integration tests)
  require "json"
  ShareableJsonParser = Ractor.make_shareable(-> (body, _h = nil, _s = nil) {
    Ractor.make_shareable(JSON.parse(body))
  })

  def setup
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
  end

  def teardown
    @server.close unless @server.closed?
  end

  # Minimal echo server: returns what method was received
  def echo_server
    Thread.new do
      client = @server.accept
      request_line = client.gets
      method = request_line.split.first
      client.print "HTTP/1.1 200 OK\r\nContent-Length: #{method.length}\r\n\r\n#{method}"
      client.close
    end
  end

  private def respond_with(body, content_type: "text/plain")
    Thread.new do
      client = @server.accept
      client.gets # consume request
      client.print "HTTP/1.1 200 OK\r\nContent-Type: #{content_type}\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
      client.close
    end
  end

  public def test_http_get_returns_status_body_headers
    echo_server

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        [m, RatatuiRuby::Tea::Command.http(:get, "http://127.0.0.1:#{@port}/".freeze, :fetch)]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, status:, body: }
        [m.with(status:, body:), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal 200, final_model.status
    assert_equal "GET", final_model.body
  end

  public def test_http_post_uses_post_method
    echo_server

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "p" }
        [m, RatatuiRuby::Tea::Command.http(:post, "http://127.0.0.1:#{@port}/".freeze, :fetch, body: "data")]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, body: }
        [m.with(method_used: body), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("p")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal "POST", final_model.method_used
  end

  public def test_http_put_uses_put_method
    echo_server

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "u" }
        [m, RatatuiRuby::Tea::Command.http(:put, "http://127.0.0.1:#{@port}/".freeze, :fetch, body: "data")]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, body: }
        [m.with(method_used: body), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("u")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal "PUT", final_model.method_used
  end

  public def test_http_patch_uses_patch_method
    echo_server

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "a" }
        [m, RatatuiRuby::Tea::Command.http(:patch, "http://127.0.0.1:#{@port}/".freeze, :fetch, body: "data")]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, body: }
        [m.with(method_used: body), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("a")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal "PATCH", final_model.method_used
  end

  public def test_http_delete_uses_delete_method
    echo_server

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "d" }
        [m, RatatuiRuby::Tea::Command.http(:delete, "http://127.0.0.1:#{@port}/".freeze, :fetch)]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, body: }
        [m.with(method_used: body), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("d")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal "DELETE", final_model.method_used
  end

  public def test_http_connection_error_returns_error_message
    # No server started—connection will fail

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "e" }
        # Port 1 is privileged and won't have anything listening
        [m, RatatuiRuby::Tea::Command.http(:get, "http://127.0.0.1:1/", :fetch)]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, error: }
        # Pattern-match on error response and store in model
        [m.with(error:), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("e")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    refute_nil final_model.error, "Expected error to be set"
    assert_kind_of String, final_model.error
  end

  public def test_http_custom_headers_are_sent
    # Server that echoes back the Authorization header value
    Thread.new do
      client = @server.accept
      headers = {}
      while (line = client.gets) && line != "\r\n"
        if line.include?(": ")
          key, value = line.split(": ", 2)
          headers[key.downcase] = value.strip
        end
      end
      auth_value = headers["authorization"] || "none"
      client.print "HTTP/1.1 200 OK\r\nContent-Length: #{auth_value.length}\r\n\r\n#{auth_value}"
      client.close
    end

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "h" }
        cmd = RatatuiRuby::Tea::Command.http(
          :get,
          "http://127.0.0.1:#{@port}/".freeze,
          :fetch,
          headers: { "Authorization" => "Bearer secret123" }.freeze
        )
        [m, cmd]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, body: }
        [m.with(body:), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("h")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_equal "Bearer secret123", final_model.body
  end

  public def test_http_command_validates_headers_shareability_in_debug_mode
    # Framework philosophy: validate and raise in debug mode, don't silently fix
    mutable_headers = { "Authorization" => "Bearer token" }

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command.http(
        :get,
        "http://example.com/",
        :fetch,
        headers: mutable_headers
      )
    end

    assert_match(/headers.*not.*shareable/i, error.message)
  end

  public def test_http_skips_headers_validation_when_debug_disabled
    RatatuiRuby::Debug.suppress_debug_mode do
      mutable_headers = { "Authorization" => "Bearer token" }

      # Should NOT raise when debug is disabled
      RatatuiRuby::Tea::Command.http(
        :get,
        "http://example.com/",
        :fetch,
        headers: mutable_headers
      )
    end
  end

  public def test_http_command_validates_body_shareability_in_debug_mode
    mutable_body = String.new("mutable request body")

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command.http(
        :post,
        "http://example.com/",
        :fetch,
        body: mutable_body
      )
    end

    assert_match(/body.*not.*shareable/i, error.message)
  end

  public def test_http_command_validates_url_shareability_in_debug_mode
    mutable_url = String.new("http://example.com/")

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command.http(
        :get,
        mutable_url,
        :fetch
      )
    end

    assert_match(/url.*not.*shareable/i, error.message)
  end

  public def test_http_timeout_returns_error
    # Server that sleeps longer than timeout
    Thread.new do
      client = @server.accept
      sleep 0.5 # Will exceed the 0.1s timeout
      client.print "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
      client.close
    end

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "t" }
        cmd = RatatuiRuby::Tea::Command.http(
          :get,
          "http://127.0.0.1:#{@port}/".freeze,
          :fetch,
          timeout: 0.1
        )
        [m, cmd]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, envelope: :fetch, error: }
        [m.with(error:), nil]
      in { type: :http, envelope: :fetch, status: }
        [m.with(status:), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("t")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    refute_nil final_model.error, "Expected timeout error"
    assert_match(/timeout|timed out/i, final_model.error)
  end

  public def test_http_raises_on_unknown_method
    error = assert_raises(ArgumentError) do
      RatatuiRuby::Tea::Command.http(
        :invalid_method,
        "http://example.com/",
        :fetch
      )
    end

    assert_match(/unsupported.*method/i, error.message)
  end

  public def test_http_has_zero_grace_period
    # Net::HTTP is blocking; grace period = 0 means immediate force-kill is acceptable
    cmd = RatatuiRuby::Tea::Command.http(:get, "http://example.com/", :fetch)
    assert_equal 0, cmd.tea_cancellation_grace_period
  end

  # --- DWIM Arity Tests (at Http.new level) ---

  public def test_http_new_url_only_implies_get_with_url_as_envelope
    # Http.new('https://api.example.com/foo')
    # → method: :get, envelope: url, url: url
    cmd = RatatuiRuby::Tea::Command::Http.new("https://api.example.com/foo")

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
  end

  public def test_command_http_url_only_implies_get_with_url_as_envelope
    # Command.http('https://api.example.com/foo') - convenience factory
    cmd = RatatuiRuby::Tea::Command.http("https://api.example.com/foo")

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
  end

  public def test_dwim_url_only_validates_ractor_shareability
    mutable_url = String.new("https://api.example.com/foo")

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command::Http.new(mutable_url)
    end

    assert_match(/url.*not.*shareable/i, error.message)
  end

  public def test_http_new_url_and_envelope
    # Http.new('https://api.example.com/foo', :mine)
    cmd = RatatuiRuby::Tea::Command::Http.new("https://api.example.com/foo", :mine)

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal :mine, cmd.envelope
  end

  public def test_http_new_method_and_url
    # Http.new(:delete, 'https://api.example.com/foo')
    cmd = RatatuiRuby::Tea::Command::Http.new(:delete, "https://api.example.com/foo")

    assert_equal :delete, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
  end

  public def test_http_new_method_url_and_envelope
    # Http.new(:delete, 'https://api.example.com/foo', :mine)
    cmd = RatatuiRuby::Tea::Command::Http.new(:delete, "https://api.example.com/foo", :mine)

    assert_equal :delete, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal :mine, cmd.envelope
  end

  public def test_http_new_method_url_and_body
    # Http.new(:post, 'https://api.example.com/foo', '{ done: true }')
    cmd = RatatuiRuby::Tea::Command::Http.new(:post, "https://api.example.com/foo", "{ done: true }")

    assert_equal :post, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
    assert_equal "{ done: true }", cmd.body
  end

  public def test_http_new_method_url_body_and_envelope
    # Http.new(:post, 'https://api.example.com/foo', '{ done: true }', :mine)
    cmd = RatatuiRuby::Tea::Command::Http.new(:post, "https://api.example.com/foo", "{ done: true }", :mine)

    assert_equal :post, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal :mine, cmd.envelope
    assert_equal "{ done: true }", cmd.body
  end

  public def test_http_new_get_keyword
    # Http.new(get: 'https://api.example.com/foo')
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "https://api.example.com/foo")

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
  end

  public def test_http_new_post_keyword
    # Http.new(post: 'https://api.example.com/foo')
    cmd = RatatuiRuby::Tea::Command::Http.new(post: "https://api.example.com/foo")

    assert_equal :post, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
    assert_equal "https://api.example.com/foo", cmd.envelope
  end

  public def test_http_new_conflicting_method_keyword_raises
    # get: 'url' with method: :post should raise
    error = assert_raises(ArgumentError) do
      RatatuiRuby::Tea::Command::Http.new(get: "https://api.example.com/foo", method: :post)
    end

    assert_match(/conflict/i, error.message)
  end

  public def test_http_new_redundant_matching_method_keyword_works
    # get: 'url' with method: :get should work
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "https://api.example.com/foo", method: :get)

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_put_keyword
    cmd = RatatuiRuby::Tea::Command::Http.new(put: "https://api.example.com/foo")
    assert_equal :put, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_patch_keyword
    cmd = RatatuiRuby::Tea::Command::Http.new(patch: "https://api.example.com/foo")
    assert_equal :patch, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_delete_keyword
    cmd = RatatuiRuby::Tea::Command::Http.new(delete: "https://api.example.com/foo")
    assert_equal :delete, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_auto_splat_hash
    # Http.new({get: 'url'}) → same as Http.new(get: 'url')
    options = { get: "https://api.example.com/foo" }
    cmd = RatatuiRuby::Tea::Command::Http.new(options)

    assert_equal :get, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_auto_spread_array
    # Http.new([:post, 'url']) → same as Http.new(:post, 'url')
    args = [:post, "https://api.example.com/foo"]
    cmd = RatatuiRuby::Tea::Command::Http.new(args)

    assert_equal :post, cmd.method
    assert_equal "https://api.example.com/foo", cmd.url
  end

  public def test_http_new_conflicting_url_keyword_raises
    # get: 'url1' with url: 'url2' should raise
    error = assert_raises(ArgumentError) do
      RatatuiRuby::Tea::Command::Http.new(get: "https://api1.example.com/", url: "https://api2.example.com/")
    end

    assert_match(/conflict/i, error.message)
  end

  public def test_mutable_envelope_raises_invariant_in_debug_mode
    mutable_envelope = String.new("custom_tag")

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command::Http.new(method: :get, url: "http://example.com", envelope: mutable_envelope)
    end

    assert_match(/envelope.*not.*shareable/i, error.message)
  end

  public def test_mutable_timeout_raises_invariant_in_debug_mode
    # Use a mutable object as timeout (normally should be a number, but test the validation)
    mutable_timeout = Object.new

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command::Http.new(method: :get, url: "http://example.com", envelope: :tag, timeout: mutable_timeout)
    end

    assert_match(/timeout.*not.*shareable/i, error.message)
  end

  # ==========================================================================
  # SSL, Timeout, Cancellation Tests (Phase 4 Completion)
  # ==========================================================================

  public def test_http_uses_ssl_for_https_urls
    # Verify SSL is attempted by connecting https:// to our non-SSL server
    # This will fail with an SSL handshake error, proving SSL was attempted
    echo_server # Start non-SSL server

    channel = Concurrent::Promises::Channel.new
    lifecycle = RatatuiRuby::Tea::Command::Lifecycle.new
    out = RatatuiRuby::Tea::Command::Outlet.new(channel, lifecycle:)
    token = RatatuiRuby::Tea::Command.uncancellable

    # Use https:// against our non-SSL server
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "https://127.0.0.1:#{@port}/".freeze)
    cmd.call(out, token)

    result = channel.pop
    # Should get an SSL-related error (proves SSL was attempted)
    assert_nil result.status
    assert_match(/ssl|handshake|connection reset/i, result.error)
  end

  public def test_http_default_timeout_is_10_seconds
    # When no timeout is specified, default should be 10 seconds
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "http://example.com")

    # The timeout should default to 10
    assert_equal 10, cmd.timeout
  end

  public def test_http_timeout_error_returns_error_message
    # Server that accepts but never responds should timeout
    Thread.new do
      client = @server.accept
      sleep 5 # Never respond, just hang
      begin
        client.close
      rescue
        nil
      end
    end

    channel = Concurrent::Promises::Channel.new
    lifecycle = RatatuiRuby::Tea::Command::Lifecycle.new
    out = RatatuiRuby::Tea::Command::Outlet.new(channel, lifecycle:)
    token = RatatuiRuby::Tea::Command.uncancellable

    # Use very short timeout to trigger quickly
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "http://127.0.0.1:#{@port}/".freeze, timeout: 0.1)
    cmd.call(out, token)

    result = channel.pop
    assert_nil result.status
    assert_match(/timeout|timed out/i, result.error)
  end

  public def test_http_validates_method_raises_for_unknown
    # Unknown HTTP method should raise ArgumentError
    error = assert_raises(ArgumentError) do
      RatatuiRuby::Tea::Command::Http.new(method: :unknown, url: "http://example.com")
    end

    assert_match(/unsupported.*method/i, error.message)
  end

  public def test_http_respects_cancellation_before_request
    # If cancelled before request starts, no message should be sent
    channel = Concurrent::Promises::Channel.new
    lifecycle = RatatuiRuby::Tea::Command::Lifecycle.new
    out = RatatuiRuby::Tea::Command::Outlet.new(channel, lifecycle:)

    # Create a pre-cancelled token
    origin = Concurrent::Promises.resolvable_event
    origin.resolve
    token = Concurrent::Cancellation.new(origin)

    cmd = RatatuiRuby::Tea::Command::Http.new(get: "http://127.0.0.1:#{@port}/".freeze)
    cmd.call(out, token)

    # Channel should be empty—no message sent
    result = channel.pop_op.value(0.1)
    assert_nil result, "Expected no message when cancelled before request"
  end

  public def test_http_new_accepts_parser_keyword
    # Http.new with parser: stores it on instance
    require "json"
    parser = Ractor.make_shareable(JSON.method(:parse))
    cmd = RatatuiRuby::Tea::Command::Http.new(get: "http://example.com", parser:)

    assert_equal parser, cmd.parser
  end

  public def test_http_new_non_callable_parser_raises
    # parser: must respond to :call
    error = assert_raises(ArgumentError) do
      RatatuiRuby::Tea::Command::Http.new(get: "http://example.com", parser: "not callable")
    end

    assert_match(/parser.*call/i, error.message)
  end

  public def test_mutable_parser_raises_invariant_in_debug_mode
    # Use a lambda that closes over mutable state
    mutable_state = []
    mutable_parser = -> (body) { mutable_state << body; body }

    error = assert_raises(RatatuiRuby::Error::Invariant) do
      RatatuiRuby::Tea::Command::Http.new(get: "http://example.com", parser: mutable_parser)
    end

    assert_match(/parser.*not.*shareable/i, error.message)
  end

  public def test_parsed_body_validates_shareability_in_debug_mode
    # Parser returns mutable data—should raise Invariant in debug mode
    Thread.new do
      client = @server.accept
      client.gets
      client.print "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\ntest"
      client.close
    end

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    error_raised = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        cmd = RatatuiRuby::Tea::Command.http(get: "http://127.0.0.1:#{@port}/".freeze, parser: MutableResultParser)
        [m, cmd]
      in { type: :key, code: "q" }
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, error: }
        error_raised = error
        [m, RatatuiRuby::Tea::Command.exit]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_match(/parsed.*body.*not.*shareable/i, error_raised)
  end

  public def test_parsed_body_skips_validation_when_debug_disabled
    # With debug disabled, mutable parsed_body should not raise
    Thread.new do
      client = @server.accept
      client.gets
      client.print "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\ntest"
      client.close
    end

    RatatuiRuby::Debug.suppress_debug_mode do
      model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
      view = -> (_m, t) { t.clear }
      final_model = nil

      update = -> (msg, m) do
        case msg
        in { type: :key, code: "f" }
          cmd = RatatuiRuby::Tea::Command.http(get: "http://127.0.0.1:#{@port}/".freeze, parser: MutableResultParser)
          [m, cmd]
        in { type: :key, code: "q" }
          final_model = m
          [m, RatatuiRuby::Tea::Command.exit]
        in { type: :http, body: }
          [m.with(body:), nil]
        else
          [m, nil]
        end
      end

      with_test_terminal do
        inject_key("f")
        inject_sync
        inject_key("q")
        RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
      end

      # Should have received parsed body without error
      refute_nil final_model.body
    end
  end

  public def test_parser_is_invoked_with_body_headers_status
    # Echo server returns JSON
    Thread.new do
      client = @server.accept
      client.gets # read request line
      json_body = '{"parsed":true}'
      client.print "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{json_body.length}\r\n\r\n#{json_body}"
      client.close
    end

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        cmd = RatatuiRuby::Tea::Command.http(
          get: "http://127.0.0.1:#{@port}/".freeze,
          parser: ShareableJsonParser
        )
        [m, cmd]
      in { type: :key, code: "q" }
        final_model = m
        [m, RatatuiRuby::Tea::Command.exit]
      in { type: :http, body: }
        # Body should be parsed Hash from JSON, not raw string
        [m.with(body:), nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    # Parser was invoked: body is a Hash, not a String
    assert_instance_of Hash, final_model.body
    assert_equal true, final_model.body["parsed"]
  end

  # ==========================================================================
  # DOCUMENTARIAN TESTS: How to use parser: with stdlib formats
  # ==========================================================================

  require "yaml"
  require "csv"

  JsonParser = Ractor.make_shareable(-> (body, _headers = nil, _status = nil) {
    Ractor.make_shareable(JSON.parse(body))
  })
  public def test_parser_json_example
    respond_with('{"name":"Alice","age":30}', content_type: "application/json")

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        # JsonParser parses JSON and makes result shareable
        [m, RatatuiRuby::Tea::Command.http(get: "http://127.0.0.1:#{@port}/".freeze, parser: JsonParser)]
      in { type: :http, body: }
        final_model = m.with(body:)
        [final_model, RatatuiRuby::Tea::Command.exit]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_instance_of Hash, final_model.body
    assert_equal "Alice", final_model.body["name"]
    assert_equal 30, final_model.body["age"]
  end

  YamlParser = Ractor.make_shareable(-> (body, _headers = nil, _status = nil) {
    Ractor.make_shareable(YAML.safe_load(body, permitted_classes: [Symbol]))
  })
  public def test_parser_yaml_example
    respond_with("name: Bob\nage: 25", content_type: "application/x-yaml")

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        # YamlParser uses YAML.safe_load for security
        [m, RatatuiRuby::Tea::Command.http(get: "http://127.0.0.1:#{@port}/".freeze, parser: YamlParser)]
      in { type: :http, body: }
        final_model = m.with(body:)
        [final_model, RatatuiRuby::Tea::Command.exit]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_instance_of Hash, final_model.body
    assert_equal "Bob", final_model.body["name"]
    assert_equal 25, final_model.body["age"]
  end

  CsvParser = Ractor.make_shareable(-> (body, _headers = nil, _status = nil) {
    Ractor.make_shareable(CSV.parse(body))
  })
  public def test_parser_csv_example
    respond_with("name,age\nAlice,30\nBob,25", content_type: "text/csv")

    model = Ractor.make_shareable(HttpModel.new(status: nil, body: nil, method_used: nil, error: nil))
    view = -> (_m, t) { t.clear }
    final_model = nil

    update = -> (msg, m) do
      case msg
      in { type: :key, code: "f" }
        # CsvParser returns array of arrays
        [m, RatatuiRuby::Tea::Command.http(get: "http://127.0.0.1:#{@port}/".freeze, parser: CsvParser)]
      in { type: :http, body: }
        final_model = m.with(body:)
        [final_model, RatatuiRuby::Tea::Command.exit]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("f")
      inject_sync
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_instance_of Array, final_model.body
    assert_equal ["name", "age"], final_model.body[0]
    assert_equal ["Alice", "30"], final_model.body[1]
    assert_equal ["Bob", "25"], final_model.body[2]
  end
end
