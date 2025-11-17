# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive error handling with custom exception classes (`InvalidPathError`, `FileNotFoundError`, `SymlinkError`, `PermissionError`)
- `FSLayer.retrieve` method to get a File object for a given path
- `FSLayer.delete` method to remove files from filesystem and index
- `FSLayer::Index.remove` method to remove files from the index
- `FSLayer::Index.clear` method to clear all tracked files
- Path validation for nil, empty, and null byte inputs
- Error handling for permission issues, missing parent directories, and broken symlinks
- Comprehensive API documentation in README
- Code coverage tracking with SimpleCov (>90% coverage)
- GitHub Actions CI/CD pipeline
- Test coverage for error conditions
- Support for Ruby 2.7+ explicitly declared

### Changed
- Updated to modern RSpec 3.x syntax (`expect` instead of `should`)
- Updated test suite to use `be true`/`be false` instead of deprecated `be_true`/`be_false`
- Fixed deprecated `File.exists?` to `File.exist?` for Ruby 3.3+ compatibility
- Improved README with comprehensive usage examples and API reference
- Enhanced gemspec with metadata (homepage, source code URI, bug tracker, changelog)
- Added MIT license specification to gemspec
- Improved Index class with `remove` and `clear` methods

### Fixed
- Compatibility with Ruby 3.3+ (removed deprecated method calls)
- Test suite compatibility with modern RSpec
- Missing `require 'pathname'` in File class
- Symlink operations now properly validate inputs
- File operations now handle edge cases and provide meaningful error messages

## [0.0.2] - 2012-XX-XX

### Changed
- Version bump (legacy release)

## [0.0.1] - 2012-XX-XX

### Added
- Initial release
- Basic file operations (insert)
- Symlink support
- Fake mode for testing
- File indexing

[Unreleased]: https://github.com/Trevoke/fs_layer/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/Trevoke/fs_layer/releases/tag/v0.0.2
[0.0.1]: https://github.com/Trevoke/fs_layer/releases/tag/v0.0.1
