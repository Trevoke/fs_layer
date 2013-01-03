require_relative '../lib/cabinet.rb'
require 'minitest/autorun'

module Cabinet
  describe Index do
    let(:file) { 'some_file_name' }
    after { FileUtils.rm_f file }
    it "adds them to the list of managed files" do
      File.add file
      Index.known_files.must_include file
    end
  end
end
