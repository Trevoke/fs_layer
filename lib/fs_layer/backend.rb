module FSLayer
  module Backend
    # Base interface for all storage backends.
    # All backends must implement these methods.
    class Base
      # === Core File Operations ===

      # Read entire file content
      # @param path [String] the file path
      # @param options [Hash] backend-specific options
      # @return [String] file content
      # @raise [FileNotFoundError] if file doesn't exist
      # @raise [PermissionError] if access denied
      def read(path, **options)
        raise NotImplementedError, "#{self.class}#read must be implemented"
      end

      # Write content to file (overwrites existing)
      # @param path [String] the file path
      # @param content [String] content to write
      # @param options [Hash] backend-specific options
      #   Common options:
      #     - mode: file permissions (local filesystem)
      #     - content_type: MIME type (S3, GCS)
      #     - metadata: custom metadata hash (S3, GCS)
      #     - ttl: time to live in seconds (Redis, Memory)
      #     - storage_class: storage tier (S3, GCS)
      # @return [void]
      # @raise [InvalidPathError] if path is invalid
      # @raise [PermissionError] if access denied
      def write(path, content, **options)
        raise NotImplementedError, "#{self.class}#write must be implemented"
      end

      # Check if file/directory exists
      # @param path [String] the file path
      # @return [Boolean] true if exists
      def exists?(path)
        raise NotImplementedError, "#{self.class}#exists? must be implemented"
      end

      # Delete a file
      # @param path [String] the file path
      # @param options [Hash] backend-specific options
      # @return [void]
      # @raise [FileNotFoundError] if file doesn't exist
      # @raise [PermissionError] if access denied
      def delete(path, **options)
        raise NotImplementedError, "#{self.class}#delete must be implemented"
      end

      # === Streaming Operations ===

      # Open file for streaming read
      # @param path [String] the file path
      # @param options [Hash] backend-specific options
      # @yield [IO] an IO-like object for reading
      # @return [Object] result of the block
      # @raise [NotSupportedError] if streaming not supported
      def open_read(path, **options, &block)
        raise NotSupportedError, "#{self.class} does not support streaming reads"
      end

      # Open file for streaming write
      # @param path [String] the file path
      # @param options [Hash] backend-specific options
      # @yield [IO] an IO-like object for writing
      # @return [Object] result of the block
      # @raise [NotSupportedError] if streaming not supported
      def open_write(path, **options, &block)
        raise NotSupportedError, "#{self.class} does not support streaming writes"
      end

      # === Directory Operations ===

      # List files/directories at path
      # @param path [String] the directory path
      # @param options [Hash] backend-specific options
      #   Common options:
      #     - recursive: list recursively (default false)
      #     - pattern: glob pattern to filter
      # @return [Array<String>] array of paths
      def list(path, **options)
        raise NotImplementedError, "#{self.class}#list must be implemented"
      end

      # Create a directory
      # @param path [String] the directory path
      # @param options [Hash] backend-specific options
      #   Common options:
      #     - parents: create parent directories (default true)
      # @return [void]
      def mkdir(path, **options)
        raise NotImplementedError, "#{self.class}#mkdir must be implemented"
      end

      # Remove a directory
      # @param path [String] the directory path
      # @param options [Hash] backend-specific options
      #   Common options:
      #     - recursive: remove recursively (default false)
      # @return [void]
      def rmdir(path, **options)
        raise NotImplementedError, "#{self.class}#rmdir must be implemented"
      end

      # === Metadata Operations ===

      # Get file metadata
      # @param path [String] the file path
      # @return [Hash] metadata hash with symbolized keys
      #   Common keys (backend-dependent):
      #     - :size - file size in bytes
      #     - :modified_at - last modification time
      #     - :created_at - creation time
      #     - :accessed_at - last access time
      #     - :content_type - MIME type
      #     - :etag - entity tag / checksum
      #     - :mode - file permissions (octal)
      #     - :uid - user ID (Unix)
      #     - :gid - group ID (Unix)
      #     - :storage_class - storage tier (S3, GCS)
      #     - :metadata - custom metadata (S3, GCS)
      # @raise [FileNotFoundError] if file doesn't exist
      def metadata(path)
        raise NotImplementedError, "#{self.class}#metadata must be implemented"
      end

      # === Movement Operations ===

      # Copy file from source to destination
      # @param source [String] source path
      # @param dest [String] destination path
      # @param options [Hash] backend-specific options
      # @return [void]
      def copy(source, dest, **options)
        # Default implementation: read and write
        content = read(source)
        write(dest, content, **options)
      end

      # Move/rename file from source to destination
      # @param source [String] source path
      # @param dest [String] destination path
      # @param options [Hash] backend-specific options
      # @return [void]
      def move(source, dest, **options)
        # Default implementation: copy and delete
        copy(source, dest, **options)
        delete(source)
      end

      # === Symlink Operations ===

      # Create a symbolic link
      # @param source [String] target path
      # @param dest [String] symlink path
      # @param options [Hash] backend-specific options
      # @return [void]
      # @raise [NotSupportedError] if symlinks not supported
      def symlink(source, dest, **options)
        raise NotSupportedError, "#{self.class} does not support symlinks"
      end

      # Check if path is a symlink
      # @param path [String] the file path
      # @return [Boolean] true if symlink
      # @raise [NotSupportedError] if symlinks not supported
      def symlink?(path)
        raise NotSupportedError, "#{self.class} does not support symlinks"
      end

      # Read symlink target
      # @param path [String] the symlink path
      # @return [String] target path
      # @raise [NotSupportedError] if symlinks not supported
      # @raise [SymlinkError] if not a symlink
      def readlink(path)
        raise NotSupportedError, "#{self.class} does not support symlinks"
      end

      # === Capability Negotiation ===

      # Check if backend supports symlinks
      # @return [Boolean]
      def supports_symlinks?
        false
      end

      # Check if backend supports file permissions
      # @return [Boolean]
      def supports_permissions?
        false
      end

      # Check if backend supports streaming operations
      # @return [Boolean]
      def supports_streaming?
        false
      end

      # Check if backend supports atomic operations
      # @return [Boolean]
      def supports_atomic_writes?
        false
      end

      # Check if backend supports custom metadata
      # @return [Boolean]
      def supports_metadata?
        false
      end

      # === Utility Methods ===

      # Normalize path for this backend
      # @param path [String] the path
      # @return [String] normalized path
      def normalize_path(path)
        path.to_s
      end

      # Get URI for path in this backend
      # @param path [String] the path
      # @return [String] URI (e.g., "file:///path", "s3://bucket/key")
      def uri_for(path)
        raise NotImplementedError, "#{self.class}#uri_for must be implemented"
      end

      protected

      # Helper to translate backend-specific errors to FSLayer errors
      # @param error_map [Hash] mapping of error classes to FSLayer errors
      # @yield block to execute
      # @return [Object] result of block
      def translate_errors(error_map = {})
        yield
      rescue => e
        mapped_error = error_map[e.class]
        if mapped_error
          raise mapped_error, e.message
        else
          raise
        end
      end
    end
  end
end
