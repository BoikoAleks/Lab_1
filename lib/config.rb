# lib/config.rb - альтернативний варіант
require 'yaml'

class Config # rubocop:disable Style/Documentation
  class << self
    def load(environment = 'development')
      @settings = load_yaml[environment]
    end

    def settings
      @settings || load
    end

    private

    def load_yaml
      yaml_content = File.read(File.join(File.dirname(__FILE__), '..', 'config', 'config.yml'))
      YAML.safe_load(yaml_content, permitted_classes: [], aliases: true)
    rescue Errno::ENOENT => e
      raise "Configuration file not found: #{e.message}"
    end
  end
end
