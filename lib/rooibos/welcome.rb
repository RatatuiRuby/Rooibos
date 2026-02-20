# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

module Rooibos
  # Built-in welcome screen used by scaffolded applications.
  module Welcome
    # Detect the gem name from the file that required this welcome screen.
    # A scaffolded app's main lib file (e.g. lib/hello_rooibos.rb) lives
    # directly under lib/ with no subdirectory — that distinguishes it from
    # gem internals (lib/rooibos/welcome.rb) and test files (test/*.rb).
    # Evaluated once at require-time; nil when loaded outside a lib/ context.
    SOURCE_GEM = begin
      rooibos_lib = File.expand_path("..", String(__dir__)) # this gem's lib/ dir
      caller_locations
        &.filter_map(&:absolute_path)
        &.find { |p| p.match?(%r{/lib/[^/]+\.rb\z}) && !p.start_with?(rooibos_lib) }
        &.then { |p| File.basename(p, ".rb") }
    end
    private_constant :SOURCE_GEM

    module UI # :nodoc:
      module Styles # :nodoc:
        TEXT = RatatuiRuby::Style::Style.new
        FILENAME = RatatuiRuby::Style::Style.new(fg: :green)
        COMMAND = RatatuiRuby::Style::Style.new(fg: :red)
        URL = RatatuiRuby::Style::Style.new(fg: :blue)

        COMMAND_BUTTON = RatatuiRuby::Style::Style.new(fg: :red, modifiers: [:underlined])
        COMMAND_BUTTON_FOCUS = RatatuiRuby::Style::Style.new(fg: :red, modifiers: [:bold, :underlined])
        COMMAND_BUTTON_HOVER = RatatuiRuby::Style::Style.new(fg: :red, modifiers: [:reversed])
        COMMAND_BUTTON_BOTH = RatatuiRuby::Style::Style.new(fg: :red, modifiers: [:bold, :reversed])

        URL_BUTTON = RatatuiRuby::Style::Style.new(fg: :blue, modifiers: [:underlined])
        URL_BUTTON_FOCUS = RatatuiRuby::Style::Style.new(fg: :blue, modifiers: [:bold, :underlined])
        URL_BUTTON_HOVER = RatatuiRuby::Style::Style.new(fg: :blue, modifiers: [:reversed])
        URL_BUTTON_BOTH = RatatuiRuby::Style::Style.new(fg: :blue, modifiers: [:bold, :reversed])
      end

      module Widgets # :nodoc:
        LIB_FILE  = SOURCE_GEM ? "lib/#{SOURCE_GEM}.rb"       : "lib/your_app.rb"
        TEST_FILE = SOURCE_GEM ? "test/test_#{SOURCE_GEM}.rb" : "test/test_your_app.rb"

        WELCOME_TEXT = {
          "Welcome to Rooibos! You will find the Ruby code " \
            "for this application in " => Styles::TEXT,
          LIB_FILE => Styles::FILENAME,
          ". The tests that verify it are at " => Styles::TEXT,
          TEST_FILE => Styles::FILENAME,
          ". You can run the tests with " => Styles::TEXT,
          "bundle exec rake test" => Styles::COMMAND,
          ". Visit " => Styles::TEXT,
          "www.rooibos.run" => Styles::URL,
          " to learn about Rooibos and to find other " \
            "Rooibos developers. You can press " => Styles::TEXT,
          "Control + C" => Styles::COMMAND,
          " to exit at any time." => Styles::TEXT,
        }

        PARAGRAPH = RatatuiRuby::Widgets::Paragraph.new(
          text: RatatuiRuby::Text::Line.new(
            spans: WELCOME_TEXT.map { |text, style| RatatuiRuby::Text::Span.new(content: text, style:) }
          ),
          wrap: true,
          alignment: :left
        )

        def self.website_button(focused: false, hovered: false)
          style = if focused && hovered
            Styles::URL_BUTTON_BOTH
          elsif focused
            Styles::URL_BUTTON_FOCUS
          elsif hovered
            Styles::URL_BUTTON_HOVER
          else
            Styles::URL_BUTTON
          end
          RatatuiRuby::Text::Span.new(content: "[Visit Website]", style:)
        end

        def self.exit_button(focused: false, hovered: false)
          style = if focused && hovered
            Styles::COMMAND_BUTTON_BOTH
          elsif focused
            Styles::COMMAND_BUTTON_FOCUS
          elsif hovered
            Styles::COMMAND_BUTTON_HOVER
          else
            Styles::COMMAND_BUTTON
          end
          RatatuiRuby::Text::Span.new(content: "[Exit App]", style:)
        end
      end

      BUTTON_SLOTS = { website: 1, exit: 3 }.freeze
      FOCUS_ORDER = [:website, :exit].freeze

      BUTTON_BAR_CONSTRAINTS = [
        RatatuiRuby::Layout::Constraint.fill(1),
        RatatuiRuby::Layout::Constraint.length(18),
        RatatuiRuby::Layout::Constraint.length(2),
        RatatuiRuby::Layout::Constraint.length(14),
        RatatuiRuby::Layout::Constraint.fill(1),
      ].freeze

      CONTENT_CONSTRAINTS = [
        RatatuiRuby::Layout::Constraint.fill(1),
        RatatuiRuby::Layout::Constraint.length(1),
      ].freeze

      def self.button_bar(focused:, hovered:)
        RatatuiRuby::Layout::Layout.new(
          direction: :horizontal,
          constraints: BUTTON_BAR_CONSTRAINTS,
          children: [
            nil,
            Widgets.website_button(focused: focused == :website, hovered: hovered == :website),
            nil,
            Widgets.exit_button(focused: focused == :exit, hovered: hovered == :exit),
            nil,
          ]
        )
      end

      def self.content_layout(focused:, hovered:)
        RatatuiRuby::Layout::Layout.new(
          direction: :vertical,
          constraints: CONTENT_CONSTRAINTS,
          children: [Widgets::PARAGRAPH, button_bar(focused:, hovered:)]
        )
      end

      def self.frame(focused:, hovered:)
        RatatuiRuby::Widgets::Block.new(
          title: "Hello, Rooibos!",
          borders: [:all],
          border_style: { fg: :cyan },
          padding: [2, 2, 1, 1],
          children: [content_layout(focused:, hovered:)]
        )
      end

      # Value object wrapping hit-test areas for clickable buttons.
      ButtonAreas = Data.define(:website, :exit) do
        def contains?(name, x, y) = public_send(name)&.contains?(x, y)

        def button_at(x, y)
          return :website if website&.contains?(x, y)
          return :exit if exit&.contains?(x, y)

          nil
        end

        def for_viewport(width, height)
          viewport = RatatuiRuby::Layout::Rect.new(x: 0, y: 0, width:, height:)
          frame = UI.frame(focused: nil, hovered: nil)
          inner = frame.inner(viewport)

          content_rects = RatatuiRuby::Layout::Layout.split(
            inner,
            direction: :vertical,
            constraints: CONTENT_CONSTRAINTS
          )
          button_rects = RatatuiRuby::Layout::Layout.split(
            content_rects[1],
            direction: :horizontal,
            constraints: BUTTON_BAR_CONSTRAINTS
          )

          ButtonAreas.new(
            website: button_rects[BUTTON_SLOTS[:website]],
            exit: button_rects[BUTTON_SLOTS[:exit]]
          )
        end
      end
    end

    # focused: keyboard focus (persists until Tab/Shift+Tab)
    # hovered: mouse hover (clears on mouse-out)
    Model = Data.define(:button_areas, :focused, :hovered) do
      def tree = UI.frame(focused:, hovered:)

      # Returns the "active" button for activation (keyboard takes precedence)
      def active_button = focused || hovered
    end

    View = -> (model, _tui) { model.tree }

    Update = -> (message, model) {
      case message
      in _ if message.ctrl_c?
        Rooibos::Command.exit
      in _ if message.resize?
        model.with(button_areas: model.button_areas.for_viewport(message.width, message.height))
      in _ if message.tab?
        cycle_focus(model, :forward)
      in _ if message.shift_back_tab?
        cycle_focus(model, :backward)
      in _ if message.enter? && model.active_button
        activate_button(model.active_button, model)
      in _ if message.mouse? && message.down? && message.button == "left"
        handle_click(message, model)
      in { type: :mouse }
        handle_hover(message, model)
      else
        model
      end
    }

    Init = -> {
      viewport = RatatuiRuby.terminal_size
      areas = UI::ButtonAreas.new(website: nil, exit: nil).for_viewport(viewport.width, viewport.height)
      Ractor.make_shareable Model.new(button_areas: areas, focused: nil, hovered: nil)
    }

    def self.handle_click(message, model)
      button = model.button_areas.button_at(message.x, message.y)
      activate_button(button, model)
    end

    def self.handle_hover(message, model)
      new_hovered = model.button_areas.button_at(message.x, message.y)
      return model if new_hovered == model.hovered

      model.with(hovered: new_hovered)
    end

    def self.cycle_focus(model, direction)
      order = UI::FOCUS_ORDER
      return model.with(focused: order.first) unless model.focused

      current_index = order.index(model.focused)
      return model.with(focused: order.first) unless current_index

      next_index = case direction
                  when :forward then (current_index + 1) % order.length
                  when :backward then (current_index - 1) % order.length
                  else 0
      end
      model.with(focused: order[next_index])
    end

    def self.activate_button(button, model)
      case button
      when :website then [model, Rooibos::Command.system("open 'https://www.rooibos.run'", :open_url)]
      when :exit then Rooibos::Command.exit
      else model
      end
    end
  end
end
