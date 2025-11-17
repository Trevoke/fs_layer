module FSLayer
  class File
    attr_reader :path, :backend

    def self.add(file, content = '')
      validate_path!(file)

      begin
        FSLayer.backend.write(file, content)
      rescue => e
        FSLayer.log(:error, "Failed to create file #{file}: #{e.message}")
        raise
      end

      Index.organize(file)
      new(file)
    end

    def self.retrieve(filename)
      new(filename)
    end

    def self.validate_path!(path)
      raise InvalidPathError, "Path cannot be nil" if path.nil?
      raise InvalidPathError, "Path cannot be empty" if path.to_s.strip.empty?
      raise InvalidPathError, "Path contains null bytes" if path.to_s.include?("\0")
    end

    def initialize(file, backend = nil)
      self.class.validate_path!(file)
      @path = file
      @backend = backend || FSLayer.backend
    end

    def name
      ::File.basename(@path)
    end

    def read
      backend.read(@path)
    end

    def write(content, **options)
      backend.write(@path, content, **options)
    end

    def exist?
      backend.exists?(@path)
    end

    def symlink?
      return false unless backend.supports_symlinks?
      backend.symlink?(@path)
    end

    def destination
      raise FileNotFoundError, "File does not exist: #{@path}" unless exist?
      raise SymlinkError, "File is not a symlink: #{@path}" unless symlink?

      backend.readlink(@path)
    end

    def metadata
      backend.metadata(@path)
    end

    def size
      metadata[:size]
    end

    def modified_at
      metadata[:modified_at]
    end

    def delete
      FSLayer.delete(self)
    end

    def uri
      backend.uri_for(@path)
    end

    # Stream reading
    def open_read(**options, &block)
      backend.open_read(@path, **options, &block)
    end

    # Stream writing
    def open_write(**options, &block)
      backend.open_write(@path, **options, &block)
    end
  end
end
