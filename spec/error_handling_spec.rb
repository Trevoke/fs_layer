require 'spec_helper'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'fs_layer')

module FSLayer
  describe "Error handling" do
    before { Index.clear }
    after { Index.clear }

    describe File do
      describe ".add" do
        it "raises InvalidPathError for nil path" do
          expect { File.add(nil) }.to raise_error(InvalidPathError, /cannot be nil/)
        end

        it "raises InvalidPathError for empty path" do
          expect { File.add("") }.to raise_error(InvalidPathError, /cannot be empty/)
        end

        it "raises InvalidPathError for path with null bytes" do
          expect { File.add("test\0file") }.to raise_error(InvalidPathError, /null bytes/)
        end

        it "raises InvalidPathError when parent directory doesn't exist" do
          expect {
            File.add("/nonexistent/directory/file.txt")
          }.to raise_error(InvalidPathError, /parent directory/)
        end
      end

      describe "#initialize" do
        it "raises InvalidPathError for nil path" do
          expect { File.new(nil) }.to raise_error(InvalidPathError, /cannot be nil/)
        end

        it "raises InvalidPathError for empty path" do
          expect { File.new("") }.to raise_error(InvalidPathError, /cannot be empty/)
        end
      end

      describe "#destination" do
        let(:test_file) { '/tmp/test_destination_file' }

        after { FileUtils.rm_f test_file }

        it "raises FileNotFoundError when file doesn't exist" do
          file = File.retrieve('/nonexistent/file')
          expect { file.destination }.to raise_error(FileNotFoundError, /does not exist/)
        end

        it "raises SymlinkError when file is not a symlink" do
          File.add test_file
          file = File.retrieve test_file
          expect { file.destination }.to raise_error(SymlinkError, /not a symlink/)
        end
      end
    end

    describe Link do
      describe "#initialize" do
        it "raises InvalidPathError for nil file" do
          expect { Link.new(nil) }.to raise_error(InvalidPathError, /cannot be nil/)
        end

        it "raises InvalidPathError for non-File instance" do
          expect { Link.new("string") }.to raise_error(InvalidPathError, /must be a FSLayer::File/)
        end
      end

      describe "#to" do
        let(:source_file) { '/tmp/test_link_source' }
        let(:dest_file) { '/tmp/test_link_dest' }

        before do
          FSLayer.fake_it
          Index.clear
        end

        after do
          FSLayer.keep_it_real
          FileUtils.rm_f [source_file, dest_file]
          Index.clear
        end

        it "raises InvalidPathError for nil destination" do
          file = FSLayer.insert source_file
          link = Link.new(file)
          expect { link.to(nil) }.to raise_error(InvalidPathError, /cannot be nil/)
        end

        it "raises InvalidPathError for empty destination" do
          file = FSLayer.insert source_file
          link = Link.new(file)
          expect { link.to("") }.to raise_error(InvalidPathError, /cannot be empty/)
        end
      end
    end

    describe "API" do
      describe "#delete" do
        let(:test_file) { '/tmp/test_delete_file' }

        before { Index.clear }
        after do
          FileUtils.rm_f test_file
          Index.clear
        end

        it "accepts both File objects and strings" do
          file = FSLayer.insert test_file
          expect { FSLayer.delete test_file }.not_to raise_error
        end
      end

      describe "#link with errors" do
        let(:source_file) { '/tmp/link_error_source' }
        let(:dest_file) { '/tmp/link_error_dest' }

        before do
          Index.clear
          FileUtils.rm_f [source_file, dest_file]
        end

        after do
          FileUtils.rm_f [source_file, dest_file]
          Index.clear
        end

        it "handles existing symlink destination" do
          FSLayer.insert source_file
          FSLayer.insert dest_file

          expect {
            FSLayer.link(source_file).to(dest_file)
          }.to raise_error(SymlinkError, /already exists/)
        end

        it "handles permission errors on symlink creation" do
          FSLayer.insert source_file
          allow(::File).to receive(:symlink).and_raise(Errno::EACCES.new)

          expect {
            FSLayer.link(source_file).to(dest_file)
          }.to raise_error(PermissionError, /Permission denied/)
        end

        it "handles generic symlink creation errors" do
          FSLayer.insert source_file
          allow(::File).to receive(:symlink).and_raise(StandardError.new("test error"))

          expect {
            FSLayer.link(source_file).to(dest_file)
          }.to raise_error(SymlinkError, /Failed to create symlink/)
        end
      end
    end
  end
end
