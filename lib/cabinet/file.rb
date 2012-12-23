require 'fileutils'

module Cabinet
  class File
    def self.add x
      FileUtils.touch x 
      Secretary.organize x
    end
  end
end
