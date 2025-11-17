require 'fileutils'
require 'pathname'

module FSLayer
  module Backend
    # Local filesystem backend implementation
    # Supports all features including symlinks, permissions, and streaming
    class LocalFileSystem < Base
      # Error translation map for errno exceptions
      ERROR_MAP = {
        Errno::ENOENT => FileNotFoundError,
        Errno::EACCES => PermissionError,
        Errno::EPERM => PermissionError,
        Errno::ELOOP => SymlinkError
      }.freeze

      def initialize(root: nil)
        @root = root
      end

      # === Core Operations ===

      def read(path, **options)
        translate_errors do
          ::File.read(resolve_path(path), **options)
        end
      end

      def write(path, content, **options)
        resolved = resolve_path(path)
        translate_errors do
          # Create parent directory if needed
          FileUtils.mkdir_p(::File.dirname(resolved))
          ::File.write(resolved, content, **options)
        end
      rescue Errno::ENOENT => e
        raise InvalidPathError, "Invalid path or parent directory doesn't exist: #{path}"
      end

      def exists?(path)
        ::File.exist?(resolve_path(path))
      end

      def delete(path, **options)
        resolved = resolve_path(path)
        translate_errors do
          if ::File.directory?(resolved)
            if options[:recursive]
              FileUtils.rm_rf(resolved)
            else
              Dir.rmdir(resolved)
            end
          else
            ::File.delete(resolved)
          end
        end
      rescue Errno::ENOTEMPTY => e
        raise Error, "Directory not empty: #{path}. Use recursive: true to delete."
      end

      # === Streaming Operations ===

      def open_read(path, **options)
        resolved = resolve_path(path)
        translate_errors do
          ::File.open(resolved, 'rb', **options) do |file|
            yield file
          end
        end
      end

      def open_write(path, **options)
        resolved = resolve_path(path)
        translate_errors do
          FileUtils.mkdir_p(::File.dirname(resolved))
          ::File.open(resolved, 'wb', **options) do |file|
            yield file
          end
        end
      rescue Errno::ENOENT => e
        raise InvalidPathError, "Invalid path or parent directory doesn't exist: #{path}"
      end

      # === Directory Operations ===

      def list(path, **options)
        resolved = resolve_path(path)
        pattern = options[:pattern] || '*'
        recursive = options[:recursive] || false

        search_pattern = if recursive
          ::File.join(resolved, '**', pattern)
        else
          ::File.join(resolved, pattern)
        end

        translate_errors do
          Dir.glob(search_pattern).map { |p| unresolve_path(p) }
        end
      end

      def mkdir(path, **options)
        resolved = resolve_path(path)
        parents = options.fetch(:parents, true)

        translate_errors do
          if parents
            FileUtils.mkdir_p(resolved)
          else
            Dir.mkdir(resolved)
          end
        end
      rescue Errno::EEXIST => e
        raise Error, "Directory already exists: #{path}"
      end

      def rmdir(path, **options)
        resolved = resolve_path(path)
        recursive = options[:recursive] || false

        translate_errors do
          if recursive
            FileUtils.rm_rf(resolved)
          else
            Dir.rmdir(resolved)
          end
        end
      rescue Errno::ENOTEMPTY => e
        raise Error, "Directory not empty: #{path}. Use recursive: true to delete."
      end

      # === Metadata Operations ===

      def metadata(path)
        resolved = resolve_path(path)
        translate_errors do
          stat = ::File.stat(resolved)
          {
            size: stat.size,
            modified_at: stat.mtime,
            accessed_at: stat.atime,
            created_at: stat.ctime,
            mode: stat.mode,
            uid: stat.uid,
            gid: stat.gid,
            directory: stat.directory?,
            file: stat.file?,
            symlink: ::File.symlink?(resolved)
          }
        end
      end

      # === Movement Operations ===

      def copy(source, dest, **options)
        src_resolved = resolve_path(source)
        dest_resolved = resolve_path(dest)

        translate_errors do
          FileUtils.mkdir_p(::File.dirname(dest_resolved))
          FileUtils.cp(src_resolved, dest_resolved)
        end
      rescue Errno::ENOENT => e
        if !::File.exist?(src_resolved)
          raise FileNotFoundError, "Source file not found: #{source}"
        else
          raise InvalidPathError, "Invalid destination path: #{dest}"
        end
      end

      def move(source, dest, **options)
        src_resolved = resolve_path(source)
        dest_resolved = resolve_path(dest)

        translate_errors do
          FileUtils.mkdir_p(::File.dirname(dest_resolved))
          FileUtils.mv(src_resolved, dest_resolved)
        end
      rescue Errno::ENOENT => e
        if !::File.exist?(src_resolved)
          raise FileNotFoundError, "Source file not found: #{source}"
        else
          raise InvalidPathError, "Invalid destination path: #{dest}"
        end
      end

      # === Symlink Operations ===

      def symlink(source, dest, **options)
        src_resolved = resolve_path(source)
        dest_resolved = resolve_path(dest)

        translate_errors do
          ::File.symlink(src_resolved, dest_resolved)
        end
      rescue Errno::EEXIST => e
        raise SymlinkError, "Symlink destination already exists: #{dest}"
      rescue Errno::ENOENT => e
        raise InvalidPathError, "Parent directory doesn't exist: #{dest}"
      end

      def symlink?(path)
        ::File.symlink?(resolve_path(path))
      end

      def readlink(path)
        resolved = resolve_path(path)

        unless ::File.symlink?(resolved)
          raise SymlinkError, "File is not a symlink: #{path}"
        end

        translate_errors do
          target = Pathname.new(resolved).realpath.to_s
          unresolve_path(target)
        end
      rescue Errno::ENOENT => e
        raise SymlinkError, "Broken symlink: #{path}"
      rescue Errno::ELOOP => e
        raise SymlinkError, "Circular symlink detected: #{path}"
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

      def supports_atomic_writes?
        true
      end

      # === Utility ===

      def normalize_path(path)
        return path unless @root
        # Remove root prefix if present
        path.to_s.sub(/^#{Regexp.escape(@root)}/, '')
      end

      def uri_for(path)
        "file://#{::File.expand_path(resolve_path(path))}"
      end

      private

      # Resolve path relative to root if configured
      def resolve_path(path)
        return path.to_s unless @root
        ::File.join(@root, path.to_s)
      end

      # Remove root from path for external representation
      def unresolve_path(path)
        return path unless @root
        path.sub(/^#{Regexp.escape(@root)}/, '')
      end

      # Translate common errno exceptions to FSLayer exceptions
      def translate_errors
        yield
      rescue => e
        mapped_error = ERROR_MAP[e.class]
        if mapped_error
          raise mapped_error, e.message
        else
          raise
        end
      end
    end
  end
end
