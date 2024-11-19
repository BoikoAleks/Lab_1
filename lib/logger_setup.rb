require 'logger'

class LoggerSetup # rubocop:disable Style/Documentation
  class << self
    def logger
      @logger ||= setup_logger
    end

    private

    def setup_logger
      logger = Logger.new(File.join(File.dirname(__FILE__), '..', Config.settings['log_file']), 'daily')
      logger.level = get_log_level
      logger.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime}] #{severity}: #{msg}\n"
      end
      logger
    end

    def get_log_level # rubocop:disable Naming/AccessorMethodName
      case Config.settings['log_level'].downcase
      when 'debug' then Logger::DEBUG
      when 'info'  then Logger::INFO
      when 'warn'  then Logger::WARN
      when 'error' then Logger::ERROR
      else Logger::INFO # rubocop:disable Lint/DuplicateBranch
      end
    end
  end
end
