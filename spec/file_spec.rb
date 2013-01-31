require_relative "../lib/cabinet.rb"
require 'spec_helper'

module Cabinet
  describe File do
    let(:file) { "filename" }
    after { FileUtils.rm_f file }

    it "can be added" do
      File.add file
      ::File.exists?(file).should be_true
    end

    it "can be a fake" do
      File.add file, fake: true
      ::File.exists?(file).should be_false
      File.retrieve(file).should be_instance_of Cabinet::File
    end

    describe "info" do
      context "for a file that exists" do
        before { File.add file }
        subject { File.retrieve file }
        its(:name) { should eq file }
        its(:exist?) { should be_true }
      end
      context "for a file that does not exist" do
        subject { File.retrieve file }
        its(:name) { should eq file}
        its(:exist?) { should be_false }
      end
    end
  end
end
