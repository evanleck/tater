# frozen_string_literal: true
require 'bigdecimal'
require 'yaml'

# Tater is a internationalization (i18n) and localization (l10n) library
# designed for speed and simplicity.
class Tater
  class MissingLocalizationFormat < ArgumentError; end
  class UnLocalizableObject < ArgumentError; end

  module Utils # :nodoc:
    # Merge all the way down.
    #
    # @param to [Hash]
    #   The target Hash to merge into. Note that modification is done in-place,
    #   not on a copy of the object.
    # @param from [Hash]
    #   The Hash to copy values from.
    def self.deep_merge!(to, from)
      to.merge!(from) do |_key, left, right|
        if left.is_a?(Hash) && right.is_a?(Hash)
          Utils.deep_merge!(left, right)
        else
          right
        end
      end
    end

    # Transform keys all the way down.
    #
    # @param hash [Hash]
    #   The Hash to modify. Note that modification is done in-place, not on a copy
    #   of the object.
    def self.deep_stringify_keys!(hash)
      hash.transform_keys!(&:to_s).transform_values! do |value|
        if value.is_a?(Hash)
          Utils.deep_stringify_keys!(value)
        else
          value
        end
      end
    end

    # Try to interpolate these things, if one of them is a string.
    #
    # @param string [String]
    #   The target string to interpolate into.
    # @param options [Hash]
    #   The values to interpolate into the target string.
    #
    # @return [String]
    def self.interpolate(string, options = {})
      return string unless string.is_a?(String)

      format(string, options)
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

  DEFAULT = 'default'
  DEFAULT_LOCALE = 'en'
  DELIMITING_REGEX = /(\d)(?=(\d\d\d)+(?!\d))/.freeze
  SEPARATOR = '.'
  SUBSTITUTION_REGEX = /%(|\^)[aAbBpP]/.freeze

  # @return [String]
  attr_reader :locale

  # @return [Hash]
  attr_reader :messages

  def initialize(path: nil, messages: nil, locale: DEFAULT_LOCALE)
    @locale = locale
    @messages = {}

    load(path: path) if path
    load(messages: messages) if messages
  end

  # An array of the available locale codes.
  #
  # @return [Array]
  def available
    messages.keys.map(&:to_s)
  end

  # Is this locale available in our current set of messages?
  #
  # @return [Boolean]
  def available?(locale)
    available.include?(locale.to_s)
  end

  # Load messages into our internal cache, either from a path containing YAML
  # files or a collection of messages.
  #
  # @param path [String]
  #   A path to search for YAML files to load messages from.
  # @param messages [Hash]
  #   A hash of messages ready to be loaded in.
  def load(path: nil, messages: nil)
    if path
      Dir.glob(File.join(path, '**', '*.{yml,yaml}')).each do |file|
        Utils.deep_merge!(@messages, YAML.safe_load(File.read(file)))
      end
    end

    Utils.deep_merge!(@messages, Utils.deep_stringify_keys!(messages)) if messages
  end

  # Set the current locale, if it's available.
  #
  # @param locale [String]
  #   The locale code to set as our default.
  def locale=(locale)
    @locale = locale.to_s if available?(locale)
  end

  # Localize a Date, Time, DateTime, or Numeric object.
  #
  # @param object [Date, Time, DateTime, Numeric]
  #   The object to localize.
  #
  # @return [String]
  #   A localized version of the object passed in.
  def localize(object, options = {})
    format_key = options.delete(:format) || DEFAULT
    locale_override = options.delete(:locale)

    case object
    when String
      object
    when Numeric
      delimiter = lookup('numeric.delimiter', locale_override)
      separator = lookup('numeric.separator', locale_override)
      precision = options.fetch(:precision) { 2 }

      raise(MissingLocalizationFormat, "Numeric localization delimiter ('numeric.delimiter') missing") unless delimiter
      raise(MissingLocalizationFormat, "Numeric localization separator ('numeric.separator') missing") unless separator

      # Heavily cribbed from Rails.
      integer, fraction = Utils.string_from_numeric(object).split('.')
      integer.gsub!(DELIMITING_REGEX) do |number|
        "#{ number }#{ delimiter }"
      end

      if precision.zero?
        integer
      else
        [integer, fraction&.ljust(precision, '0')].compact.join(separator)
      end
    when Date, Time, DateTime
      key = object.class.to_s.downcase
      format = lookup("#{ key }.formats.#{ format_key }", locale_override) || format_key

      # Heavily cribbed from I18n, many thanks to the people who sorted this out
      # before I worked on this library.
      format = format.gsub(SUBSTITUTION_REGEX) do |match|
        case match
        when '%a'  then lookup('date.abbreviated_days', locale_override)[object.wday]
        when '%^a' then lookup('date.abbreviated_days', locale_override)[object.wday].upcase
        when '%A'  then lookup('date.days', locale_override)[object.wday]
        when '%^A' then lookup('date.days', locale_override)[object.wday].upcase
        when '%b'  then lookup('date.abbreviated_months', locale_override)[object.mon - 1]
        when '%^b' then lookup('date.abbreviated_months', locale_override)[object.mon - 1].upcase
        when '%B'  then lookup('date.months', locale_override)[object.mon - 1]
        when '%^B' then lookup('date.months', locale_override)[object.mon - 1].upcase
        when '%p'  then lookup("time.#{ object.hour < 12 ? 'am' : 'pm' }", locale_override).upcase if object.respond_to?(:hour) # rubocop:disable Metrics/BlockNesting
        when '%P'  then lookup("time.#{ object.hour < 12 ? 'am' : 'pm' }", locale_override).downcase if object.respond_to?(:hour) # rubocop:disable Metrics/BlockNesting
        end
      end

      object.strftime(format)
    else
      raise(UnLocalizableObject, "The object class #{ object.class } cannot be localized by Tater.")
    end
  end
  alias l localize

  # Lookup a key in the messages hash, using the current locale or an override.
  #
  # @param key [String]
  # @param locale_override [String]
  #   A locale to use instead of our current one.
  #
  # @return
  #   Basically anything that can be stored in YAML, including nil.
  def lookup(key, locale_override = nil)
    path = key.split(SEPARATOR).prepend(locale_override || locale).map(&:to_s)

    @messages.dig(*path)
  end

  # Translate a key path and optional interpolation arguments into a string.
  # It's effectively a combination of #lookup and #interpolate.
  #
  # @example
  #   Tater.new(messages: { 'en' => { 'hi' => 'Hello' }}).translate('hi') # => 'Hello'
  #
  # @param key [String]
  #   The period-separated key path to look within our messages for.
  #
  # @return [String]
  #   The translated and interpreted string, if found, or any data at the
  #   defined key.
  def translate(key, options = {})
    locale_override = options.delete(:locale)

    Utils.interpolate(lookup(key, locale_override), options) || "Tater lookup failed: #{ locale_override || locale }.#{ key }"
  end
  alias t translate
end
