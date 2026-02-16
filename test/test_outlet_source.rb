# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "test_helper"
require "rooibos/test_helper"

# Integration tests for Outlet#source demonstrating command composition.
#
# These tests serve as documentation for app developers who need to
# orchestrate multi-step workflows within custom commands.
class TestOutletSource < Minitest::Test
  include Rooibos::TestHelper

  # Class-scope state for lambda-based updates
  def setup
    @@messages = []
    @@command = nil
  end

  def teardown
    @@messages = []
    @@command = nil
  end

  ClearView = -> (_m, t) { t.clear }

  # Base source update - handles s for start, q for quit
  SourceUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s" then [m, TestOutletSource.class_variable_get(:@@command)]
      when "q" then [m, Rooibos::Command.exit]
      else [m, nil]
      end
    else
      TestOutletSource.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # Cancel source update - handles s for start with model tracking, c for cancel, q for quit
  CancelSourceUpdate = -> (msg, m) do
    case msg
    when RatatuiRuby::Event::Key
      case msg.code
      when "s"
        cmd = TestOutletSource.class_variable_get(:@@command)
        [Ractor.make_shareable({ cmd: }), cmd]
      when "c"
        [m, Rooibos::Command.cancel(m[:cmd])]
      when "q"
        [m, Rooibos::Command.exit]
      else
        [m, nil]
      end
    else
      TestOutletSource.class_variable_get(:@@messages) << msg
      [m, nil]
    end
  end

  # A command that fetches a result, then uses it for a second fetch.
  # Demonstrates the basic source pattern: call a child command,
  # wait for its result, then continue processing.
  TwoStepFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      # Step 1: Get first value
      step1_result = out.source(TestOutletSource::StepOneCommand.new, token)
      return if step1_result.nil?

      # Step 2: Use it to get second value
      step2_result = out.source(TestOutletSource::StepTwoCommand.new(step1_result), token)
      return if step2_result.nil?

      # Final output - must be Ractor-shareable for debug mode
      out.put(:two_step_complete, Ractor.make_shareable({ step1: step1_result, step2: step2_result }))
    end
  end

  StepOneCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, _token)
      out.put(:step_one_value, 42)
    end
  end

  StepTwoCommand = Data.define(:input) do
    include Rooibos::Command::Custom

    def call(out, _token)
      # Double the input value
      out.put(:step_two_value, input.last * 2)
    end
  end

  def test_source_orchestrates_multi_step_commands
    model = Ractor.make_shareable({})

    @@command = TwoStepFetch.new
    view = ClearView
    update = SourceUpdate

    with_test_terminal do
      inject_key("s")  # Start two-step fetch
      inject_sync      # Wait for command to complete
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_no_errors(@@messages)

    # The final composed result should arrive
    final = @@messages.find { |m| m.is_a?(Array) && m.first == :two_step_complete }
    assert final, "Should receive composed result, got: #{@@messages.inspect}"
    assert_equal({ step1: [:step_one_value, 42], step2: [:step_two_value, 84] }, final.last)
  end

  # A command that bails out when cancellation is detected.
  # Demonstrates how source returns nil on cancellation, allowing
  # the parent command to clean up and exit gracefully.
  CancellableMultiStep = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.put(:multi_step_started)

      # This step takes a while
      result = out.source(TestOutletSource::SlowCommand.new, token)

      if result.nil?
        out.put(:multi_step_canceled)
        return
      end

      out.put(:multi_step_finished, result)
    end
  end

  SlowCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      sleep 0.02 until token.canceled?
      # If canceled, never puts, so source returns nil
    end
  end

  def test_source_returns_nil_when_parent_canceled
    model = Ractor.make_shareable({ cmd: nil })

    @@command = CancellableMultiStep.new
    view = ClearView
    update = CancelSourceUpdate

    with_test_terminal do
      inject_key("s")  # Start multi-step command
      inject_key("c")  # Cancel it
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    assert_includes @@messages, :multi_step_started
    assert_includes @@messages, :multi_step_canceled
    refute @@messages.any? { |m| m.is_a?(Array) && m.first == :multi_step_finished }
  end

  # A command that handles exceptions from child commands.
  # Demonstrates how source propagates exceptions, allowing the
  # parent to catch and handle them appropriately.
  ResilientFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      out.source(TestOutletSource::FailingCommand.new, token, timeout: 0.5)
      out.put(:should_not_reach)
    rescue ArgumentError => e
      out.put(:error_handled, Ractor.make_shareable({ message: e.message.freeze }))
    end
  end

  FailingCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      raise ArgumentError, "simulated failure"
    end
  end

  def test_source_propagates_exceptions_for_handling
    model = Ractor.make_shareable({})

    @@command = ResilientFetch.new
    view = ClearView
    update = SourceUpdate

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")

      Rooibos::Runtime.run(model:, view:, update:)
    end

    error_msg = @@messages.find { |m| m.is_a?(Array) && m.first == :error_handled }
    refute_nil error_msg, "Parent should catch and handle the exception"
    assert_equal "simulated failure", error_msg.last[:message]
    refute @@messages.include?(:should_not_reach)
  end

  # A command that respects a timeout when child command hangs.
  # Demonstrates how timeout prevents indefinite blocking.
  TimeoutAwareFetch = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      result = out.source(TestOutletSource::HungCommand.new, token, timeout: 0.05)

      if result.nil?
        out.put(:fetch_timed_out)
      else
        out.put(:fetch_succeeded, result)
      end
    end
  end

  HungCommand = Data.define do
    include Rooibos::Command::Custom

    def call(_out, _token)
      sleep 10 # Never completes
    end
  end

  def test_source_times_out_with_timeout
    model = Ractor.make_shareable({})

    @@command = TimeoutAwareFetch.new
    view = ClearView
    update = SourceUpdate

    start_time = Time.now

    with_test_terminal do
      inject_key("s")
      inject_sync
      inject_key("q")

      Rooibos::Runtime.run(model:, view:, update:)
    end

    elapsed = Time.now - start_time

    assert_includes @@messages, :fetch_timed_out
    assert_operator elapsed, :<, 5.0, "Should timeout quickly, not wait 10s"
  end

  # Demonstrates sync→parallel→sync orchestration within a custom command.
  # This pattern is essential for workflows that need to:
  # 1. Perform sequential setup (authentication, config loading)
  # 2. Launch multiple parallel operations (fetch multiple resources)
  # 3. Aggregate results and continue with sequential processing
  SyncParallelSyncCommand = Data.define do
    include Rooibos::Command::Custom

    def call(out, token)
      # Phase 1: Synchronous setup
      setup_result = out.source(TestOutletSource::SetupCommand.new, token)
      return if setup_result.nil?
      out.put(:phase1_complete, setup_result.last)

      # Phase 2: Parallel fetch using Command.all
      # NOTE: Workers must be Ractor-shareable for Command.all
      parallel_result = out.source(
        Rooibos::Command.all(:parallel_phase,
          Ractor.make_shareable(TestOutletSource::ParallelWorkerA.new),
          Ractor.make_shareable(TestOutletSource::ParallelWorkerB.new),
        ),
        token
      )
      return if parallel_result.nil?

      # Extract results from Message::All
      worker_results = parallel_result.results.map(&:last)
      out.put(:phase2_complete, Ractor.make_shareable(worker_results))

      # Phase 3: Synchronous finalization using parallel results
      final_result = out.source(TestOutletSource::FinalizeCommand.new(worker_results.sum), token)
      return if final_result.nil?
      out.put(:phase3_complete, final_result.last)
    end
  end

  SetupCommand = Data.define do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:setup_done, 100)
    end
  end

  ParallelWorkerA = Data.define do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:worker_a, 10)
    end
  end

  ParallelWorkerB = Data.define do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:worker_b, 20)
    end
  end

  FinalizeCommand = Data.define(:accumulated_value) do
    include Rooibos::Command::Custom
    def call(out, _token)
      out.put(:finalized, accumulated_value * 2)
    end
  end

  def test_source_orchestrates_sync_parallel_sync_flow
    model = Ractor.make_shareable({})

    @@command = SyncParallelSyncCommand.new
    view = ClearView
    update = SourceUpdate

    with_test_terminal do
      inject_key("s")  # Start the workflow
      inject_sync      # Wait for completion
      inject_key("q")  # Quit

      Rooibos::Runtime.run(model:, view:, update:)
    end

    # Fail fast if any unexpected errors occurred
    assert_no_errors(@@messages)

    # Verify all three phases completed in order
    phase1 = @@messages.find { |m| m.is_a?(Array) && m.first == :phase1_complete }
    phase2 = @@messages.find { |m| m.is_a?(Array) && m.first == :phase2_complete }
    phase3 = @@messages.find { |m| m.is_a?(Array) && m.first == :phase3_complete }

    refute_nil phase1, "Phase 1 (sync setup) should complete"
    refute_nil phase2, "Phase 2 (parallel fetch) should complete"
    refute_nil phase3, "Phase 3 (sync finalize) should complete"

    # Verify correct values flow through the pipeline
    assert_equal 100, phase1.last, "Setup should return 100"
    assert_equal [10, 20], phase2.last, "Parallel workers should return [10, 20]"
    assert_equal 60, phase3.last, "Finalize should double the sum (10+20)*2 = 60"

    # Verify ordering: phase 1 before phase 2 before phase 3
    indices = [phase1, phase2, phase3].map { |p| @@messages.index(p) }
    assert_equal indices, indices.sort, "Phases should execute in order: setup → parallel → finalize"
  end
end
