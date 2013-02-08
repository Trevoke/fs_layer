require_relative '../lib/fs_layer.rb'
require 'spec_helper'

module FSLayer
  describe Index do
    let(:file) { 'some_file_name' }
    after { FileUtils.rm_f file }
    it "adds them to the list of managed files" do
      File.add file
      Index.known_files.should include(file)
    end
  end
end
