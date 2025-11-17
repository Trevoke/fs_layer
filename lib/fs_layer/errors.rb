module FSLayer
  class Error < StandardError; end
  class FileNotFoundError < Error; end
  class InvalidPathError < Error; end
  class SymlinkError < Error; end
  class PermissionError < Error; end
  class NotSupportedError < Error; end
end
