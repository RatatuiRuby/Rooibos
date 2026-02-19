# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Mixin for user-defined custom commands.
    #
    # Custom commands extend Rooibos with side effects: WebSockets, gRPC, database polls,
    # background tasks. The runtime dispatches them in threads and routes results
    # back as messages.
    #
    # Include this module to identify your class as a command. The runtime uses
    # +rooibos_command?+ to distinguish commands from plain models. Override
    # +rooibos_cancellation_grace_period+ if your cleanup takes longer than 100 milliseconds.
    #
    # Use it to build real-time features, long-polling connections, or background workers.
    #
    # === Example
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   class WebSocketCommand
    #     include Rooibos::Command::Custom
    #
    #     def initialize(url)
    #       @url = url
    #     end
    #
    #     def call(out, token)
    #       ws = WebSocket::Client.new(@url)
    #       ws.on_message { |msg| out.put(:ws_message, msg) }
    #       ws.connect
    #
    #       until token.canceled?
    #         ws.ping
    #         sleep 1
    #       end
    #
    #       ws.close
    #     end
    #
    #     # WebSocket close handshake needs extra time
    #     def rooibos_cancellation_grace_period
    #       5.0
    #     end
    #   end
    #--
    # SPDX-SnippetEnd
    #++
    module Custom
      # Brand predicate for command identification.
      #
      # The runtime calls this to distinguish commands from plain models.
      # Returns <tt>true</tt> unconditionally.
      #
      # You do not need to override this method.
      def rooibos_command?
        true
      end

      # Cleanup time after cancellation is requested. In seconds.
      #
      # When the runtime cancels your command (app exit, navigation, explicit cancel),
      # it calls <tt>token.cancel!</tt> and waits this long for your command to stop.
      # If your command does not exit within this window, it is orphaned until
      # process exit. There is no safe way to force-kill a Ruby thread.
      #
      # *This is NOT a lifetime limit.* Your command runs indefinitely until canceled.
      # A WebSocket open for 15 minutes is fine. This timeout only applies to the
      # cleanup phase after cancellation is requested.
      #
      # Override this method to specify how long your cleanup takes:
      #
      # - <tt>0.5</tt> — Quick HTTP abort, no cleanup needed
      # - <tt>2.0</tt> — Default, suitable for most commands
      # - <tt>5.0</tt> — WebSocket close handshake with remote server
      # - <tt>Float::INFINITY</tt> — Wait indefinitely for cooperative exit (database transactions)
      #
      # === Example
      #
      #--
      # SPDX-SnippetBegin
      # SPDX-FileCopyrightText: 2026 Kerrick Long
      # SPDX-License-Identifier: MIT-0
      #++
      #   # Database transactions should never be interrupted mid-write
      #   def rooibos_cancellation_grace_period
      #     Float::INFINITY
      #   end
      #--
      # SPDX-SnippetEnd
      #++
      def rooibos_cancellation_grace_period
        0.1
      end

      # Infrastructure methods to exclude from introspection.
      # Computed once from bare prototypes.
      INFRASTRUCTURE_METHODS = begin
        bare_data = Data.define(:_)
        bare_struct = Struct.new(:_)

        methods = Object.public_instance_methods +
          bare_data.public_instance_methods +
          bare_struct.public_instance_methods

        # PP methods can error when called on objects without pretty_print override
        methods += %i[
          pretty_print
          pretty_print_cycle
          pretty_print_instance_variables
          pretty_print_inspect
]

        methods.uniq.freeze
      end
      private_constant :INFRASTRUCTURE_METHODS

      # Deconstructs for hash-based pattern matching.
      #
      # Introspects public query methods (CQS: zero-arity, no side effects) and
      # returns a hash suitable for +case+/+in+ matching. Excludes infrastructure
      # methods from Object, Data, and Struct.
      #
      # Always includes +:type+ as a snake_case symbol of the class name.
      # Anonymous classes default to +:custom+.
      #
      # Data.define members are automatically included since they generate
      # public accessor methods.
      #
      # This is a naive but practical default. Override for:
      # - Hot paths (introspects methods on every call)
      # - Ghost methods via +method_missing+/+respond_to_missing?+
      # - Methods with optional arguments (only zero-arity detected)
      #
      # @param keys [Array<Symbol>, nil] Limit output to specific keys for performance.
      #   Pass +nil+ to include all keys.
      # @return [Hash{Symbol => Object}] Deconstructed hash with +:type+ discriminator.
      #
      # @example Pattern matching with Data.define command
      #   case msg
      #   in { type: :http_response, envelope: :users, status: 200 }
      #     # handle success
      #   end
      def deconstruct_keys(keys)
        class_name = self.class.name&.split("::")&.last
        type_name = if class_name
          class_name
            .gsub(/([a-z])([A-Z])/, '\1_\2')
            .downcase
            .to_sym
        else
          :custom
        end

        result = { type: type_name }

        # Include Data.define/Struct members
        if self.class.respond_to?(:members)
          klass = self.class #: Class & _HasMembers
          klass.members.each do |member|
            next if keys && !keys.include?(member)
            result[member] = public_send(member)
          end
        end

        # Include public zero-arity query methods (excluding infrastructure)
        # Use Kernel#public_method to avoid collision with Data.define :method member
        get_method = Kernel.instance_method(:public_method)
        (public_methods - INFRASTRUCTURE_METHODS).each do |method_name|
          next if method_name.to_s.end_with?("=", "!")
          next unless get_method.bind_call(self, method_name).arity.zero?
          next if keys && !keys.include?(method_name)
          result[method_name] = public_send(method_name)
        end

        result
      end
    end
  end
end
