# Tater Changelog

## 3.0.5

1. Modify some internals to allow freezing an instance of `Tater`. Note that
   instances cannot load additional messages or assign a new default locale
   once frozen.
2. Add `Tater#inspect`.
3. Sort the entries in `Tater#available`.

## 3.0.4

Add an optimization for empty options to `Tater#includes?`.

## 3.0.3

Really fix the `LoadError` by actually including the files in lib/tater in the
gem ***facepalm***.

## 3.0.2

Fix `LoadError` when requiring `tater/utils`.

## 3.0.1

Fix missing `Hash#except` in Ruby \< 3.

## 3.0.0

### Breaking changes

1. `Tater#translate` no longer returns arbitrary data stored at the requested
   key, it will only return strings now. To retrieve arbitrary data use
   `Tater#lookup`.
2. Remove the aliases `Tater#t` and `Tater#l`. To restore these aliases you can
   require `'tater/aliases'` e.g. in your `Gemfile`: `gem   'tater', require:
   'tater/aliases'`.
3. Internally used option keys `:cascade`, `:default`, `:locale`, and
   `:locales` are no longer passed to the block or interpolation string in
   `Tater#translate`.

### Non-breaking changes

Improve the performance of `Tater#translate`.

1. `Tater#translate` now has an optimization for an empty options hash.
2. `Tater::Utils#interpolate` now checks whether the string passed as the
   first argument contains any interpolation placeholders that could be used by
   `Kernel#format`, specifically `%{` and `%<`. If those are both absent then no
   interpolation is performed.
3. `Tater#translate` removes interally used option keys from the options hash
   before handing them over to `Tater::Utils#interpolate`, allowing that method
   to skip `Kernel#format` when those irrelevant options were the only ones
   passed to `#translate`.

Benchmark code:

``` ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'benchmark/ips'
require 'tater'

i18n = Tater.new(path: File.expand_path('test/fixtures'), locale: 'en')

Benchmark.ips do |x|
  x.report('no opts') { i18n.translate('english') }
  x.report('legit') { i18n.translate('english', legit: 'legit') }
  x.report('default') { i18n.translate('english', default: 'default') }

  x.compare!
end
```

Before:

``` example
no opts      2.649M (± 2.2%) i/s -     13.256M in   5.006062s
  legit      1.347M (± 2.0%) i/s -      6.818M in   5.062726s
default      1.338M (± 2.8%) i/s -      6.773M in   5.065340s
```

After:

``` example
no opts      3.735M (± 2.2%) i/s -     18.984M in   5.085179s
  legit      1.293M (± 2.2%) i/s -      6.581M in   5.092466s
default      1.667M (± 1.9%) i/s -      8.411M in   5.048828s
```

## 2.0.4

Slightly improve the performance of `Tater#lookup` and lookup caching.

Benchmark code:

``` ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'benchmark/ips'
require 'tater'

i18n = Tater.new(path: File.expand_path('test/fixtures'), locale: 'en')

Benchmark.ips do |x|
  x.report('hit') { i18n.lookup('cascade.tacos') }
  x.report('cascade+hit') { i18n.lookup('cascade.tacos', cascade: true) }
  x.report('cascade+miss') { i18n.lookup('cascade.nope.tacos', cascade: true) }

  x.compare!
end
```

Before:

``` example
         hit      5.500M (± 1.1%) i/s -     27.674M in   5.032145s
 cascade+hit      4.878M (± 0.5%) i/s -     24.488M in   5.019685s
cascade+miss      4.807M (± 0.8%) i/s -     24.338M in   5.063039s
```

After:

``` example
         hit      6.467M (± 0.9%) i/s -     32.732M in   5.061503s
 cascade+hit      5.912M (± 0.9%) i/s -     29.766M in   5.035720s
cascade+miss      5.883M (± 0.6%) i/s -     29.693M in   5.047433s
```

## 2.0.3

Refactor `Tater#localize` to use discrete private methods for each branch of
the `case` statement. Additionally add some minor optimizations when formatting
numeric and date-like objects.

## 2.0.2

Add optimizations for localizing small numbers that don't require delimiting and
numbers without fractional parts.

Before:

``` example
   100    537.853k (± 0.5%) i/s -      2.699M in   5.018053s
 100.0    390.349k (± 0.5%) i/s -      1.973M in   5.054799s
  1000    538.111k (± 1.3%) i/s -      2.696M in   5.010775s
1000.0    379.626k (± 2.4%) i/s -      1.901M in   5.009570s
```

After:

``` example
   100      1.219M (± 3.5%) i/s -      6.094M in   5.006669s
 100.0    507.402k (± 0.9%) i/s -      2.546M in   5.018059s
  1000      1.240M (± 0.8%) i/s -      6.244M in   5.037353s
1000.0    506.906k (± 0.6%) i/s -      2.578M in   5.086512s
```

Benchmark code follows.

``` ruby
i18n = Tater.new(locale: 'en')
i18n.load(messages: { 'en' => { 'numeric' => { 'delimiter' => ',', 'separator' => '.' }}})

BIG = BigDecimal('100.0')

Benchmark.ips do |x|
  x.report('100') { i18n.localize(100) }
  x.report('100.0') { i18n.localize(BIG) }
  x.report('1000') { i18n.localize(100) }
  x.report('1000.0') { i18n.localize(BIG) }

  x.compare!
end
```

## 2.0.1

Fix an issue where `precision` would not guarantee a maximum length if more than
`precision` characters were present in the fractional part of a number.

## 2.0.0

- **Breaking:** the default `en` locale has been removed. Without supplying a
  default locale during initialization you'll have to provide a `:locale` or
  list of `:locales` to the `translate` method directly.
- **Breaking:** `#lookup` now takes keyword arguments for `:locale` and
  `:cascade` instead of positional arguments.
- Messages are no longer modified in place.
- Messages now frozen after being loaded.
- Lookups are now cached in a Hash. This yields a huge performance improvement
  in repeat lookups but will invariably increase memory usage proportionally
  with how many messages stored. See the benchmark below for the new version,
  marked `lookup` compared to the original implementation, marked `original`.

``` example
Warming up --------------------------------------
            original   149.148k i/100ms
    original(missing)   154.393k i/100ms
              lookup   566.109k i/100ms
      lookup(missing)   421.125k i/100ms
Calculating -------------------------------------
            original      1.503M (± 1.4%) i/s -      7.607M in   5.063043s
   original(missing)      1.550M (± 0.9%) i/s -      7.874M in   5.080857s
              lookup      5.749M (± 1.9%) i/s -     28.872M in   5.024032s
     lookup(missing)      4.268M (± 0.3%) i/s -     21.477M in   5.032214s

Comparison:
              lookup:  5748968.8 i/s
     lookup(missing):  4268014.7 i/s - 1.35x  (± 0.00) slower
   original(missing):  1549883.6 i/s - 3.71x  (± 0.00) slower
            original:  1502656.0 i/s - 3.83x  (± 0.00) slower
```

## 1.3.0

- Add support for localizing arrays.

## 1.2.0

- Add a new `#includes?` method.

## 1.1.1

- Add a few more tests and improve documentation.

## 1.1.0

- Add the new `:cascade` option to `#translate` and initialization.
- Add a default option to `#translate`.
- Add the ability store messages in Ruby files that can contain procs.
- Add new `:delimiter` and `:separator` options to `#localize`.
- Add new `:locales` option to `#translate`.

## 1.0

- Initial release.
