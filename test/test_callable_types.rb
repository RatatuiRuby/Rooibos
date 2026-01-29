# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

# Documents that procs, lambdas, Method objects, and service objects all work
# as callable parameters for the Rooibos runtime.
#
# IMPORTANT: Callables must be able to be made Ractor-shareable. This means:
# - Procs/lambdas must be defined at CLASS/MODULE SCOPE (not inside methods)
# - Method objects must come from modules (not instance methods)
# - Service objects must be freezable after creation
class TestCallableTypes < Minitest::Test
  include Rooibos::TestHelper

  def teardown
    @@proc_view_called = false
    @@proc_update_called = false
    @@lambda_view_called = false
    @@lambda_update_called = false
    @@method_view_called = false
    @@method_update_called = false
    @@service_view_called = false
    @@service_update_called = false
    CommandTestUpdate.reset!
  end

  # ==========================================================================
  # Procs and Lambdas as View/Update
  # Must be defined at class scope to be Ractor-shareable
  # ==========================================================================

  @@proc_view_called = false
  @@proc_update_called = false

  # Class-scope proc works as View callable
  ProcView = proc do |_model, tui|
    @@proc_view_called = true
    tui.clear
  end

  # Class-scope proc works as Update callable
  ProcUpdate = proc do |_message, current_model|
    @@proc_update_called = true
    [current_model, Rooibos::Command.exit]
  end

  def test_procs_work_as_view_and_update
    @@proc_view_called = false
    @@proc_update_called = false
    model = Ractor.make_shareable({ text: "hello" })

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view: ProcView, update: ProcUpdate)
    end

    assert @@proc_view_called, "proc should work as view"
    assert @@proc_update_called, "proc should work as update"
  end

  @@lambda_view_called = false
  @@lambda_update_called = false

  # Class-scope lambda works as View callable
  LambdaView = -> (_model, tui) do
    @@lambda_view_called = true
    tui.clear
  end

  # Class-scope lambda works as Update callable
  LambdaUpdate = -> (_message, current_model) do
    @@lambda_update_called = true
    [current_model, Rooibos::Command.exit]
  end

  def test_lambdas_work_as_view_and_update
    @@lambda_view_called = false
    @@lambda_update_called = false
    model = Ractor.make_shareable({ text: "hello" })

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view: LambdaView, update: LambdaUpdate)
    end

    assert @@lambda_view_called, "lambda should work as view"
    assert @@lambda_update_called, "lambda should work as update"
  end

  # ==========================================================================
  # Method Objects as View/Update
  # Must come from a module (not instance methods) to be Ractor-shareable
  # ==========================================================================

  @@method_view_called = false
  @@method_update_called = false

  module MethodCallables
    def self.view(_model, tui)
      TestCallableTypes.class_variable_set(:@@method_view_called, true)
      tui.clear
    end

    def self.update(_message, current_model)
      TestCallableTypes.class_variable_set(:@@method_update_called, true)
      [current_model, Rooibos::Command.exit]
    end
  end

  def test_method_objects_work_as_view_and_update
    @@method_view_called = false
    @@method_update_called = false
    model = Ractor.make_shareable({ text: "hello" })

    # Method objects from a MODULE (not instance) are Ractor-shareable
    view_method = MethodCallables.method(:view)
    update_method = MethodCallables.method(:update)

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view: view_method, update: update_method)
    end

    assert @@method_view_called, "Method object should work as view"
    assert @@method_update_called, "Method object should work as update"
  end

  # ==========================================================================
  # Service Objects (any object responding to #call)
  # Must be frozen to be Ractor-shareable
  # ==========================================================================

  @@service_view_called = false
  @@service_update_called = false

  class MyView
    def call(_model, tui)
      TestCallableTypes.class_variable_set(:@@service_view_called, true)
      tui.clear
    end
  end

  class MyUpdate
    def call(_message, current_model)
      TestCallableTypes.class_variable_set(:@@service_update_called, true)
      [current_model, Rooibos::Command.exit]
    end
  end

  def test_service_objects_work_as_view_and_update
    @@service_view_called = false
    @@service_update_called = false
    model = Ractor.make_shareable({ text: "hello" })

    # Service objects must be frozen to be Ractor-shareable
    view = MyView.new.freeze
    update = MyUpdate.new.freeze

    with_test_terminal do
      inject_key("q")
      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert @@service_view_called, "frozen service object should work as view"
    assert @@service_update_called, "frozen service object should work as update"
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
  def LambdaCommand.rooibos_command? = true
  def LambdaCommand.rooibos_cancellation_grace_period = 0.1

  # Module-scope Update for command tests
  module CommandTestUpdate
    class << self
      attr_accessor :events, :command_to_run
    end
    @events = []
    @command_to_run = nil

    def self.call(msg, m)
      case msg
      when RatatuiRuby::Event::Key
        case msg.code
        when "s" then [m, command_to_run]
        when "q" then [m, Rooibos::Command.exit]
        else [m, nil]
        end
      else
        events << msg
        [m, nil]
      end
    end

    def self.reset!
      @events = []
      @command_to_run = nil
    end
  end

  # Module-scope View for command tests
  module CommandTestView
    def self.call(_m, t)
      t.clear
    end
  end

  def test_lambda_with_singleton_methods_works_as_command
    CommandTestUpdate.reset!
    CommandTestUpdate.command_to_run = LambdaCommand
    model = Ractor.make_shareable({})

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view: CommandTestView, update: CommandTestUpdate)
    end

    assert_includes CommandTestUpdate.events, :lambda_done,
      "Lambda with singleton methods should work as command"
  end

  # Proc with singleton methods works as a custom command
  ProcCommand = proc { |out, _token| out.put(:proc_done) }
  def ProcCommand.rooibos_command? = true
  def ProcCommand.rooibos_cancellation_grace_period = 0.1

  def test_proc_with_singleton_methods_works_as_command
    CommandTestUpdate.reset!
    CommandTestUpdate.command_to_run = ProcCommand
    model = Ractor.make_shareable({})

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view: CommandTestView, update: CommandTestUpdate)
    end

    assert_includes CommandTestUpdate.events, :proc_done,
      "Proc with singleton methods should work as command"
  end

  # Method object with singleton methods works as a custom command
  module MethodCommand
    def self.execute(out, _token)
      out.put(:method_done)
    end

    def self.command
      cmd = method(:execute)
      cmd.define_singleton_method(:rooibos_command?) { true }
      cmd.define_singleton_method(:rooibos_cancellation_grace_period) { 0.1 }
      cmd
    end
  end

  def test_method_object_with_singleton_methods_works_as_command
    CommandTestUpdate.reset!
    CommandTestUpdate.command_to_run = MethodCommand.command
    model = Ractor.make_shareable({})

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view: CommandTestView, update: CommandTestUpdate)
    end

    assert_includes CommandTestUpdate.events, :method_done,
      "Method object with singleton methods should work as command"
  end

  # Callable instance with singleton methods works as a custom command
  class CallableCommand
    def call(out, _token)
      out.put(:callable_done)
    end
  end

  def test_callable_instance_with_singleton_methods_works_as_command
    callable_cmd = CallableCommand.new
    callable_cmd.define_singleton_method(:rooibos_command?) { true }
    callable_cmd.define_singleton_method(:rooibos_cancellation_grace_period) { 0.1 }

    CommandTestUpdate.reset!
    CommandTestUpdate.command_to_run = callable_cmd
    model = Ractor.make_shareable({})

    with_test_terminal do
      inject_key("s")
      inject_key("q")
      Rooibos::Runtime.run(model:, view: CommandTestView, update: CommandTestUpdate)
    end

    assert_includes CommandTestUpdate.events, :callable_done,
      "Callable instance with singleton methods should work as command"
  end
end
