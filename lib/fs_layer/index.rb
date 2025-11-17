module FSLayer
  class Index
    def self.known_files
      @known_files ||= []
    end

    def self.organize file
      known_files << file
    end

    def self.remove file
      known_files.delete file
    end

    def self.clear
      @known_files = []
    end
  end
end
