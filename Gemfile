# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.2.2'

gem 'puma', '~> 6.4'
gem 'sinatra', '~> 3.2'
gem 'sinatra-contrib', '~> 3.2'

group :production, :development do
  gem 'pi_piper', '~> 2.0'
end

group :test do
  gem 'factory_bot', '~> 6.4'
  gem 'rack-test', '~> 2.1'
  gem 'rspec', '~> 3.13'
  gem 'simplecov', '~> 0.22'
  gem 'simplecov-console', '~> 0.9'
  gem 'timecop', '~> 0.9'
end

group :development, :test do
  gem 'pry', '~> 0.14'
  gem 'pry-byebug', '~> 3.10'
  gem 'rubocop', '~> 1.60'
  gem 'rubocop-performance', '~> 1.20'
  gem 'rubocop-rspec', '~> 2.27'
end

group :development do
  gem 'rerun', '~> 0.14'
end
