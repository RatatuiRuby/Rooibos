# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "router/route"
require_relative "router/registry/routes"
require_relative "router/guard"
require_relative "router/rule"
require_relative "router/predicate"
require_relative "router/registry"
require_relative "router/action"
require_relative "router/registry/actions"
require_relative "router/rule/forward"
require_relative "router/registry/forwards"
require_relative "router/rule/receive"
require_relative "router/registry/receives"
require_relative "router/rule/observe"
require_relative "router/registry/observes"
require_relative "router/rule/otherwise"
require_relative "router/registry/otherwises"
require_relative "router/flow/dispatch"
require_relative "router/flow/inward"
require_relative "router/flow/outward"
require_relative "router/router_update"

module Rooibos
  # Fractal routing DSL for composing hierarchical updates.
  #
  # A growing app accumulates message-handling logic. One Update handles
  # dozens of cases. Model fields multiply. View code sprawls.
  #
  # Include Router in a fragment module. It decomposes your Update
  # into declarative rules: routes bind nested fragments to model slices,
  # forwards route messages inward, receives handle them exclusively,
  # and observers process without stopping the flow.
  #
  # Use it to build tab containers, panel layouts, or any hierarchy
  # where messages flow inward through nested fragments.
  #
  # === Example
  #
  #   module Dashboard
  #     include Rooibos::Router
  #
  #     route :sidebar, to: Sidebar
  #     route :main,    to: MainPanel
  #
  #     receive_events :ctrl_c, :quit
  #     action :quit, -> { Rooibos::Command.exit }
  #
  #     forward_events :enter, to: :main, as: :submit
  #     otherwise route_to: :main
  #
  #     Update = from_router
  #   end
  module Router
    # Sentinel for "all routes" - unique object prevents accidental collision
    ALL_ROUTES = Object.new.freeze
    private_constant :ALL_ROUTES

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    # The Router declaration surface.
    #
    # Fragments grow. One Update handles dozens of cases. Routing logic,
    # keybindings, and guard conditions tangle together.
    #
    # These class methods decompose that logic into declarative rules.
    # Declare routes, forwards, receives, observes, and otherwises.
    # Call <tt>from_router</tt> to freeze them into an Update callable.
    #
    # Use it inside any module that includes <tt>Rooibos::Router</tt>.
    module ClassMethods
      private def routes
        @routes ||= Routes.new
      end

      private def actions
        @actions ||= Actions.new
      end

      private def forwards
        @forwards ||= Forwards.new
      end

      private def receives
        @receives ||= Receives.new(actions:)
      end

      private def observes
        @observes ||= Observes.new(actions:)
      end

      private def otherwises
        @otherwises ||= Otherwises.new
      end

      # Assembles all declared routes, forwards, receives, observes, and
      # otherwises into a frozen RouterUpdate callable.
      #
      # Call this once at the end of your Router declarations. Assign the
      # result to <tt>Update</tt> so the runtime dispatches messages through
      # your router.
      #
      # Raises Rooibos::Error::Invariant if any forward or otherwise target
      # is ambiguous (e.g. two routes share the same prefix or fragment).
      #
      # === Example
      #
      #   module MyFragment
      #     include Rooibos::Router
      #
      #     route :child, to: ChildFragment
      #     forward_events :enter, to: :child, as: :submit
      #
      #     Update = from_router
      #   end
      def from_router
        RouterUpdate.new(
          inward: Flow::Inward.new(observes:, receives:, forwards:, otherwises:, routes:),
          outward: Flow::Outward.new(observes:, receives:, routes:)
        )
      end

      # Declares a child route binding a nested fragment to a model slice.
      #
      # The simplest form names a model attribute. <tt>:sidebar</tt> means
      # "read from <tt>model.sidebar</tt>, write back with
      # <tt>model.with(sidebar: ...)</tt>."
      #
      # When your model stores fragments in hashes or other structures, pass
      # <tt>read:</tt> and <tt>write:</tt> lambdas for custom extraction and
      # merging. A route with lambdas has no prefix symbol.
      #
      # Returns the Route object. Capture it when neither the prefix symbol
      # nor the fragment module can unambiguously identify the route.
      #
      # [prefix] Symbol or String naming the model attribute. Optional when
      #          using <tt>read:</tt>/<tt>write:</tt>.
      # [to]     The fragment module whose <tt>Update</tt> handles messages.
      # [read]   Lambda <tt>->(model) -> nested_model</tt>. Overrides prefix-based extraction.
      # [write]  Lambda <tt>->(model, value) -> model</tt>. Overrides prefix-based merging.
      #
      # === Example
      #
      #   # Named attribute (most common)
      #   route :sidebar, to: Sidebar
      #
      #   # Custom accessors for hash-stored fragments
      #   route read: ->(model) { model.panels[:sidebar] },
      #         write: ->(model, value) { model.with(panels: model.panels.merge(sidebar: value)) },
      #         to: Sidebar
      #
      #   # Capture for disambiguation
      #   ACTIVE = route read: ->(m) { m.tabs[m.active_tab] },
      #                 write: ->(m, v) { m.with(tabs: m.tabs.merge(m.active_tab => v)) },
      #                 to: TabContent
      #   forward_events :enter, to: ACTIVE, as: :submit
      def route(prefix = nil, to:, read: nil, write: nil, **)
        routes.add(Route.new(prefix: prefix&.to_s&.to_sym, fragment: to, read:, write:))
      end

      # Defines a named action referenceable by symbol.
      #
      # Actions are reusable handlers. Reference them by name in
      # <tt>receive*</tt>, <tt>intercept*</tt>, and <tt>observe*</tt>
      # methods anywhere a handler lambda is accepted.
      #
      # Lambda actions run directly. Routed actions dispatch a
      # <tt>Message::Routed</tt> to a fragment, using the action name as
      # the envelope.
      #
      # [name]    Symbol identifying the action.
      # [handler] A lambda or a fragment Module for routed dispatch.
      #
      # === Example
      #
      #   # Lambda action
      #   action :quit, -> { Rooibos::Command.exit }
      #
      #   # Keyword form
      #   action scroll_up: ->(_, model) { model.with(offset: model.offset - 1) }
      #
      #   # Routed action (dispatches :go_back to HistoryPanel)
      #   action :go_back, HistoryPanel
      def action(name = nil, handler = nil, **kwargs)
        if name && handler
          actions.add(name, handler)
        elsif kwargs.any?
          kwargs.each { |k, v| actions.add(k, v) }
        else
          raise ArgumentError, "action requires name and handler, or keyword arguments"
        end
      end

      # Handles matching key events directly. Stops further processing.
      #
      # Matches raw RatatuiRuby events by their <tt>to_sym</tt> value.
      # The second argument is an action name (Symbol) or a handler lambda.
      # The first matching receive wins; later handlers do not run.
      #
      # <tt>intercept_events</tt> is an alias. Use <tt>receive</tt> when the
      # message is addressed to you. Use <tt>intercept</tt> when stopping a
      # bubbled message mid-chain.
      #
      # === Example
      #
      #   receive_events :ctrl_c, :quit
      #   receive_events :q, :quit
      #   receive_events :enter, ->(_, model) { model.with(submitted: true) }
      def receive_events(...)
        receives.add_events(...)
      end

      # Handles matching routed messages. Stops further processing.
      #
      # Matches <tt>Message::Routed</tt> messages by their envelope symbol.
      # Use this when an outer fragment has forwarded a message with
      # <tt>as:</tt> and your fragment handles it.
      #
      # <tt>intercept_routed</tt> is an alias.
      #
      # === Example
      #
      #   receive_routed :panel_self,
      #     ->(_, model) { model.with(count: model.count + 1) }
      def receive_routed(...)
        receives.add_routed(...)
      end

      # Handles matching class instances. Stops further processing.
      #
      # Matches messages by class. Use <tt>receive</tt> for messages
      # addressed to you. Use <tt>intercept</tt> to stop a bubbled message
      # mid-chain.
      #
      # <tt>intercept_instances_of</tt> is an alias.
      #
      # === Example
      #
      #   receive_instances_of FatalError,
      #     ->(msg, model) { [model.with(error: msg), Rooibos::Command.exit] }
      def receive_instances_of(...)
        receives.add_instances_of(...)
      end

      # Handles any message. Stops further processing.
      #
      # Matches every message. Combine with guards to create conditional
      # catch-alls. For example, block all input when a fragment is inactive.
      #
      # <tt>intercept_all</tt> is an alias.
      #
      # === Example
      #
      #   receive_all ->(msg, model) { [model, nil] },
      #     unless: ->(_, model) { model.active }
      def receive_all(...)
        receives.add_all(...)
      end

      # Handles messages matching a custom predicate. Stops further processing.
      #
      # The predicate lambda receives <tt>(message, model)</tt>. If it returns
      # a truthy value, the handler runs and no later handlers execute.
      #
      # <tt>intercept</tt> is an alias.
      #
      # === Example
      #
      #   receive ->(msg, _) { msg.key? && msg.text? },
      #     ->(msg, model) { model.with(buffer: model.buffer + msg.char) }
      def receive(...)
        receives.add_custom(...)
      end

      alias intercept_events receive_events
      alias intercept_routed receive_routed
      alias intercept_instances_of receive_instances_of
      alias intercept_all receive_all
      alias intercept receive

      # Routes matching key events to a declared route.
      #
      # Matches raw RatatuiRuby events by their <tt>to_sym</tt> value.
      # Pass a symbol for a single event or an array for multiple events
      # that route to the same destination.
      #
      # The <tt>to:</tt> parameter accepts a symbol (model attribute), a
      # module (fragment), or a Route (return value of <tt>route</tt>).
      #
      # Use <tt>as:</tt> to wrap the event in a <tt>Message::Routed</tt>
      # with a semantic envelope. This decouples keybindings from nested
      # fragment internals.
      #
      # === Example
      #
      #   forward_events :enter, to: :active_form, as: :submit
      #   forward_events [:up, :k], to: :list, as: :move_up
      def forward_events(keys, to: @_scoped_target, **)
        forwards.add_events(keys, to:, **)
      end

      # Forwards all instances of a class to routes.
      #
      # Matches messages by class. Ideal for custom message types or
      # RatatuiRuby event classes like <tt>Event::Resize</tt>.
      #
      # Use <tt>broadcast: true</tt> to send to all declared routes, or
      # <tt>broadcast_to:</tt> with an array of specific route targets.
      #
      # === Example
      #
      #   forward_instances_of RatatuiRuby::Event::Resize, to: :main_layout
      #   forward_instances_of ThemeChanged, broadcast: true
      def forward_instances_of(klass, to: @_scoped_target, **)
        forwards.add_instances_of(klass, to:, **)
      end

      # Routes matching routed messages to a declared route.
      #
      # Matches <tt>Message::Routed</tt> messages by envelope. Use this
      # when an outer fragment has already routed an event and you need
      # to route it further to a nested fragment.
      #
      # Use <tt>as:</tt> to transform the envelope before forwarding.
      # Each layer speaks its inner fragment's API without knowing what
      # lies deeper.
      #
      # === Example
      #
      #   forward_routed :leaf_1, to: :top_leaf, as: :increment
      #   forward_routed :leaf_2, to: :bottom_leaf, as: :increment
      def forward_routed(envelopes, to: @_scoped_target, **)
        forwards.add_routed(envelopes, to:, **)
      end

      # Routes any message to a declared route.
      #
      # Matches every message. Combine with guards to conditionally route
      # unhandled messages. Without guards, acts as a catch-all forward.
      #
      # === Example
      #
      #   only when: -> (_, model) { model.active_tab == :counter_tab } do
      #     forward_all to: :counter_tab
      #   end
      #   forward_all to: :active_panel
      def forward_all(to: @_scoped_target, **guard_opts)
        forwards.add_custom(Predicate::Always.new, to:, **guard_opts)
      end

      # Routes messages matching a custom predicate to a declared route.
      #
      # The predicate lambda receives <tt>(message, model)</tt>. If it
      # returns a truthy value, the message is forwarded. Use this for
      # complex matching logic that the specialized variants cannot express.
      #
      # === Example
      #
      #   forward ->(msg, _) { msg.key? && msg.ctrl? },  to: :editor
      #   forward ->(msg, _) { msg.key? && msg.shift? }, to: Sidebar
      def forward(predicate, to: @_scoped_target, **)
        forwards.add_custom(predicate, to:, **)
      end

      # Observes matching key events. Does not stop further processing.
      #
      # Matches raw RatatuiRuby events by <tt>to_sym</tt>. All matching
      # observers run in declaration order. The message continues to later
      # handlers. Use observe for side effects that should not block other
      # handlers: logging, counting, updating derived state.
      #
      # === Example
      #
      #   observe_events :enter,
      #     ->(_, model) { [model, Rooibos::Command.custom(Logger.log("Enter pressed"))] }
      def observe_events(...)
        observes.add_events(...)
      end

      # Observes matching routed messages. Does not stop further processing.
      #
      # Matches <tt>Message::Routed</tt> by envelope. The message continues
      # to later handlers after this observer runs.
      #
      # === Example
      #
      #   observe_routed :submit,
      #     ->(_, model) { model.with(submissions: model.submissions + 1) }
      def observe_routed(...)
        observes.add_routed(...)
      end

      # Observes matching class instances. Does not stop further processing.
      #
      # Matches messages by class. Use it to react to custom message types
      # while allowing them to continue to other handlers.
      #
      # === Example
      #
      #   observe_instances_of LeafReset,
      #     ->(_, model) { model.with(nested_resets: model.nested_resets + 1) }
      def observe_instances_of(...)
        observes.add_instances_of(...)
      end

      # Observes any message. Does not stop further processing.
      #
      # Matches every message. Useful for metrics, debugging, or global
      # state updates that apply regardless of message type.
      #
      # === Example
      #
      #   observe_all ->(msg, model) {
      #     model.with(message_count: model.message_count + 1)
      #   }
      def observe_all(...)
        observes.add_all(...)
      end

      # Observes messages matching a custom predicate. Does not stop further
      # processing.
      #
      # The predicate lambda receives <tt>(message, model)</tt>. All matching
      # observers run. The message continues to later handlers.
      #
      # === Example
      #
      #   observe ->(msg, _) { msg.leaf_reset? || msg.panel_reset? },
      #     ->(_, model) { model.with(total_resets: model.total_resets + 1) }
      def observe(...)
        observes.add_custom(...)
      end

      # Catches unhandled messages as a router-level fallback.
      #
      # Messages not handled by <tt>receive</tt>, <tt>intercept</tt>, or
      # <tt>forward</tt> fall through to <tt>otherwise</tt>. The
      # <tt>route_to:</tt> parameter accepts the same three forms as
      # <tt>to:</tt> in the forward family. Multiple <tt>otherwise</tt>
      # declarations with guards create a conditional fallthrough chain.
      #
      # This keeps outer fragments minimal. Declare what you handle;
      # everything else flows to the nested fragment.
      #
      # === Example
      #
      #   otherwise route_to: :counter_tab,
      #     when: ->(_, model) { model.active_tab == :counter }
      #   otherwise route_to: :color_tab,
      #     when: ->(_, model) { model.active_tab == :color }
      #   otherwise route_to: :dashboard
      def otherwise(...)
        otherwises.add(...)
      end

      # Scopes a positive guard over declarations within the block.
      #
      # Every forward, receive, intercept, observe, and otherwise inside
      # the block runs only when the guard returns truthy. Blocks nest;
      # inner guards combine with outer ones.
      #
      # === Example
      #
      #   only when: -> (_, model) { model.focused? } do
      #     forward_events :j, to: :list, as: :move_down
      #   end
      private def only(when: nil, if: nil, &)
        Guard.scoped(binding.local_variable_get(:when) || binding.local_variable_get(:if), &)
      end

      # Scopes a negative guard over declarations within the block.
      #
      # The inverse of <tt>only</tt>. Declarations inside the block run
      # only when the guard returns falsy.
      #
      # === Example
      #
      #   skip when: -> (_, model) { model.locked? } do
      #     receive_events :d, :delete
      #   end
      private def skip(when: nil, if: nil, &)
        positive = binding.local_variable_get(:when) || binding.local_variable_get(:if)
        Guard.scoped(-> (msg, model) { !positive.call(msg, model) }, &)
      end

      # Scopes the default <tt>to:</tt> target for forwards and receives
      # within the block.
      #
      # Avoids repeating <tt>to: :some_route</tt> on every declaration.
      # The scoped target resets after the block.
      #
      # === Example
      #
      #   route_to :left_panel do
      #     forward_events :a, as: :panel_self
      #     forward_events :"1", as: :leaf_1
      #     forward_events :"2", as: :leaf_2
      #   end
      private def route_to(target)
        @_scoped_target = target
        yield if block_given?
      ensure
        @_scoped_target = nil
      end
    end
  end
end
