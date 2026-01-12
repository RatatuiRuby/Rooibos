# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "ratatui_ruby/test_helper"

# Documents that procs, lambdas, Method objects, and service objects all work
# as callable parameters for the Tea runtime.
class TestCallableTypes < Minitest::Test
  include RatatuiRuby::TestHelper

  def test_procs_work_as_view_and_update
    model = Ractor.make_shareable({ text: "hello" })
    view_called = false
    update_called = false

    view = proc do |_model, tui|
      view_called = true
      tui.clear
    end

    update = proc do |_message, current_model|
      update_called = true
      [current_model, RatatuiRuby::Tea::Command.exit]
    end

    with_test_terminal do
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert view_called, "proc should work as view"
    assert update_called, "proc should work as update"
  end

  def test_lambdas_work_as_view_and_update
    model = Ractor.make_shareable({ text: "hello" })
    view_called = false
    update_called = false

    view = lambda do |_model, tui|
      view_called = true
      tui.clear
    end

    update = lambda do |_message, current_model|
      update_called = true
      [current_model, RatatuiRuby::Tea::Command.exit]
    end

    with_test_terminal do
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert view_called, "lambda should work as view"
    assert update_called, "lambda should work as update"
  end

  def view_method(_model, tui)
    @view_method_called = true
    tui.clear
  end

  def update_method(_message, current_model)
    @update_method_called = true
    [current_model, RatatuiRuby::Tea::Command.exit]
  end

  def test_method_objects_work_as_view_and_update
    model = Ractor.make_shareable({ text: "hello" })
    @view_method_called = false
    @update_method_called = false

    with_test_terminal do
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(
        model:,
        view: method(:view_method),
        update: method(:update_method)
      )
    end

    assert @view_method_called, "Method object should work as view"
    assert @update_method_called, "Method object should work as update"
  end

  # Functional objects: any object responding to #call

  class MyView
    attr_reader :called

    def initialize
      @called = false
    end

    def call(_model, tui)
      @called = true
      tui.clear
    end
  end

  class MyUpdate
    attr_reader :called

    def initialize
      @called = false
    end

    def call(_message, current_model)
      @called = true
      [current_model, RatatuiRuby::Tea::Command.exit]
    end
  end

  def test_service_objects_work_as_view_and_update
    model = Ractor.make_shareable({ text: "hello" })
    view = MyView.new
    update = MyUpdate.new

    with_test_terminal do
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert view.called, "service object should work as view"
    assert update.called, "service object should work as update"
  end

  # ==========================================================================
  # Lightweight Command Callables
  #
  # Documents that lambdas, procs, Method objects, and callable instances work
  # as custom commands when they define singleton methods for the Command interface.
  # This is the lightweight alternative to including Command::Custom in a class.
  # ==========================================================================

  # Lambda with singleton methods works as a custom command
  LambdaCommand = -> (out, _token) { out.put(:lambda_done) }
  def LambdaCommand.tea_command? = true
  def LambdaCommand.tea_cancellation_grace_period = 0.1

  def test_lambda_with_singleton_methods_works_as_command
    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, LambdaCommand]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :lambda_done, "Lambda with singleton methods should work as command"
  end

  # Proc with singleton methods works as a custom command
  ProcCommand = proc { |out, _token| out.put(:proc_done) }
  def ProcCommand.tea_command? = true
  def ProcCommand.tea_cancellation_grace_period = 0.1

  def test_proc_with_singleton_methods_works_as_command
    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, ProcCommand]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :proc_done, "Proc with singleton methods should work as command"
  end

  # Method object with singleton methods works as a custom command
  def command_method(out, _token)
    out.put(:method_done)
  end

  def test_method_object_with_singleton_methods_works_as_command
    method_cmd = method(:command_method)
    method_cmd.define_singleton_method(:tea_command?) { true }
    method_cmd.define_singleton_method(:tea_cancellation_grace_period) { 0.1 }

    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, method_cmd]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :method_done, "Method object with singleton methods should work as command"
  end

  # Callable instance with singleton methods works as a custom command
  class CallableCommand
    def call(out, _token)
      out.put(:callable_done)
    end
  end

  def test_callable_instance_with_singleton_methods_works_as_command
    callable_cmd = CallableCommand.new
    callable_cmd.define_singleton_method(:tea_command?) { true }
    callable_cmd.define_singleton_method(:tea_cancellation_grace_period) { 0.1 }

    events = []
    model = Ractor.make_shareable({})
    view = -> (_m, t) { t.clear }

    update = -> (msg, m) do
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, callable_cmd]
        when "q" then [m, RatatuiRuby::Tea::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      RatatuiRuby::Tea::Runtime.run(model:, view:, update:)
    end

    assert_includes events, :callable_done, "Callable instance with singleton methods should work as command"
  end
end
