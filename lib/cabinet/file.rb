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

    def symlink_to destination
      orig = ::File.expand_path @file
      dest = ::File.expand_path destination
      ::File.symlink orig, dest
    end

    def symlink?
      ::File.symlink? @file
    end

  end
end
