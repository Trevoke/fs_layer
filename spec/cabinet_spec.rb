require 'spec_helper'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'fs_layer')

describe FSLayer do
  subject { FSLayer }

  describe "API methods" do
    let(:test_file) { '/tmp/test_api_file' }

    before do
      FileUtils.rm_f test_file
      FSLayer::Index.clear
    end

    after do
      FileUtils.rm_f test_file
      FSLayer::Index.clear
    end

    describe "#retrieve" do
      it "returns a File object for a given path" do
        subject.insert test_file
        retrieved = subject.retrieve test_file
        expect(retrieved).to be_an_instance_of FSLayer::File
        expect(retrieved.path).to eq test_file
      end
    end

    describe "#delete" do
      it "removes the file from filesystem and index" do
        subject.insert test_file
        expect(subject.has?(test_file)).to be true
        expect(::File.exist?(test_file)).to be true

        subject.delete test_file
        expect(subject.has?(test_file)).to be false
        expect(::File.exist?(test_file)).to be false
      end

      it "accepts a File object" do
        file = subject.insert test_file
        expect(subject.has?(test_file)).to be true

        subject.delete file
        expect(subject.has?(test_file)).to be false
      end
    end
  end

  describe "Faking it" do

    before do
      subject.fake_it
      FSLayer::Index.clear
    end

    after do
      subject.keep_it_real
      FSLayer::Index.clear
    end

    it "does not really create files" do
      file = subject.insert '/tmp/file'
      expect(file).to be_an_instance_of FSLayer::File
      expect(subject.has?('/tmp/file')).to be true
      expect(file).not_to exist
    end

    it "does not really create symlinks" do
      subject.insert '/tmp/file1'
      file = subject.link('/tmp/file1').to('/tmp/file2')
      expect(file).to be_an_instance_of FSLayer::File
      expect(file.path).to eq '/tmp/file2'
      expect(::File.exist?(file.path)).to be false
    end

    it "does not really delete files" do
      subject.insert '/tmp/fake_file'
      expect(subject.has?('/tmp/fake_file')).to be true

      subject.delete '/tmp/fake_file'
      expect(subject.has?('/tmp/fake_file')).to be false
      expect(::File.exist?('/tmp/fake_file')).to be false
    end
  end
end
