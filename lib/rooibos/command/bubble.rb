# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # Carries a message outward through the fragment hierarchy.
    #
    # Nested fragments produce signals. Outer fragments consume them. Passing
    # callbacks down the tree couples fragments tightly. Direct references
    # make reuse difficult.
    #
    # This command wraps a message for bubbling. Outer fragments intercept it
    # and decide how to handle it. With the Router DSL, use <tt>observe</tt>
    # or <tt>intercept</tt>. Without the Router, check for <tt>Command::Bubble</tt>
    # manually and extract the message. Unhandled bubbles can be re-returned
    # to continue propagation outward.
    #
    # The runtime does not execute this command. Outer fragments handle it.
    # Calling <tt>call</tt> raises an error.
    #
    # [message] The payload to propagate outward.
    class Bubble < Data.define(:message)
      include Custom

      # No-op: unhandled bubbles that escape the Router hierarchy( when no
      # fragment intercepts the message) are silently dropped.
      def call(_out, _token) = nil
    end
  end
end
