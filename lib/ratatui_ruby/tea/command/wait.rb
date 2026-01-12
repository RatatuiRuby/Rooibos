# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module RatatuiRuby
  module Tea
    module Command
      # A one-shot timer command.
      #
      # Applications need timed events. Notification auto-dismissal,
      # debounced search, and animation frames all depend on delays.
      # Building timers from scratch with threads is error-prone.
      # Cancellation is tricky.
      #
      # This command waits, then sends a message. It responds to
      # cancellation cooperatively. When cancelled, it sends
      # <tt>Command.cancel(self)</tt> so you know the timer stopped.
      #
      # Use it for delayed actions, debounced inputs, or animation loops.
      #
      # === Example: Notification dismissal
      #
      #   def update(msg, model)
      #     case msg
      #     in [:save_clicked]
      #       [model.with(notification: "Saved!"), Command.wait(3.0, :dismiss)]
      #     in [:dismiss]
      #       [model.with(notification: nil), nil]
      #     in Command::Cancel
      #       [model.with(notification: nil), nil]  # User navigated away
      #     end
      #   end
      #
      # === Example: Animation loop
      #
      #   def update(msg, model)
      #     case msg
      #     in [:start_animation]
      #       [model.with(frame: 0), Command.tick(0.1, :animate)]
      #     in [:animate]
      #       frame = (model.frame + 1) % 10
      #       [model.with(frame:), Command.tick(0.1, :animate)]
      #     end
      #   end
      Wait = Data.define(:seconds, :tag) do
        include Custom

        # Cooperative cancellation needs no grace period.
        # The command responds instantly to cancellation via
        # <tt>Concurrent::Cancellation.timeout</tt>.
        def tea_cancellation_grace_period
          0
        end

        # Executes the timer.
        #
        # Waits for <tt>seconds</tt>, then sends <tt>[tag]</tt>.
        # If cancelled, sends <tt>Command.cancel(self)</tt> instead.
        #
        # [outlet] Outlet for sending messages.
        # [token] Cancellation token from the runtime.
        def call(outlet, token)
          timer_cancellation, _origin = Concurrent::Cancellation.timeout(seconds)
          combined = token.join(timer_cancellation)
          combined.origin.wait

          if token.canceled?
            outlet.put(Command.cancel(self))
          else
            outlet.put(tag)
          end
        end
      end
    end
  end
end
