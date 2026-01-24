# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require_relative "custom_shell_input"
require_relative "custom_shell_output"

# Modal overlay for custom shell command execution.
module CustomShellModal
  Command = Rooibos::Command

  Model = Data.define(:mode, :input, :output)

  Init = -> do
    input, = Rooibos.normalize_init(CustomShellInput::Init.())
    output, = Rooibos.normalize_init(CustomShellOutput::Init.())
    Ractor.make_shareable(Model.new(mode: :none, input:, output:))
  end

  View = -> (model, tui) do
    case model.mode
    when :input
      CustomShellInput::View.call(model.input, tui)
    when :output
      CustomShellOutput::View.call(model.output, tui)
    else
      nil
    end
  end

  Update = -> (message, model) do
    case [model.mode, message]
    in [:input, _]
      # Delegate first, then check if user wants to close
      new_input, _cmd = CustomShellInput::Update.call(message, model.input)

      if new_input.canceled
        [Init.(), nil]
      elsif new_input.submitted
        shell_cmd = new_input.text
        new_output = CustomShellOutput::Init.().with(command: shell_cmd, running: true)
        reset_input, = Rooibos.normalize_init(CustomShellInput::Init.())
        [
          model.with(mode: :output, input: reset_input, output: new_output),
          Command.system(shell_cmd, :shell_output, stream: true),
        ]
      else
        [model.with(input: new_input), nil]
      end

    in [:output, _]
      # Delegate first, then check if user wants to close
      case message
      in RatatuiRuby::Event::Key if message.ctrl_c?
        [Init.(), nil]
      else
        new_output, _cmd = CustomShellOutput::Update.call(message, model.output)

        if new_output.dismissed
          [Init.(), nil]
        else
          [model.with(output: new_output), nil]
        end
      end

    else
      [model, nil]
    end
  end

  def self.open
    input, = Rooibos.normalize_init(CustomShellInput::Init.())
    Init.().with(mode: :input, input:)
  end

  def self.active?(model)
    model.mode != :none
  end
end
