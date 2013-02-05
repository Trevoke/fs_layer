module Cabinet
  class << self
    attr_reader :fake

    def fake_it
      @fake = true
    end

    def keep_it_real
      @fake = false
    end

    def insert file
      Cabinet::File.add file
    end

    def has? file_object
      Index.known_files.include? file_object 
    end
  end
end
