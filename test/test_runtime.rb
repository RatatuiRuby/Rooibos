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
  INIT_COMPLETE_COMMAND = -> (out, _token) { out.put(:init_complete) }
  def INIT_COMPLETE_COMMAND.rooibos_command? = true
  def INIT_COMPLETE_COMMAND.rooibos_cancellation_grace_period = 0.1
  Ractor.make_shareable(INIT_COMPLETE_COMMAND)

  private def ractor_error_pattern
    /ractor|frozen|shareable/i
  end

  # Class-scope state variables - initialized in setup before each test
  def setup
    @@view_args = nil
    @@received_model = nil
    @@call_count = 0
    @@view_called = false
    @@final_model = nil
    @@init_ran = false
    @@received_stdout = nil
    @@received_stderr = nil
    @@received_msg = nil
    @@result_seen_before_quit = nil
    @@messages = []
    @@init_called = false
    @@init_captured_size = nil
    @@command_class = nil
  end

  # ===========================================================================
  # Shared lambdas for common patterns
  # ===========================================================================

  # Consolidated view that captures all state for verification
  # Sets: @@view_args, @@received_model, @@final_model, @@view_called
  RecordingView = -> (m, tui) do
    TestRuntime.class_variable_set(:@@view_args, [m, tui])
    TestRuntime.class_variable_set(:@@received_model, m)
    TestRuntime.class_variable_set(:@@final_model, m)
    TestRuntime.class_variable_set(:@@view_called, true)
    tui.clear
  end

  # View that returns nil (for testing error path)
  ViewReturnsNil = -> (_m, _t) { nil }

  # View that queries viewport
  ViewQueriesViewport = -> (m, tui) do
    width = tui.viewport_area.width
    tui.paragraph(text: "Width: #{width}")
  end

  # ===========================================================================
  # Consolidated RecordingUpdate - handles all cases via message dispatch
  # ===========================================================================

  RecordingUpdate = -> (msg, m) do
    # Increment call count on every invocation
    count = TestRuntime.class_variable_get(:@@call_count) + 1
    TestRuntime.class_variable_set(:@@call_count, count)

    case msg
    # Init message from custom command
    in :init_complete
      TestRuntime.class_variable_set(:@@init_ran, true)
      [Ractor.make_shareable({ initialized: true }, copy: true), nil]

    # System command results (successful with :got_output envelope)
    in { type: :system, envelope: :got_output, status: 0, stdout: }
      TestRuntime.class_variable_set(:@@received_stdout, stdout.strip)
      raise "Background message must be Ractor-shareable" unless Ractor.shareable?(msg)
      [Ractor.make_shareable({ output: stdout }), Rooibos::Command.exit]

    # System command results (failed with non-zero status)
    in { type: :system, envelope: :ran_cmd, stderr:, status: } if status != 0
      TestRuntime.class_variable_set(:@@received_stderr, stderr)
      raise "Background message must be Ractor-shareable" unless Ractor.shareable?(msg)
      [Ractor.make_shareable({ error: stderr }), Rooibos::Command.exit]

    # System command results (success with stdout+stderr)
    in { type: :system, envelope: :ran_cmd, status: 0, stdout:, stderr: }
      TestRuntime.class_variable_set(:@@received_stdout, stdout)
      TestRuntime.class_variable_set(:@@received_stderr, stderr)
      [Ractor.make_shareable({ output: stdout, noise: stderr }), Rooibos::Command.exit]

    # System command results with :data envelope (sync test)
    in { envelope: :data, stdout: }
      Ractor.make_shareable({ result: stdout.strip })

    # Mapped command results (array wrapper)
    in [:parent, Rooibos::Message::System::Batch => batch]
      TestRuntime.class_variable_set(:@@received_msg, msg)
      [Ractor.make_shareable({ output: batch.stdout }), Rooibos::Command.exit]

    # Other array messages - pass through
    in Array
      m

    # Key 'q' - exit
    in RatatuiRuby::Event::Key if msg.q?
      TestRuntime.class_variable_set(:@@result_seen_before_quit, m[:result]) if m.is_a?(Hash) && m.key?(:result)
      new_model = Ractor.make_shareable({ width: 80 }, copy: true) if m.is_a?(Hash) && m.key?(:width)
      TestRuntime.class_variable_set(:@@final_model, new_model) if new_model
      [new_model || m, Rooibos::Command.exit]

    # Key 'n' - return nil (for testing nil return handling)
    in RatatuiRuby::Event::Key if msg.code == "n"
      nil

    # Key 'x' - return non-shareable object (for testing error path)
    in RatatuiRuby::Event::Key if msg.code == "x"
      obj = Object.new
      def obj.callback
        @callback ||= -> { self }
      end
      obj.callback
      obj

    # Key 'p' - return plain model, not tuple (for testing plain model return)
    in RatatuiRuby::Event::Key if msg.code == "p"
      m

    # Key 'a' - dispatch command based on model context
    in RatatuiRuby::Event::Key if msg.code == "a"
      if m.is_a?(Hash) && m.key?(:result)
        [m, Rooibos::Command.system("echo 'loaded'", :data)]
      elsif m.is_a?(Hash) && m.key?(:noise)
        [m, Rooibos::Command.system("compiler --verbose", :ran_cmd)]
      elsif m.is_a?(Hash) && m.key?(:output)
        [m, Rooibos::Command.system("echo hello", :got_output)]
      elsif m.is_a?(Hash) && m.key?(:error)
        [m, Rooibos::Command.system("false", :ran_cmd)]
      elsif m.is_a?(Hash) && m.key?(:count)
        { count: m[:count] + 1 }.freeze
      else
        inner_cmd = Rooibos::Command.system("echo hello", :inner_done)
        mapped_cmd = Rooibos::Command.map(inner_cmd) { |msg| [:parent, msg] }
        [m, mapped_cmd]
      end

    # Other key events - pass through
    in RatatuiRuby::Event::Key
      m

    # Default - exit
    else
      [m, Rooibos::Command.exit]
    end
  end

  # DrainUpdate - handles command class instantiation via @@command_class
  # Used for testing channel draining on quit
  DrainUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s"
        cmd_class = TestRuntime.class_variable_get(:@@command_class)
        [m, cmd_class.new]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    when Array
      TestRuntime.class_variable_set(:@@messages, TestRuntime.class_variable_get(:@@messages) + [msg])
      [m, nil]
    else
      [m, nil]
    end
  end

  # ===========================================================================
  # Tests
  # ===========================================================================

  def test_runtime_class_exists
    assert_kind_of Class, Rooibos::Runtime
  end

  def test_runtime_responds_to_run
    assert_respond_to Rooibos::Runtime, :run
  end

  def test_run_accepts_fps_parameter
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    view = ClearView

    update = ExitOnAnyKeyUpdate

    result = with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:, fps: 30)
    end

    assert_equal model, result
  end

  def test_fps_calculates_float_timeout
    captured_timeout = nil

    model = Ractor.make_shareable({ count: 0 }, copy: true)

    view = ClearView

    update = ExitOnAnyKeyUpdate

    with_test_terminal do
      inject_key("q")

      original_poll = RatatuiRuby.method(:poll_event)
      RatatuiRuby.stub(:poll_event, -> (timeout: nil) {
        captured_timeout = timeout
        original_poll.call(timeout:)
      }) do
        Rooibos::Runtime.run(model:, view:, update:, fps: 60)
      end
    end

    assert_kind_of Float, captured_timeout, "timeout should be a Float, not Integer"
    assert_operator captured_timeout, :>, 0, "timeout should be positive (not 0 from integer division)"
    assert_in_delta 1.0 / 60, captured_timeout, 0.001, "timeout should be ~0.0167 for 60fps"
  end

  def test_view_receives_model_and_tui
    @@view_args = nil
    model = Ractor.make_shareable({ text: "hello" }, copy: true)

    view = RecordingView

    update = ExitOnAnyKeyUpdate

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal model, @@view_args[0], "view should receive model as first arg"
    assert_kind_of RatatuiRuby::TUI, @@view_args[1], "view should receive TUI as second arg"
  end

  def test_init_callable_object
    # Create a callable object that is Ractor-shareable
    callable_init = Class.new do
      def call
        [Ractor.make_shareable({ count: 0 }, copy: true), nil]
      end
    end.new.freeze

    fragment = Module.new
    fragment.const_set(:Init, callable_init)

    update = ExitOnAnyKeyUpdate
    fragment.const_set(:Update, update)

    view = ClearView
    fragment.const_set(:View, view)

    result = with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(fragment)
    end

    assert_equal({ count: 0 }, result)
  end

  def test_init_invalid_callable
    fragment = Module.new
    fragment.const_set(:Init, Object.new)

    update = ExitOnAnyKeyUpdate
    fragment.const_set(:Update, update)

    view = ClearView
    fragment.const_set(:View, view)

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos::Runtime.run(fragment)
      end
    end
    assert_match(/Fragment::Init must respond to :call/, error.message)
  end

  def test_model_invalid_new
    fragment = Module.new
    fragment.const_set(:Model, Object.new)

    update = ExitOnAnyKeyUpdate
    fragment.const_set(:Update, update)

    view = ClearView
    fragment.const_set(:View, view)

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        Rooibos::Runtime.run(fragment)
      end
    end
    assert_match(/Fragment::Model must respond to :new/, error.message)
  end

  def test_update_can_return_plain_model
    @@call_count = 0
    model = Ractor.make_shareable({})

    view = ClearView

    update = RecordingUpdate

    with_test_terminal do
      inject_key("p")  # Returns plain model, not tuple
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal 2, @@call_count, "update should be called twice (once per event)"
  end

  def test_update_detects_array_model_vs_tuple
    @@received_model = nil
    model = [:item1, :item2].freeze

    view = RecordingView

    update = ExitOnQUpdate

    with_test_terminal do
      inject_key("a")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal [:item1, :item2], @@received_model, "array model should not be confused with [model, cmd] tuple"
  end

  def test_update_can_return_command_only
    @@received_model = nil
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    view = RecordingView

    update = ExitOnAnyKeyUpdate

    with_test_terminal do
      inject_key("a")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_same model, @@received_model, "model should be preserved when update returns Cmd only"
  end

  def test_update_can_return_nil
    @@received_model = nil
    @@call_count = 0
    model = Ractor.make_shareable({})

    view = RecordingView

    update = RecordingUpdate

    with_test_terminal do
      inject_key("n")  # Returns nil
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal model, @@received_model, "model should be preserved when update returns nil"
  end

  def test_view_returning_nil_raises_error
    model = Ractor.make_shareable({ text: "hello" }, copy: true)

    view = ViewReturnsNil

    update = ExitOnAnyKeyUpdate

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("q")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_match(/\bnil\b/i, error.message, "error message should mention 'nil'")
  end

  def test_view_returning_clear_renders_empty_screen
    @@view_called = false
    model = Ractor.make_shareable({ text: "hello" }, copy: true)

    view = RecordingView

    update = ExitOnAnyKeyUpdate

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert @@view_called, "view should have been called"
  end

  def test_mutable_model_allowed_in_production_mode
    mutable_model = { count: 0 }

    view = ClearView

    update = ExitOnAnyKeyUpdate

    RatatuiRuby::Debug.suppress_debug_mode do
      with_test_terminal do
        inject_key("q")
        Rooibos::Runtime.run(model: mutable_model, view:, update:)
      end
    end
  end

  def test_mutable_model_raises_error
    # Create an object that CANNOT be made shareable - contains a Proc with captured self
    non_shareable_model = Object.new
    def non_shareable_model.callback
      @callback ||= -> { self }  # Captures self in a closure
    end
    non_shareable_model.callback  # Ensure it's created

    view = ClearView

    update = ExitOnAnyKeyUpdate

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("q")
        Rooibos::Runtime.run(model: non_shareable_model, view:, update:)
      end
    end

    assert_match ractor_error_pattern, error.message
  end

  def test_update_returning_non_shareable_model_raises_error
    model = Ractor.make_shareable({})

    view = ClearView

    update = RecordingUpdate

    error = assert_raises(Rooibos::Error::Invariant) do
      with_test_terminal do
        inject_key("x")  # Returns non-shareable object
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_match ractor_error_pattern, error.message
  end

  def test_update_returning_frozen_model_succeeds
    @@final_model = nil
    model = Ractor.make_shareable({ count: 0 }, copy: true)

    view = RecordingView

    update = RecordingUpdate

    with_test_terminal do
      inject_key("a")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal({ count: 1 }, @@final_model)
  end

  def test_init_triggers_update_before_first_event
    @@init_ran = false
    model = Ractor.make_shareable({ initialized: false }, copy: true)

    view = ClearView

    update = RecordingUpdate

    init_cmd = Rooibos::Command.custom(INIT_COMPLETE_COMMAND)

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:, command: init_cmd)
    end

    assert @@init_ran, "init command should trigger update with :init_complete message"
  end

  def test_update_receives_message_from_successful_command
    @@received_stdout = nil
    model = Ractor.make_shareable({ output: nil }, copy: true)

    view = ClearView

    update = RecordingUpdate

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["hello\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "hello", @@received_stdout
  end

  def test_update_receives_message_from_failed_command
    @@received_stderr = nil
    model = Ractor.make_shareable({ error: nil }, copy: true)

    view = ClearView

    update = RecordingUpdate

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 1 }
    Open3.stub(:capture3, ["", "command failed\n", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "command failed\n", @@received_stderr
  end

  def test_runtime_executes_command_system_success_with_stderr_noise
    @@received_stdout = nil
    @@received_stderr = nil
    model = Ractor.make_shareable({ output: nil, noise: nil }, copy: true)

    view = ClearView

    update = RecordingUpdate

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["compiled.o\n", "warning: deprecated syntax\n", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "compiled.o\n", @@received_stdout
    assert_equal "warning: deprecated syntax\n", @@received_stderr
  end

  def test_runtime_dispatches_mapped_command
    @@received_msg = nil
    model = Ractor.make_shareable({})

    view = ClearView

    update = RecordingUpdate

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["hello\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a")
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_kind_of Rooibos::Message::System::Batch, @@received_msg[1], "Should receive System::Batch"
    assert_equal :inner_done, @@received_msg[1].envelope, "Inner envelope should be preserved"
  end

  def test_sync_event_waits_for_pending_threads
    @@result_seen_before_quit = nil
    model = Ractor.make_shareable({ result: nil }, copy: true)

    view = ClearView

    update = RecordingUpdate

    require "open3"
    mock_status = Object.new
    mock_status.define_singleton_method(:exitstatus) { 0 }
    Open3.stub(:capture3, ["loaded\n", "", mock_status]) do
      with_test_terminal do
        inject_key("a")
        inject_sync
        inject_key(:q)
        Rooibos::Runtime.run(model:, view:, update:)
      end
    end

    assert_equal "loaded", @@result_seen_before_quit,
      "Sync should ensure async result is processed before next event"
  end

  def test_quit_drains_channel_before_exiting
    @@messages = []
    model = Ractor.make_shareable({})

    view = ClearView

    fast_command = Class.new do
      include Rooibos::Command::Custom
      def call(out, _token)
        out.put(:fast_message, :data)
      end
    end

    @@command_class = fast_command
    update = DrainUpdate

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)
    assert_includes @@messages.map(&:first), :fast_message,
      "Quit should drain pending messages before exiting"
  end

  def test_view_can_query_viewport_area_without_deadlock
    @@final_model = nil
    model = Ractor.make_shareable({ width: nil }, copy: true)

    view = ViewQueriesViewport

    update = RecordingUpdate

    with_test_terminal(80, 24) do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_equal 80, @@final_model[:width], "View should be able to query viewport_area"
  end

  def test_init_can_query_terminal_size
    @@init_called = false
    @@init_captured_size = nil
    fragment = Module.new

    init = Class.new do
      @called = false
      @captured_size = nil
      def self.call
        TestRuntime.class_variable_set(:@@init_called, true)
        size = RatatuiRuby.terminal_size
        TestRuntime.class_variable_set(:@@init_captured_size, size)
        Ractor.make_shareable({ width: size.width })
      end
    end
    fragment.const_set(:Init, init)

    update = RecordingUpdate
    fragment.const_set(:Update, update)

    view = ClearView
    fragment.const_set(:View, view)

    with_test_terminal(80, 24) do
      inject_key("q")
      Rooibos::Runtime.run(fragment)
    end

    assert @@init_called, "Init should have been called"
    assert_equal 80, @@init_captured_size.width, "Init should be able to query terminal_size"
  end
end
