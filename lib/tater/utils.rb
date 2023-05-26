# frozen_string_literal: true
class Tater
  # Utility methods that require no state.
  module Utils
    HASH = {}.freeze
    FORMAT_CURLY = '%{'
    FORMAT_NAMED = '%<'

    # Merge all the way down.
    #
    # @param to [Hash]
    #   The target Hash to merge into.
    # @param from [Hash]
    #   The Hash to copy values from.
    # @return [Hash]
    def self.deep_merge(to, from)
      to.merge(from) do |_key, left, right|
        if left.is_a?(Hash) && right.is_a?(Hash)
          Utils.deep_merge(left, right)
        else
          right
        end
      end
    end

    # Transform keys all the way down.
    #
    # @param hash [Hash]
    #   The Hash to stringify keys for.
    # @return [Hash]
    def self.deep_stringify_keys(hash)
      hash.transform_keys(&:to_s).transform_values do |value|
        if value.is_a?(Hash)
          Utils.deep_stringify_keys(value)
        else
          value
        end
      end
    end

    # Freeze all the way down.
    #
    # @param hash [Hash]
    # @return [Hash]
    def self.deep_freeze(hash)
      hash.transform_keys(&:freeze).transform_values do |value|
        if value.is_a?(Hash)
          Utils.deep_freeze(value)
        else
          value.freeze
        end
      end.freeze
    end

    # Format values into a string, conditionally checking the string and options
    # before interpolating.
    #
    # @param string [String]
    #   The target string to interpolate into.
    # @param options [Hash]
    #   The values to interpolate into the target string.
    #
    # @return [String]
    def self.interpolate(string, options = HASH)
      return string if options.empty?
      return string unless interpolation_string?(string)

      interpolate!(string, options)
    end

    # Format values into a string unconditionally.
    #
    # @param string [String]
    #   The target string to interpolate into.
    # @param options [Hash]
    #   The values to interpolate into the target string.
    #
    # @return [String]
    def self.interpolate!(string, options)
      format(string, options)
    end

    # Determine whether a string includes any interpolation placeholders e.g.
    # "%{" or "%<"
    #
    # @param string [String]
    # @return [Boolean]
    def self.interpolation_string?(string)
      string.include?(FORMAT_CURLY) || string.include?(FORMAT_NAMED)
    end

    # Convert a Numeric to a string, particularly formatting BigDecimals to a
    # Float-like string representation.
    #
    # @param numeric [Numeric]
    #
    # @return [String]
    def self.string_from_numeric(numeric)
      if numeric.is_a?(BigDecimal)
        numeric.to_s('F')
      else
        numeric.to_s
      end
    end
  end
end
