require_relative '../lib/fs_layer.rb'
require 'spec_helper'

module FSLayer
  describe Index do
    let(:file) { 'some_file_name' }

    before { Index.clear }
    after do
      FileUtils.rm_f file
      Index.clear
    end

    it "adds them to the list of managed files" do
      File.add file
      expect(Index.known_files).to include(file)
    end

    it "removes them from the list of managed files" do
      File.add file
      expect(Index.known_files).to include(file)
      Index.remove file
      expect(Index.known_files).not_to include(file)
    end

    it "can be cleared" do
      File.add file
      File.add 'another_file'
      expect(Index.known_files.size).to eq 2
      Index.clear
      expect(Index.known_files).to be_empty
    end
  end
end
