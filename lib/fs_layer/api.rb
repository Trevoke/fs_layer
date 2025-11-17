module FSLayer
  class << self
    attr_writer :logger

    def logger
      @logger ||= defined?(Rails) ? Rails.logger : nil
    end

    def log(level, message)
      logger&.send(level, "[FSLayer] #{message}")
    end

    # Backward compatibility: fake_it now switches to memory backend
    def fake_it
      @previous_backend = backend
      self.backend = Backend::Memory.new
      log(:info, "Switched to memory backend (fake mode)")
    end

    # Backward compatibility: keep_it_real switches back to real backend
    def keep_it_real
      self.backend = @previous_backend || Backend::LocalFileSystem.new
      @previous_backend = nil
      log(:info, "Switched back to real backend")
    end

    # Backward compatibility: check if using memory backend
    def fake?
      backend.is_a?(Backend::Memory)
    end

    # === Core API Methods ===

    def insert(file, content = '')
      log(:debug, "Inserting file: #{file}")
      result = FSLayer::File.add(file, content)
      log(:info, "Successfully inserted file: #{file}")
      result
    end

    def retrieve(file)
      log(:debug, "Retrieving file: #{file}")
      FSLayer::File.retrieve(file)
    end

    def delete(file)
      file_obj = file.is_a?(FSLayer::File) ? file : FSLayer::File.retrieve(file)
      log(:debug, "Deleting file: #{file_obj.path}")

      begin
        backend.delete(file_obj.path)
        Index.remove(file_obj.path)
        log(:info, "Successfully deleted file: #{file_obj.path}")
      rescue => e
        log(:error, "Failed to delete file #{file_obj.path}: #{e.message}")
        raise
      end

      file_obj
    end

    def has?(file_object)
      Index.known_files.include?(file_object)
    end

    def link(file)
      log(:debug, "Creating symlink from: #{file}")
      FSLayer::Link.new(FSLayer::File.add(file))
    end

    # === New Convenience Methods ===

    def read(path)
      log(:debug, "Reading file: #{path}")
      backend.read(path)
    end

    def write(path, content, **options)
      log(:debug, "Writing file: #{path}")
      backend.write(path, content, **options)
      Index.organize(path)
      log(:info, "Successfully wrote file: #{path}")
    end

    def exists?(path)
      backend.exists?(path)
    end

    def list(path, **options)
      backend.list(path, **options)
    end

    def copy(source, dest, **options)
      log(:debug, "Copying #{source} to #{dest}")
      backend.copy(source, dest, **options)
      Index.organize(dest)
      log(:info, "Successfully copied #{source} to #{dest}")
    end

    def move(source, dest, **options)
      log(:debug, "Moving #{source} to #{dest}")
      backend.move(source, dest, **options)
      Index.remove(source)
      Index.organize(dest)
      log(:info, "Successfully moved #{source} to #{dest}")
    end

    def metadata(path)
      backend.metadata(path)
    end

    def mkdir(path, **options)
      log(:debug, "Creating directory: #{path}")
      backend.mkdir(path, **options)
      log(:info, "Successfully created directory: #{path}")
    end

    # Streaming operations
    def open_read(path, **options, &block)
      backend.open_read(path, **options, &block)
    end

    def open_write(path, **options, &block)
      backend.open_write(path, **options, &block)
    end
  end
end

