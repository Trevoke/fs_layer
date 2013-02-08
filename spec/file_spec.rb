require_relative "../lib/fs_layer.rb"
require 'spec_helper'

module FSLayer
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
        FSLayer.fake_it
        File.add file 
      end
      after do
        FSLayer.keep_it_real
      end

      context "has relevant information" do
        subject { File.retrieve file }
        its(:name) { should eq file}
        its(:exist?) { should be_false }
      end
    end
  end
end
