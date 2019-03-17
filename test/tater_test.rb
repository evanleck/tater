# frozen_string_literal: true
require_relative '../lib/tater'
require 'minitest/autorun'
require 'date'

describe Tater do
  describe Tater::Utils do
    describe '#deep_merge!' do
      it 'deeply merges two hashes, modifying the first' do
        first = { 'one' => 'one', 'two' => { 'three' => 'three' } }
        second = { 'two' => { 'four' => 'four' } }

        Tater::Utils.deep_merge!(first, second)

        assert_equal({ 'one' => 'one', 'two' => { 'three' => 'three', 'four' => 'four' } }, first)
      end
    end

    describe '#deep_stringify_keys!' do
      it 'converts all keys into strings, recursively modifying the hash passed in' do
        start = { en: { login: { title: 'Hello!' } } }

        Tater::Utils.deep_stringify_keys!(start)

        assert_equal({ 'en' => { 'login' => { 'title' => 'Hello!' } } }, start)
      end
    end

    describe '#interpolate' do
      it 'interpolates a string and hash' do
        assert_equal 'this thing', Tater::Utils.interpolate('this %{what}', what: 'thing')
      end

      it 'raises a KeyError when an argument is missing' do
        assert_raises(KeyError) do
          Tater::Utils.interpolate('this %{what}')
        end
      end
    end

    describe '#string_from_numeric' do
      it 'converts numerics to decimal-ish strings' do
        assert_equal '1', Tater::Utils.string_from_numeric(1)
        assert_equal '1.0', Tater::Utils.string_from_numeric(1.0)
        assert_equal '1.0', Tater::Utils.string_from_numeric(BigDecimal(1))
      end
    end
  end

  describe '#available?' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'tells you if the locale is available' do
      assert i18n.available?('en')
      refute i18n.available?('romulan')
    end
  end

  describe '#load' do
    it 'loads from a path on initialization' do
      i18n = Tater.new(path: File.expand_path('test'))

      assert_instance_of(Hash, i18n.messages)
    end

    it 'loads from a path after initialization' do
      i18n = Tater.new
      i18n.load(path: File.expand_path('test'))

      assert_instance_of(Hash, i18n.messages)
    end

    it 'loads from a hash of messages on initialization' do
      i18n = Tater.new(messages: { 'hey' => 'Oh hi' })

      assert_instance_of(Hash, i18n.messages)
    end

    it 'loads from a hash of messages after initialization' do
      i18n = Tater.new
      i18n.load(messages: { 'hey' => 'Oh hi' })

      assert_instance_of(Hash, i18n.messages)
    end
  end

  describe '#available' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'returns an array with the available locales (i.e. the top-level keys in our messages hash)' do
      assert_equal %w[en delimiter_only separator_only fr].sort, i18n.available.sort
    end
  end

  describe '#lookup' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'returns keys from messages' do
      assert_equal 'This is a title', i18n.lookup('title')
    end

    it 'does no interpolation' do
      assert_equal 'This has some %{fancy} text', i18n.lookup('interpolated')
    end

    it 'returns nil for missing lookups' do
      assert_nil i18n.lookup('nope')
    end
  end

  describe '#translate' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'translates strings' do
      assert_equal 'This is a title', i18n.translate('title')
    end

    it 'translates nested strings' do
      assert_equal 'This key is deeper', i18n.translate('deep.key')
    end

    it 'returns a hash for nested keys' do
      assert_equal({ 'key' => 'This key is deeper' }, i18n.translate('deep'))
    end

    it 'interpolates additional variables' do
      assert_equal 'This has some fancy text', i18n.translate('interpolated', fancy: 'fancy')
      assert_equal 'Double down!', i18n.translate('double', first: 'Double', second: 'down')
    end

    it 'works with multiple files' do
      assert_equal 'This is from a different file', i18n.translate('another')
      assert_equal "Oh there's more!", i18n.translate('more')
    end

    it 'returns a message for failed translations' do
      assert_equal 'Tater lookup failed: en.nope', i18n.translate('nope')
    end

    it 'is aliased as t' do
      assert_equal 'This is a title', i18n.t('title')
    end
  end

  describe '#localize' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'localizes Dates' do
      assert_equal '1970/1/1', i18n.localize(Date.new(1970, 1, 1))
    end

    it 'localizes Times' do
      assert_equal '1970/1/1/00/00/00', i18n.localize(Time.new(1970, 1, 1, 0, 0, 0))
    end

    it 'localizes DateTimes' do
      assert_equal '1970/1/1/00/00/00', i18n.localize(DateTime.new(1970, 1, 1, 0, 0, 0))
    end

    it 'localizes Floats' do
      assert_equal '10TURKEYS000NAH12', i18n.localize(10_000.12)
    end

    it 'localizes Integers' do
      assert_equal '10TURKEYS000', i18n.localize(10_000)
    end

    it 'localizes BigDecimals' do
      assert_equal '1NAH12', i18n.localize(BigDecimal('1.12'))
    end

    it 'accepts other formats' do
      assert_equal '1 something 1 oh my 1970', i18n.localize(Date.new(1970, 1, 1), format: 'ohmy')
    end

    it 'uses the passed in format if the specified class and format are not present' do
      assert_equal 'not there', i18n.localize(Date.new(1970, 1, 1), format: 'not there')
    end

    it 'raises a MissingLocalizationFormat if a delimiter is missing' do
      assert_raises(Tater::MissingLocalizationFormat) do
        i18n.localize(10, locale: 'separator_only')
      end
    end

    it 'raises a MissingLocalizationFormat if a separator is missing' do
      assert_raises(Tater::MissingLocalizationFormat) do
        i18n.localize(10, locale: 'delimiter_only')
      end
    end

    it 'is aliased l' do
      assert_equal '1970/1/1', i18n.l(Date.new(1970, 1, 1))
    end

    describe 'month, day, and AM/PM names' do
      let :i18n do
        Tater.new(path: File.expand_path('test'), locale: 'fr')
      end

      it 'localizes day names' do
        assert_equal 'jeudi', i18n.localize(Date.new(1970, 1, 1), format: 'day')
        assert_equal 'vendredi', i18n.localize(Date.new(1970, 1, 2), format: 'day')
        assert_equal 'samedi', i18n.localize(Date.new(1970, 1, 3), format: 'day')
        assert_equal 'dimanche', i18n.localize(Date.new(1970, 1, 4), format: 'day')
        assert_equal 'lundi', i18n.localize(Date.new(1970, 1, 5), format: 'day')
        assert_equal 'mardi', i18n.localize(Date.new(1970, 1, 6), format: 'day')
        assert_equal 'mercredi', i18n.localize(Date.new(1970, 1, 7), format: 'day')
      end

      it 'localizes abbreviated day names' do
        assert_equal 'jeu', i18n.localize(Date.new(1970, 1, 1), format: 'abbreviated_day')
        assert_equal 'ven', i18n.localize(Date.new(1970, 1, 2), format: 'abbreviated_day')
        assert_equal 'sam', i18n.localize(Date.new(1970, 1, 3), format: 'abbreviated_day')
        assert_equal 'dim', i18n.localize(Date.new(1970, 1, 4), format: 'abbreviated_day')
        assert_equal 'lun', i18n.localize(Date.new(1970, 1, 5), format: 'abbreviated_day')
        assert_equal 'mar', i18n.localize(Date.new(1970, 1, 6), format: 'abbreviated_day')
        assert_equal 'mer', i18n.localize(Date.new(1970, 1, 7), format: 'abbreviated_day')
      end

      it 'localizes months' do
        assert_equal 'janvier', i18n.localize(Date.new(1970, 1, 1), format: 'month')
        assert_equal 'février', i18n.localize(Date.new(1970, 2, 1), format: 'month')
        assert_equal 'mars', i18n.localize(Date.new(1970, 3, 1), format: 'month')
        assert_equal 'avril', i18n.localize(Date.new(1970, 4, 1), format: 'month')
        assert_equal 'mai', i18n.localize(Date.new(1970, 5, 1), format: 'month')
        assert_equal 'juin', i18n.localize(Date.new(1970, 6, 1), format: 'month')
        assert_equal 'juillet', i18n.localize(Date.new(1970, 7, 1), format: 'month')
        assert_equal 'août', i18n.localize(Date.new(1970, 8, 1), format: 'month')
        assert_equal 'septembre', i18n.localize(Date.new(1970, 9, 1), format: 'month')
        assert_equal 'octobre', i18n.localize(Date.new(1970, 10, 1), format: 'month')
        assert_equal 'novembre', i18n.localize(Date.new(1970, 11, 1), format: 'month')
        assert_equal 'décembre', i18n.localize(Date.new(1970, 12, 1), format: 'month')
      end

      it 'localizes abbreviated months' do
        assert_equal 'jan.', i18n.localize(Date.new(1970, 1, 1), format: 'abbreviated_month')
        assert_equal 'fév.', i18n.localize(Date.new(1970, 2, 1), format: 'abbreviated_month')
        assert_equal 'mar.', i18n.localize(Date.new(1970, 3, 1), format: 'abbreviated_month')
        assert_equal 'avr.', i18n.localize(Date.new(1970, 4, 1), format: 'abbreviated_month')
        assert_equal 'mai', i18n.localize(Date.new(1970, 5, 1), format: 'abbreviated_month')
        assert_equal 'juin', i18n.localize(Date.new(1970, 6, 1), format: 'abbreviated_month')
        assert_equal 'juil.', i18n.localize(Date.new(1970, 7, 1), format: 'abbreviated_month')
        assert_equal 'août', i18n.localize(Date.new(1970, 8, 1), format: 'abbreviated_month')
        assert_equal 'sept.', i18n.localize(Date.new(1970, 9, 1), format: 'abbreviated_month')
        assert_equal 'oct.', i18n.localize(Date.new(1970, 10, 1), format: 'abbreviated_month')
        assert_equal 'nov.', i18n.localize(Date.new(1970, 11, 1), format: 'abbreviated_month')
        assert_equal 'déc.', i18n.localize(Date.new(1970, 12, 1), format: 'abbreviated_month')
      end

      it 'localizes AM/PM' do
        assert_equal '05pm', i18n.localize(Time.new(1970, 1, 1, 17))
        assert_equal '05PM', i18n.localize(Time.new(1970, 1, 1, 17), format: 'loud')
        assert_equal '05am', i18n.localize(Time.new(1970, 1, 1, 5))
        assert_equal '05AM', i18n.localize(Time.new(1970, 1, 1, 5), format: 'loud')
      end
    end
  end

  describe '#locale=' do
    let :i18n do
      Tater.new(path: File.expand_path('test'))
    end

    it 'overrides the locale when available' do
      i18n.locale = 'delimiter_only'
      assert_equal 'delimiter_only', i18n.locale
    end

    it 'does not override the locale when not available' do
      i18n.locale = 'nopeskies'
      assert_equal 'en', i18n.locale
    end
  end
end
