require 'stringio'
require 'pathname'

module FSLayer
  module Backend
    # In-memory backend for testing
    # Fully functional implementation that mimics filesystem behavior without disk I/O
    class Memory < Base
      def initialize
        @files = {}       # path => content (String)
        @metadata = {}    # path => metadata (Hash)
        @symlinks = {}    # path => target (String)
        @directories = {} # path => true

        # Initialize root directory
        @directories['/'] = true
      end

      # === Core Operations ===

      def read(path, **options)
        normalized = normalize_path(path)

        unless exists?(normalized)
          raise FileNotFoundError, "File not found: #{path}"
        end

        # Follow symlinks
        if symlink?(normalized)
          target = follow_symlink(normalized)
          return read(target, **options)
        end

        if @directories[normalized]
          raise Error, "Is a directory: #{path}"
        end

        @files[normalized]
      end

      def write(path, content, **options)
        normalized = normalize_path(path)

        # Create parent directories
        parent = parent_path(normalized)
        ensure_parent_exists(parent) if parent != normalized

        # Can't write to directory
        if @directories[normalized]
          raise Error, "Is a directory: #{path}"
        end

        @files[normalized] = content
        @metadata[normalized] = {
          size: content.bytesize,
          modified_at: Time.now,
          created_at: @metadata[normalized]&.[](:created_at) || Time.now,
          accessed_at: Time.now,
          content_type: options[:content_type] || 'application/octet-stream',
          mode: options[:mode] || 0644,
          custom: options[:metadata] || {}
        }

        # Remove from directories if it was one
        @directories.delete(normalized)
      end

      def exists?(path)
        normalized = normalize_path(path)
        @files.key?(normalized) || @directories.key?(normalized) || @symlinks.key?(normalized)
      end

      def delete(path, **options)
        normalized = normalize_path(path)

        unless exists?(normalized)
          raise FileNotFoundError, "File not found: #{path}"
        end

        if @directories[normalized]
          # Check if directory is empty
          unless directory_empty?(normalized) || options[:recursive]
            raise Error, "Directory not empty: #{path}. Use recursive: true to delete."
          end

          if options[:recursive]
            # Delete all children
            delete_children(normalized)
          end

          @directories.delete(normalized)
        else
          @files.delete(normalized)
          @metadata.delete(normalized)
          @symlinks.delete(normalized)
        end
      end

      # === Streaming Operations ===

      def open_read(path, **options)
        content = read(path, **options)
        io = StringIO.new(content)

        if block_given?
          begin
            yield io
          ensure
            io.close
          end
        else
          io
        end
      end

      def open_write(path, **options)
        io = StringIO.new

        if block_given?
          begin
            yield io
            write(path, io.string, **options)
          ensure
            io.close
          end
        else
          # Return an IO-like object that writes on close
          WriteProxy.new(self, path, io, options)
        end
      end

      # === Directory Operations ===

      def list(path, **options)
        normalized = normalize_path(path)

        unless exists?(normalized)
          raise FileNotFoundError, "Directory not found: #{path}"
        end

        unless @directories[normalized]
          raise Error, "Not a directory: #{path}"
        end

        pattern = options[:pattern] || '*'
        recursive = options[:recursive] || false

        prefix = normalized == '/' ? '/' : "#{normalized}/"
        results = []

        all_paths = @files.keys + @directories.keys + @symlinks.keys

        all_paths.each do |p|
          next unless p.start_with?(prefix)

          relative = p[prefix.length..-1]
          next if relative.empty?

          if recursive
            results << p if ::File.fnmatch(pattern, ::File.basename(p))
          else
            # Only direct children
            next if relative.include?('/')
            results << p if ::File.fnmatch(pattern, relative)
          end
        end

        results.sort
      end

      def mkdir(path, **options)
        normalized = normalize_path(path)
        parents = options.fetch(:parents, true)

        if exists?(normalized)
          raise Error, "Path already exists: #{path}"
        end

        parent = parent_path(normalized)

        if parent != normalized && !@directories[parent]
          if parents
            mkdir(parent, parents: true)
          else
            raise Error, "Parent directory doesn't exist: #{parent}"
          end
        end

        @directories[normalized] = true
      end

      def rmdir(path, **options)
        delete(path, **options)
      end

      # === Metadata Operations ===

      def metadata(path)
        normalized = normalize_path(path)

        unless exists?(normalized)
          raise FileNotFoundError, "File not found: #{path}"
        end

        # Follow symlinks for metadata
        if symlink?(normalized)
          target = follow_symlink(normalized)
          return metadata(target)
        end

        if @directories[normalized]
          {
            size: 0,
            modified_at: Time.now,
            created_at: Time.now,
            directory: true,
            file: false,
            symlink: false
          }
        else
          meta = @metadata[normalized] || {}
          meta.merge(
            directory: false,
            file: true,
            symlink: false
          )
        end
      end

      # === Movement Operations ===

      def copy(source, dest, **options)
        src_normalized = normalize_path(source)
        dest_normalized = normalize_path(dest)

        unless exists?(src_normalized)
          raise FileNotFoundError, "Source file not found: #{source}"
        end

        if @directories[src_normalized]
          raise Error, "Cannot copy directory: #{source}"
        end

        # Ensure parent exists
        parent = parent_path(dest_normalized)
        ensure_parent_exists(parent) if parent != dest_normalized

        content = read(source)
        write(dest, content, **options)
      end

      def move(source, dest, **options)
        copy(source, dest, **options)
        delete(source)
      end

      # === Symlink Operations ===

      def symlink(source, dest, **options)
        src_normalized = normalize_path(source)
        dest_normalized = normalize_path(dest)

        if exists?(dest_normalized)
          raise SymlinkError, "Symlink destination already exists: #{dest}"
        end

        # Ensure parent exists
        parent = parent_path(dest_normalized)
        unless @directories[parent]
          raise InvalidPathError, "Parent directory doesn't exist: #{dest}"
        end

        @symlinks[dest_normalized] = src_normalized
      end

      def symlink?(path)
        normalized = normalize_path(path)
        @symlinks.key?(normalized)
      end

      def readlink(path)
        normalized = normalize_path(path)

        unless symlink?(normalized)
          raise SymlinkError, "File is not a symlink: #{path}"
        end

        target = @symlinks[normalized]

        # Check for broken symlinks
        unless exists?(target)
          raise SymlinkError, "Broken symlink: #{path}"
        end

        # Detect circular symlinks
        begin
          follow_symlink(normalized, max_depth: 40)
        rescue Error => e
          raise SymlinkError, "Circular symlink detected: #{path}"
        end

        target
      end

      # === Capabilities ===

      def supports_symlinks?
        true
      end

      def supports_permissions?
        true
      end

      def supports_streaming?
        true
      end

      def supports_metadata?
        true
      end

      # === Utility ===

      def normalize_path(path)
        # Normalize to absolute path
        p = Pathname.new(path.to_s).cleanpath.to_s
        p == '.' ? '/' : p
      end

      def uri_for(path)
        "memory://#{normalize_path(path)}"
      end

      # === Testing Helpers ===

      # Inspect internal state (useful for testing)
      def dump
        {
          files: @files.dup,
          directories: @directories.keys,
          symlinks: @symlinks.dup,
          metadata: @metadata.dup
        }
      end

      # Clear all data
      def clear
        @files.clear
        @metadata.clear
        @symlinks.clear
        @directories.clear

        # Re-create root directory
        @directories['/'] = true
      end

      # Get statistics
      def stats
        {
          file_count: @files.size,
          directory_count: @directories.size,
          symlink_count: @symlinks.size,
          total_size: @files.values.sum(&:bytesize)
        }
      end

      private

      # Follow symlink to final target
      def follow_symlink(path, visited: Set.new, max_depth: 40)
        if visited.include?(path) || visited.size > max_depth
          raise Error, "Circular symlink or max depth exceeded"
        end

        if @symlinks[path]
          visited << path
          follow_symlink(@symlinks[path], visited: visited, max_depth: max_depth)
        else
          path
        end
      end

      # Get parent directory path
      def parent_path(path)
        return '/' if path == '/'
        Pathname.new(path).parent.to_s
      end

      # Ensure parent directory exists, create if not
      def ensure_parent_exists(parent)
        return if parent == '/'

        unless @directories[parent]
          parent_of_parent = parent_path(parent)
          ensure_parent_exists(parent_of_parent) if parent_of_parent != parent
          @directories[parent] = true
        end
      end

      # Check if directory is empty
      def directory_empty?(path)
        prefix = path == '/' ? '/' : "#{path}/"
        all_paths = @files.keys + @directories.keys + @symlinks.keys

        !all_paths.any? { |p| p.start_with?(prefix) && p != path }
      end

      # Delete all children of a directory
      def delete_children(path)
        prefix = path == '/' ? '/' : "#{path}/"

        [@files, @directories, @symlinks, @metadata].each do |hash|
          hash.keys.each do |p|
            if p.start_with?(prefix) && p != path
              hash.delete(p)
            end
          end
        end
      end

      # Proxy class for non-block streaming writes
      class WriteProxy
        def initialize(backend, path, io, options)
          @backend = backend
          @path = path
          @io = io
          @options = options
        end

        def write(data)
          @io.write(data)
        end

        def puts(data)
          @io.puts(data)
        end

        def print(data)
          @io.print(data)
        end

        def <<(data)
          @io << data
          self
        end

        def close
          @backend.write(@path, @io.string, **@options)
          @io.close
        end

        def closed?
          @io.closed?
        end
      end
    end
  end
end
