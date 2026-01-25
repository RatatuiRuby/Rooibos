# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

class TestRuntime < Minitest::Test
  include Rooibos::TestHelper

  # Shareable command callable for testing init commands
  INIT_COMPLETE_COMMAND = Ractor.make_shareable(-> (out, _token) { out.put(:init_complete) })

  private def ractor_error_pattern
    /ractor|frozen|shareable/i
  end

  def test_runtime_class_exists
    assert_kind_of Class, Rooibos::Runtime
  end

  def test_runtime_responds_to_run
    assert_respond_to Rooibos::Runtime, :run
  end

  def test_run_accepts_fps_parameter
    model = Ractor.make_shareable({ count: 0 }, copy: true)
    view = -> (_m, tui) { tui.clear }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    # Verify it runs and returns the model
    result = with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:, fps: 30)
    end

    assert_equal model, result
  end

  def test_view_receives_model_and_tui
    model = Ractor.make_shareable({ text: "hello" }, copy: true)
    view_args = nil

    view = -> (m, t) { view_args = [m, t]; t.clear }
    update = -> (msg, _m) { [model, Rooibos::Command.exit] }

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal model, view_args[0], "view should receive model as first arg"
    assert_kind_of RatatuiRuby::TUI, view_args[1], "view should receive TUI as second arg"
  end

  def test_init_callable_object
    # Init is an object responding to call (but not a Proc/Method)
    callable_init = Object.new
    def callable_init.call
      [Ractor.make_shareable({ count: 0 }, copy: true), nil]
    end

    fragment = Module.new
    fragment.const_set(:Init, callable_init)
    fragment.const_set(:Update, -> (_msg, _m) { Rooibos::Command.exit })
    fragment.const_set(:View, -> (_m, tui) { tui.clear })

    # specific verification that it runs without raising and returns the correct model
    result = with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(fragment)
    end

    assert_equal({ count: 0 }, result)
  end

  def test_init_invalid_callable
    # Init does not respond to call
    fragment = Module.new
    fragment.const_set(:Init, Object.new)
    fragment.const_set(:Update, -> (_msg, _m) { Rooibos::Command.exit })
    fragment.const_set(:View, -> (_m, tui) { tui.clear })

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos::Runtime.run(fragment)
      end
    end
    assert_match(/Fragment::Init must respond to :call/, error.message)
  end

  def test_model_invalid_new
    # Model does not respond to new
    fragment = Module.new
    fragment.const_set(:Model, Object.new) # Object.new returns an instance, which doesn't have .new
    fragment.const_set(:Update, -> (_msg, _m) { Rooibos::Command.exit })
    fragment.const_set(:View, -> (_m, tui) { tui.clear })

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos::Runtime.run(fragment)
      end
    end
    assert_match(/Fragment::Model must respond to :new/, error.message)
  end

  def test_update_can_return_plain_model
    model = Ractor.make_shareable({ count: 0 }, copy: true)
    call_count = 0

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      call_count += 1
      if call_count >= 2 || msg.q?
        [m, Rooibos::Command.exit]
      else
        m # Return plain model, no tuple
      end
    end

    with_test_terminal do
      inject_key("a") # First event: causes plain model return
      inject_key("q") # Second event: causes quit
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal 2, call_count, "update should be called twice (once per event)"
  end

  def test_update_detects_array_model_vs_tuple
    # Model is a 2-element array - should not be confused with [model, cmd] tuple
    model = [:item1, :item2].freeze
    received_model = nil

    view = -> (m, tui) { received_model = m; tui.clear }
    update = -> (msg, m) do
      if msg.q?
        [m, Rooibos::Command.exit]
      else
        m # Return the array model directly
      end
    end

    with_test_terminal do
      inject_key("a") # First event: returns array model
      inject_key("q") # Second event: quits
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # The model should still be the 2-element array, not destructured
    assert_equal [:item1, :item2], received_model, "array model should not be confused with [model, cmd] tuple"
  end

  def test_update_can_return_command_only
    model = Ractor.make_shareable({ count: 0 }, copy: true)
    received_model = nil

    view = -> (m, tui) { received_model = m; tui.clear }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    with_test_terminal do
      inject_key("a")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_same model, received_model, "model should be preserved when update returns Cmd only"
  end

  def test_update_can_return_nil
    model = Ractor.make_shareable({ count: 0 }, copy: true)
    received_model = nil
    call_count = 0

    view = -> (m, tui) { received_model = m; tui.clear }
    update = -> (_msg, _m) do
      call_count += 1
      (call_count >= 2) ? Rooibos::Command.exit : nil
    end

    with_test_terminal do
      inject_key("a")
      inject_key("b")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_same model, received_model, "model should be preserved when update returns nil"
  end

  def test_view_returning_nil_raises_error
    model = Ractor.make_shareable({ text: "hello" }, copy: true)

    view = -> (_m, _t) { nil }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("q")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_match(/\bnil\b/i, error.message, "error message should mention 'nil'")
  end

  def test_view_returning_clear_renders_empty_screen
    model = Ractor.make_shareable({ text: "hello" }, copy: true)
    view_called = false

    view = -> (_m, tui) { view_called = true; tui.clear }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    # tui.clear is the intentional way to render nothing
    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert view_called, "view should have been called"
  end

  def test_mutable_model_allowed_in_production_mode
    mutable_model = { count: 0 } # NOT frozen

    view = -> (_m, tui) { tui.clear }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    RatatuiRuby::Debug.suppress_debug_mode do
      with_test_terminal do
        inject_key("q")
        # Should NOT raise - validation is skipped in production mode
        Rooibos::Runtime.run(model: mutable_model, view:, update:)
      end
    end
  end

  def test_mutable_model_raises_error
    mutable_model = { count: 0 } # NOT frozen

    view = -> (_m, tui) { tui.clear }
    update = -> (_msg, _m) { Rooibos::Command.exit }

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("q")
        Rooibos::Runtime.run(model: mutable_model, view:, update:)
      end
    end

    assert_match ractor_error_pattern, error.message
  end

  def test_update_returning_mutable_model_raises_error
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    view = -> (_m, tui) { tui.clear }
    update = -> (_msg, _m) { { count: 1 } } # Returns mutable hash - NOT frozen

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("a")
        inject_key("q")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_match ractor_error_pattern, error.message
  end

  def test_update_returning_frozen_model_succeeds
    model = Ractor.make_shareable({ count: 0 }, copy: true)
    final_model = nil

    view = -> (m, tui) { final_model = m; tui.clear }
    update = -> (msg, m) do
      msg.q? ? [m, Rooibos::Command.exit] : { count: m[:count] + 1 }.freeze
    end

    with_test_terminal do
      inject_key("a") # Triggers update that returns frozen model
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal({ count: 1 }, final_model)
  end

  def test_init_triggers_update_before_first_event
    model = Ractor.make_shareable({ initialized: false }, copy: true)
    init_ran = false

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      when :init_complete
        init_ran = true
        [Ractor.make_shareable({ initialized: true }, copy: true), nil]
      else
        [m, Rooibos::Command.exit]
      end
    end

    # command: is a Cmd that returns a message
    init_cmd = Rooibos::Command.custom(INIT_COMPLETE_COMMAND)

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:, command: init_cmd)
    end

    assert init_ran, "init command should trigger update with :init_complete message"
  end

  def test_update_receives_message_from_successful_command
    model = Ractor.make_shareable({ output: nil }, copy: true)
    received_stdout = nil

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      in { type: :system, envelope: :got_output, status: 0, stdout: }
        received_stdout = stdout.strip
        assert Ractor.shareable?(msg), "Background message must be Ractor-shareable"
        [Ractor.make_shareable({ output: stdout }), Rooibos::Command.exit]
      else
        # First event triggers the exec command
        [m, Rooibos::Command.system("echo hello", :got_output)]
      end
    end

    # Stub Open3.capture3 to avoid actual shell execution
    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["hello\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a") # triggers exec
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "hello", received_stdout
  end

  def test_update_receives_message_from_failed_command
    model = Ractor.make_shareable({ error: nil }, copy: true)
    received_stderr = nil

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      in { type: :system, envelope: :ran_cmd, stderr:, status: } unless status == 0
        received_stderr = stderr
        assert Ractor.shareable?(msg), "Background message must be Ractor-shareable"
        [Ractor.make_shareable({ error: stderr }), Rooibos::Command.exit]
      else
        [m, Rooibos::Command.system("false", :ran_cmd)]
      end
    end

    # Stub Open3.capture3 for failure
    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 1 }
    Open3.stub(:capture3, ["", "command failed\n", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "command failed\n", received_stderr
  end

  def test_runtime_executes_command_system_success_with_stderr_noise
    # Some programs write output to stdout AND noise/warnings to stderr on success
    model = Ractor.make_shareable({ output: nil, noise: nil }, copy: true)
    received_stdout = nil
    received_stderr = nil

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      in { type: :system, envelope: :ran_cmd, status: 0, stdout:, stderr: }
        received_stdout = stdout
        received_stderr = stderr
        [Ractor.make_shareable({ output: stdout, noise: stderr }), Rooibos::Command.exit]
      else
        [m, Rooibos::Command.system("compiler --verbose", :ran_cmd)]
      end
    end

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["compiled.o\n", "warning: deprecated syntax\n", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "compiled.o\n", received_stdout
    assert_equal "warning: deprecated syntax\n", received_stderr
  end

  def test_runtime_dispatches_mapped_command
    model = Ractor.make_shareable({ output: nil }, copy: true)
    received_msg = nil

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      when Array
        if msg[0] == :parent && msg[1].is_a?(Rooibos::Message::System::Batch)
          received_msg = msg
          batch = msg[1]
          [Ractor.make_shareable({ output: batch.stdout }), Rooibos::Command.exit]
        else
          m
        end
      else
        # First event triggers the mapped command
        inner_cmd = Rooibos::Command.system("echo hello", :inner_done)
        mapped_cmd = Rooibos::Command.map(inner_cmd) { |m| [:parent, m] }
        [m, mapped_cmd]
      end
    end

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["hello\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a") # triggers mapped command
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_kind_of Rooibos::Message::System::Batch, received_msg[1], "Should receive System::Batch"
    assert_equal :inner_done, received_msg[1].envelope, "Inner envelope should be preserved"
  end

  def test_sync_event_waits_for_pending_threads
    # When the runtime sees a Sync event, it should wait for all pending
    # threads to complete and process their results before continuing.
    model = Ractor.make_shareable({ result: nil }, copy: true)
    result_seen_before_quit = nil

    view = -> (_m, tui) { tui.clear }
    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        if msg.code == "a"
          cmd = Rooibos::Command.system("echo 'loaded'", :data)
          [m, cmd]
        elsif msg.q?
          result_seen_before_quit = m[:result]
          [m, Rooibos::Command.exit]
        else
          m
        end
      when -> (msg) { msg.respond_to?(:envelope) && msg.envelope == :data }
        Ractor.make_shareable({ result: msg.stdout.strip })
      else
        m
      end
    end

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["loaded\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a")       # Triggers async command
        inject_sync           # Wait for command to complete
        inject_key(:q)        # Quit - should see result
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "loaded", result_seen_before_quit,
      "Sync should ensure async result is processed before next event"
  end

  def test_quit_drains_channel_before_exiting
    # When a command pushes messages and the user quits immediately after,
    # those messages should still be processed. This tests graceful exit.
    #
    # We use a custom command that pushes to the channel synchronously
    # during dispatch, guaranteeing the message is there when quit runs.
    messages = []
    model = Ractor.make_shareable({})
    view = -> (_m, tui) { tui.clear }

    # Command that pushes immediately when called
    fast_command = Class.new do
      include Rooibos::Command::Custom
      def call(out, _token)
        out.put(:fast_message, :data)
      end
    end

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, fast_command.new]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      when Array
        messages << msg
        [m, nil]
      else
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s") # Start command that pushes immediately
      # NO inject_sync - quit happens before channel is polled
      inject_key("q") # Quit
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(messages)

    # Without graceful_exit!, this fails - message is lost
    # With graceful_exit!, this passes - message is drained before exit
    assert_includes messages.map(&:first), :fast_message,
      "Quit should drain pending messages before exiting"
  end

  # Regression test: View must be able to query terminal dimensions.
  # BUG: When View.call is inside the draw block, viewport_area is called during
  #      an active draw context, which raises Error::Invariant in RatatuiRuby.
  # FIX: Move View.call outside the draw block so queries work.
  def test_view_can_query_viewport_area_without_deadlock
    model = Ractor.make_shareable({ width: nil }, copy: true)
    final_model = nil

    # View that queries terminal dimensions - raises Invariant if View is inside draw
    view = -> (m, tui) {
      width = tui.viewport_area.width
      tui.paragraph(text: "Width: #{width}")
    }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        final_model = Ractor.make_shareable({ width: 80 }, copy: true)
        [final_model, Rooibos::Command.exit]
      else
        m
      end
    end

    # This raises Error::Invariant if View.call is inside draw block.
    with_test_terminal(80, 24) do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    # If we get here, no deadlock occurred
    assert_equal 80, final_model[:width], "View should be able to query viewport_area"
  end

  # Init runs after terminal is ready. It can query terminal dimensions,
  # compute layout areas, or do other terminal-dependent initialization.
  def test_init_can_query_terminal_size
    init_called = false
    captured_size = nil

    fragment = Module.new
    fragment.const_set(:Init, -> {
      init_called = true
      captured_size = RatatuiRuby.terminal_size
      Ractor.make_shareable({ width: captured_size.width })
    })
    fragment.const_set(:Update, -> (msg, m) { Rooibos::Command.exit })
    fragment.const_set(:View, -> (_m, tui) { tui.clear })

    with_test_terminal(80, 24) do
      inject_key("q")
      Rooibos::Runtime.run(fragment)
    end

    assert init_called, "Init should have been called"
    assert_equal 80, captured_size.width, "Init should be able to query terminal_size"
  end
end
