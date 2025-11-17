# FSLayer

A friendly file/directory interface for Ruby that provides a clean abstraction layer over File and FileUtils operations. FSLayer makes file operations easier to test and reason about by providing a consistent API with built-in indexing and fake mode support.

## Features

- Clean, intuitive API for file operations
- Built-in file indexing to track managed files
- Fake mode for testing without touching the filesystem
- Comprehensive error handling with custom exceptions
- Symlink support with validation
- Thread-safe index management

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fs_layer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fs_layer

## Usage

### Basic File Operations

```ruby
# Insert a new file (creates if it doesn't exist)
file = FSLayer.insert '/path/to/file.txt'

# Retrieve a file object
file = FSLayer.retrieve '/path/to/file.txt'

# Check if a file is tracked
FSLayer.has?('/path/to/file.txt')  # => true

# Delete a file (removes from filesystem and index)
FSLayer.delete '/path/to/file.txt'
# or
FSLayer.delete file
```

### Working with File Objects

```ruby
file = FSLayer.insert '/path/to/file.txt'

file.name        # => "file.txt"
file.path        # => "/path/to/file.txt"
file.exist?      # => true
file.symlink?    # => false
```

### Creating Symlinks

```ruby
# Create a symlink
source = '/path/to/source.txt'
destination = '/path/to/link.txt'

FSLayer.link(source).to(destination)
```

### Working with Symlinks

```ruby
file = FSLayer.retrieve '/path/to/symlink'

file.symlink?      # => true
file.destination   # => "/path/to/actual/file.txt" (resolved path)
```

### Testing Mode (Fake It)

For testing, you can enable fake mode which prevents actual filesystem operations:

```ruby
# Enable fake mode
FSLayer.fake_it

# These operations won't touch the filesystem
file = FSLayer.insert '/tmp/test_file'
file.exist?  # => false (not actually created)
FSLayer.has?('/tmp/test_file')  # => true (tracked in index)

# Create symlinks without touching filesystem
FSLayer.link('/tmp/source').to('/tmp/dest')

# Disable fake mode
FSLayer.keep_it_real
```

This is particularly useful in test suites:

```ruby
describe "My file operations" do
  before { FSLayer.fake_it }
  after { FSLayer.keep_it_real }

  it "processes files" do
    file = FSLayer.insert '/tmp/test'
    # test your logic without creating real files
  end
end
```

### Error Handling

FSLayer provides comprehensive error handling with custom exceptions:

```ruby
begin
  FSLayer.insert nil
rescue FSLayer::InvalidPathError => e
  puts e.message  # => "Path cannot be nil"
end

begin
  file = FSLayer.retrieve '/path/to/regular_file'
  file.destination
rescue FSLayer::SymlinkError => e
  puts e.message  # => "File is not a symlink: /path/to/regular_file"
end
```

#### Exception Types

- `FSLayer::Error` - Base exception class
- `FSLayer::InvalidPathError` - Invalid file path (nil, empty, null bytes, nonexistent parent)
- `FSLayer::FileNotFoundError` - File doesn't exist when required
- `FSLayer::SymlinkError` - Symlink-related errors (broken links, circular references, not a symlink)
- `FSLayer::PermissionError` - Permission denied for file operations

### Index Management

FSLayer maintains an internal index of managed files:

```ruby
# Clear the index (useful in test cleanup)
FSLayer::Index.clear

# Get all tracked files
FSLayer::Index.known_files  # => ['/path/to/file1', '/path/to/file2']

# Remove a file from the index (without deleting)
FSLayer::Index.remove '/path/to/file'
```

**Important for Long-Running Processes**: The index stores all file paths in memory. For long-running applications, periodically call `FSLayer::Index.clear` or use `FSLayer.delete` to remove files you no longer need to track. This prevents unbounded memory growth.

### Logging and Monitoring

FSLayer includes built-in logging for production monitoring:

```ruby
require 'logger'

# Configure a logger
FSLayer.logger = Logger.new(STDOUT)
FSLayer.logger.level = Logger::INFO

# Operations will now be logged
FSLayer.insert '/path/to/file'
# => [FSLayer] Inserting file: /path/to/file
# => [FSLayer] Successfully inserted file: /path/to/file

# Errors are automatically logged
begin
  FSLayer.insert '/invalid/path/file'
rescue FSLayer::InvalidPathError => e
  # Error was logged before exception was raised
end
```

**Log Levels**:
- `DEBUG` - Detailed operation information (retrieve, insert start, symlink creation start)
- `INFO` - Successful operations (file created, deleted, symlink created, mode changes)
- `ERROR` - Operation failures with details

**Rails Integration**: FSLayer automatically uses `Rails.logger` when running in a Rails application.

**Custom Logger**: You can provide any logger that responds to standard logging methods (`debug`, `info`, `warn`, `error`, `fatal`).

## API Reference

### Module Methods

- `FSLayer.insert(path)` - Create a file and track it in the index
- `FSLayer.retrieve(path)` - Get a File object for the given path
- `FSLayer.delete(path_or_file)` - Delete a file from filesystem and index
- `FSLayer.has?(path)` - Check if a file is tracked in the index
- `FSLayer.link(path)` - Create a Link object for symlinking
- `FSLayer.fake_it` - Enable fake mode (no filesystem operations)
- `FSLayer.keep_it_real` - Disable fake mode
- `FSLayer.fake?` - Check if fake mode is enabled

### File Instance Methods

- `#name` - Get the basename of the file
- `#path` - Get the full path
- `#exist?` - Check if file exists on filesystem
- `#symlink?` - Check if file is a symlink
- `#destination` - Get the resolved path for a symlink

### Index Class Methods

- `FSLayer::Index.known_files` - Array of tracked file paths
- `FSLayer::Index.organize(path)` - Add a file to the index
- `FSLayer::Index.remove(path)` - Remove a file from the index
- `FSLayer::Index.clear` - Clear all tracked files

## Development

Run the test suite:

```bash
rspec spec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License - see LICENSE.txt for details
