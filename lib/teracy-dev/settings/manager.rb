require 'yaml'

require_relative '../logging'
require_relative '../util'
require_relative '../version'

module TeracyDev
  module Settings
    class Manager

      def initialize
        @logger = Logging.logger_for('Settings::Manager')
      end

      # build teracy-dev, organization and extensions setting levels
      # then override extensions => organization => teracy-dev
      # the latter extension will override the former one to build extensions settings
      def build_settings(organization_dir_path)
        organization_dir_path = Util.normalized_dir_path(organization_dir_path)
        @logger.debug("build_settings: #{organization_dir_path}")
        teracy_dev_settings = build_teracy_dev_settings()
        organization_settings = build_organization_settings(organization_dir_path)
        extensions_settings = build_extensions_settings(organization_settings)
        settings = Util.override(organization_settings, extensions_settings)
        @logger.debug("override(organization_settings, extensions_settings): #{settings}")
        settings = Util.override(teracy_dev_settings, settings)
        @logger.debug("override(teracy_dev_settings, settings): #{settings}")
        # create nodes by overrides each node with the default
        settings["nodes"].each_with_index do |node, index|
          settings["nodes"][index] = Util.override(settings['default'], node)
        end
        @logger.debug("final: #{settings}")
        settings
      end

      private

      def build_teracy_dev_settings()
        config_file_path = File.dirname(__FILE__) + '/../../../config.yaml'
        settings = load_yaml_file(config_file_path)
        @logger.debug("build_teracy_dev_settings: #{settings}")
        settings
      end


      def build_organization_settings(lookup_dir)
        config_default_file_path = File.dirname(__FILE__) + '/../../../' + lookup_dir + 'config_default.yaml'
        settings = build_settings_from(config_default_file_path)
        @logger.debug("build_organization_settings: #{settings}")
        settings
      end

      def build_extensions_settings(organization_settings)
        if !Util.exist? organization_settings['teracy-dev'] or !Util.exist? organization_settings['teracy-dev']['extensions']
          return {}
        end
        extensions = organization_settings["teracy-dev"]["extensions"]
        @logger.debug("build_extensions_settings: #{extensions}")
        extensions_settings = []
        extensions.each do |extension|
          validate_extension(extension)
          absolute_path = File.dirname(__FILE__) + '/../../../' + Util.normalized_dir_path(extension['path']) + 'config_default.yaml'
          extensions_settings << build_settings_from(absolute_path)
        end

        settings = {}
        extensions_settings.reverse_each do |extension_settings|
          settings = Util.override(extension_settings, settings)
        end
        @logger.debug("build_extensions_settings: #{settings}")
        settings
      end

      def validate_extension(extension)
        @logger.debug("validate_extension: #{extension}")
        absolute_path = File.dirname(__FILE__) + '/../../../' + Util.normalized_dir_path(extension['path'])

        # extension does exists, load the meta info and check the version requirements
        if File.exist? absolute_path
          validate_extension_meta(extension)
        else
          # extension path does not exist, check if it's required
          # if required, send error message and abort
          # otherwise, send a warning message
          required = extension['required'] || false
          if required == true
            @logger.error("This extension is required but its path does not exist: #{extension}")
            abort
          else
            @logger.warn("This extension's path does not exist, make sure it's intented: #{extension}")
          end
        end

      end

      def validate_extension_meta(extension)
        meta_path = File.dirname(__FILE__) + '/../../../' + Util.normalized_dir_path(extension['path']) + "meta.yaml"

        if File.exist? meta_path
          meta = load_yaml_file(meta_path)
          if !Util.exist?(meta['name']) or !Util.exist?(meta['version'])
            @logger.error("The extension meta's name and version must be defined: #{meta}, #{extension}")
            abort
          end
          # check the version requirement
          if !Util.require_version_valid?(meta['version'], extension['require_version'])
            @logger.error("`#{extension['require_version']}` is required, but current `#{meta['version']}`: #{extension}")
            @logger.error("The current extension version must be updated to satisfy the requirements above")
            abort
          end

          # check if teracy-dev version satisfies the meta['require_version'] if specified
          if Util.exist?(meta['require_version']) and !Util.require_version_valid?(TeracyDev::VERSION, meta['require_version'])
            @logger.error("teracy-dev's current version: #{TeracyDev::VERSION}")
            @logger.error("this extension requires teracy-dev version: #{meta['require_version']} (#{extension})")
            abort
          end
        else
          @logger.error("#{meta_path} must exist for this extension: #{extension}")
          abort
        end
      end

      def build_settings_from(default_file_path)
        @logger.debug("build_settings_from default file path: '#{default_file_path}'")
        override_file_path = default_file_path.gsub(/default\.yaml$/, "override.yaml")
        default_settings = load_yaml_file(default_file_path)
        @logger.debug("build_settings_from default_settings: #{default_settings}")
        override_settings = load_yaml_file(override_file_path)
        @logger.debug("build_settings_from override_settings: #{override_settings}")
        settings = Util.override(default_settings, override_settings)
        @logger.debug("build_settings_from final: #{settings}")
        settings
      end


      def load_yaml_file(file_path)
        if File.exist? file_path
          # TODO: exception handling
          result = YAML.load(File.new(file_path))
          if result == false
            @logger.debug("load_yaml_file: #{file_path} is empty")
            result = {}
          end
          result
        else
          @logger.debug("load_yaml_file: #{file_path} does not exist")
          {}
        end
      end
    end
  end
end
