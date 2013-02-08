module Cabinet
  class Link
    attr_reader :file
    
    def initialize file
      @file = file
    end

    def to symlink_destination
      ::File.symlink(file.path, symlink_destination) unless Cabinet.fake?
      Cabinet::File.add(symlink_destination)
    end
  end
end
