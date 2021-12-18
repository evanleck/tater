# frozen_string_literal: true
class Tater
  # Refine Hash and add the #except method from Ruby 3.
  module HashExcept
    refine Hash do
      # Taken from the excellent backports gem written by Marc-André Lafortune.
      #   https://github.com/marcandre/backports/blob/master/lib/backports/3.0.0/hash/except.rb
      def except(*keys)
        if keys.size > 4 && size > 4 # index if O(m*n) is big
          h = {}
          keys.each { |key| h[key] = true }
          keys = h
        end

        reject { |key, _value| keys.include?(key) }
      end
    end
  end
end
