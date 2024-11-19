require_relative 'config'
require_relative 'logger_setup'
require 'nokogiri'
require 'httparty'
require 'json'
require 'yaml'
require 'digest'

class FoxtrotScraper # rubocop:disable Metrics/ClassLength,Style/Documentation
  def initialize
    @phones = []
    @logger = LoggerSetup.logger
    @config = Config.settings
  end

  def scrape
    @logger.info('Starting scraping process')
    page = fetch_page
    return unless page

    parse_phones(page)
    save_to_json
    @logger.info('Scraping completed successfully')
  end

  def save_to_yml # rubocop:disable Metrics/MethodLength
    output_dir = 'output/yml_items'
    FileUtils.mkdir_p(output_dir)
  
    @phones.each do |phone|
      # Видаляємо або замінюємо неприпустимі символи в назві файлу
      sanitized_model = phone[:model].gsub(/[^0-9A-Za-zА-Яа-я\s]/, '')
                                     .gsub(/\s+/, '_')
                                     .slice(0, 100) # обмеження довжини назви файлу
  
      file_name = "#{output_dir}/#{sanitized_model}.yml"
      
      # Створюємо директорію, якщо її немає
      FileUtils.mkdir_p(File.dirname(file_name))
  
      File.open(file_name, 'w:UTF-8') do |file|
        file.write(phone.to_yaml)
      end
  
      @logger.info("Saved #{phone[:model]} to #{file_name}")
    end
  end

  def create_item_collection # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    collection = {
      total_items: @phones.size,
      items: @phones.map do |phone|
        {
          model: phone[:model],
          name: phone[:name],
          link: phone[:link],
          base_price: phone[:base_price],
          memory_options: phone[:memory_options].map do |option|
            {
              capacity: option[:capacity],
              price: option[:price]
            }
          end
        }
      end
    }
  
    FileUtils.mkdir_p('output')
    
    # Збереження в JSON
    File.open('output/cart.json', 'w:UTF-8') do |file|
      file.write(JSON.pretty_generate(collection))
    end
  
    # Збереження в YAML
    File.open('output/cart.yml', 'w:UTF-8') do |file|
      file.write(collection.to_yaml)
    end
  
    @logger.info("Item collection created with #{collection[:total_items]} items")
    collection
  end


  private

  def fetch_page  # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    url = "#{@config['base_url']}#{@config['phones_path']}"
    @logger.debug("Fetching page: #{url}")

    attempts = 0
    begin
      attempts += 1
      response = HTTParty.get(url, headers: { 'User-Agent' => @config['user_agent'] })
      if response.success?
        @logger.debug('Page fetched successfully')
        Nokogiri::HTML(response.body)
      else
        @logger.error("Failed to fetch page. Status: #{response.code}")
        nil
      end
    rescue StandardError => e
      @logger.error("Error fetching page: #{e.message}")
      if attempts < @config['retry_attempts']
        @logger.info("Retrying... Attempt #{attempts} of #{@config['retry_attempts']}")
        sleep @config['retry_delay']
        retry
      end
      nil
    end
  end

  def parse_phones(page) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    products = page.css('.card__body')
    @logger.info("Found #{products.size} products")
  
    products.each_with_index do |product, index| # rubocop:disable Metrics/BlockLength
      begin
        base_name = product.css('.card__title').text.strip
        model_name = base_name.split(/\s*\d+\s*GB/).first.strip
  
        # Знаходимо посилання на сторінку товару
        link_element = product.at_css('a.card__title') # або інший варіант селектора
        if link_element
          product_path = link_element['href']
          product_link = URI.join(@config['base_url'], product_path).to_s
        else
          @logger.warn('No link found for product')
          product_link = nil
        end
  
        # Витягуємо пам'ять та ціну
        current_memory = base_name.match(/(\d+)\s*GB/)&.captures&.first
        current_price = product.css('.card-price').text.strip.gsub(/[^\d]/, '').to_i
  
        memory_variants = []
        memory_variants << {
          capacity: "#{current_memory}GB",
          price: current_price
        }
  
        phone = {
          model: model_name,
          name: base_name,
          link: product_link,
          base_price: current_price,
          memory_options: memory_variants
        }
  
        @phones << phone
        @logger.debug("Parsed phone #{index + 1}: #{model_name} (#{current_memory}GB, #{current_price} UAH, #{product_link})")
      rescue StandardError => e
        @logger.error("Error parsing product #{index + 1}: #{e.message}")
      end
    end
  
    @phones = group_phones_by_model
    @logger.info("Total unique models parsed: #{@phones.size}")
  end  

  def group_phones_by_model # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    phones_by_model = {}

    @phones.each do |phone|
      model_key = phone[:model]

      if phones_by_model[model_key]
        phones_by_model[model_key][:memory_options].concat(phone[:memory_options])
        phones_by_model[model_key][:memory_options].uniq! { |opt| opt[:capacity] }
      else
        phones_by_model[model_key] = phone
      end
    end

    phones_by_model.values.each do |phone|
      phone[:memory_options].sort_by! { |opt| opt[:capacity].to_i }
    end

    phones_by_model.values
  end

  def save_to_json # rubocop:disable Metrics/MethodLength
    file_path = @config['output_file'] || 'iphones.json'
    if @phones.empty?
      @logger.warn('No data to save.')
      return
    end

    @logger.debug("Saving data to #{file_path}")
    begin
      File.open(file_path, 'w') do |file|
        file.write(JSON.pretty_generate(@phones))
      end
      @logger.info("Data successfully saved to #{file_path}")
    rescue StandardError => e
      @logger.error("Error saving data to JSON: #{e.message}")
    end
  end
end
