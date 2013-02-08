module Cabinet
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
      Cabinet::File.add file
    end

    def has? file_object
      Index.known_files.include? file_object 
    end

    def link file
      Cabinet::Link.new(Cabinet::File.add(file))
    end
  end
end

