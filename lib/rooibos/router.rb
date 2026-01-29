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

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    # Class methods added when Router is included.
    module ClassMethods
      # Declares a route to a child fragment.
      #
      # [fragment_model_instance_attr] Symbol naming the attr on the parent's model
      #   that holds this fragment's model instance (normalized via +.to_s.to_sym+).
      # [to] The child fragment module (must have Update and Init constants).
      def route(fragment_model_instance_attr, to:)
        routes[fragment_model_instance_attr.to_s.to_sym] = to
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
      # Supports both positional and keyword syntax:
      #   action :scroll_up, -> { Command.scroll(-1) }  # Positional
      #   action scroll_up: -> { Command.scroll(-1) }   # Keyword
      #
      # [name] Symbol or String identifying the action (normalized via +.to_s.to_sym+).
      # [value] Callable that returns a command or message.
      def action(name = nil, value = nil, keymap: nil, key: nil, keys: nil, mousemap: nil, **kwargs)
        # key: and keys: are aliases for keymap:
        effective_keymap = keymap || key || keys
        action_name, action_value = if name && value
          # Positional: action :name, handler
          [name, value]
        elsif name.respond_to?(:call) && value.nil?
          # Anonymous: action -> { ... }, keymap: %i[...]
          # No name, just handler with bindings
          [nil, name]
        elsif kwargs.size == 1
          # Keyword: action name: handler
          kwargs.first
        else
          raise ArgumentError, "action requires (name, value) or (name: value)"
        end

        # @type var action_name: Symbol?
        # @type var action_value: (^() -> Command::execution? | Module)?
        register_action(action_name, action_value) if action_name && action_value

        # For anonymous actions, store handler directly in keymap
        handler_for_keymap = action_name.nil? ? action_value : nil

        # Register keymap bindings if provided
        if effective_keymap
          Array(effective_keymap).each do |key_name|
            key_handlers[key_name.to_s.to_sym] = Router::KeyHandlerConfig.new(
              handler: handler_for_keymap,
              action: action_name&.to_s&.to_sym,
              guard: nil,
              route: nil
            )
          end
        end

        # Register mousemap bindings if provided
        if mousemap
          Array(mousemap).each do |mouse_event|
            scroll_handlers[mouse_event.to_s.to_sym] = Router::ScrollHandlerConfig.new(
              handler: handler_for_keymap,
              action: action_name&.to_s&.to_sym
            )
          end
        end
      end

      private def register_action(name, value)
        key = name.to_s.to_sym
        case value
        when Module
          routed_actions[key] = value
        else
          actions[key] = value
        end
      end

      # Returns the registered handler actions hash.
      def actions
        @actions ||= {}
      end

      # Returns the registered routed actions hash.
      def routed_actions
        @routed_actions ||= {}
      end

      # Declares an intercept handler (stops further processing when predicate matches).
      #
      # Supports positional or keyword syntax:
      #   intercept ->(msg) { msg.q? }, ->(msg, model) { ... }
      #   intercept if: ->(msg) { msg.q? }, then: ->(msg, model) { ... }
      #   intercept when: ->(msg) { msg.q? }, then: ->(msg, model) { ... }
      #   intercept unless: ->(msg) { msg.none? }, then: ->(msg, model) { ... }
      def intercept(predicate = nil, handler = nil, if: nil, when: nil, unless: nil, except: nil, then: nil)
        # Extract predicate from keyword args
        effective_predicate = predicate ||
          binding.local_variable_get(:if) ||
          binding.local_variable_get(:when)

        # Handle inverted predicates (unless/except)
        negative = binding.local_variable_get(:unless) || except
        if negative
          effective_predicate = ->(msg) { !negative.call(msg) }
        end

        # Extract handler from keyword args
        effective_handler = handler || binding.local_variable_get(:then)

        intercept_handlers << { predicate: effective_predicate, handler: effective_handler }
      end

      # Returns the registered intercept handlers array.
      def intercept_handlers
        @intercept_handlers ||= []
      end

      # Declares an intercept handler that matches all messages (arity 1 convenience).
      def intercept_all(handler)
        intercept(->(_msg) { true }, handler)
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
          routed_actions:,
          key_handlers:,
          scroll_handlers:,
          click_handler:,
          intercept_handlers:
        )
      end
    end

    # Internal UPDATE callable with proper typing.
    class RouterUpdate # :nodoc:
      def initialize(routes:, actions:, routed_actions:, key_handlers:, scroll_handlers:, click_handler:, intercept_handlers:)
        @routes = routes
        @actions = actions
        @routed_actions = routed_actions
        @key_handlers = key_handlers
        @scroll_handlers = scroll_handlers
        @click_handler = click_handler
        @intercept_handlers = intercept_handlers
      end

      # Process message and return [model, command] tuple.
      def call(message, model)
        # 0. Try intercept handlers - first match stops processing
        @intercept_handlers.each do |config|
          if config[:predicate].call(message)
            result = config[:handler].call(message, model)
            return normalize_handler_result(result, model)
          end
        end

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

            # Check for routed action if no handler found
            if handler.nil? && config.action
              routed_fragment = @routed_actions[config.action]
              if routed_fragment
                # Find the model attr for this fragment
                fragment_model_instance_attr = @routes.key(routed_fragment)
                next unless fragment_model_instance_attr

                # Synthesize Message::Routed and dispatch to child
                routed_message = Rooibos::Message::Routed.new(envelope: config.action, event: message)
                child_update = routed_fragment.const_get(:Update)
                previous_child_fragment_model_instance = model.public_send(fragment_model_instance_attr)
                updated_child_fragment_model_instance, command = child_update.call(routed_message, previous_child_fragment_model_instance)
                return [model.with(fragment_model_instance_attr => updated_child_fragment_model_instance), command]
              end
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

      private

      # Normalizes handler return value to [model, command] tuple (DWIM).
      def normalize_handler_result(result, previous_model)
        # Nil - preserve model
        return [previous_model, nil] if result.nil?

        # Already a [model, command] tuple
        if result.is_a?(Array) && result.size == 2
          model, command = result
          if command.nil? || (command.respond_to?(:rooibos_command?) && command.rooibos_command?)
            return [model, command]
          end
        end

        # Just a command - preserve model
        if result.respond_to?(:rooibos_command?) && result.rooibos_command?
          return [previous_model, result]
        end

        # Just a model
        [result, nil]
      end
    end
    private_constant :RouterUpdate

    # Builder for keymap DSL.
    class KeymapBuilder
      # Returns the registered handlers hash.
      attr_reader :handlers

      def initialize # :nodoc:
        @handlers = {}
        @guard_stack = []
      end

      # Registers a key handler.
      #
      # Supports multiple forms:
      #   key :q, -> { Command.exit }           # Single key with handler
      #   key :q, :quit                         # Single key with action name
      #   key :down, :j, action: :move_down     # Multiple keys with action
      #   key :enter, -> { ... }, route: :foo   # With options
      #
      # [*key_names] One or more key names (String or Symbol).
      # [handler_or_action] Callable or Symbol (action name) - optional if action: given.
      # [action] Action name as keyword arg (alternative to positional).
      # [route] Optional route prefix for the command result.
      # [when/if/only/guard] Guard that runs if truthy (aliases).
      # [unless/except/skip] Guard that runs if falsy (negative aliases).
      def key(*args, action: nil, route: nil, when: nil, if: nil, only: nil, guard: nil, unless: nil, except: nil, skip: nil, **bindings)
        # Parse args: all symbols/strings are keys, last callable is handler
        key_names = [] #: Array[Symbol | String]
        handler = nil
        action_name = action

        args.each do |arg|
          if arg.is_a?(Hash)
            # Hash passed positionally: key({q: -> { ... }})
            bindings.merge!(arg)
          elsif arg.respond_to?(:call)
            handler = arg
          elsif arg.is_a?(Symbol) || arg.is_a?(String)
            # Could be a key name or action name (positional action from old API)
            key_names << arg
          end
        end

        # Keyword syntax: key ctrl_c: -> { ... }
        # Each kwarg is key_name => handler
        bindings.each do |key_name, handler_or_action|
          if handler_or_action.respond_to?(:call)
            register_key_handler(key_name, handler_or_action, nil, route, nil)
          else
            register_key_handler(key_name, nil, handler_or_action, route, nil)
          end
        end

        # If we had keyword bindings, skip positional processing
        return if bindings.any?

        # Old API: key :q, :quit - last symbol is the action
        if handler.nil? && action_name.nil? && key_names.size >= 2
          # Check if last "key" is actually an action by seeing if it looks like a handler
          action_name = key_names.pop
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

        # Register each key
        key_names.each do |key_name|
          register_key_handler(key_name, handler, action_name, route, combined_guard)
        end
      end

      private def register_key_handler(key_name, handler, action_name, route, guard)
        @handlers[key_name.to_s] = KeyHandlerConfig.new(
          handler:,
          action: action_name,
          route:,
          guard:
        )
      end

      # Alias for key (reads better with multiple keys)
      alias_method :keys, :key

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

      def initialize # :nodoc:
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
