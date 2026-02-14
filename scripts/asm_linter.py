#!/usr/bin/env python3
"""
Custom Assembly Linter for NASM x86 Assembly Files
Checks for common style issues and potential problems in assembly code.
"""

import sys
import re
import os
from pathlib import Path

class AssemblyLinter:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.line_number = 0
        
    def lint_file(self, filepath):
        """Lint a single assembly file"""
        self.errors = []
        self.warnings = []
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            self.errors.append(f"Error reading file: {e}")
            return
            
        self.check_file_structure(lines)
        
        for i, line in enumerate(lines, 1):
            self.line_number = i
            self.check_line(line.rstrip('\n\r'))
            
    def check_file_structure(self, lines):
        """Check overall file structure"""
        content = ''.join(lines)
        
        # Check for org directive
        if not re.search(r'^\s*org\s+', content, re.MULTILINE):
            self.warnings.append("No 'org' directive found - consider adding one for clarity")
            
        # Check for bits directive
        if not re.search(r'^\s*bits\s+', content, re.MULTILINE):
            self.warnings.append("No 'bits' directive found - consider specifying architecture")
            
        # Check for boot signature in boot sector code
        if re.search(r'org\s+0x7[cC]00', content):
            if not re.search(r'0x[aA][aA]55', content):
                self.errors.append("Boot sector missing boot signature (0xAA55)")
                
    def check_line(self, line):
        """Check individual line for issues"""
        # Skip empty lines and pure comments
        if not line.strip() or line.strip().startswith(';'):
            return
            
        # Check for mixed tabs and spaces (prefer consistent indentation)
        if '\t' in line and '    ' in line:
            self.warnings.append(f"Line {self.line_number}: Mixed tabs and spaces")
            
        # Check for trailing whitespace
        if line.endswith(' ') or line.endswith('\t'):
            self.warnings.append(f"Line {self.line_number}: Trailing whitespace")
            
        # Check for very long lines
        if len(line) > 120:
            self.warnings.append(f"Line {self.line_number}: Line too long ({len(line)} chars)")
            
        # Check for proper label formatting
        if ':' in line and not line.strip().startswith(';'):
            label_match = re.match(r'^(\w+):', line.strip())
            if label_match:
                label = label_match.group(1)
                # Labels should be descriptive
                if len(label) < 2:
                    self.warnings.append(f"Line {self.line_number}: Label '{label}' is too short")
                    
        # Check for common instruction issues
        self.check_instruction_issues(line)
        
        # Check for register usage patterns
        self.check_register_usage(line)
        
    def check_instruction_issues(self, line):
        """Check for common instruction-related issues"""
        line_clean = line.strip().lower()
        
        # Check for potentially dangerous instructions
        dangerous_patterns = [
            (r'\bhlt\b', "HLT instruction - ensure this is intentional"),
            (r'\bcli\b', "CLI instruction - disables interrupts"),
            (r'\bsti\b', "STI instruction - enables interrupts"),
        ]
        
        for pattern, message in dangerous_patterns:
            if re.search(pattern, line_clean):
                self.warnings.append(f"Line {self.line_number}: {message}")
                
        # Check for missing operand size specifiers
        memory_ops = ['mov', 'add', 'sub', 'cmp', 'and', 'or', 'xor']
        for op in memory_ops:
            # Look for operations with memory operands that might need size specifiers
            pattern = rf'\b{op}\s+.*\[.*\]'
            if re.search(pattern, line_clean):
                if not re.search(r'\b(byte|word|dword|qword)\s+ptr\b', line_clean):
                    # This is just a warning as NASM can often infer size
                    pass  # Skip this check for NASM as it's more flexible than MASM
                    
    def check_register_usage(self, line):
        """Check for register usage patterns"""
        line_clean = line.strip().lower()
        
        # Check for potential register conflicts in function calls
        if 'int' in line_clean and re.search(r'int\s+0x', line_clean):
            # BIOS interrupt - remind about register preservation
            if self.line_number > 1:  # Don't warn on first line
                pass  # This would need more context to be useful
                
    def print_results(self, filepath):
        """Print linting results"""
        if not self.errors and not self.warnings:
            print(f"✅ {filepath}: No issues found")
            return True
            
        print(f"\n📄 {filepath}:")
        
        for error in self.errors:
            print(f"❌ ERROR: {error}")
            
        for warning in self.warnings:
            print(f"⚠️  WARNING: {warning}")
            
        return len(self.errors) == 0
        
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 asm_linter.py <file1.asm> [file2.asm] ...")
        sys.exit(1)
        
    linter = AssemblyLinter()
    all_passed = True
    
    for filepath in sys.argv[1:]:
        if not os.path.exists(filepath):
            print(f"❌ ERROR: File not found: {filepath}")
            all_passed = False
            continue
            
        if not filepath.lower().endswith(('.asm', '.s')):
            print(f"⚠️  WARNING: {filepath} doesn't appear to be an assembly file")
            
        linter.lint_file(filepath)
        file_passed = linter.print_results(filepath)
        all_passed = all_passed and file_passed
        
    if all_passed:
        print(f"\n✅ All files passed linting!")
        sys.exit(0)
    else:
        print(f"\n❌ Some files have issues")
        sys.exit(1)
        
if __name__ == "__main__":
    main()
