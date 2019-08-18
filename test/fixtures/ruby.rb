# frozen_string_literal: true
{
  en: {
    ruby: proc do |key, _options = {}|
      "Hey #{ key }!"
    end,
    options: proc do |_key, _options = {}|
      'Hey %{options}!'
    end
  }
}
