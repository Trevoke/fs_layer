require 'fileutils'

module Cabinet
  class File
    def self.add x
      FileUtils.touch x 
      managed << x
    end

    def self.managed
      @managed ||= []
    end
  end
end
