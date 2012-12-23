require 'fileutils'

module Cabinet
  def self.insert x
   FileUtils.touch x 
  end
end
