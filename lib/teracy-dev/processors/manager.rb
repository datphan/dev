require_relative '../logging'
require_relative 'variables'

module TeracyDev
  module Processors
    class Manager
      @@instance = nil

      def initialize
        if !!@@instance
          raise "TeracyDev::Processors::Manager can only be initialized once"
        end
        @@instance = self

        @logger = Logging.logger_for(self.class.name)
        @processors = []

        # system processors
        register(Variables.new)
      end

      def register(processor)
        if !processor.respond_to?(:process)
          @logger.warn("processor #{processor} must implement process method, ignored")
          return
        end
        @processors << processor
        @logger.debug("processor: #{processor} registered")
      end

      # run the pipelines
      def process(settings)
        @logger.debug("start processing: #{settings}")

        @processors.each do |processor|
          result = processor.process(settings)
          if !result
            @logger.warn("invalid result from #{processor}, ignored")
            next
          end
          settings = result
        end

        settings
      end

    end
  end
end
