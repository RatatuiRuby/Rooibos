# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "ratatui_ruby"
require "concurrent-edge"

# Enable inline sync mode for deterministic event ordering in tests.
# This ensures poll_event returns Event::Sync in sequence with key events.
RatatuiRuby::SyntheticEvents.inline_sync!

module Rooibos
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
  #   Rooibos.run(
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
    # == Root Fragment with Init
    #
    # Pass a fragment module with <tt>Init</tt>, <tt>Update</tt>, and <tt>View</tt> constants.
    # This allows your application to do work at startup, and your Update will be called with the result.
    # It also allows you to create a more complex model with access to <tt>ARGV</tt> and <tt>ENV</tt>.
    #
    #   module MyApp
    #     # Init is any callable, and returns an immutable Model and/or Command, according to your application's needs.
    #     # The Model is your application's initial state, and the Command is any command to run at startup.
    #     Init = -> () {
    #       # To do work at startup:
    #       return [Data.define(:count).new(count: 0), Command.http("https://api.example.com/data")]
    #       # To start idle:
    #       return Data.define(:count).new(count: 0)
    #     }
    #
    #     # Update has access to a single Message, and your fragment's latest immutable Model.
    #     # It returns a new Model and/or a Command, according to your application's needs.
    #     Update = ->(message, model) {
    #       [model, Command.exit]
    #     }
    #
    #     # View has access to your fragment's latest immutable Model, and a RatatuiRuby::TUI.
    #     # It returns a tree of RatatuiRuby::Widget and/or Custom Widgets.
    #     View = ->(model, tui) {
    #       tui.paragraph(text: model.count.to_s)
    #     }
    #   end
    #
    #   Rooibos.run(MyApp)
    #
    # == Root Fragment with auto-Init
    #
    # Pass a fragment module with a <tt>Model</tt> class and <tt>Update</tt> and <tt>View</tt> constants.
    # Your application will be idle until a RatatuiRuby::Event message is sent to your Update.
    #
    #   module MyApp
    #     # Model is anything that responds to <tt>new</tt>.
    #     Model = Data.define(:count).new(count: 0)
    #
    #     # Update has access to a single Message, and your fragment's latest immutable Model.
    #     # It returns a new Model and/or a Command, according to your application's needs.
    #     Update = ->(message, model) {
    #       [model, Command.exit]
    #     }
    #
    #     # View has access to your fragment's latest immutable Model, and a RatatuiRuby::TUI.
    #     # It returns a tree of RatatuiRuby::Widget and/or Custom Widgets.
    #     View = ->(model, tui) {
    #       tui.paragraph(text: model.count.to_s)
    #     }
    #   end
    #
    #   Rooibos.run(MyApp)
    #
    # == Explicit Parameters API
    #
    # Tests need deterministic state. Init reads from the filesystem, network, or
    # environment—sources that change between runs. Injecting a known model makes
    # tests reproducible.
    #
    # Pass <tt>model:</tt>, <tt>view:</tt>, and <tt>update:</tt> directly. The runtime
    # skips Init and uses your model as the starting state.
    #
    #   Rooibos.run(
    #     model: Ractor.make_shareable(MyApp::Model.new(count: 0)),
    #     view: MyApp::View,
    #     update: MyApp::Update
    #   )
    #
    # == Parameters
    #
    # [root_fragment] Module with Model, Init, Update, View constants. *Mutually exclusive with model/view/update.*
    # [fps] Target frames per second for the application. Higher values feel more responsive, but may spike CPU usage.
    # [model] Initial application state (immutable). *Required if fragment not provided.*
    # [view] Callable receiving <tt>(model, tui)</tt>, returns a widget. *Required if fragment not provided.*
    # [update] Callable receiving <tt>(message, model)</tt>, returns <tt>[new_model, command]</tt> or just <tt>new_model</tt>. *Required if fragment not provided.*
    # [command] Optional callable to run at startup. Returns a message for update.
    #
    # == Raises
    #
    # [Rooibos::Error::Invariant] If both fragment and any of (model, view, update, command) are provided.
    def self.run(root_fragment = nil, fps: 60, model: nil, view: nil, update: nil, command: nil)
      @fragment = fragment_from_kwargs(root_fragment, model:, view:, update:, command:)
      @view = @fragment::View
      @update = @fragment::Update
      @init_callable = init_callable
      @timeout = 1.0 / fps

      start_runtime
    end

    # Normalizes Init callable return value to <tt>[model, command]</tt> tuple.
    #
    # Init callables return initial state and optional startup command. They can use
    # DWIM (Do What I Mean) syntax: return just a model, just a command, or a full tuple.
    #
    # This method handles all formats. Use it when composing child fragment Inits.
    #
    # [result] The Init return value (model, command, or <tt>[model, command]</tt> tuple).
    #
    # === Examples
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   # Just model
    #   model, cmd = Rooibos.normalize_init(Model.new(...))
    #   # => [Model.new(...), nil]
    #
    #   # Just command
    #   model, cmd = Rooibos.normalize_init(Command.http(...))
    #   # => [nil, Command.http(...)]
    #
    #   # Tuple (already normalized)
    #   model, cmd = Rooibos.normalize_init([Model.new(...), Command.http(...)])
    #   # => [Model.new(...), Command.http(...)]
    #--
    # SPDX-SnippetEnd
    #++
    def self.normalize_init(result)
      normalize_update_return(result, nil)
    end

    # Sentinel value avoids accidentally quitting from application exceptions.
    QUIT = Object.new.freeze

    class << self
      private def start_runtime
        @message_queue = Concurrent::Promises::Channel.new
        @pending_futures = [] #: Array[Concurrent::Promises::Future[void]]
        @lifecycle = Command::Lifecycle.new

        catch(QUIT) do
          RatatuiRuby.run do |tui|
            @tui = tui

            # Init runs after terminal is ready so it can query terminal_size, etc.
            @model, @command = @init_callable.call
            validate_ractor_shareable!(@command, "command")
            validate_ractor_shareable!(@model, "model")
            validate_ractor_shareable!(@update, "update")
            validate_ractor_shareable!(@view, "view")
            validate_ractor_shareable!(@init_callable, "init")
            dispatch_command

            loop do
              draw_view
              handle_ratatui_event
              send_pending_messages
            end
          end
        end

        # Shutdown: signal all, wait grace periods (cooperative cancellation)
        @lifecycle.shutdown

        # Process any final messages from completed commands
        send_pending_messages(dispatch: false)

        @model
      end

      private def draw_view
        # Build widget tree OUTSIDE draw context - queries work here
        widget = @view.call(@model, @tui)
        validate_view_return!(widget)

        # Render INSIDE draw context - only rendering happens here
        @tui.draw do |frame|
          frame.render_widget(widget, frame.area)
        end
      end
      # Enforces invariants
      private def fragment_from_kwargs(root_fragment, model: nil, view: nil, update: nil, command: nil)
        if root_fragment
          fragment_invariant!("model") if model
          fragment_invariant!("view") if view
          fragment_invariant!("update") if update
          fragment_invariant!("command") if command
          root_fragment
        else
          fragment = Module.new
          fragment.const_set(:Model, model)
          fragment.const_set(:View, view)
          fragment.const_set(:Update, update)
          fragment.const_set(:InitCommand, command)
          # Init uses a module singleton method accessing constants via self.
          # Module objects are always shareable, so this makes init shareable.
          fragment.define_singleton_method(:call) do
            [self::Model, self::InitCommand] # steep:ignore UnknownConstant
          end
          fragment.const_set(:Init, fragment)
          fragment
        end
      end

      # Helps app developers understand invariants
      private def fragment_invariant!(param)
        raise Rooibos::Error::Invariant, "Cannot provide both fragment: and #{param}: parameters. Use fragment-first API (fragment:) OR explicit parameters (model:, view:, update:, command:), not both."
      end

      private def init_callable
        if @fragment.const_defined?(:Init)
          if @fragment::Init.respond_to?(:call)
            @fragment::Init
          else
            raise Rooibos::Error::Invariant, "Fragment::Init must respond to :call"
          end
        else
          if @fragment.const_defined?(:Model)
            if @fragment::Model.respond_to?(:new)
              # Synthesize an Init using module singleton method.
              # Module objects are always shareable, so accessing
              # constants via self makes this Ractor-shareable.
              unless @fragment.respond_to?(:call)
                @fragment.define_singleton_method(:call) { self::Model.new } # steep:ignore UnknownConstant
              end
              @fragment
            else
              raise Rooibos::Error::Invariant, "Fragment::Model must respond to :new; or pass Fragment::Init instead"
            end
          else
            raise Rooibos::Error::Invariant, "Fragment must define a Model class or an Init callable"
          end
        end
      end

      private

      # Validates the view returned a widget.
      #
      # Views return widget trees. Returning +nil+ is a bug—you forgot to
      # return something. For an intentionally empty screen, use TUI#clear.
      private def validate_view_return!(widget)
        return unless widget.nil?

        raise Rooibos::Error::Invariant,
          "View returned nil. Return a widget, or use TUI#clear for an empty screen."
      end

      # Extracts [model, command] from Update return value.
      private def normalize_update_return(result, previous_model)
        # Case 0: Nil result - preserve previous model
        return [previous_model, nil] if result.nil?

        # Case 1: Already a [model, command] tuple
        if result.is_a?(Array) && (result.size == 2)
          model, command = result
          # Verify the second element is a valid command
          if command.nil? ||
              (command.respond_to?(:rooibos_command?) && command.rooibos_command?)

            return [model, command]
          end

          # Debug-mode heuristic: warn about suspicious command-like objects
          if RatatuiRuby::Debug.enabled? &&
              command.respond_to?(:call) &&
              !command.respond_to?(:rooibos_command?) &&
              !Ractor.shareable?(result)

            warn "WARNING: Update returned [model, #{command.class}] but #{command.class} " \
              "responds to #call without #rooibos_command?. Did you forget to include Command::Custom? " \
              "The tuple will be treated as the model, not as [model, command]. " \
              "To suppress this warning if the array is your model, use Ractor.make_shareable on it. " \
              "(#{caller.first})"
          end

        end

        # Case 2: Result is a Command - use previous model
        if result.respond_to?(:rooibos_command?) && result.rooibos_command?
          command = result #: Rooibos::Command::execution
          return [previous_model, command]
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
      #
      # This method TRIES to make the object shareable (which auto-freezes).
      # It only fails if the object captures non-shareable state (e.g., a
      # lambda defined inside a method that captures self).
      private def validate_ractor_shareable!(object, name)
        return unless RatatuiRuby::Debug.enabled?
        return if Ractor.shareable?(object)

        # Try to make it shareable - this will freeze it and succeed for
        # most objects. It only fails for objects that truly can't be shared.
        Ractor.make_shareable(object)
      rescue Ractor::IsolationError => e
        raise Rooibos::Error::Invariant,
          "#{name} cannot be made Ractor-shareable: #{e.message}"
      end

      private def handle_ratatui_event
        message = @tui.poll_event(timeout: @timeout)
        return false if message.none?

        # Handle sync events: wait for pending async work before continuing
        if message.sync?
          @pending_futures.each(&:wait)
          @pending_futures.clear
          Thread.pass
          send_pending_messages
          return true
        end

        @model, @command = normalize_update_return(@update.call(message, @model), @model)
        validate_ractor_shareable!(@model, "model")
        throw QUIT if Command::Exit === @command
        dispatch_command
        true # Event was processed
      end

      QUEUE_EMPTY = Object.new.freeze
      private_constant :QUEUE_EMPTY

      private def send_pending_messages(dispatch: true)
        loop do
          background_message = @message_queue.try_pop(QUEUE_EMPTY)
          break if background_message == QUEUE_EMPTY

          result = @update.call(background_message, @model)
          @model, @command = normalize_update_return(result, @model)
          return unless dispatch

          validate_ractor_shareable!(@model, "model")
          throw QUIT if Command::Exit === @command

          dispatch_command
        end
      end

      # Spawns a future and pushes results to the message queue.
      # See Command.system for message formats.
      private def dispatch_command
        future = if @command.nil?
          nil
        elsif Command::Cancel === @command
          entry = @lifecycle.cancel(@command.handle)
          # Remove cancelled future from pending list so sync doesn't wait for it
          @pending_futures.delete(entry.future) if entry
          nil
        elsif @command.respond_to?(:rooibos_command?) && @command.rooibos_command?
          entry = @lifecycle.run_async(@command, @message_queue)
          entry.future
        else
          raise Rooibos::Error::Invariant,
            "#{@command.inspect} is not a valid Rooibos command."
        end
        @pending_futures << future if future
      end
    end
  end
end
