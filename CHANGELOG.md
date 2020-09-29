# Tater Changelog

## 2.0.0

- **Breaking:** the default `en` locale has been removed. Without supplying a
  default locale during initialization you'll have to provide a `:locale` or
  list of `:locales` to  the `translate` method directly.
- **Breaking:** `#lookup` now takes keyword arguments for `:locale` and
  `:cascade` instead of positional arguments.
- Messages are no longer modified in place.
- Messages now frozen after being loaded.
- Lookups are now cached in a Hash. This yields a huge performance improvement
  in repeat lookups but will invariably increase memory usage proportionally
  with how many messages stored. See the benchmark below for the new version,
  marked `lookup` compared to the original implementation, marked `original`.

```
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
