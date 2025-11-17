require 'spec_helper'
require 'logger'
require 'stringio'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'fs_layer')

module FSLayer
  describe "Logging" do
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output) }
    let(:test_file) { '/tmp/logging_test_file' }

    before do
      Index.clear
      FileUtils.rm_f test_file
      FSLayer.logger = logger
    end

    after do
      FileUtils.rm_f test_file
      Index.clear
      FSLayer.logger = nil
    end

    describe "configuration" do
      it "allows setting a custom logger" do
        FSLayer.logger = logger
        expect(FSLayer.logger).to eq logger
      end

      it "logs operations" do
        FSLayer.insert test_file
        expect(log_output.string).to include("Inserting file:")
        expect(log_output.string).to include("Successfully inserted file:")
      end
    end

    describe "fake mode logging" do
      before { FSLayer.fake_it }
      after { FSLayer.keep_it_real }

      it "logs when fake mode is enabled" do
        expect(log_output.string).to include("Enabled fake mode")
      end

      it "logs when fake mode is disabled" do
        log_output.truncate(0)
        log_output.rewind
        FSLayer.keep_it_real
        expect(log_output.string).to include("Disabled fake mode")
      end
    end

    describe "operation logging" do
      it "logs file insertion" do
        FSLayer.insert test_file
        log_content = log_output.string
        expect(log_content).to include("Inserting file:")
        expect(log_content).to include("Successfully inserted file:")
      end

      it "logs file retrieval" do
        FSLayer.insert test_file
        log_output.truncate(0)
        log_output.rewind

        FSLayer.retrieve test_file
        expect(log_output.string).to include("Retrieving file:")
      end

      it "logs file deletion" do
        FSLayer.insert test_file
        log_output.truncate(0)
        log_output.rewind

        FSLayer.delete test_file
        log_content = log_output.string
        expect(log_content).to include("Deleting file:")
        expect(log_content).to include("Successfully deleted file:")
      end

      it "logs symlink creation" do
        FSLayer.insert test_file
        log_output.truncate(0)
        log_output.rewind

        FSLayer.link(test_file).to("#{test_file}_link")
        log_content = log_output.string
        expect(log_content).to include("Creating symlink from:")
        expect(log_content).to include("Created symlink:")

        FileUtils.rm_f "#{test_file}_link"
      end
    end

    describe "error logging" do
      it "logs insert attempt before validation" do
        begin
          FSLayer.insert nil
        rescue InvalidPathError
          # Expected
        end

        # Insert logs before validation, so we see the debug log
        expect(log_output.string).to include("Inserting file:")
      end

      it "logs permission errors" do
        allow(FileUtils).to receive(:touch).and_raise(Errno::EACCES.new)

        begin
          FSLayer.insert test_file
        rescue PermissionError
          # Expected
        end

        expect(log_output.string).to include("Permission denied creating file:")
      end
    end

    describe "without logger" do
      before { FSLayer.logger = nil }

      it "does not crash when no logger is configured" do
        expect { FSLayer.insert test_file }.not_to raise_error
      end
    end
  end
end
