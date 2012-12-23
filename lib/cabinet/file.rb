require 'fileutils'

module Cabinet
  class File
    def self.add x
      FileUtils.touch x 
    end
  end
end
