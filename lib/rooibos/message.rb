# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Messages sent from commands to update functions.
  #
  # All built-in response types live here. Each includes the <tt>Predicates</tt>
  # mixin for safe predicate calls.
  module Message
    # Matches built-in framework message types for case/when dispatch.
    #
    # Returns <tt>true</tt> only for classes under <tt>Rooibos::Message::</tt>.
    # Rejects key events and user-defined message classes.
    #
    # === Example
    #
    #   case message
    #   when Rooibos::Message
    #     handle_command_response(message)
    #   when RatatuiRuby::Event::Key
    #     handle_key(message)
    #   end
    def self.===(other)
      other.class.name&.start_with?("Rooibos::Message::")
    end

    # Fallback predicate mixin.
    #
    # Update functions receive many message types. Checking unknown predicates
    # crashes with NoMethodError. Verifying every predicate clutters the code.
    #
    # This mixin returns <tt>false</tt> for unknown predicates. It also adds
    # symbol comparison via <tt>to_sym</tt> and <tt>==</tt>.
    #
    # Include in custom message types for safe predicate calls and symbol matching.
    module Predicates
      # Converts the message to a Symbol.
      #
      # Returns the <tt>:type</tt> value from <tt>deconstruct_keys</tt> prefixed
      # with <tt>message_</tt>. The prefix avoids collision with RatatuiRuby
      # event symbols like <tt>:resize</tt> or <tt>:mouse</tt>.
      #
      # === Example
      #
      #   timer = Message::Timer.new(envelope: :tick, elapsed: 0.016)
      #   timer.to_sym # => :message_timer
      def to_sym
        :"message_#{deconstruct_keys(nil)[:type]}"
      end

      # Compares the message with another object.
      #
      # Symbols compare against <tt>to_sym</tt>. Other objects use default equality.
      #
      # === Example
      #
      #   if message == :message_timer
      #     handle_tick(message)
      #   end
      def ==(other)
        case other
        when Symbol then to_sym == other
        else super
        end
      end

      # Returns <tt>true</tt> if predicate matches <tt>:type</tt> or
      # <tt>:envelope</tt> from <tt>deconstruct_keys</tt>. Returns
      # <tt>false</tt> for unknown predicate methods.
      def method_missing(name, *args, **kwargs, &block)
        if name.to_s.end_with?("?") && args.empty? && kwargs.empty?
          predicate = name.to_s.chomp("?").to_sym
          keys = deconstruct_keys(nil)
          keys[:type] == predicate || keys[:envelope] == predicate
        else
          super
        end
      end

      # Fallback pattern matching for classes without explicit deconstruct_keys.
      #
      # Derives <tt>:type</tt> from the class name in snake_case. Anonymous
      # classes default to <tt>:custom</tt>.
      #
      # === Example
      #
      #   class MyCustomMessage
      #     include Rooibos::Message::Predicates
      #   end
      #
      #   msg = MyCustomMessage.new
      #   msg.deconstruct_keys(nil) # => { type: :my_custom_message }
      #   msg.to_sym                # => :message_my_custom_message
      def deconstruct_keys(keys)
        class_name = self.class.name&.split("::")&.last
        type_name = if class_name
          class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
        else
          :custom
        end

        # Filter out :type before calling super — Data returns {} if any
        # requested key is unknown, which breaks pattern matching
        filtered_keys = keys&.reject { |k| k == :type }

        # Preserve parent's fields (e.g., Data.define members) and add :type
        parent_keys = begin
          super(filtered_keys)
        rescue NoMethodError
          {} #: Hash[Symbol, untyped]
        end
        parent_keys.merge(type: type_name)
      end

      # Responds to all predicate methods.
      def respond_to_missing?(name, *)
        name.to_s.end_with?("?")
      end
    end
  end
end

require_relative "message/timer"
require_relative "message/clock"
require_relative "message/random"
require_relative "message/open"
require_relative "message/http_response"
require_relative "message/system/batch"
require_relative "message/system/stream"
require_relative "message/all"
require_relative "message/batch"
require_relative "message/error"
require_relative "message/canceled"
require_relative "message/routed"
require_relative "message/bubbled"
