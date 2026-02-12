# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: MIT-0
#++

require "rooibos"

# Shared message types for the tabbed fragments example.
#
# All messages include Rooibos::Message::Predicates for type predicates
# (e.g., message.milestone?) and have an envelope attribute for routing.

# Delivered when a counter reaches 5 (fire-and-forget to Root).
class Milestone < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

# Bubbled when a leaf counter reaches 10 and resets.
class LeafReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

# Bubbled when a panel counter reaches 10 and resets.
class PanelReset < Data.define(:envelope, :count)
  include Rooibos::Message::Predicates
end

# Re-bubbled from Panel with added context about which leaf reset.
class PanelChildReset < Data.define(:envelope, :leaf, :count)
  include Rooibos::Message::Predicates
end

# Bubbled when ColorTab selects a color.
class ColorChanged < Data.define(:color_name, :hex)
  include Rooibos::Message::Predicates
end

# Broadcast when theme changes.
class ThemeChanged < Data.define(:theme)
  include Rooibos::Message::Predicates
end

# Bubbled when TabBar selects a tab.
class TabSelected < Data.define(:tab)
  include Rooibos::Message::Predicates
end
