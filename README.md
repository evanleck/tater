# Tater the Translator

Tater is an internationalization (i18n) and localization (l10n) library designed
for simplicity. It doesn't do everything that other libraries do, but that's by
design.

Under the hood, Tater uses a Hash to store the messages, the `dig` method for
lookups, `strftime` for date and time localizations, and `format` for
interpolation. That's probably 90% of what Tater does.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tater'
```

And then execute:

```sh
bundle
```

Or install it yourself as:

```sh
gem install tater
```


## Usage

```ruby
messages = {
  'some' => {
    'key' => 'This here string!'
  },
  'interpolated' => 'Hello %{you}!'
}

i18n = Tater.new
i18n.load(messages: messages)

# Basic lookup:
i18n.translate('some.key') # => 'This here string!'

# Interpolation:
i18n.translate('interpolated', you: 'world') # => 'Hello world!'
```

## Numeric Localization

Numeric localization (`Numeric`, `Integer`, `Float`, and `BigDecimal`) require
filling in a separater and delimiter. For example:

```yaml
en:
  numeric:
    delimiter: ','
    separator: '.'
```

With that, you can do things like this:

```ruby
i18n.localize(1000.2) # => "1,000.20"
```


## Date and Time Localization

Date and time localization (`Date`, `Time`, and `DateTime`) require filling in
all of the needed names and abbreviations for days and months. Here's the
example for French, which is used in the tests.

```yaml
fr:
  time:
    am: 'am'
    pm: 'pm'

    formats:
      default: '%I%P'
      loud: '%I%p'

  date:
    formats:
      abbreviated_day: '%a'
      day: '%A'

      abbreviated_month: '%b'
      month: '%B'

    days:
      - dimanche
      - lundi
      - mardi
      - mercredi
      - jeudi
      - vendredi
      - samedi

    abbreviated_days:
      - dim
      - lun
      - mar
      - mer
      - jeu
      - ven
      - sam

    months:
      - janvier
      - février
      - mars
      - avril
      - mai
      - juin
      - juillet
      - août
      - septembre
      - octobre
      - novembre
      - décembre

    abbreviated_months:
      - jan.
      - fév.
      - mar.
      - avr.
      - mai
      - juin
      - juil.
      - août
      - sept.
      - oct.
      - nov.
      - déc.
```

The statically defined keys for dates are `days`, `abbreviated_days`, `months`,
and `abbreviated_months`. Only `am` and `pm` are needed for times and only if
you plan on using the `%p` or `%P` format strings.

With all of that, you can do something like:

```ruby
i18n.localize(Date.new(1970, 1, 1), format: '%A') # => 'jeudi'

# Or, using a key defined in "formats":
i18n.localize(Date.new(1970, 1, 1), format: 'day') # => 'jeudi'
```


## Limitations

- It is not "pluggable", it does what it does and that's it.
- It doesn't handle pluralization yet, though it may in the future.
- It doesn't cache anything, that's up to you.


## Why?

Because [Ruby I18n][rubyi18n] is amazing and I wanted to try to create a minimum
viable implementation of the bits of I18n that I use 90% of the time. Tater is a
single file that handles the basics of lookup and interpolation.


## Trivia

I was orininally going to call this library "Translator" but with a
[numeronym][numeronym] like I18n: "t8r". I looked at it for a while but I read
it as "tater" instead of "tee-eight-arr" so I figured I'd just name it Tater.
Tater the translator.

[numeronym]: https://en.wikipedia.org/wiki/Numeronym
[rubyi18n]: https://github.com/ruby-i18n/i18n
