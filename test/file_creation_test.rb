require_relative "../lib/cabinet.rb"
require 'minitest/autorun'

class FileCreationTest < MiniTest::Spec
  let(:file) { "filename" }
  describe "Creating files" do
    after do
      FileUtils.rm_f file
    end
    it "is as simple as putting a file in a drawer" do
      Cabinet.insert file
      File.exists?(file).must_be :==, true
    end
  end
end
