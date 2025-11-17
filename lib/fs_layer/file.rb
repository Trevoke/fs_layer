require 'fileutils'
require 'pathname'

module FSLayer
  class File
    def self.add file
      validate_path!(file)

      begin
        FileUtils.touch file unless FSLayer.fake?
      rescue Errno::EACCES => e
        FSLayer.log(:error, "Permission denied creating file: #{file}")
        raise PermissionError, "Permission denied: #{file}"
      rescue Errno::ENOENT => e
        FSLayer.log(:error, "Invalid path or missing parent directory: #{file}")
        raise InvalidPathError, "Invalid path or parent directory doesn't exist: #{file}"
      rescue StandardError => e
        FSLayer.log(:error, "Failed to create file #{file}: #{e.message}")
        raise Error, "Failed to create file #{file}: #{e.message}"
      end

      Index.organize file
      new file
    end

    def self.retrieve filename
      new filename
    end

    def self.validate_path!(path)
      raise InvalidPathError, "Path cannot be nil" if path.nil?
      raise InvalidPathError, "Path cannot be empty" if path.to_s.strip.empty?
      raise InvalidPathError, "Path contains null bytes" if path.to_s.include?("\0")
    end

    def initialize file
      self.class.validate_path!(file)
      @file = file
    end

    def name
      ::File.basename @file
    end

    def exist?
      ::File.exist? @file
    end

    def symlink?
      ::File.symlink? @file
    end

    def destination
      raise FileNotFoundError, "File does not exist: #{@file}" unless exist?
      raise SymlinkError, "File is not a symlink: #{@file}" unless symlink?

      begin
        Pathname.new(@file).realpath.to_s
      rescue Errno::ENOENT
        raise SymlinkError, "Broken symlink: #{@file}"
      rescue Errno::ELOOP
        raise SymlinkError, "Circular symlink detected: #{@file}"
      end
    end

    def path
      @file
    end
  end
end
