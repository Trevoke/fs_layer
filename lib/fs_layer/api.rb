module FSLayer
  class << self
    attr_writer :logger

    def logger
      @logger ||= defined?(Rails) ? Rails.logger : nil
    end

    def log(level, message)
      logger&.send(level, "[FSLayer] #{message}")
    end

    def fake_it
      @fake = true
      log(:info, "Enabled fake mode")
    end

    def keep_it_real
      @fake = false
      log(:info, "Disabled fake mode")
    end

    def fake?
      @fake
    end

    def insert file
      log(:debug, "Inserting file: #{file}")
      result = FSLayer::File.add file
      log(:info, "Successfully inserted file: #{file}")
      result
    end

    def retrieve file
      log(:debug, "Retrieving file: #{file}")
      FSLayer::File.retrieve file
    end

    def delete file
      file_obj = file.is_a?(FSLayer::File) ? file : FSLayer::File.retrieve(file)
      log(:debug, "Deleting file: #{file_obj.path}")

      unless FSLayer.fake?
        begin
          ::FileUtils.rm_f file_obj.path
        rescue Errno::EACCES
          log(:error, "Permission denied deleting file: #{file_obj.path}")
          raise PermissionError, "Permission denied deleting file: #{file_obj.path}"
        rescue StandardError => e
          log(:error, "Failed to delete file #{file_obj.path}: #{e.message}")
          raise Error, "Failed to delete file #{file_obj.path}: #{e.message}"
        end
      end

      Index.remove file_obj.path
      log(:info, "Successfully deleted file: #{file_obj.path}")
      file_obj
    end

    def has? file_object
      Index.known_files.include? file_object
    end

    def link file
      log(:debug, "Creating symlink from: #{file}")
      FSLayer::Link.new(FSLayer::File.add(file))
    end
  end
end

