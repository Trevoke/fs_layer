require 'spec_helper'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'fs_layer')

describe FSLayer do
  subject { FSLayer }

  describe "Faking it" do

    before do
      subject.fake_it
    end

    after do
      subject.keep_it_real
    end

    it "does not really create files" do
      file = subject.insert '/tmp/file'
      file.should be_an_instance_of FSLayer::File
      subject.has?('/tmp/file').should be_true
      file.should_not exist
    end

    it "does not really create symlinks" do
      subject.insert '/tmp/file1'
      file = subject.link('/tmp/file1').to('/tmp/file2')
      file.should be_an_instance_of FSLayer::File
      file.path.should eq '/tmp/file2'
      ::File.exist?(file.path).should be_false
    end
  end
end
