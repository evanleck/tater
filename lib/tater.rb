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

  def initialize(path: nil, messages: nil, locale: DEFAULT_LOCALE, cascade: false)
    @cascade = cascade
    @locale = locale
    @messages = {}

    load(path: path) if path
    load(messages: messages) if messages
  end

  # Do lookups cascade by default?
  #
  # @return [Boolean]
  def cascades?
    @cascade
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
  #   A path to search for YAML or Ruby files to load messages from.
  # @param messages [Hash]
  #   A hash of messages ready to be loaded in.
  def load(path: nil, messages: nil)
    if path
      Dir.glob(File.join(path, '**', '*.{yml,yaml}')).each do |file|
        Utils.deep_merge!(@messages, YAML.load_file(file))
      end

      Dir.glob(File.join(path, '**', '*.rb')).each do |file|
        Utils.deep_merge!(@messages, Utils.deep_stringify_keys!(eval(IO.read(file), binding, file)))
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

  # Localize an Array, Date, Time, DateTime, or Numeric object.
  #
  # @param object [Date, Time, DateTime, Numeric]
  #   The object to localize.
  # @param options [Hash]
  #   Options to configure localization.
  #
  # @option options [String] :format
  #   The key or format string to use for localizing the current object.
  # @option options [String] :locale
  #   The locale to use in lieu of the current default.
  # @option options [String] :delimiter
  #   The delimiter to use when localizing numberic values.
  # @option options [String] :separator
  #   The separator to use when localizing numberic values.
  # @option options [String] :two_words_connector
  #   The string used to join two array elements together e.g. " and ".
  # @option options [String] :words_connector
  #   The string used to connect multiple array elements e.g. ", ".
  # @option options [String] :last_word_connector
  #   The string used to connect the final element with preceding array elements
  #   e.g. ", and ".
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
      delimiter = options.delete(:delimiter) || lookup('numeric.delimiter', locale_override)
      separator = options.delete(:separator) || lookup('numeric.separator', locale_override)
      precision = options.delete(:precision) || 2

      raise(MissingLocalizationFormat, "Numeric localization delimiter ('numeric.delimiter') missing or not passed as option :delimiter") unless delimiter
      raise(MissingLocalizationFormat, "Numeric localization separator ('numeric.separator') missing or not passed as option :separator") unless separator

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
    when Array
      case object.length
      when 0
        ''
      when 1
        object[0]
      when 2
        two_words_connector = options.delete(:two_words_connector) || lookup('array.two_words_connector', locale_override)

        raise(MissingLocalizationFormat, "Sentence localization connector ('array.two_words_connector') missing or not passed as option :two_words_connector") unless two_words_connector

        "#{ object[0] }#{ two_words_connector }#{ object[1] }"
      else
        last_word_connector = options.delete(:last_word_connector) || lookup('array.last_word_connector', locale_override)
        words_connector = options.delete(:words_connector) || lookup('array.words_connector', locale_override)

        raise(MissingLocalizationFormat, "Sentence localization connector ('array.last_word_connector') missing or not passed as option :last_word_connector") unless last_word_connector
        raise(MissingLocalizationFormat, "Sentence localization connector ('array.words_connector') missing or not passed as option :words_connector") unless words_connector

        "#{ object[0...-1].join(words_connector) }#{ last_word_connector }#{ object[-1] }"
      end
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
  # @param cascade_override [Boolean]
  #   A boolean to forcibly set the cascade option for this lookup.
  #
  # @return
  #   Basically anything that can be stored in YAML, including nil.
  def lookup(key, locale_override = nil, cascade_override = nil)
    path = key.split(SEPARATOR).prepend(locale_override || locale).map(&:to_s)

    if cascade_override.nil? ? @cascade : cascade_override
      while path.length >= 2 do
        attempt = @messages.dig(*path)

        if attempt
          break attempt
        else
          path.delete_at(path.length - 2)
        end
      end
    else
      @messages.dig(*path)
    end
  end

  # Check that there's a key at the given path.
  #
  # @param key [String]
  #   The period-separated key path to look within our messages for.
  # @param options [Hash]
  #   Options to pass to the #lookup method, including locale overrides.
  #
  # @option options [Boolean] :cascade
  #   Should this lookup cascade or not? Can override @cascade.
  # @option options [String] :locale
  #   A specific locale to lookup within. This will take precedence over the
  #   :locales option.
  # @option options [Array<String>] :locales
  #   An array of locales to look within.
  #
  # @return [Boolean]
  def includes?(key, options = {})
    cascade_override = options.delete(:cascade)
    locale_override = options.delete(:locale)
    locales = options.delete(:locales)

    message =
      if locale_override || !locales
        lookup(key, locale_override, cascade_override)
      else
        locales.find do |accept|
          found = lookup(key, accept, cascade_override)

          break found if found
        end
      end

    !message.nil?
  end

  # Translate a key path and optional interpolation arguments into a string.
  # It's effectively a combination of #lookup and #interpolate.
  #
  # @example
  #   Tater.new(messages: { 'en' => { 'hi' => 'Hello' }}).translate('hi') # => 'Hello'
  #
  # @param key [String]
  #   The period-separated key path to look within our messages for.
  # @param options [Hash]
  #   Options, including values to interpolate to any found string.
  #
  # @option options [Boolean] :cascade
  #   Should this lookup cascade or not? Can override @cascade.
  # @option options [String] :default
  #   A default string to return, should lookup fail.
  # @option options [String] :locale
  #   A specific locale to lookup within. This will take precedence over the
  #   :locales option.
  # @option options [Array<String>] :locales
  #   An array of locales to look within.
  #
  # @return [String]
  #   The translated and interpreted string, if found, or any data at the
  #   defined key.
  def translate(key, options = {})
    cascade_override = options.delete(:cascade)
    locale_override = options.delete(:locale)
    locales = options.delete(:locales)

    message =
      if locale_override || !locales
        lookup(key, locale_override, cascade_override)
      else
        locales.find do |accept|
          found = lookup(key, accept, cascade_override)

          break found if found
        end
      end

    # Call procs that should return a string.
    if message.is_a?(Proc)
      message = message.call(key, options)
    end

    Utils.interpolate(message, options) || options.delete(:default) { "Tater lookup failed: #{ locale_override || locales || locale }.#{ key }" }
  end
  alias t translate
end
