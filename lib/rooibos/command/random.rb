# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # A command that generates a random value.
    #
    # Games roll dice. Encryption needs keys. Shuffling needs seeds.
    # All of these call <tt>Kernel#rand</tt> or <tt>Random</tt>. But
    # randomness in Update is a side effect: the same model and message
    # would produce different results on each call. Testing would become
    # fragile and non-deterministic.
    #
    # This command delegates to Ruby's <tt>Random</tt> class through
    # the runtime. Update receives the result as a
    # <tt>Message::Random</tt>.
    #
    # Use it for dice rolls, shuffles, key generation, or any feature
    # that needs random values without side effects in Update.
    #
    # Prefer the <tt>Command.random</tt> factory method for convenience.
    #
    # === Example: Dice roll
    #
    #   def update(msg, model)
    #     case msg
    #     in { type: :random, envelope: :roll, value: }
    #       model.with(die_face: value)
    #     end
    #   end
    #
    # === Example: Random float
    #
    #   def update(msg, model)
    #     case msg
    #     in { type: :random, envelope: :spawn_chance, value: }
    #       model.with(should_spawn: value < 0.3)
    #     end
    #   end
    class Random < Data.define(:args, :envelope)
      include Custom

      # Executes the random command.
      #
      # Without a leading symbol, calls <tt>Random.rand</tt> with the
      # stored arguments. With a leading symbol, calls that method on
      # <tt>Random</tt> via <tt>public_send</tt>.
      #
      # [out] Outlet for sending messages.
      # [token] Cancellation token from the runtime.
      def call(out, token)
        if token.canceled?
          out.put(Message::Canceled.new(command: self))
          return
        end

        value = if args.first.is_a?(Symbol)
          method_name = args.first
          ::Random.public_send(method_name, *args[1..])
        else
          ::Random.rand(*args)
        end
        out.put(Ractor.make_shareable(Message::Random.new(envelope:, value:)))
      end
    end
  end
end
