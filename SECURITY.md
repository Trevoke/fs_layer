# Security Policy

## Supported Versions

Currently supported versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in FSLayer, please report it by:

1. **DO NOT** open a public GitHub issue
2. Email security concerns to: trevoke@gmail.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

You can expect:
- Acknowledgment within 48 hours
- Status update within 7 days
- Fix and disclosure timeline based on severity

## Security Considerations

### Path Validation

FSLayer performs comprehensive path validation to prevent security issues:

- **Null byte injection**: Paths containing null bytes (`\0`) are rejected
- **Empty paths**: Empty or whitespace-only paths are rejected
- **Nil values**: Nil paths are rejected with clear error messages

### File Operations

All file operations include:

- **Permission checking**: Operations fail gracefully with `PermissionError` when permissions are insufficient
- **Parent directory validation**: File creation validates parent directory existence
- **Symlink safety**: Circular symlinks and broken symlinks are detected and reported

### No Shell Command Injection

FSLayer uses Ruby's built-in `FileUtils` and `File` classes exclusively. It does **not**:
- Execute shell commands
- Use `system()`, `exec()`, or backticks
- Invoke external binaries

This eliminates command injection vulnerabilities.

### Path Traversal

While FSLayer validates path format, it does **not** restrict path traversal (e.g., `../`). This is intentional, as FSLayer is designed as a low-level file abstraction layer.

**Application developers** should:
- Validate and sanitize user-provided paths before passing to FSLayer
- Use absolute paths or resolve paths relative to a known safe directory
- Implement application-level access controls

Example safe usage:

```ruby
# DON'T: Accept user input directly
file_path = params[:file_path]
FSLayer.insert file_path  # UNSAFE

# DO: Validate and constrain paths
base_dir = '/var/app/uploads'
filename = File.basename(params[:filename])  # Remove directory components
file_path = File.join(base_dir, filename)
FSLayer.insert file_path  # SAFE
```

### Symlink Attacks

FSLayer does not prevent Time-of-Check-Time-of-Use (TOCTOU) symlink attacks. If your application operates in an environment where:

- Multiple users can write to the same directories
- Attackers might replace files with symlinks between checks

Then implement application-level locking or use atomic operations.

### Denial of Service

The Index class stores all tracked files in memory. In adversarial environments:

- **Unbounded growth**: An attacker creating many files could exhaust memory
- **Mitigation**: Use `FSLayer::Index.clear` periodically, or use `FSLayer.delete` to remove files you no longer need to track
- **Rate limiting**: Implement application-level rate limiting on file creation

### Logging Considerations

FSLayer logs file paths at various log levels. In production:

- Ensure logs are not publicly accessible
- Be aware that file paths may contain sensitive information
- Configure appropriate log retention and rotation
- Use secure log aggregation services

### Dependency Security

FSLayer has minimal dependencies. To check for vulnerabilities:

```bash
bundle audit check --update
```

## Best Practices

1. **Input Validation**: Always validate user input before passing paths to FSLayer
2. **Principle of Least Privilege**: Run applications using FSLayer with minimal required permissions
3. **Audit Logging**: Enable logging in production for security monitoring
4. **Regular Updates**: Keep FSLayer and Ruby updated to receive security patches
5. **Code Review**: Review all file operations for security implications

## Security Features

FSLayer includes several security features:

- Comprehensive error handling prevents information disclosure
- Path validation prevents common injection attacks
- No dynamic code evaluation or shell command execution
- Clear separation between test mode (fake) and production mode
- Detailed logging for security auditing

## Changelog

Security-related changes are documented in [CHANGELOG.md](CHANGELOG.md) with a `[SECURITY]` prefix.
