module FSLayer
  class Index
    def self.known_files
      @known_files ||= []
    end

    def self.organize file
      known_files << file
    end
  end
end
