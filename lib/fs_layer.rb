require_relative 'fs_layer/version'
require_relative 'fs_layer/errors'
require_relative 'fs_layer/backend'
require_relative 'fs_layer/backend/local_file_system'
require_relative 'fs_layer/backend/memory'
require_relative 'fs_layer/index'
require_relative 'fs_layer/file'
require_relative 'fs_layer/link'
require_relative 'fs_layer/api'

module FSLayer
  class << self
    attr_writer :backend

    def backend
      @backend ||= Backend::LocalFileSystem.new
    end

    def configure
      yield Configuration.new
    end
  end

  class Configuration
    def use_local_filesystem(root: nil)
      FSLayer.backend = Backend::LocalFileSystem.new(root: root)
    end

    def use_memory
      FSLayer.backend = Backend::Memory.new
    end

    def use_custom(backend)
      unless backend.is_a?(Backend::Base)
        raise ArgumentError, "Backend must be an instance of FSLayer::Backend::Base"
      end
      FSLayer.backend = backend
    end
  end
end
