# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Message
    # Response from a random command.
    #
    # Games roll dice. Encryption needs keys. Shuffling needs seeds.
    # All of these call <tt>Kernel#rand</tt> or <tt>Random</tt>. But
    # randomness in Update is a side effect: the same model and message
    # would produce different results on each call. Testing would become
    # fragile.
    #
    # This response carries the random value from the runtime. Update
    # pattern-matches on the envelope to distinguish multiple rolls.
    #
    # Use it to handle <tt>Command.random</tt> completions.
    #
    # === Example
    #
    #   case msg
    #   in { type: :random, envelope: :roll_die, value: }
    #     model.with(roll: value)
    #   in { type: :random, envelope: :shuffle_seed, value: }
    #     model.with(sort_seed: value)
    #   end
    #
    class Random < Data.define(:envelope, :value)
      include Predicates
      # Returns +true+ for random responses.
      def random?
        true
      end
    end
  end
end
