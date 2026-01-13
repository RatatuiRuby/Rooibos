# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: LGPL-3.0-or-later
#++

require "net/http"
require "uri"

module RatatuiRuby
  module Tea
    module Command
      # Alias to Message::HttpResponse for backwards compatibility.
      # New code should use RatatuiRuby::Tea::Message::HttpResponse.
      HttpResponse = Message::HttpResponse

      # An HTTP request command.
      Http = Data.define(:method, :url, :envelope, :headers, :body, :timeout, :parser) do
        include Custom

        def self.new(*args, method: nil, url: nil, envelope: nil, headers: nil, body: nil, timeout: nil, parser: nil,
          get: nil, post: nil, put: nil, patch: nil, delete: nil
        )
          # Auto-splat single hash argument
          return new(**args.first) if args.size == 1 && args.first.is_a?(Hash)

          # Auto-spread single array argument
          return new(*args.first) if args.size == 1 && args.first.is_a?(Array)

          # DWIM: parse positional args and keyword method shortcuts
          method_keywords = { get:, post:, put:, patch:, delete: }.compact
          method, url, envelope, body = parse_dwim_args(args, method, url, envelope, body, method_keywords)

          # Ractor validation
          if RatatuiRuby::Debug.enabled? && !Ractor.shareable?(url)
            raise RatatuiRuby::Error::Invariant,
              "URL is not Ractor-shareable: #{url.inspect}\n" \
                "Use a frozen string or Ractor.make_shareable."
          end

          if RatatuiRuby::Debug.enabled? && headers && !Ractor.shareable?(headers)
            raise RatatuiRuby::Error::Invariant,
              "Headers are not Ractor-shareable: #{headers.inspect}\n" \
                "Use Ractor.make_shareable or freeze the hash and its contents."
          end

          if RatatuiRuby::Debug.enabled? && body && !Ractor.shareable?(body)
            raise RatatuiRuby::Error::Invariant,
              "Body is not Ractor-shareable: #{body.inspect}\n" \
                "Use a frozen string or Ractor.make_shareable."
          end

          if RatatuiRuby::Debug.enabled? && envelope && !Ractor.shareable?(envelope)
            raise RatatuiRuby::Error::Invariant,
              "Envelope is not Ractor-shareable: #{envelope.inspect}\n" \
                "Use a frozen string, symbol, or Ractor.make_shareable."
          end

          if RatatuiRuby::Debug.enabled? && timeout && !Ractor.shareable?(timeout)
            raise RatatuiRuby::Error::Invariant,
              "Timeout is not Ractor-shareable: #{timeout.inspect}\n" \
                "Use a number or Ractor.make_shareable."
          end

          # Parser validation
          if parser && !parser.respond_to?(:call)
            raise ArgumentError, "parser: must respond to :call"
          end

          if RatatuiRuby::Debug.enabled? && parser && !Ractor.shareable?(parser)
            raise RatatuiRuby::Error::Invariant,
              "Parser is not Ractor-shareable: #{parser.inspect}\n" \
                "Use a frozen Method object or Ractor.make_shareable."
          end

          # Method validation
          unless %i[get post put patch delete].include?(method)
            raise ArgumentError, "Unsupported HTTP method: #{method.inspect}"
          end

          instance = allocate
          instance.__send__(:initialize, method:, url:, envelope:, headers:, body:, timeout: timeout || 10, parser:)
          instance
        end

        # Net::HTTP is blocking; no cooperative cancellation possible.
        # Grace period = 0 means runtime can force-kill immediately.
        def tea_cancellation_grace_period = 0

        def self.parse_dwim_args(args, method_kw, url_kw, envelope_kw, body_kw, method_keywords)
          # Handle keyword method shortcuts: get: 'url'
          if method_keywords.any?
            method_key, url = method_keywords.first
            # Check for conflicts with method: keyword
            if method_kw && method_kw != method_key
              raise ArgumentError, "Conflicting method specified: #{method_key}: and method: #{method_kw}"
            end
            # Check for conflicts with url: keyword
            if url_kw && url_kw != url
              raise ArgumentError, "Conflicting url specified: #{method_key}: provides url but url: also given"
            end
            return [method_key, url, url, body_kw]
          end

          # If keywords provided, use them directly
          return [method_kw, url_kw, envelope_kw, body_kw] if args.empty?

          case args
          in [String => url]
            # Http.new('url') → GET, URL as envelope
            [:get, url, url, body_kw]
          in [String => url, Symbol => envelope]
            # Http.new('url', :tag) → GET, custom envelope
            [:get, url, envelope, body_kw]
          in [Symbol => method, String => url]
            # Http.new(:delete, 'url') → method, URL as envelope
            [method, url, url, body_kw]
          in [Symbol => method, String => url, Symbol => envelope]
            # Http.new(:delete, 'url', :tag) → method, custom envelope
            [method, url, envelope, body_kw]
          in [Symbol => method, String => url, String => body]
            # Http.new(:post, 'url', 'body') → method, URL as envelope, body
            [method, url, url, body]
          in [Symbol => method, String => url, String => body, Symbol => envelope]
            # Http.new(:post, 'url', 'body', :tag) → method, custom envelope, body
            [method, url, envelope, body]
          else
            raise ArgumentError, "Invalid arguments for Http.new: #{args.inspect}"
          end
        end
        private_class_method :parse_dwim_args

        def call(out, token)
          return if token.canceled?

          uri = URI(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          if timeout
            http.open_timeout = timeout
            http.read_timeout = timeout
          end

          klass = case method
                  when :get    then Net::HTTP::Get
                  when :post   then Net::HTTP::Post
                  when :put    then Net::HTTP::Put
                  when :patch  then Net::HTTP::Patch
                  when :delete then Net::HTTP::Delete
          end
          request = klass.new(uri)
          request.body = body if body
          headers&.each { |key, value| request[key] = value }
          response = http.request(request)

          response_body = response.body.freeze
          response_headers = response.each_header.to_h.freeze
          response_status = response.code.to_i

          # Invoke parser with positional params if provided
          parsed_body = if parser
            parser.call(response_body, response_headers, response_status)
          else
            response_body
          end

          # Validate parsed body is Ractor-shareable in debug mode
          if RatatuiRuby::Debug.enabled? && parser && !Ractor.shareable?(parsed_body)
            raise RatatuiRuby::Error::Invariant,
              "Parsed body is not Ractor-shareable: #{parsed_body.class}\n" \
                "Parser must return frozen/shareable data. Use .freeze or Ractor.make_shareable."
          end

          out.put(Ractor.make_shareable(HttpResponse.new(
            envelope:,
            status: response_status,
            body: parsed_body,
            headers: response_headers,
            error: nil
          )))
        rescue => e
          out.put(Ractor.make_shareable(HttpResponse.new(
            envelope:,
            status: nil,
            body: nil,
            headers: nil,
            error: e.message.freeze
          )))
        end
      end
    end
  end
end
