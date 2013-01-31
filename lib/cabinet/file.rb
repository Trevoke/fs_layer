require 'fileutils'

module Cabinet
  class File
    def self.add file, options={}
      FileUtils.touch file unless options[:fake]
      Index.organize file
    end

    def self.retrieve filename
      new filename
    end

    def initialize file
      @file = file
    end

    def name
      @file
    end

    def exist?
      ::File.exists? @file
    end

    def symlink?
      ::File.symlink? @file
    end

    def self.symlink orig, dest
      ::File.symlink ::File.expand_path(orig), ::File.expand_path(dest)
    end

  end
end
