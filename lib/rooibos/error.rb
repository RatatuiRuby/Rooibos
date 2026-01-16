# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

module Rooibos
  # Base error class for Rooibos.
  #
  # All library-specific exceptions inherit from this class.
  # Catch this to handle any Rooibos error generically.
  #
  # === Example
  #
  #--
  # SPDX-SnippetBegin
  # SPDX-FileCopyrightText: 2026 Kerrick Long
  # SPDX-License-Identifier: MIT-0
  #++
  #   begin
  #     Rooibos.run(MyApp)
  #   rescue Rooibos::Error => e
  #     puts "Rooibos error: #{e.message}"
  #   end
  #--
  # SPDX-SnippetEnd
  #++
  class Error < StandardError
    # Invariant violation.
    #
    # The library enforces rules about valid states and contracts.
    # Breaking these rules raises this error.
    #
    # Common causes:
    # - Providing conflicting API parameters (e.g., both fragment and model/view/update)
    # - Callable return type mismatch (e.g., view returns <tt>nil</tt> instead of a widget)
    #
    # To resolve, check the method's documented contract. Ensure
    # state preconditions are met and return types are correct.
    #
    # === Example
    #
    #--
    # SPDX-SnippetBegin
    # SPDX-FileCopyrightText: 2026 Kerrick Long
    # SPDX-License-Identifier: MIT-0
    #++
    #   Rooibos.run(model: Model.new, view: nil, update: Update)  # => raises Error::Invariant
    #--
    # SPDX-SnippetEnd
    #++
    class Invariant < Error; end
  end
end
