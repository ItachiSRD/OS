# Linting Setup for OS Development

This project includes comprehensive linting support for assembly (.asm), C (.c), and C++ (.cpp) files to maintain code quality and catch potential issues early.

## Available Linters

### Assembly Files (.asm, .s)
- **Custom Assembly Linter** (`scripts/asm_linter.py`)
  - Checks for common style issues and potential problems
  - Validates boot sector structure and signatures
  - Warns about potentially dangerous instructions
  - Enforces consistent formatting

### C Files (.c)
- **cppcheck** - Static analysis for bugs and undefined behavior
- **cpplint** - Google C++ style guide compliance
- **clang-tidy** - Comprehensive static analysis and modernization

### C++ Files (.cpp, .cc, .cxx)
- **cppcheck** - Static analysis for bugs and undefined behavior  
- **cpplint** - Google C++ style guide compliance
- **clang-tidy** - Comprehensive static analysis and modernization

## Installation

### macOS (using Homebrew)
```bash
# Install system tools
brew install llvm cppcheck

# Install Python tools (recommended: use pipx for isolation)
brew install pipx
pipx install cpplint

# Alternative: use pip with virtual environment
python3 -m venv venv
source venv/bin/activate
pip install cpplint
```

### Linux (Ubuntu/Debian)
```bash
# Install system packages
sudo apt update
sudo apt install clang-tidy cppcheck clang-format

# Install Python tools
pip3 install --user cpplint
# or use pipx for isolation
sudo apt install pipx
pipx install cpplint
```

### Linux (Fedora/RHEL)
```bash
# Install system packages
sudo dnf install clang-tools-extra cppcheck clang

# Install Python tools
pip3 install --user cpplint
# or use pipx for isolation
sudo dnf install pipx
pipx install cpplint
```

## Usage

### Quick Start
```bash
# Lint all files
make lint

# Lint specific file types
make lint-asm    # Assembly files only
make lint-c      # C files only  
make lint-cpp    # C++ files only
```

### Individual Tools
```bash
# Assembly linter
python3 scripts/asm_linter.py src/main.asm

# C/C++ tools (when installed)
cppcheck --config-file=.cppcheck src/kernel.c
cpplint src/kernel.c
clang-tidy src/kernel.c -- -std=c99

clang-tidy src/memory.cpp -- -std=c++17
```

## Configuration Files

### `.clang-tidy`
- Configures clang-tidy checks and options
- Tailored for systems programming (allows low-level operations)
- Enforces naming conventions and code quality standards

### `.clang-format`
- Code formatting rules for C/C++
- Based on LLVM style with modifications for OS development
- 100 column limit, 4-space indentation

### `.cppcheck`
- Cppcheck configuration
- Suppresses warnings common in systems programming
- Enables comprehensive static analysis

### `CPPLINT.cfg`
- cpplint configuration
- Relaxes some Google style guide rules for OS development
- 100 character line limit

### `scripts/asm_linter.py`
- Custom assembly linter implementation
- Extensible Python script for assembly-specific checks
- Configurable rules and warnings

## Integration

### Pre-commit Hooks
Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
make lint-all
if [ $? -ne 0 ]; then
    echo "Linting failed. Please fix issues before committing."
    exit 1
fi
```

### CI/CD Integration
Add to your CI pipeline:
```yaml
- name: Run Linters
  run: make lint-all
```

### Editor Integration

#### VS Code
Install extensions:
- C/C++ (Microsoft)
- clang-tidy
- Cppcheck

#### Vim/Neovim
Use with ALE (Asynchronous Lint Engine):
```vim
let g:ale_linters = {
\   'c': ['cppcheck', 'clang-tidy', 'cpplint'],
\   'cpp': ['cppcheck', 'clang-tidy', 'cpplint'],
\   'asm': ['custom_asm_linter']
\}
```

## Customization

### Adding New Rules
1. **Assembly**: Edit `scripts/asm_linter.py`
2. **C/C++**: Modify configuration files (`.clang-tidy`, `.cppcheck`, `CPPLINT.cfg`)

### Suppressing Warnings
```c
// Suppress specific clang-tidy warnings
// NOLINT(readability-magic-numbers)
#define VGA_MEMORY 0xB8000

// Suppress cppcheck warnings
// cppcheck-suppress unusedFunction
void debug_function() { }
```

## Troubleshooting

### Common Issues

1. **Tools not found**: Install missing linters using platform-specific instructions above

2. **False positives in OS code**: Many linters aren't designed for systems programming. The configurations provided suppress common false positives.

3. **Performance**: For large codebases, consider running linters on changed files only:
   ```bash
   # Lint only modified files
   git diff --name-only --diff-filter=AM | grep -E '\.(c|cpp|asm)$' | xargs make lint-files
   ```

### Debugging Linter Issues
```bash
# Verbose output
cppcheck --verbose src/kernel.c
clang-tidy -explain-config src/kernel.c
python3 scripts/asm_linter.py -v src/main.asm
```

## Benefits

- **Early Bug Detection**: Catch issues before runtime
- **Code Consistency**: Enforce consistent style across the project
- **Security**: Detect potential security vulnerabilities
- **Maintainability**: Improve code readability and structure
- **Learning**: Educational feedback for better coding practices

## File Structure
```
.
├── .clang-format          # C/C++ formatting rules
├── .clang-tidy           # clang-tidy configuration
├── .cppcheck             # cppcheck configuration  
├── CPPLINT.cfg           # cpplint configuration
├── Makefile              # Build and lint targets
├── scripts/
│   └── asm_linter.py     # Custom assembly linter
└── src/
    ├── main.asm          # Assembly source
    ├── kernel.c          # C source
    └── memory.cpp        # C++ source
```
