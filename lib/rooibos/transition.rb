# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Transition represents a normalized [model, command] tuple from Update.
  # Use Transition.from to convert DWIM return values.
  class Transition < Data.define(:model, :command)
    # Creates a Transition from an Update return value.
    #
    # Handles:
    # <tt>nil</tt>:: preserve previous model, no command
    # <tt>model</tt>:: new model, no command
    # <tt>command</tt>:: previous model, command
    # <tt>[model, command]</tt>:: as-is
    def self.from(update_return, previous_model)
      case update_return
      when nil
        new(model: previous_model, command: nil)
      when -> (r) { r.respond_to?(:rooibos_command?) && r.rooibos_command? }
        new(model: previous_model, command: update_return)
      when Array
        case update_return
        in [model, command] if command.nil? || (command.respond_to?(:rooibos_command?) && command.rooibos_command?)
          new(model:, command:)
        else
          warn_suspicious_callable(update_return)
          new(model: update_return, command: nil)
        end
      else
        new(model: update_return, command: nil)
      end
    end

    # Creates an initial Transition with no command.
    def self.initial(model)
      new(model:, command: nil)
    end

    # Returns new Transition with an updated model, or self if nil.
    def with_model(new_model)
      return self unless new_model

      Transition.new(model: new_model, command:)
    end

    # Returns new Transition with an updated command, or self if nil.
    def with_command(new_command)
      return self unless new_command

      Transition.new(model:, command: new_command)
    end

    # Returns new Transition with command added (batched if existing).
    def with_added_command(new_command)
      return self unless new_command
      return with_command(new_command) unless command

      with_command(Command.batch(command, new_command))
    end

    # Returns new Transition with command added via Separate (for observe).
    def with_separate_command(new_command)
      return self unless new_command
      return with_command(new_command) unless command

      with_command(Command.const_get(:Separate).new(commands: [command, new_command]))
    end

    # Converts to [model, command] tuple.
    def to_a = [model, command]
    alias to_ary to_a
    alias deconstruct to_a

    # Warns if tuple looks like [model, command] but command isn't marked as such.
    private_class_method def self.warn_suspicious_callable(update_return) # :nodoc:
      return unless RatatuiRuby::Debug.enabled?

      _, suspect = update_return
      return unless suspect.respond_to?(:call)
      return if Ractor.shareable?(update_return)

      warn "WARNING: Update returned [model, #{suspect.class}] but #{suspect.class} " \
        "responds to #call without #rooibos_command?. Did you forget to include Command::Custom? " \
        "The tuple will be treated as the model, not as [model, command]. " \
        "To suppress this warning if the array is your model, use Ractor.make_shareable on it."
    end
  end
end
