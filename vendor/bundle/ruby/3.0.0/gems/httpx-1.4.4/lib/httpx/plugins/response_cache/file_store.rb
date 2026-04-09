# frozen_string_literal: true

require "pathname"
require_relative "store"

module HTTPX::Plugins
  module ResponseCache
    class FileStore < Store
      def initialize(dir = Dir.tmpdir)
        @dir = Pathname.new(dir)
      end

      def clear
        # delete all files
      end

      def cached?(request)
        file_path = @dir.join(request.response_cache_key)

        exist?(file_path)
      end

      private

      def _get(request)
        return unless cached?(request)

        File.open(@dir.join(request.response_cache_key))
      end

      def _set(request, response)
        file_path = @dir.join(request.response_cache_key)

        response.copy_to(file_path)

        response.body.rewind
      end
    end
  end
end
