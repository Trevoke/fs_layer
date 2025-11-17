# Backend System Usage Examples

## Basic Usage (Backward Compatible)

The existing API works exactly as before:

```ruby
require 'fs_layer'

# Default: uses LocalFileSystem backend
file = FSLayer.insert('/tmp/test.txt')
file.exist? # => true

# Retrieve and read
file = FSLayer.retrieve('/tmp/test.txt')

# Delete
FSLayer.delete('/tmp/test.txt')
```

## Using Memory Backend for Testing

The "fake mode" now uses a real Memory backend:

```ruby
# Old way (still works)
FSLayer.fake_it
file = FSLayer.insert('/tmp/test.txt')
file.exist? # => true (in memory, not on disk)
FSLayer.keep_it_real

# New way (more explicit)
FSLayer.configure do |config|
  config.use_memory
end

file = FSLayer.insert('/test/file.txt', 'content')
FSLayer.read('/test/file.txt') # => 'content'

# Inspect state (useful for testing)
FSLayer.backend.dump
# => {files: {"/test/file.txt" => "content"}, directories: ["/", "/test"], ...}

FSLayer.backend.stats
# => {file_count: 1, directory_count: 2, symlink_count: 0, total_size: 7}
```

## New Convenience Methods

```ruby
# Read file content directly
content = FSLayer.read('/path/to/file.txt')

# Write content directly
FSLayer.write('/path/to/file.txt', 'Hello World')

# Check existence
FSLayer.exists?('/path/to/file.txt') # => true

# Get metadata
meta = FSLayer.metadata('/path/to/file.txt')
# => {size: 11, modified_at: Time, mode: 0644, ...}

# Copy files
FSLayer.copy('/source.txt', '/dest.txt')

# Move files
FSLayer.move('/old/path.txt', '/new/path.txt')

# List directory
files = FSLayer.list('/some/directory')
files = FSLayer.list('/some/directory', recursive: true, pattern: '*.rb')
```

## Streaming Large Files

Efficiently handle large files without loading into memory:

```ruby
# Stream write
FSLayer.open_write('/large/file.dat') do |io|
  1000.times do |i|
    io.write("Line #{i}\n")
  end
end

# Stream read
FSLayer.open_read('/large/file.dat') do |io|
  io.each_line do |line|
    process(line)
  end
end

# File object streaming
file = FSLayer.retrieve('/large/file.dat')

file.open_write do |io|
  io.write(large_data)
end

file.open_read do |io|
  io.each_chunk(1024) { |chunk| process(chunk) }
end
```

## Enhanced File Objects

```ruby
file = FSLayer.insert('/test.txt', 'initial content')

# Read content
file.read # => 'initial content'

# Write content
file.write('new content')

# Get size
file.size # => 11

# Get metadata
file.metadata # => {size: 11, modified_at: Time, ...}
file.modified_at # => Time object

# Get URI
file.uri # => "file:///absolute/path/to/test.txt"

# Backend-aware
file.backend # => #<FSLayer::Backend::LocalFileSystem>
```

## Testing with Memory Backend

### RSpec Example

```ruby
require 'fs_layer'

RSpec.describe "MyFileProcessor" do
  before(:each) do
    FSLayer.fake_it # or FSLayer.configure { |c| c.use_memory }
  end

  after(:each) do
    FSLayer.backend.clear
    FSLayer.keep_it_real
  end

  it "processes files" do
    # Create test files in memory
    FSLayer.write('/input/data.txt', 'test data')

    # Run your code
    MyFileProcessor.process('/input/data.txt', '/output/result.txt')

    # Assert results
    expect(FSLayer.exists?('/output/result.txt')).to be true
    expect(FSLayer.read('/output/result.txt')).to eq('processed: test data')

    # Inspect state
    files = FSLayer.backend.dump[:files]
    expect(files.keys).to include('/input/data.txt', '/output/result.txt')
  end
end
```

### Minitest Example

```ruby
require 'minitest/autorun'
require 'fs_layer'

class TestFileOperations < Minitest::Test
  def setup
    FSLayer.fake_it
  end

  def teardown
    FSLayer.backend.clear
    FSLayer.keep_it_real
  end

  def test_file_creation
    FSLayer.insert('/test/file.txt', 'content')
    assert FSLayer.exists?('/test/file.txt')
    assert_equal 'content', FSLayer.read('/test/file.txt')
  end

  def test_symlinks
    FSLayer.insert('/test/target.txt', 'target')
    FSLayer.link('/test/target.txt').to('/test/link.txt')

    file = FSLayer.retrieve('/test/link.txt')
    assert file.symlink?
    assert_equal '/test/target.txt', file.destination
  end
end
```

## Creating Custom Backends

Here's how to create a backend for S3:

```ruby
require 'aws-sdk-s3'

module FSLayer
  module Backend
    class S3 < Base
      def initialize(bucket:, region: 'us-east-1', prefix: nil)
        @bucket = bucket
        @prefix = prefix
        @client = Aws::S3::Client.new(region: region)
      end

      def read(path, **options)
        response = @client.get_object(bucket: @bucket, key: s3_key(path))
        response.body.read
      rescue Aws::S3::Errors::NoSuchKey
        raise FileNotFoundError, "File not found: #{path}"
      rescue Aws::S3::Errors::AccessDenied
        raise PermissionError, "Access denied: #{path}"
      end

      def write(path, content, **options)
        @client.put_object(
          bucket: @bucket,
          key: s3_key(path),
          body: content,
          content_type: options[:content_type],
          metadata: options[:metadata] || {},
          storage_class: options[:storage_class]
        )
      rescue Aws::S3::Errors::AccessDenied
        raise PermissionError, "Access denied: #{path}"
      end

      def exists?(path)
        @client.head_object(bucket: @bucket, key: s3_key(path))
        true
      rescue Aws::S3::Errors::NotFound
        false
      end

      def delete(path, **options)
        @client.delete_object(bucket: @bucket, key: s3_key(path))
      rescue Aws::S3::Errors::NoSuchKey
        raise FileNotFoundError, "File not found: #{path}"
      end

      def list(path, **options)
        prefix = s3_key(path).chomp('/') + '/'
        response = @client.list_objects_v2(
          bucket: @bucket,
          prefix: prefix,
          delimiter: options[:recursive] ? nil : '/'
        )
        response.contents.map { |obj| unresolve_key(obj.key) }
      end

      def metadata(path)
        response = @client.head_object(bucket: @bucket, key: s3_key(path))
        {
          size: response.content_length,
          modified_at: response.last_modified,
          content_type: response.content_type,
          etag: response.etag,
          storage_class: response.storage_class,
          metadata: response.metadata
        }
      rescue Aws::S3::Errors::NotFound
        raise FileNotFoundError, "File not found: #{path}"
      end

      def copy(source, dest, **options)
        @client.copy_object(
          bucket: @bucket,
          copy_source: "#{@bucket}/#{s3_key(source)}",
          key: s3_key(dest)
        )
      end

      # Streaming support
      def open_read(path, **options)
        response = @client.get_object(bucket: @bucket, key: s3_key(path))
        yield response.body
      end

      def open_write(path, **options)
        io = StringIO.new
        yield io
        write(path, io.string, **options)
      end

      # Capabilities
      def supports_symlinks?; false; end
      def supports_permissions?; false; end
      def supports_streaming?; true; end
      def supports_metadata?; true; end

      def normalize_path(path)
        path.to_s.sub(/^\//, '')
      end

      def uri_for(path)
        "s3://#{@bucket}/#{s3_key(path)}"
      end

      private

      def s3_key(path)
        key = normalize_path(path)
        @prefix ? File.join(@prefix, key) : key
      end

      def unresolve_key(key)
        key = key.sub(/^#{Regexp.escape(@prefix)}/, '') if @prefix
        "/#{key}"
      end
    end
  end
end

# Usage:
FSLayer.configure do |config|
  config.use_custom(
    FSLayer::Backend::S3.new(
      bucket: 'my-app-files',
      region: 'us-west-2',
      prefix: 'uploads'
    )
  )
end

# Now all FSLayer operations use S3
FSLayer.write('documents/report.pdf', pdf_data,
              content_type: 'application/pdf',
              storage_class: 'INTELLIGENT_TIERING')

file = FSLayer.retrieve('documents/report.pdf')
file.uri # => "s3://my-app-files/uploads/documents/report.pdf"
file.metadata # => {size: 1024, etag: "...", storage_class: "INTELLIGENT_TIERING"}
```

## Redis Backend Example

For caching or temporary storage:

```ruby
require 'redis'

module FSLayer
  module Backend
    class Redis < Base
      def initialize(redis_url: 'redis://localhost:6379', ttl: nil)
        @redis = ::Redis.new(url: redis_url)
        @default_ttl = ttl
      end

      def read(path, **options)
        value = @redis.get(normalize_path(path))
        raise FileNotFoundError, "File not found: #{path}" unless value
        value
      end

      def write(path, content, **options)
        key = normalize_path(path)
        ttl = options[:ttl] || @default_ttl

        if ttl
          @redis.setex(key, ttl, content)
        else
          @redis.set(key, content)
        end

        # Store metadata
        @redis.hset("#{key}:meta", "size", content.bytesize)
        @redis.hset("#{key}:meta", "created_at", Time.now.to_i)
      end

      def exists?(path)
        @redis.exists?(normalize_path(path)) > 0
      end

      def delete(path, **options)
        key = normalize_path(path)
        result = @redis.del(key)
        @redis.del("#{key}:meta")
        raise FileNotFoundError, "File not found: #{path}" if result == 0
      end

      def list(path, **options)
        pattern = "#{normalize_path(path)}/*"
        @redis.keys(pattern).reject { |k| k.end_with?(':meta') }
      end

      def metadata(path)
        key = normalize_path(path)
        meta = @redis.hgetall("#{key}:meta")
        raise FileNotFoundError, "File not found: #{path}" if meta.empty?

        {
          size: meta["size"].to_i,
          created_at: Time.at(meta["created_at"].to_i)
        }
      end

      def supports_streaming?; false; end
      def uri_for(path); "redis://#{normalize_path(path)}"; end
      def normalize_path(path); path.to_s.sub(/^\//, ''); end
    end
  end
end

# Usage:
FSLayer.configure do |config|
  config.use_custom(
    FSLayer::Backend::Redis.new(
      redis_url: ENV['REDIS_URL'],
      ttl: 3600 # 1 hour default TTL
    )
  )
end

# Store with custom TTL
FSLayer.write('cache/session/abc123', session_data, ttl: 1800)

# After 1800 seconds, the file will automatically expire
FSLayer.exists?('cache/session/abc123') # => false (after expiry)
```

## Composing Backends

You can create composite backends that combine multiple backends:

```ruby
module FSLayer
  module Backend
    class Cached < Base
      def initialize(cache_backend, storage_backend)
        @cache = cache_backend
        @storage = storage_backend
      end

      def read(path, **options)
        # Try cache first
        if @cache.exists?(path)
          @cache.read(path, **options)
        else
          # Fall back to storage and cache the result
          content = @storage.read(path, **options)
          @cache.write(path, content, ttl: 300) # 5 min cache
          content
        end
      end

      def write(path, content, **options)
        # Write to both
        @storage.write(path, content, **options)
        @cache.write(path, content, ttl: 300)
      end

      def exists?(path)
        @cache.exists?(path) || @storage.exists?(path)
      end

      # Delegate other methods to storage
      def delete(path, **options); @storage.delete(path, **options); end
      def list(path, **options); @storage.list(path, **options); end
      def metadata(path); @storage.metadata(path); end
      def uri_for(path); @storage.uri_for(path); end
    end
  end
end

# Usage:
redis_cache = FSLayer::Backend::Redis.new(ttl: 300)
s3_storage = FSLayer::Backend::S3.new(bucket: 'my-bucket')

FSLayer.configure do |config|
  config.use_custom(
    FSLayer::Backend::Cached.new(redis_cache, s3_storage)
  )
end

# Reads hit Redis cache, writes go to both Redis and S3
```

## Migrating Between Backends

```ruby
# Copy all files from one backend to another
def migrate_backend(from_backend, to_backend, path = '/')
  from_backend.list(path, recursive: true).each do |file_path|
    next if from_backend.metadata(file_path)[:directory]

    content = from_backend.read(file_path)
    to_backend.write(file_path, content)
    puts "Migrated: #{file_path}"
  end
end

# Example: Migrate from local to S3
local = FSLayer::Backend::LocalFileSystem.new(root: '/app/uploads')
s3 = FSLayer::Backend::S3.new(bucket: 'my-uploads')

migrate_backend(local, s3, '/')
```

## Best Practices

1. **Use Memory backend for tests**: Fast, isolated, inspectable
   ```ruby
   before { FSLayer.fake_it }
   after { FSLayer.backend.clear; FSLayer.keep_it_real }
   ```

2. **Stream large files**: Don't load everything into memory
   ```ruby
   FSLayer.open_read(large_file) { |io| io.each_line { |line| process(line) } }
   ```

3. **Check capabilities**: Not all backends support all features
   ```ruby
   if FSLayer.backend.supports_symlinks?
     FSLayer.link(source).to(dest)
   end
   ```

4. **Use backend-specific options**: Leverage special features
   ```ruby
   # S3-specific options
   FSLayer.write(path, content,
                storage_class: 'GLACIER',
                metadata: {user_id: '123'})
   ```

5. **Handle errors gracefully**: All backends raise FSLayer errors
   ```ruby
   begin
     FSLayer.read(path)
   rescue FSLayer::FileNotFoundError
     # Handle missing file
   rescue FSLayer::PermissionError
     # Handle access denied
   end
   ```
