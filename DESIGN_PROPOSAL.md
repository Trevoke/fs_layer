# FSLayer Multi-Backend Architecture Design

## Overview

Transform FSLayer into a storage-agnostic abstraction that works with local filesystems, cloud storage (S3, GCS), and remote storage (FTP) using a unified API.

## Architecture

### 1. Backend Interface (Contract)

Every backend must implement this interface:

```ruby
module FSLayer
  module Backend
    class Base
      # File operations
      def read(path) -> String
      def write(path, content, options = {}) -> void
      def exists?(path) -> Boolean
      def delete(path) -> void

      # Directory operations
      def list(path) -> Array<String>
      def mkdir(path, options = {}) -> void
      def rmdir(path) -> void

      # Metadata
      def metadata(path) -> Hash
        # Returns: { size:, modified_at:, content_type:, etag:, etc. }

      # Movement
      def copy(source, dest) -> void
      def move(source, dest) -> void

      # Optional (not all backends support)
      def symlink(source, dest) -> void
      def symlink?(path) -> Boolean
      def readlink(path) -> String

      # Backend capabilities
      def supports_symlinks? -> Boolean
      def supports_permissions? -> Boolean
      def supports_streaming? -> Boolean

      # Utility
      def normalize_path(path) -> String
      def uri_for(path) -> String  # e.g., "s3://bucket/key", "file:///path"
    end
  end
end
```

### 2. Backend Implementations

#### Local Filesystem (Default)

```ruby
module FSLayer
  module Backend
    class LocalFileSystem < Base
      def read(path)
        File.read(normalize_path(path))
      end

      def write(path, content, options = {})
        normalized = normalize_path(path)
        FileUtils.mkdir_p(File.dirname(normalized))
        File.write(normalized, content, **options)
      end

      def exists?(path)
        File.exist?(normalize_path(path))
      end

      def list(path)
        Dir.glob(File.join(normalize_path(path), '*'))
      end

      def metadata(path)
        stat = File.stat(normalize_path(path))
        {
          size: stat.size,
          modified_at: stat.mtime,
          accessed_at: stat.atime,
          mode: stat.mode,
          uid: stat.uid,
          gid: stat.gid
        }
      end

      def symlink(source, dest)
        File.symlink(normalize_path(source), normalize_path(dest))
      end

      def supports_symlinks?; true; end
      def supports_permissions?; true; end

      def uri_for(path)
        "file://#{File.expand_path(normalize_path(path))}"
      end
    end
  end
end
```

#### Memory Backend (Testing)

```ruby
module FSLayer
  module Backend
    class Memory < Base
      def initialize
        @files = {}  # path => content
        @metadata = {}  # path => metadata hash
        @symlinks = {}  # path => target
      end

      def read(path)
        raise FileNotFoundError unless exists?(path)
        follow_symlinks(path) { |p| @files[p] }
      end

      def write(path, content, options = {})
        @files[path] = content
        @metadata[path] = {
          size: content.bytesize,
          modified_at: Time.now,
          content_type: 'application/octet-stream'
        }
      end

      def exists?(path)
        @files.key?(path) || @symlinks.key?(path)
      end

      def list(path)
        pattern = "#{path.chomp('/')}/*"
        @files.keys.select { |k| File.fnmatch(pattern, k) }
      end

      def symlink(source, dest)
        @symlinks[dest] = source
      end

      def symlink?(path)
        @symlinks.key?(path)
      end

      # Easy to inspect for testing
      def dump
        { files: @files, symlinks: @symlinks, metadata: @metadata }
      end

      def clear
        @files.clear
        @metadata.clear
        @symlinks.clear
      end
    end
  end
end
```

#### S3 Backend

```ruby
module FSLayer
  module Backend
    class S3 < Base
      def initialize(bucket:, region: 'us-east-1', prefix: nil)
        require 'aws-sdk-s3'
        @bucket = bucket
        @prefix = prefix
        @client = Aws::S3::Client.new(region: region)
      end

      def read(path)
        @client.get_object(bucket: @bucket, key: s3_key(path)).body.read
      end

      def write(path, content, options = {})
        @client.put_object(
          bucket: @bucket,
          key: s3_key(path),
          body: content,
          **options
        )
      end

      def exists?(path)
        @client.head_object(bucket: @bucket, key: s3_key(path))
        true
      rescue Aws::S3::Errors::NotFound
        false
      end

      def list(path)
        prefix = s3_key(path).chomp('/') + '/'
        @client.list_objects_v2(bucket: @bucket, prefix: prefix)
          .contents.map(&:key)
      end

      def metadata(path)
        resp = @client.head_object(bucket: @bucket, key: s3_key(path))
        {
          size: resp.content_length,
          modified_at: resp.last_modified,
          content_type: resp.content_type,
          etag: resp.etag,
          storage_class: resp.storage_class
        }
      end

      def copy(source, dest)
        @client.copy_object(
          bucket: @bucket,
          copy_source: "#{@bucket}/#{s3_key(source)}",
          key: s3_key(dest)
        )
      end

      def supports_symlinks?; false; end
      def supports_permissions?; false; end

      def uri_for(path)
        "s3://#{@bucket}/#{s3_key(path)}"
      end

      private

      def s3_key(path)
        key = path.start_with?('/') ? path[1..-1] : path
        @prefix ? File.join(@prefix, key) : key
      end
    end
  end
end
```

### 3. Backend Registry & Configuration

```ruby
module FSLayer
  class << self
    attr_writer :backend

    def backend
      @backend ||= Backend::LocalFileSystem.new
    end

    def configure
      yield Configuration.new
    end
  end

  class Configuration
    def use_local_filesystem(root: '/')
      FSLayer.backend = Backend::LocalFileSystem.new(root: root)
    end

    def use_memory
      FSLayer.backend = Backend::Memory.new
    end

    def use_s3(bucket:, region: 'us-east-1', prefix: nil)
      FSLayer.backend = Backend::S3.new(
        bucket: bucket,
        region: region,
        prefix: prefix
      )
    end

    def use_gcs(bucket:, project:, prefix: nil)
      FSLayer.backend = Backend::GCS.new(
        bucket: bucket,
        project: project,
        prefix: prefix
      )
    end

    def use_custom(backend)
      raise ArgumentError unless backend.is_a?(Backend::Base)
      FSLayer.backend = backend
    end
  end
end
```

### 4. Updated API Layer

The public API stays almost the same, but delegates to backends:

```ruby
module FSLayer
  class << self
    def insert(path, content = '')
      log(:debug, "Inserting file: #{path}")
      backend.write(path, content)
      Index.organize(path, backend)
      File.new(path, backend)
    end

    def retrieve(path)
      File.new(path, backend)
    end

    def delete(path_or_file)
      path = path_or_file.is_a?(FSLayer::File) ? path_or_file.path : path_or_file
      backend.delete(path)
      Index.remove(path, backend)
    end

    def read(path)
      backend.read(path)
    end

    def write(path, content)
      backend.write(path, content)
      Index.organize(path, backend)
    end

    def exists?(path)
      backend.exists?(path)
    end

    def list(path)
      backend.list(path)
    end

    def copy(source, dest)
      backend.copy(source, dest)
      Index.organize(dest, backend)
    end

    def move(source, dest)
      backend.move(source, dest)
      Index.remove(source, backend)
      Index.organize(dest, backend)
    end

    # Backward compatibility
    def fake_it
      @previous_backend = backend
      self.backend = Backend::Memory.new
      log(:info, "Switched to memory backend (fake mode)")
    end

    def keep_it_real
      self.backend = @previous_backend || Backend::LocalFileSystem.new
      log(:info, "Switched back to real backend")
    end
  end
end
```

### 5. Updated File Object

```ruby
module FSLayer
  class File
    attr_reader :path, :backend

    def initialize(path, backend = FSLayer.backend)
      @path = path
      @backend = backend
    end

    def read
      backend.read(path)
    end

    def write(content)
      backend.write(path, content)
    end

    def exist?
      backend.exists?(path)
    end

    def delete
      FSLayer.delete(self)
    end

    def metadata
      backend.metadata(path)
    end

    def size
      metadata[:size]
    end

    def modified_at
      metadata[:modified_at]
    end

    def name
      ::File.basename(path)
    end

    def symlink?
      backend.symlink?(path) if backend.supports_symlinks?
    end

    def destination
      return nil unless symlink?
      backend.readlink(path)
    end

    def uri
      backend.uri_for(path)
    end
  end
end
```

### 6. Multi-Backend Index

The index now tracks files per-backend:

```ruby
module FSLayer
  class Index
    @indices = {}  # backend => Set of paths

    def self.organize(path, backend = FSLayer.backend)
      @indices[backend] ||= Set.new
      @indices[backend] << path
    end

    def self.remove(path, backend = FSLayer.backend)
      @indices[backend]&.delete(path)
    end

    def self.known_files(backend = FSLayer.backend)
      (@indices[backend] || Set.new).to_a
    end

    def self.clear(backend = nil)
      if backend
        @indices[backend]&.clear
      else
        @indices.clear
      end
    end
  end
end
```

## Usage Examples

### Local Filesystem (Default)

```ruby
# Works exactly as before
FSLayer.insert('/tmp/test.txt')
file = FSLayer.retrieve('/tmp/test.txt')
file.exist? # => true
```

### Memory Backend (Testing)

```ruby
# In tests
FSLayer.configure do |config|
  config.use_memory
end

# Or use the familiar API
FSLayer.fake_it  # Now uses real Memory backend

file = FSLayer.insert('/tmp/test.txt', 'content')
FSLayer.read('/tmp/test.txt')  # => 'content'
file.exist?  # => true (in memory)

# Inspect state
FSLayer.backend.dump  # => { files: {'/tmp/test.txt' => 'content'}, ... }
```

### S3 Backend

```ruby
FSLayer.configure do |config|
  config.use_s3(
    bucket: 'my-app-files',
    region: 'us-west-2',
    prefix: 'uploads'
  )
end

file = FSLayer.insert('documents/report.pdf', pdf_content)
file.uri  # => 's3://my-app-files/uploads/documents/report.pdf'
file.size  # => 1024
file.metadata  # => { size:, modified_at:, etag:, storage_class: }

# Same API, different storage
FSLayer.list('documents/')  # Lists S3 objects
FSLayer.copy('documents/report.pdf', 'documents/report-backup.pdf')
```

### Multiple Backends Simultaneously

```ruby
# Use different backends for different purposes
local = FSLayer::Backend::LocalFileSystem.new
s3 = FSLayer::Backend::S3.new(bucket: 'backups')

# Read locally, backup to S3
content = local.read('/var/log/app.log')
s3.write('logs/app.log', content)

# Or configure dynamically
FSLayer.backend = local
local_file = FSLayer.insert('/tmp/local.txt')

FSLayer.backend = s3
s3_file = FSLayer.insert('remote.txt')
```

### Custom Backend

```ruby
class RedisBackend < FSLayer::Backend::Base
  def initialize(redis_url)
    @redis = Redis.new(url: redis_url)
  end

  def read(path)
    @redis.get(path) || raise(FSLayer::FileNotFoundError)
  end

  def write(path, content, options = {})
    ttl = options[:ttl]
    if ttl
      @redis.setex(path, ttl, content)
    else
      @redis.set(path, content)
    end
  end

  def exists?(path)
    @redis.exists?(path)
  end

  # ... implement other methods
end

# Use it
FSLayer.configure do |config|
  config.use_custom(RedisBackend.new('redis://localhost:6379'))
end
```

## Migration Path

### Phase 1: Add Backend Layer (Backward Compatible)
- Create Backend::Base interface
- Implement Backend::LocalFileSystem (wraps current behavior)
- Implement Backend::Memory (replaces fake mode)
- Keep all existing API methods working

### Phase 2: Deprecate Direct File Operations
- Add deprecation warnings to methods that bypass backends
- Update documentation

### Phase 3: Add Cloud Backends
- Implement S3, GCS backends
- Add optional dependencies (aws-sdk-s3, google-cloud-storage)

### Phase 4: Clean Up
- Remove deprecated methods
- Finalize backend interface

## Benefits

1. **Testability**: Memory backend is a full implementation, easier to test than skip-mode
2. **Flexibility**: Swap storage without changing application code
3. **Cloud Native**: First-class support for S3, GCS
4. **Mockability**: Each backend can be mocked independently
5. **Backend Composition**: Mix backends (e.g., local cache + S3)
6. **Clear Contracts**: Backend interface documents all capabilities
7. **Backward Compatible**: Existing API continues to work

## Trade-offs

### Pros
- **Storage agnostic**: One API for all storage types
- **Better testing**: Memory backend > fake mode
- **Extensible**: Easy to add new backends
- **Type safety**: Clear interface contract

### Cons
- **Complexity**: More classes and abstractions
- **Lowest common denominator**: API limited to features all backends support
- **Performance**: Extra indirection layer
- **Dependencies**: Cloud backends require SDK gems

## Recommendations

1. **Start with Memory backend**: Replace `fake_it` with a real Memory implementation
2. **Extract Backend::LocalFileSystem**: Move current logic to a backend class
3. **Keep API stable**: Don't break existing users
4. **Make backends optional**: Cloud SDKs should be optional dependencies
5. **Document capabilities**: Clear docs on what each backend supports
6. **Add middleware layer**: For cross-cutting concerns (caching, logging, metrics)

## Questions to Consider

1. Should backends be stateful (configured once) or stateless (pass options per-call)?
2. How to handle streaming for large files (S3 multipart, etc.)?
3. Should we support backend composition (e.g., caching layer over S3)?
4. How to handle backend-specific options (S3 storage class, GCS ACLs)?
5. Should File objects be tied to a specific backend or dynamically resolve?
6. How to handle transactions/atomicity across backends?
