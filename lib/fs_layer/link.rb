module FSLayer
  class Link
    attr_reader :file

    def initialize file
      raise InvalidPathError, "File cannot be nil" if file.nil?
      raise InvalidPathError, "File must be a FSLayer::File instance" unless file.is_a?(FSLayer::File)
      @file = file
    end

    def to symlink_destination
      FSLayer::File.validate_path!(symlink_destination)

      unless FSLayer.fake?
        begin
          ::File.symlink(file.path, symlink_destination)
          FSLayer.log(:info, "Created symlink: #{symlink_destination} -> #{file.path}")
        rescue Errno::EEXIST
          FSLayer.log(:error, "Symlink destination already exists: #{symlink_destination}")
          raise SymlinkError, "Symlink destination already exists: #{symlink_destination}"
        rescue Errno::EACCES
          FSLayer.log(:error, "Permission denied creating symlink: #{symlink_destination}")
          raise PermissionError, "Permission denied creating symlink: #{symlink_destination}"
        rescue Errno::ENOENT
          FSLayer.log(:error, "Parent directory doesn't exist: #{symlink_destination}")
          raise InvalidPathError, "Parent directory doesn't exist: #{symlink_destination}"
        rescue StandardError => e
          FSLayer.log(:error, "Failed to create symlink: #{e.message}")
          raise SymlinkError, "Failed to create symlink: #{e.message}"
        end
      end

      FSLayer::File.add(symlink_destination)
    end
  end
end
