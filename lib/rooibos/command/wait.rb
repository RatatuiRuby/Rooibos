# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  module Command
    # A one-shot timer command.
    #
    # Applications need timed events. Notification auto-dismissal,
    # debounced search, and animation frames all depend on delays.
    # Building timers from scratch with threads is error-prone.
    # Cancellation is tricky.
    #
    # This command waits, then sends a message. It responds to
    # cancellation cooperatively. When canceled, it sends
    # <tt>Message::Canceled</tt> so you know the timer stopped.
    #
    # Use it for delayed actions, debounced inputs, or animation loops.
    #
    # Prefer the <tt>Command.wait</tt> or <tt>Command.tick</tt> factory
    # methods for convenience. Both are aliases for the same behavior.
    #
    # === Example: Notification dismissal
    #
    #   def update(msg, model)
    #     case msg
    #     in :save_clicked
    #       [model.with(notification: "Saved!"), Command.wait(3.0, :dismiss)]
    #     in :dismiss
    #       [model.with(notification: nil), nil]
    #     in Message::Canceled
    #       [model.with(notification: nil), nil]  # User navigated away
    #     end
    #   end
    #
    # === Example: Animation loop
    #
    #   def update(msg, model)
    #     case msg
    #     in :start_animation
    #       [model.with(frame: 0), Command.tick(0.1, :animate)]
    #     in :animate
    #       frame = (model.frame + 1) % 10
    #       [model.with(frame:), Command.tick(0.1, :animate)]
    #     end
    #   end
    class Wait < Data.define(:seconds, :envelope)
      include Custom
      include Timed

      private def timed_response(start_time)
        elapsed = Time.now - start_time
        Message::Timer.new(envelope:, elapsed:)
      end
    end
  end
end
