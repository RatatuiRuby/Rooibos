#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# frozen_string_literal: true

# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Declarative DSL for Fractal Architecture.
  #
  # Large applications decompose into fragments. Each fragment has its own Model,
  # UPDATE, and VIEW. Parent fragments route messages to child fragments and compose views.
  # Writing this routing logic by hand is tedious and error-prone.
  #
  # Include this module to declare routes and keymaps. Call +from_router+ to
  # generate an Update lambda that handles routing automatically.
  #
  # A *fragment* is a module containing <tt>Model</tt>, <tt>Init</tt>,
  # <tt>Update</tt>, and <tt>View</tt> constants. Fragments compose: parent fragments
  # delegate to child fragments.
  #
  # === Example
  #
  #   class Dashboard
  #     include Rooibos::Router
  #
  #     route :stats, to: StatsPanel
  #     route :network, to: NetworkPanel
  #
  #     keymap do
  #       key "s", -> { SystemInfo.fetch_command }, route: :stats
  #       key "q", -> { Command.exit }
  #     end
  #
  #     Model = Data.define(:stats, :network)
  #     Init = -> { Model.new(stats: StatsPanel::Init.(), network: NetworkPanel::Init.()) }
  #     View = ->(model, tui) { ... }
  #     Update = from_router
  #   end
  module Router
    # Configuration for key handlers.
    KeyHandlerConfig = Data.define(:handler, :action, :route, :guard) do
      def initialize(handler: nil, action: nil, route: nil, guard: nil)
        super
      end
    end

    # Configuration for scroll handlers (no coordinates).
    ScrollHandlerConfig = Data.define(:handler, :action) do
      def initialize(handler: nil, action: nil)
        super
      end
    end

    # Configuration for click handlers (x, y coordinates).
    ClickHandlerConfig = Data.define(:handler, :action) do
      def initialize(handler: nil, action: nil)
        super
      end
    end

    # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods added when Router is included.
    module ClassMethods
      # Declares a route to a child.
      #
      # [prefix] Symbol or String identifying the route (normalized via +.to_s.to_sym+).
      # [to] The child module (must have UPDATE and INITIAL constants).
      def route(prefix, to:)
        routes[prefix.to_s.to_sym] = to
      end

      # Returns the registered routes hash.
      def routes
        @routes ||= {}
      end

      # Declares a named action.
      #
      # Actions are shared handlers that keymap and mousemap can reference.
      # This avoids duplicating logic for keys and mouse events that do
      # the same thing.
      #
      # [name] Symbol or String identifying the action (normalized via +.to_s.to_sym+).
      # [handler] Callable that returns a command or message.
      def action(name, handler)
        actions[name.to_s.to_sym] = handler
      end

      # Returns the registered actions hash.
      def actions
        @actions ||= {}
      end

      # Declares key handlers in a block.
      #
      # === Example
      #
      #   keymap do
      #     key "q", -> { Command.exit }
      #     key :up, :scroll_up  # Delegate to action
      #   end
      def keymap(&)
        builder = KeymapBuilder.new
        builder.instance_eval(&)
        @key_handlers = builder.handlers
      end

      # Declares mouse handlers in a block.
      #
      # === Example
      #
      #   mousemap do
      #     click -> (x, y) { [:clicked, x, y] }
      #     scroll :up, :scroll_up  # Delegate to action
      #   end
      def mousemap(&)
        builder = MousemapBuilder.new
        builder.instance_eval(&)
        @scroll_handlers = builder.scroll_handlers
        @click_handler = builder.click_handler
      end

      # Returns the registered key handlers hash.
      private def key_handlers
        @key_handlers ||= {}
      end

      # Returns the registered scroll handlers hash.
      private def scroll_handlers
        @scroll_handlers ||= {}
      end

      # Returns the registered click handler, if any.
      private def click_handler
        @click_handler
      end

      # Generates an UPDATE lambda from routes, keymap, and mousemap.
      #
      # The generated UPDATE:
      # 1. Routes prefixed messages to child UPDATEs
      # 2. Handles keyboard events via keymap
      # 3. Handles mouse events via mousemap
      # 4. Returns model unchanged for unhandled messages
      def from_router
        RouterUpdate.new(
          routes:,
          actions:,
          key_handlers:,
          scroll_handlers:,
          click_handler:
        )
      end
    end

    # Internal UPDATE callable with proper typing.
    class RouterUpdate # :nodoc:
      def initialize(routes:, actions:, key_handlers:, scroll_handlers:, click_handler:)
        @routes = routes
        @actions = actions
        @key_handlers = key_handlers
        @scroll_handlers = scroll_handlers
        @click_handler = click_handler
      end

      # Process message and return [model, command] tuple.
      def call(message, model)
        # 1. Try routing prefixed messages to child fragments
        @routes.each do |prefix, fragment|
          fragment_update = fragment.const_get(:Update)
          result = Rooibos.delegate(message, prefix, fragment_update, model.public_send(prefix))
          if result
            new_fragment_model, command = result
            return [model.with(prefix => new_fragment_model), command] #: [_DataModel, Command::execution?]
          end
        end

        # 2. Try keymap handlers (message is an Event::Key)
        if message.is_a?(RatatuiRuby::Event::Key)
          @key_handlers.each do |key_name, config|
            predicate = :"#{key_name}?"
            next unless message.respond_to?(predicate) && message.public_send(predicate)

            # Check guard if present
            if (config.guard) && !config.guard.call(model)
              next
            end

            # Get handler - either inline or from actions registry
            handler = config.handler
            if handler.nil? && config.action
              handler = @actions[config.action]
            end
            next unless handler

            command = handler.call
            if command && config.route
              command = Rooibos.route(command, config.route)
            end
            return [model, command] #: [_DataModel, Command::execution?]
          end
        end

        # 3. Try mousemap handlers (message is an Event::Mouse)
        if message.is_a?(RatatuiRuby::Event::Mouse)
          # Scroll events (handler takes no arguments)
          if message.scroll_up?
            config = @scroll_handlers[:scroll_up]
            if config
              scroll_handler = config.handler
              if scroll_handler.nil? && config.action
                scroll_handler = @actions[config.action]
              end
              return [model, scroll_handler&.call] #: [_DataModel, Command::execution?]
            end
          end
          if message.scroll_down?
            config = @scroll_handlers[:scroll_down]
            if config
              scroll_handler = config.handler
              if scroll_handler.nil? && config.action
                scroll_handler = @actions[config.action]
              end
              return [model, scroll_handler&.call] #: [_DataModel, Command::execution?]
            end
          end
          # Click events (handler takes x, y coordinates)
          click_config = @click_handler
          if message.down? && click_config
            click_handler_proc = click_config.handler
            if click_handler_proc.nil? && click_config.action
              # Actions don't take coordinates, so just call without args
              action_handler = @actions[click_config.action]
              return [model, action_handler&.call] #: [_DataModel, Command::execution?]
            elsif click_handler_proc
              return [model, click_handler_proc.call(message.x, message.y)] #: [_DataModel, Command::execution?]
            end
          end
        end

        # 4. Unhandled - return model unchanged
        [model, nil] #: [_DataModel, Command::execution?]
      end
    end
    private_constant :RouterUpdate

    # Builder for keymap DSL.
    class KeymapBuilder
      # Returns the registered handlers hash.
      attr_reader :handlers

      # :nodoc:
      def initialize
        @handlers = {}
        @guard_stack = []
      end

      # Registers a key handler.
      #
      # [key_name] String or Symbol for the key (normalized via +.to_s+).
      # [handler_or_action] Callable or Symbol (action name).
      # [route] Optional route prefix for the command result.
      # [when/if/only/guard] Guard that runs if truthy (aliases).
      # [unless/except/skip] Guard that runs if falsy (negative aliases).
      def key(key_name, handler_or_action, route: nil, when: nil, if: nil, only: nil, guard: nil, unless: nil, except: nil, skip: nil)
        handler = nil
        action = nil
        if handler_or_action.is_a?(Symbol)
          action = handler_or_action
        else
          handler = handler_or_action
        end

        guards = @guard_stack.dup

        # Positive guards (when, if, only, guard)
        positive = binding.local_variable_get(:when) ||
          binding.local_variable_get(:if) ||
          only ||
          guard
        guards << positive if positive

        # Negative guards (unless, except, skip) - wrap to invert
        negative = binding.local_variable_get(:unless) || except || skip
        if negative
          guards << -> (model) { !negative.call(model) }
        end

        combined_guard = if guards.any?
          -> (model) { guards.all? { |g| g.call(model) } }
        end

        @handlers[key_name.to_s] = KeyHandlerConfig.new(
          handler:,
          action:,
          route:,
          guard: combined_guard
        )
      end

      # Applies a guard to all keys in the block.
      #
      # [when/if/only/guard] Guard that runs if truthy.
      def only(when: nil, if: nil, only: nil, guard: nil, &)
        arg_count = 0
        arg_count += 1 if binding.local_variable_get(:when)
        arg_count += 1 if binding.local_variable_get(:if)
        arg_count += 1 if only
        arg_count += 1 if guard

        if arg_count > 1
          raise ArgumentError, "only accepts exactly one of: when, if, only, guard"
        end

        positive = binding.local_variable_get(:when) ||
          binding.local_variable_get(:if) ||
          only ||
          guard
        with_guard(positive, &)
      end

      # Skips all keys in the block when the guard is true.
      #
      # [when/if/skip/guard] Guard that skips if truthy.
      def skip(when: nil, if: nil, skip: nil, guard: nil, &)
        arg_count = 0
        arg_count += 1 if binding.local_variable_get(:when)
        arg_count += 1 if binding.local_variable_get(:if)
        arg_count += 1 if skip
        arg_count += 1 if guard

        if arg_count > 1
          raise ArgumentError, "skip accepts exactly one of: when, if, skip, guard"
        end

        skip_guard = binding.local_variable_get(:when) ||
          binding.local_variable_get(:if) ||
          skip ||
          guard

        # Invert the guard: skip when true means run when false
        inverted = skip_guard ? -> (model) { !skip_guard.call(model) } : nil
        with_guard(inverted, &)
      end
      private def with_guard(guard, &block)
        if guard
          @guard_stack << guard
          begin
            block.call
          ensure
            @guard_stack.pop
          end
        else
          block.call
        end
      end
    end

    # Builder for mousemap DSL.
    class MousemapBuilder
      # Returns the registered scroll handlers (scroll_up, scroll_down).
      attr_reader :scroll_handlers

      # Returns the registered click handler.
      attr_reader :click_handler

      # :nodoc:
      def initialize
        @scroll_handlers = {}
        @click_handler = nil
      end

      # Registers a click handler.
      #
      # [handler_or_action] Callable `^(Integer, Integer) -> Command` or Symbol (action name).
      def click(handler_or_action)
        if handler_or_action.is_a?(Symbol)
          @click_handler = ClickHandlerConfig.new(action: handler_or_action)
        else
          @click_handler = ClickHandlerConfig.new(handler: handler_or_action)
        end
      end

      # Registers a scroll handler.
      #
      # [direction] <tt>:up</tt> or <tt>:down</tt>.
      # [handler_or_action] Callable `^() -> Command` or Symbol (action name).
      def scroll(direction, handler_or_action)
        config = if handler_or_action.is_a?(Symbol)
          ScrollHandlerConfig.new(action: handler_or_action)
        else
          ScrollHandlerConfig.new(handler: handler_or_action)
        end
        @scroll_handlers[:"scroll_#{direction}"] = config
      end
    end
  end
end
