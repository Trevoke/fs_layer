require_relative "../lib/cabinet.rb"
require 'spec_helper'

module Cabinet
  describe File do
    let(:file) { "filename" }
    after { FileUtils.rm_f file }

    it "can be added" do
      File.add file
      ::File.exists?(file).should eq true
    end

    describe "info" do
      before { File.add file }
      subject { File.retrieve file }
      it "has the name" do
        subject.name.should eq file
      end
    end
  end
end
