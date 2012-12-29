require_relative "../lib/cabinet.rb"
require 'minitest/autorun'

module Cabinet
  describe File do
    let(:file) { "filename" }
    after { FileUtils.rm_f file }

    it "can be added" do
      File.add file
      ::File.exists?(file).must_equal true
    end

    describe "info" do
      before { File.add file }
      subject { File.retrieve file }
      it "has the name" do
        subject.name.must_equal file
      end
    end
  end
end
