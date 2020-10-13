source 'https://rubygems.org'

# Padrino supports Ruby version 2.2.2 and later
ruby '2.5.7'

# Distribute your app as a gem
# gemspec

# Server requirements
# gem 'thin' # or mongrel
# gem 'trinidad', :platform => 'jruby'

# Optional JSON codec (faster performance)
# gem 'oj'

# Project requirements
gem 'rake'

# Component requirements
gem 'sass'
gem 'erubi', '~> 1.6'
gem 'activerecord', '5.1.5', :require => 'active_record'
gem 'pg'

gem 'will_paginate', '~>3.0'
gem 'settingslogic'
gem 'bcrypt'
gem 'rack-oauth2', '~> 1.9.1'

gem 'carrierwave', '1.2.2'
gem 'roo', '~> 2.7.1'
# Test requirements
group :test do
  gem 'rspec'
  gem 'rack-test', :require => 'rack/test'
  gem 'database_cleaner'
  gem 'simplecov', :require => false
end

# Padrino Stable Gem
gem 'padrino', '0.15.0'

# Or Padrino Edge
# gem 'padrino', :github => 'padrino/padrino-framework'

# Or Individual Gems
# %w(core support gen helpers cache mailer admin).each do |g|
#   gem 'padrino-' + g, '0.15.0'
# end
