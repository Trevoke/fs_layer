require 'fileutils'

module Cabinet
  class File
    def self.add file
      FileUtils.touch file unless Cabinet.fake
      Index.organize file
      new file
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
      @symlink = ::File.expand_path destination
      ::File.symlink orig, @symlink
    end

    def symlink?
      ::File.symlink? @file
    end

    def destination
      Pathname.new(@file).realpath.to_s
    end

  end
end
