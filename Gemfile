source "https://rubygems.org"

ruby file: ".ruby-version"

gem "ostruct" # Needed by pry 0.14 (pinned by pry-nav), no longer a default gem in Ruby 4
gem "pry"
gem "pry-nav"
gem "pry-remote"
gem "readline" # Needed by pry-remote, no longer bundled with Ruby 4
gem "rainbow"

# Scraper
gem "faraday"
gem "nokogiri"

group :development, :test do
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rails"
end
