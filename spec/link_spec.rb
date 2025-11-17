require 'spec_helper'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'fs_layer')

module FSLayer
  describe Link do
    let(:source_file) { '/tmp/link_spec_source' }
    let(:symlink_dest) { '/tmp/link_spec_dest' }

    before do
      Index.clear
      FileUtils.rm_f [source_file, symlink_dest]
    end

    after do
      FileUtils.rm_f [source_file, symlink_dest]
      Index.clear
    end

    describe "creating symlinks" do
      it "creates a working symlink" do
        FSLayer.insert source_file
        result = FSLayer.link(source_file).to(symlink_dest)

        expect(result).to be_an_instance_of FSLayer::File
        expect(::File.symlink?(symlink_dest)).to be true
        expect(::File.readlink(symlink_dest)).to eq source_file
      end

      it "tracks the symlink in the index" do
        FSLayer.insert source_file
        FSLayer.link(source_file).to(symlink_dest)

        expect(FSLayer.has?(symlink_dest)).to be true
      end
    end

    describe "accessing symlink attributes" do
      before do
        FSLayer.insert source_file
        FSLayer.link(source_file).to(symlink_dest)
      end

      it "correctly identifies as symlink" do
        file = FSLayer.retrieve symlink_dest
        expect(file.symlink?).to be true
      end

      it "resolves destination" do
        file = FSLayer.retrieve symlink_dest
        expect(file.destination).to eq ::File.realpath(source_file)
      end

      it "gets the symlink name" do
        file = FSLayer.retrieve symlink_dest
        expect(file.name).to eq 'link_spec_dest'
      end
    end

    describe "with fake mode" do
      before do
        FSLayer.fake_it
        Index.clear
      end

      after do
        FSLayer.keep_it_real
        Index.clear
      end

      it "doesn't create actual symlinks" do
        FSLayer.insert source_file
        FSLayer.link(source_file).to(symlink_dest)

        expect(::File.exist?(symlink_dest)).to be false
        expect(FSLayer.has?(symlink_dest)).to be true
      end
    end
  end
end
