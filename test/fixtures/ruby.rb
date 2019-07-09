{
  en: {
    ruby: proc do |key, options = {}|
      "Hey #{ key }!"
    end,
    options: proc do |_key, options = {}|
      "Hey %{options}!"
    end
  }
}
