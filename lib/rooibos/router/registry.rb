# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

module Rooibos
  module Router
    # :stopdoc:
    # Common behavior for Rule collections.
    # Classes including this must define :rules as a Data member.
    module Registry
      include Enumerable

      def add(rule) = rules << rule

      def each(&block)
        return rules.each unless block
        rules.each { |rule| block.call(rule) }
      end
    end
    private_constant :Registry
  end
end
