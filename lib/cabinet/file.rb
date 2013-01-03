require 'fileutils'

module Cabinet
  class File
    def self.add file
      FileUtils.touch file 
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
  end
end
