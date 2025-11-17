module FSLayer
  class Link
    attr_reader :file

    def initialize(file)
      raise InvalidPathError, "File cannot be nil" if file.nil?
      raise InvalidPathError, "File must be a FSLayer::File instance" unless file.is_a?(FSLayer::File)
      @file = file
    end

    def to(symlink_destination)
      FSLayer::File.validate_path!(symlink_destination)

      begin
        FSLayer.backend.symlink(file.path, symlink_destination)
        FSLayer.log(:info, "Created symlink: #{symlink_destination} -> #{file.path}")
      rescue => e
        FSLayer.log(:error, "Failed to create symlink: #{e.message}")
        raise
      end

      FSLayer::File.add(symlink_destination)
    end
  end
end
