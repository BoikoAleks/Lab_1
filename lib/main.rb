# lib/main.rb
require_relative 'scraper'
require_relative 'config'
require_relative 'logger_setup'
require 'httparty'
require 'nokogiri'
require 'json'

begin
  puts '=== Starting iPhone Scraper ==='
  
  # Встановлюємо environment
  environment = 'development'
  puts "Environment: #{environment}"
  
  # Завантажуємо конфігурацію
  puts 'Loading configuration...'
  Config.load(environment)
  puts 'Configuration loaded successfully'
  
  # Ініціалізуємо і запускаємо скрапер
  puts "\nInitializing scraper..."
  scraper = FoxtrotScraper.new
  
  puts 'Starting scraping process...'
  scraper.scrape
  
rescue StandardError => e
  puts "\nERROR: #{e.message}"
  puts e.backtrace
end

scraper = FoxtrotScraper.new
scraper.scrape
scraper.save_to_yml
scraper.create_item_collection
