# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Encapsulates dispatch logic - given frozen rule sets, processes messages.
    class RouterUpdate < Data.define(:inward, :outward)
      def call(message, model)
        case message
        when Message::Bubbled then dispatch_outward(message.message, model)
        else dispatch_inward(message, model)
        end
      end

      private def dispatch_inward(message, model)
        transition = inward.call(message, model)
        case transition.command
        when Command::Bubble # Sentinel; not a real Command to be handled by the runtime
          bubble_model, bubble_cmd = dispatch_outward(transition.command.message, transition.model)
          transition = transition.with_model(bubble_model).with_command(bubble_cmd)
        when Command::Batch
          transition = extract_bubbles_from_batch(transition)
        end
        transition = transition.with(command: nil) if transition.command.equal?(Flow::Outward::INTERCEPTED)
        transition.to_a
      end

      private def extract_bubbles_from_batch(transition)
        bubbles, remaining = transition.command.extract_bubbles
        return transition if bubbles.empty?

        result = Transition.new(model: transition.model, command: remaining)
        bubbles.each do |bubble|
          model, cmd = dispatch_outward(bubble.message, result.model)
          result = Transition.new(model:, command: result.command)
          result = result.with_added_command(cmd) unless cmd.nil? || cmd.equal?(Flow::Outward::INTERCEPTED)
        end
        result
      end

      private def dispatch_outward(message, model)
        outward.call(message, model).to_a
      end
    end
    private_constant :RouterUpdate
  end
end
