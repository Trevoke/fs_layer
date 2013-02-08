require_relative "../lib/cabinet.rb"
require 'spec_helper'

module Cabinet
  describe File do
    let(:file) { "filename" }

    context "that exists" do
      before { File.add file }
      after { FileUtils.rm_f file }

      context "has relevant information" do
        subject { File.retrieve file }
        its(:name) { should eq file }
        its(:exist?) { should be_true }
        its(:symlink?) { should be_false }
      end

    end

    context "that does not exist" do
      before do
        Cabinet.fake_it
        File.add file 
      end
      after do
        Cabinet.keep_it_real
      end

      context "has relevant information" do
        subject { File.retrieve file }
        its(:name) { should eq file}
        its(:exist?) { should be_false }
      end
    end
  end
end
