# Tater 

[![Gem Version](https://badge.fury.io/rb/tater.svg)](https://badge.fury.io/rb/tater)
[![Build Status](https://secure.travis-ci.org/evanleck/tater.svg)](https://travis-ci.org/evanleck/tater)

Tater is an internationalization (i18n) and localization (l10n) library designed
for simplicity. It doesn't do everything that other libraries do, but that's by
design.

Under the hood, Tater uses a Hash to store the messages, the `dig` method for
lookups, `strftime` for date and time localizations, and `format` for
interpolation. That's probably 90% of what Tater does.


## Installation

Tater requires Ruby 2.5 or higher. To install Tater, add this line to your
application's Gemfile (or gems.rb):

```ruby
gem 'tater'
```

And then execute:

```sh
bundle
```

Or install it yourself by running:

```sh
gem install tater
```


## Usage

```ruby
require 'tater'

messages = {
  'en' => {
    'some' => {
      'key' => 'This here string!'
    },
    'interpolated' => 'Hello %{you}!'
  }
}

i18n = Tater.new(locale: 'en')
i18n.load(messages: messages)

# OR
i18n = Tater.new(locale: 'en', messages: messages)

# Basic lookup:
i18n.translate('some.key') # => 'This here string!'

# Interpolation:
i18n.translate('interpolated', you: 'world') # => 'Hello world!'
```


## Array localization

Given an array, Tater will do it's best to join the elements of the array into a
sentence based on how many elements there are.

```yaml
en:
  array:
    last_word_connector: ", and "
    two_words_connector: " and "
    words_connector: ", "
```

```ruby
i18n.localize(%w[tacos enchiladas burritos]) # => "tacos, enchiladas, and burritos"
```


## Numeric localization

Numeric localization (`Numeric`, `Integer`, `Float`, and `BigDecimal`) require
filling in a separator and delimiter. For example:

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

The separator and delimiter can also be passed in per-call:

```ruby
i18n.localize(1000.2, delimiter: '_', separator: '+') # => "1_000+20"
```


## Date and time localization

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


## Cascading lookups

Lookups can be cascaded, i.e. pieces of the scope of the can be lopped off
incrementally.

```ruby
messages = {
  'en' => {
    'login' => {
      'title' => 'Login',
      'description' => 'Normal description.'

      'special' => {
        'title' => 'Special Login'
      }
    }
  }
}

i18n = Tater.new(locale: 'en', messages: messages)
i18n.translate('login.special.title') # => 'Special Login'
i18n.translate('login.special.description') # => 'Tater lookup failed'

i18n.translate('login.special.description', cascade: true) # => 'Normal description.'
```

With cascade, the final key stays the same, but pieces of the scope get lopped
off. In this case, lookups will be tried in this order:

1. `'login.special.description'`
2. `'login.description'`

This can be useful when you want to override some messages but don't want to
have to copy all of the other, non-overwritten messages.

Cascading can also be enabled by default when initializing an instance of Tater.

```ruby
Tater.new(cascade: true)
```

Cascading is off by default.


## Defaults

If you'd like to default to another value in case of a missed lookup, you can
provide the `:default` option to `#translate`.

```ruby
Tater.new.translate('nope', default: 'Yep!') # => 'Yep!'
```


## Procs and messages in Ruby

Ruby files can be used to store messages in addition to YAML, so long as the
Ruby file returns a `Hash` when evalled.

```ruby
{
  'en' => {
    ruby: proc do |key, options = {}|
      "Hey #{ key }!"
    end
  }
}
```


## Multiple locales

If you would like to check multiple locales and pull the first matching one out,
you can pass the `:locales` option to initialization or the `translate` method
with an array of top-level locale keys.

```ruby
messages = {
  'en' => {
    'title' => 'Login',
    'description' => 'English description.'
  },
  'fr' => {
    'title' => 'la connexion'
  }
}

i18n = Tater.new(messages: messages)
i18n.translate('title', locales: %w[fr en]) # => 'la connexion'
i18n.translate('description', locales: %w[fr en]) # => 'English description.'

# OR
i18n = Tater.new(messages: messages, locales: %w[fr en])
i18n.translate('title') # => 'la connexion'
i18n.translate('description') # => 'English description.'
```

Locales will be tried in order and whichever one matches first will be returned.


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
