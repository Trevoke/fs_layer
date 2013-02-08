module FSLayer
  class << self

    def fake_it
      @fake = true
    end

    def keep_it_real
      @fake = false
    end

    def fake?
      @fake
    end

    def insert file
      FSLayer::File.add file
    end

    def has? file_object
      Index.known_files.include? file_object 
    end

    def link file
      FSLayer::Link.new(FSLayer::File.add(file))
    end
  end
end

