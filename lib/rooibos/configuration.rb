# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Configuration represents the Mealy machine (state, input) pair.
  # Immutable value object; use with_model to derive new configurations.
  class Configuration < Data.define(:message, :model)
    ##
    # Derives a new Configuration with an updated model.
    # Returns <tt>self</tt> if <tt>new_model</tt> is <tt>nil</tt>.
    def with_model(new_model)
      return self unless new_model

      Configuration.new(message:, model: new_model)
    end

    ##
    # Destructures into <tt>[message, model]</tt> array.
    def to_a
      [message, model]
    end
    alias to_ary to_a
    alias deconstruct to_a
  end
end
