# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby"
require "concurrent-edge"

module RatatuiRuby
  module Tea
    # Runs the Model-View-Update event loop.
    #
    # Applications need a render loop. You poll events, update state, redraw. Every frame.
    # The boilerplate is tedious and error-prone.
    #
    # This class handles the loop. You provide the model, view, and update. It handles the rest.
    #
    # Use it to build applications with predictable state.
    #
    # === Example
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   RatatuiRuby::Tea.run(
    #     model: { count: 0 }.freeze,
    #     view: ->(model, tui) { tui.paragraph(text: model[:count].to_s) },
    #     update: ->(message, model) { message.q? ? [model, Command.exit] : [model, nil] }
    #   )
    #--
    # SPDX-SnippetEnd
    #++
    class Runtime
      # Starts the MVU event loop.
      #
      # Runs until the update function returns a <tt>Command.exit</tt> command.
      #
      # [model] Initial application state (immutable).
      # [view] Callable receiving <tt>(model, tui)</tt>, returns a widget.
      # [update] Callable receiving <tt>(message, model)</tt>, returns <tt>[new_model, command]</tt> or just <tt>new_model</tt>.
      # [init] Optional callable to run at startup. Returns a message for update.
      def self.run(model:, view:, update:, init: nil)
        validate_ractor_shareable!(model, "model")

        # Execute init command synchronously if provided
        if init
          init_message = init.call
          result = update.call(init_message, model)
          model, _command = normalize_update_result(result, model)
          validate_ractor_shareable!(model, "model")
        end

        channel = Concurrent::Promises::Channel.new
        pending_futures = [] #: Array[Concurrent::Promises::Future[void]]
        active_commands = Concurrent::Map.new #: Concurrent::Map[Command::_Command, active_entry]

        catch(:quit) do
          RatatuiRuby.run do |tui|
            loop do
              tui.draw do |frame|
                widget = view.call(model, tui)
                validate_view_result!(widget)
                frame.render_widget(widget, frame.area)
              end

              # 1. Handle user input (blocks up to 16ms)
              message = tui.poll_event

              # If provided, handle the event
              unless message.is_a?(RatatuiRuby::Event::None)
                result = update.call(message, model)
                model, command = normalize_update_result(result, model)
                validate_ractor_shareable!(model, "model")
                throw :quit if command.is_a?(Command::Exit)

                future = dispatch(command, channel, active_commands) if command
                pending_futures << future if future
              end

              # 2. Check for synthetic events (Sync)
              # This comes AFTER poll_event so Sync waits for commands dispatched
              # by the preceding event (e.g., inject_key("a"); inject_sync)
              if RatatuiRuby::SyntheticEvents.pending?
                synthetic = RatatuiRuby::SyntheticEvents.pop
                if synthetic&.sync?
                  # Wait for all pending futures to complete
                  pending_futures.each(&:wait)
                  pending_futures.clear

                  # Yield to ensure any final queue writes are visible
                  Thread.pass

                  # Process all pending channel items
                  loop do
                    background_message = channel.try_pop(:EMPTY)
                    break if background_message == :EMPTY

                    result = update.call(background_message, model)
                    model, command = normalize_update_result(result, model)
                    validate_ractor_shareable!(model, "model")
                    throw :quit if command.is_a?(Command::Exit)

                    future = dispatch(command, channel, active_commands) if command
                    pending_futures << future if future
                  end
                end
              end

              # 3. Check for background outcomes (non-blocking)
              loop do
                background_message = channel.try_pop(:EMPTY)
                break if background_message == :EMPTY

                result = update.call(background_message, model)
                model, command = normalize_update_result(result, model)
                validate_ractor_shareable!(model, "model")
                throw :quit if command.is_a?(Command::Exit)

                future = dispatch(command, channel, active_commands) if command
                pending_futures << future if future
              end
            end
          end
        end

        # Shutdown: signal all, wait grace periods (cooperative cancellation)
        active_commands.each do |handle, entry|
          entry[:origin].resolve # Signal cancellation
          grace = handle.tea_cancellation_grace_period
          if grace.finite?
            entry[:future].wait(grace)
          else
            entry[:future].wait
          end
        end

        # Process any final messages from completed commands
        loop do
          background_message = channel.try_pop(:EMPTY)
          break if background_message == :EMPTY

          result = update.call(background_message, model)
          model, = normalize_update_result(result, model)
        end

        model
      end

      # Validates the view returned a widget.
      #
      # Views return widget trees. Returning +nil+ is a bug—you forgot to
      # return something. For an intentionally empty screen, use TUI#clear.
      private_class_method def self.validate_view_result!(widget)
        return unless widget.nil?

        raise RatatuiRuby::Error::Invariant,
          "View returned nil. Return a widget, or use TUI#clear for an empty screen."
      end

      # Extracts [model, command] from update result.
      #
      # Uses is_a? checks for type narrowing. The result parameter is untyped
      # because the method performs runtime type detection.
      #
      # @param result [Array, Command::execution, Object] The update result
      # @param previous_model [Model] Fallback model if result is a command
      # @return [Array(Object, Command::execution?)] The [model, command] tuple
      private_class_method def self.normalize_update_result(result, previous_model)
        # Case 0: Nil result - preserve previous model
        return [previous_model, nil] if result.nil?

        # Case 1: Already a [model, command] tuple
        if result.is_a?(Array) && (result.size == 2)
          model = result[0]
          command = result[1]
          # Verify the second element is a valid command (nil, built-in, or custom)
          if command.nil? ||
              command.class.name&.start_with?("RatatuiRuby::Tea::Command::") ||
              (command.respond_to?(:tea_command?) && command.tea_command?)

            return [model, command]
          end
        end

        # Case 2: Result is a Command - use previous model
        if result.class.name&.start_with?("RatatuiRuby::Tea::Command::")
          return [previous_model, result]
        end
        if result.respond_to?(:tea_command?) && result.tea_command?
          return [previous_model, result]
        end

        # Case 3: Result is the new model
        [result, nil]
      end

      # Validates an object is Ractor-shareable (deeply frozen).
      #
      # Models and messages must be shareable for future Ractor support.
      # Mutable objects cause race conditions. Freeze your data.
      #
      # Only enforced in debug mode (and tests). Production skips this check
      # for performance; mutable objects will still cause bugs, but silently.
      private_class_method def self.validate_ractor_shareable!(object, name)
        return unless RatatuiRuby::Debug.enabled?
        return if Ractor.shareable?(object)

        raise RatatuiRuby::Error::Invariant,
          "#{name.capitalize} is not Ractor-shareable. Use Ractor.make_shareable or Object#freeze."
      end

      # Spawns a future and pushes results to the message channel.
      # See Command.system for message formats.
      private_class_method def self.dispatch(command, channel, active_commands = Concurrent::Map.new)
        case command
        when Command::Cancel
          entry = active_commands[command.handle]
          if entry && entry[:future].pending?
            entry[:origin].resolve # Signal cancellation
            grace = command.handle.tea_cancellation_grace_period
            entry[:future].wait(grace.finite? ? grace : nil)
          end
          active_commands.delete(command.handle)
          nil
        else
          # Custom command (responds to tea_command?)
          if command.respond_to?(:tea_command?) && command.tea_command?
            cancellation, origin = Concurrent::Cancellation.new
            outlet = Command::Outlet.new(channel)

            future = Concurrent::Promises.future do
              command.call(outlet, cancellation)
            rescue => e
              channel.push Command::Error.new(command:, exception: e)
            end

            active_commands[command] = { future:, origin: }
            future
          end
        end
      end
    end
  end
end
