#!/usr/bin/env ruby

require_relative 'lib/fs_layer'

def test(description)
  print "Testing: #{description}... "
  begin
    yield
    puts "✓"
    true
  rescue => e
    puts "✗"
    puts "  Error: #{e.class}: #{e.message}"
    puts "  #{e.backtrace.first(3).join("\n  ")}"
    false
  end
end

passed = 0
failed = 0

puts "=" * 60
puts "Testing FSLayer Backend System"
puts "=" * 60

# Test 1: LocalFileSystem Backend
puts "\n--- LocalFileSystem Backend ---"

test("Load default backend") do
  raise "Expected LocalFileSystem" unless FSLayer.backend.is_a?(FSLayer::Backend::LocalFileSystem)
end && passed += 1 || failed += 1

test("Create file with LocalFileSystem") do
  file = FSLayer.insert('/tmp/fslayer_test.txt', 'Hello World')
  content = FSLayer.read('/tmp/fslayer_test.txt')
  raise "Content mismatch" unless content == 'Hello World'
  FSLayer.delete('/tmp/fslayer_test.txt')
end && passed += 1 || failed += 1

test("Check file exists") do
  file = FSLayer.insert('/tmp/fslayer_test2.txt', 'test')
  raise "File should exist" unless FSLayer.exists?('/tmp/fslayer_test2.txt')
  FSLayer.delete('/tmp/fslayer_test2.txt')
end && passed += 1 || failed += 1

test("File metadata") do
  file = FSLayer.insert('/tmp/fslayer_test3.txt', 'metadata test')
  meta = FSLayer.metadata('/tmp/fslayer_test3.txt')
  raise "No size in metadata" unless meta[:size] == 'metadata test'.bytesize
  FSLayer.delete('/tmp/fslayer_test3.txt')
end && passed += 1 || failed += 1

# Test 2: Memory Backend
puts "\n--- Memory Backend ---"

test("Switch to memory backend") do
  FSLayer.fake_it
  raise "Expected Memory backend" unless FSLayer.backend.is_a?(FSLayer::Backend::Memory)
end && passed += 1 || failed += 1

test("Create file in memory") do
  file = FSLayer.insert('/test/memory_file.txt', 'In Memory')
  content = FSLayer.read('/test/memory_file.txt')
  raise "Content mismatch" unless content == 'In Memory'
end && passed += 1 || failed += 1

test("File exists in memory") do
  raise "File should exist" unless FSLayer.exists?('/test/memory_file.txt')
end && passed += 1 || failed += 1

test("List files in memory") do
  FSLayer.insert('/test/file1.txt', 'one')
  FSLayer.insert('/test/file2.txt', 'two')
  files = FSLayer.list('/test')
  raise "Expected 3 files, got #{files.size}" unless files.size == 3
end && passed += 1 || failed += 1

test("Delete file in memory") do
  FSLayer.delete('/test/file1.txt')
  raise "File should not exist" if FSLayer.exists?('/test/file1.txt')
end && passed += 1 || failed += 1

test("Copy file in memory") do
  FSLayer.copy('/test/file2.txt', '/test/file2_copy.txt')
  original = FSLayer.read('/test/file2.txt')
  copy = FSLayer.read('/test/file2_copy.txt')
  raise "Copy content mismatch" unless original == copy
end && passed += 1 || failed += 1

test("Move file in memory") do
  FSLayer.move('/test/file2_copy.txt', '/test/file2_moved.txt')
  raise "Original should not exist" if FSLayer.exists?('/test/file2_copy.txt')
  raise "Moved file should exist" unless FSLayer.exists?('/test/file2_moved.txt')
end && passed += 1 || failed += 1

test("Memory backend dump") do
  dump = FSLayer.backend.dump
  raise "No files key" unless dump.key?(:files)
  raise "No directories key" unless dump.key?(:directories)
end && passed += 1 || failed += 1

test("Memory backend stats") do
  stats = FSLayer.backend.stats
  raise "No file_count" unless stats[:file_count] > 0
  raise "No total_size" unless stats[:total_size] > 0
end && passed += 1 || failed += 1

# Test 3: Streaming
puts "\n--- Streaming Operations ---"

test("Stream write in memory") do
  FSLayer.open_write('/test/stream_write.txt') do |io|
    io.write "Line 1\n"
    io.write "Line 2\n"
  end
  content = FSLayer.read('/test/stream_write.txt')
  raise "Content mismatch" unless content == "Line 1\nLine 2\n"
end && passed += 1 || failed += 1

test("Stream read in memory") do
  lines = []
  FSLayer.open_read('/test/stream_write.txt') do |io|
    io.each_line { |line| lines << line }
  end
  raise "Expected 2 lines" unless lines.size == 2
end && passed += 1 || failed += 1

# Test 4: Symlinks
puts "\n--- Symlinks ---"

test("Create symlink in memory") do
  FSLayer.insert('/test/link_target.txt', 'target content')
  FSLayer.link('/test/link_target.txt').to('/test/link.txt')
  raise "Should be symlink" unless FSLayer.retrieve('/test/link.txt').symlink?
end && passed += 1 || failed += 1

test("Read through symlink") do
  content = FSLayer.read('/test/link.txt')
  raise "Content mismatch" unless content == 'target content'
end && passed += 1 || failed += 1

test("Readlink") do
  target = FSLayer.backend.readlink('/test/link.txt')
  raise "Expected /test/link_target.txt" unless target == '/test/link_target.txt'
end && passed += 1 || failed += 1

# Test 5: Configuration
puts "\n--- Configuration ---"

test("Configure with use_memory") do
  FSLayer.configure do |config|
    config.use_memory
  end
  raise "Expected Memory backend" unless FSLayer.backend.is_a?(FSLayer::Backend::Memory)
end && passed += 1 || failed += 1

test("Configure with use_local_filesystem") do
  FSLayer.configure do |config|
    config.use_local_filesystem
  end
  raise "Expected LocalFileSystem backend" unless FSLayer.backend.is_a?(FSLayer::Backend::LocalFileSystem)
end && passed += 1 || failed += 1

test("Switch back with keep_it_real") do
  FSLayer.fake_it
  FSLayer.keep_it_real
  raise "Expected LocalFileSystem backend" unless FSLayer.backend.is_a?(FSLayer::Backend::LocalFileSystem)
end && passed += 1 || failed += 1

# Test 6: File Object
puts "\n--- File Object ---"

FSLayer.fake_it

test("File object with backend") do
  file = FSLayer.insert('/obj/test.txt', 'object test')
  raise "Wrong path" unless file.path == '/obj/test.txt'
  raise "Wrong backend" unless file.backend.is_a?(FSLayer::Backend::Memory)
end && passed += 1 || failed += 1

test("File#read") do
  file = FSLayer.retrieve('/obj/test.txt')
  content = file.read
  raise "Content mismatch" unless content == 'object test'
end && passed += 1 || failed += 1

test("File#write") do
  file = FSLayer.retrieve('/obj/test.txt')
  file.write('updated content')
  raise "Content not updated" unless file.read == 'updated content'
end && passed += 1 || failed += 1

test("File#size") do
  file = FSLayer.retrieve('/obj/test.txt')
  raise "Size mismatch" unless file.size == 'updated content'.bytesize
end && passed += 1 || failed += 1

test("File#uri") do
  file = FSLayer.retrieve('/obj/test.txt')
  uri = file.uri
  raise "Expected memory:// URI" unless uri.start_with?('memory://')
end && passed += 1 || failed += 1

# Test 7: Error Handling
puts "\n--- Error Handling ---"

test("FileNotFoundError on read") do
  begin
    FSLayer.read('/nonexistent/file.txt')
    raise "Should have raised FileNotFoundError"
  rescue FSLayer::FileNotFoundError
    # Expected
  end
end && passed += 1 || failed += 1

test("InvalidPathError on nil path") do
  begin
    FSLayer.insert(nil)
    raise "Should have raised InvalidPathError"
  rescue FSLayer::InvalidPathError
    # Expected
  end
end && passed += 1 || failed += 1

test("SymlinkError when not a symlink") do
  file = FSLayer.insert('/regular/file.txt', 'regular')
  begin
    file.destination
    raise "Should have raised SymlinkError"
  rescue FSLayer::SymlinkError
    # Expected
  end
end && passed += 1 || failed += 1

test("NotSupportedError for unsupported features") do
  # Create a minimal backend that doesn't support symlinks
  backend = Class.new(FSLayer::Backend::Base) do
    def read(path, **options); "data"; end
    def write(path, content, **options); end
    def exists?(path); true; end
    def delete(path, **options); end
    def list(path, **options); []; end
    def mkdir(path, **options); end
    def rmdir(path, **options); end
    def metadata(path); {size: 0}; end
    def uri_for(path); "test://#{path}"; end
    def normalize_path(path); path; end
  end.new

  begin
    backend.symlink('/a', '/b')
    raise "Should have raised NotSupportedError"
  rescue FSLayer::NotSupportedError
    # Expected
  end
end && passed += 1 || failed += 1

# Summary
puts "\n" + "=" * 60
puts "Test Results"
puts "=" * 60
puts "Passed: #{passed}"
puts "Failed: #{failed}"
puts "Total:  #{passed + failed}"
puts "=" * 60

if failed == 0
  puts "✓ All tests passed!"
  exit 0
else
  puts "✗ Some tests failed"
  exit 1
end
