# frozen_string_literal: true
require 'bigdecimal'
require 'date'
require 'time'
require 'yaml'

require 'tater/hash' unless Hash.method_defined?(:except)
require 'tater/utils'
require 'tater/version'

# Tater is a internationalization (i18n) and localization (l10n) library
# designed for speed and simplicity.
class Tater
  class MissingLocalizationFormat < ArgumentError; end
  class UnLocalizableObject < ArgumentError; end

  DEFAULT = 'default'
  DELIMITING_REGEX = /(\d)(?=(\d\d\d)+(?!\d))/.freeze
  HASH = {}.freeze
  SEPARATOR = '.'
  SUBSTITUTION_REGEX = /%(|\^)[aAbBpP]/.freeze

  # Needed for Ruby < 3.
  using HashExcept unless Hash.method_defined?(:except)

  # An array of the available locale codes found in loaded messages.
  #
  # @return [Array<String>]
  attr_reader :available

  # @return [String]
  attr_reader :locale

  # @return [Hash]
  attr_reader :messages

  # @param cascade [Boolean]
  #   A boolean indicating if lookups should cascade by default.
  # @param locale [String]
  #   The default locale.
  # @param messages [Hash]
  #   A hash of messages ready to be loaded in.
  # @param path [String]
  #   A path to search for YAML or Ruby files to load messages from.
  def initialize(cascade: false, locale: nil, messages: nil, path: nil)
    @available = []
    @cache = {}
    @cascade = cascade
    @locale = locale
    @messages = {}

    load(path: path) if path
    load(messages: messages) if messages
  end

  # @return [String]
  def inspect
    %(#<Tater:#{ object_id } @cascade=#{ @cascade } @locale="#{ @locale }" @available=#{ @available }>)
  end

  # Do lookups cascade by default?
  #
  # @return [Boolean]
  def cascades?
    @cascade
  end

  # Is this locale available in our current set of messages?
  #
  # @return [Boolean]
  def available?(locale)
    available.include?(locale.to_s)
  end

  # Load messages into our internal cache, either from a path containing YAML
  # files or a Hash of messages.
  #
  # @param path [String]
  #   A path to search for YAML or Ruby files to load messages from.
  # @param messages [Hash]
  #   A hash of messages ready to be loaded in.
  def load(path: nil, messages: nil)
    return if path.nil? && messages.nil?

    if path
      Dir.glob(File.join(path, '**', '*.{yml,yaml}')).each do |file|
        @messages = Utils.deep_merge(@messages, YAML.load_file(file))
      end

      Dir.glob(File.join(path, '**', '*.rb')).each do |file|
        @messages = Utils.deep_merge(@messages, Utils.deep_stringify_keys(eval(File.read(file), binding, file))) # rubocop:disable Security/Eval
      end
    end

    @messages = Utils.deep_merge(@messages, Utils.deep_stringify_keys(messages)) if messages
    @messages = Utils.deep_freeze(@messages)

    # Update our available locales.
    @available.replace(@messages.keys.map(&:to_s).sort)

    # Not only does this clear our cache but it establishes the basic structure
    # that we rely on in other methods.
    @cache.clear

    @messages.each_key do |key|
      @cache[key] = { false => {}, true => {} }
    end
  end

  # Set the current locale, if it's available.
  #
  # @param locale [String]
  #   The locale code to set as our default.
  def locale=(locale)
    str = locale.to_s
    @locale = str if available?(str)
  end

  # Localize an Array, Date, Time, DateTime, or Numeric object.
  #
  # @param object [Array<String>, Date, Time, DateTime, Numeric]
  #   The object to localize.
  # @param options [Hash]
  #   Options to configure localization.
  #
  # @option options [String] :format
  #   The key or format string to use for localizing the current object.
  # @option options [String] :locale
  #   The locale to use in lieu of the current default.
  # @option options [String] :delimiter
  #   The delimiter to use when localizing numeric values.
  # @option options [String] :separator
  #   The separator to use when localizing numeric values.
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
  def localize(object, options = HASH)
    case object
    when String
      object
    when Numeric
      localize_numeric(object, options)
    when Date, Time, DateTime
      localize_datetime(object, options)
    when Array
      localize_array(object, options)
    else
      raise(UnLocalizableObject, "The object class #{ object.class } cannot be localized by Tater.")
    end
  end

  # Lookup a key in the messages hash, using the current locale or an override.
  #
  # @example Using the default locale, look up a key's value.
  #   i18n = Tater.new(locale: 'en', messages: { 'en' => { 'greeting' => { 'world' => 'Hello, world!' } } })
  #   i18n.lookup('greeting.world') # => "Hello, world!"
  #
  # @param key [String]
  #   The period-separated key path to look for within our messages.
  # @param locale [String]
  #   A locale to use instead of our current one, if any.
  # @param cascade [Boolean]
  #   A boolean to forcibly set the cascade option for this lookup.
  #
  # @return
  #   Basically anything that can be stored in your messages Hash.
  def lookup(key, locale: nil, cascade: nil)
    locale =
      if locale.nil?
        @locale
      else
        locale.to_s
      end

    cascade = @cascade if cascade.nil?

    @cache[locale][cascade][key] ||= begin
      path = key.split(SEPARATOR)

      message = @messages[locale].dig(*path)

      if message.nil? && cascade
        message =
          while path.length > 1
            path.delete_at(path.length - 2)
            attempt = @messages[locale].dig(*path)

            break attempt unless attempt.nil?
          end
      end

      message
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
  def includes?(key, options = HASH)
    if options.empty?
      !lookup(key).nil?
    else
      message =
        if options.key?(:locales)
          options[:locales].append(@locale) if @locale && !options[:locales].include?(@locale)

          options[:locales].find do |accept|
            found = lookup(key, locale: accept, cascade: options[:cascade])

            break found unless found.nil?
          end
        else
          lookup(key, locale: options[:locale], cascade: options[:cascade])
        end

      !message.nil?
    end
  end

  # Translate a key path and optional interpolation arguments into a string.
  # It's effectively a combination of #lookup and #interpolate.
  #
  # @example
  #   Tater.new(locale: 'en', messages: { 'en' => { 'hi' => 'Hello' }}).translate('hi') # => 'Hello'
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
  #   A specific locale to lookup within.
  # @option options [Array<String>] :locales
  #   An array of locales to look within. This will take precedence over the
  #   :locale option and will append the default :locale option passed during
  #   initialization if present.
  #
  # @return [String]
  #   The translated and interpreted string, if found, or any data at the
  #   defined key.
  def translate(key, options = HASH)
    if options.empty?
      message = lookup(key)

      if message.is_a?(Proc) # rubocop:disable Style/CaseLikeIf
        message.call(key)
      elsif message.is_a?(String)
        message
      else
        "Tater lookup failed: #{ locale }.#{ key }"
      end
    else
      message =
        if options.key?(:locales)
          options[:locales].append(@locale) if @locale && !options[:locales].include?(@locale)

          options[:locales].find do |accept|
            found = lookup(key, locale: accept, cascade: options[:cascade])

            break found unless found.nil?
          end
        else
          lookup(key, locale: options[:locale], cascade: options[:cascade])
        end

      if message.is_a?(Proc) # rubocop:disable Style/CaseLikeIf
        message.call(key, options.except(:cascade, :default, :locale, :locales))
      elsif message.is_a?(String)
        Utils.interpolate(message, options.except(:cascade, :default, :locale, :locales))
      else
        options[:default] || "Tater lookup failed: #{ options[:locale] || options[:locales] || locale }.#{ key }"
      end
    end
  end

  private

  # Localize an Array object.
  #
  # @param object [Array<String>]
  #   The array to localize.
  # @param options [Hash]
  #   Options to configure localization.
  # @return [String]
  #   The localize array string.
  def localize_array(object, options)
    case object.length
    when 0
      ''
    when 1
      object[0]
    when 2
      two_words_connector = options[:two_words_connector] || lookup('array.two_words_connector', locale: options[:locale])

      raise(MissingLocalizationFormat, "Sentence localization connector ('array.two_words_connector') missing or not passed as option :two_words_connector") unless two_words_connector

      "#{ object[0] }#{ two_words_connector }#{ object[1] }"
    else
      last_word_connector = options[:last_word_connector] || lookup('array.last_word_connector', locale: options[:locale])
      words_connector = options[:words_connector] || lookup('array.words_connector', locale: options[:locale])

      raise(MissingLocalizationFormat, "Sentence localization connector ('array.last_word_connector') missing or not passed as option :last_word_connector") unless last_word_connector
      raise(MissingLocalizationFormat, "Sentence localization connector ('array.words_connector') missing or not passed as option :words_connector") unless words_connector

      "#{ object[0...-1].join(words_connector) }#{ last_word_connector }#{ object[-1] }"
    end
  end

  # Localize a Date, DateTime, or Time object.
  #
  # @param object [Date, DateTime, Time]
  #   The date-ish object to localize.
  # @param options [Hash]
  #   Options to configure localization.
  # @return [String]
  #   The localized date string.
  def localize_datetime(object, options)
    frmt = options[:format] || DEFAULT
    loc = options[:locale]
    format = lookup("#{ object.class.to_s.downcase }.formats.#{ frmt }", locale: loc) || frmt

    # Heavily cribbed from I18n, many thanks to the people who sorted this out
    # before I worked on this library.
    format = format.gsub(SUBSTITUTION_REGEX) do |match|
      case match
      when '%a'  then lookup('date.abbreviated_days', locale: loc)[object.wday]
      when '%^a' then lookup('date.abbreviated_days', locale: loc)[object.wday].upcase
      when '%A'  then lookup('date.days', locale: loc)[object.wday]
      when '%^A' then lookup('date.days', locale: loc)[object.wday].upcase
      when '%b'  then lookup('date.abbreviated_months', locale: loc)[object.mon - 1]
      when '%^b' then lookup('date.abbreviated_months', locale: loc)[object.mon - 1].upcase
      when '%B'  then lookup('date.months', locale: loc)[object.mon - 1]
      when '%^B' then lookup('date.months', locale: loc)[object.mon - 1].upcase
      when '%p'  then lookup("time.#{ object.hour < 12 ? 'am' : 'pm' }", locale: loc).upcase if object.respond_to?(:hour)
      when '%P'  then lookup("time.#{ object.hour < 12 ? 'am' : 'pm' }", locale: loc).downcase if object.respond_to?(:hour)
      end
    end

    if format.include?('%')
      object.strftime(format)
    else
      format
    end
  end

  # Localize a Numeric object.
  #
  # @param object [Array<String>, Date, Time, DateTime, Numeric]
  #   The object to localize.
  # @param options [Hash]
  #   Options to configure localization.
  # @return [String]
  #   The localized numeric string.
  def localize_numeric(object, options)
    delimiter = options[:delimiter] || lookup('numeric.delimiter', locale: options[:locale])
    separator = options[:separator] || lookup('numeric.separator', locale: options[:locale])
    precision = options[:precision] || 2

    raise(MissingLocalizationFormat, "Numeric localization delimiter ('numeric.delimiter') missing or not passed as option :delimiter") unless delimiter
    raise(MissingLocalizationFormat, "Numeric localization separator ('numeric.separator') missing or not passed as option :separator") unless separator

    # Break the number up into integer and fraction parts.
    integer = Utils.string_from_numeric(object)
    integer, fraction = integer.split('.') unless object.is_a?(Integer)

    if object >= 1_000
      integer.gsub!(DELIMITING_REGEX) do |number|
        "#{ number }#{ delimiter }"
      end
    end

    if precision.zero? || fraction.nil?
      integer
    else
      "#{ integer }#{ separator }#{ fraction.ljust(precision, '0').slice(0, precision) }"
    end
  end
end
