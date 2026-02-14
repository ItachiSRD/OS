ASM=nasm
CC=gcc
CXX=g++

SRC_DIR=src
BUILD_DIR=build
SCRIPTS_DIR=scripts

# Linter tools
ASM_LINTER=$(SCRIPTS_DIR)/asm_linter.py
CLANG_TIDY=clang-tidy
CPPCHECK=cppcheck
CPPLINT=cpplint

# Find source files
ASM_FILES=$(wildcard $(SRC_DIR)/*.asm $(SRC_DIR)/*.s)
C_FILES=$(wildcard $(SRC_DIR)/*.c)
CPP_FILES=$(wildcard $(SRC_DIR)/*.cpp $(SRC_DIR)/*.cc $(SRC_DIR)/*.cxx)

# Build targets
$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
	truncate -s 1440k $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/main.bin

# Linting targets
.PHONY: lint lint-asm lint-c lint-cpp lint-all clean help

lint: lint-all

lint-asm:
	@echo "🔍 Linting assembly files..."
	@if [ -n "$(ASM_FILES)" ]; then \
		python3 $(ASM_LINTER) $(ASM_FILES); \
	else \
		echo "No assembly files found"; \
	fi

lint-c:
	@echo "🔍 Linting C files..."
	@if [ -n "$(C_FILES)" ]; then \
		if command -v $(CPPCHECK) >/dev/null 2>&1; then \
			echo "Running cppcheck on C files..."; \
			$(CPPCHECK) --config-file=.cppcheck $(C_FILES) || true; \
		else \
			echo "⚠️  cppcheck not found - install with: brew install cppcheck"; \
		fi; \
		if command -v $(CPPLINT) >/dev/null 2>&1; then \
			echo "Running cpplint on C files..."; \
			$(CPPLINT) $(C_FILES) || true; \
		else \
			echo "⚠️  cpplint not found - install with: pipx install cpplint"; \
		fi; \
		if command -v $(CLANG_TIDY) >/dev/null 2>&1; then \
			echo "Running clang-tidy on C files..."; \
			$(CLANG_TIDY) $(C_FILES) -- -std=c99 || true; \
		else \
			echo "⚠️  clang-tidy not found - install with: brew install llvm"; \
		fi; \
	else \
		echo "No C files found"; \
	fi

lint-cpp:
	@echo "🔍 Linting C++ files..."
	@if [ -n "$(CPP_FILES)" ]; then \
		if command -v $(CPPCHECK) >/dev/null 2>&1; then \
			echo "Running cppcheck on C++ files..."; \
			$(CPPCHECK) --config-file=.cppcheck $(CPP_FILES) || true; \
		else \
			echo "⚠️  cppcheck not found - install with: brew install cppcheck"; \
		fi; \
		if command -v $(CPPLINT) >/dev/null 2>&1; then \
			echo "Running cpplint on C++ files..."; \
			$(CPPLINT) $(CPP_FILES) || true; \
		else \
			echo "⚠️  cpplint not found - install with: pipx install cpplint"; \
		fi; \
		if command -v $(CLANG_TIDY) >/dev/null 2>&1; then \
			echo "Running clang-tidy on C++ files..."; \
			$(CLANG_TIDY) $(CPP_FILES) -- -std=c++17 || true; \
		else \
			echo "⚠️  clang-tidy not found - install with: brew install llvm"; \
		fi; \
	else \
		echo "No C++ files found"; \
	fi

lint-all: lint-asm lint-c lint-cpp
	@echo "✅ All linting completed!"

# Format code (requires clang-format)
format:
	@echo "🎨 Formatting C/C++ files..."
	@if [ -n "$(C_FILES)$(CPP_FILES)" ]; then \
		clang-format -i $(C_FILES) $(CPP_FILES); \
		echo "Code formatted!"; \
	else \
		echo "No C/C++ files to format"; \
	fi

# Install linting tools
install-linters:
	@echo "📦 Installing linting tools..."
	@echo "Installing Python packages..."
	pip3 install cpplint
	@echo "Please install the following system packages:"
	@echo "  - clang-tidy (usually in clang-tools package)"
	@echo "  - cppcheck"
	@echo "  - clang-format (for code formatting)"
	@echo ""
	@echo "On macOS: brew install llvm cppcheck"
	@echo "On Ubuntu/Debian: sudo apt install clang-tidy cppcheck clang-format"
	@echo "On Fedora/RHEL: sudo dnf install clang-tools-extra cppcheck clang"

clean:
	rm -rf $(BUILD_DIR)/*

help:
	@echo "Available targets:"
	@echo "  build targets:"
	@echo "    $(BUILD_DIR)/main.bin         - Build main binary"
	@echo "    $(BUILD_DIR)/main_floppy.img  - Build floppy image"
	@echo ""
	@echo "  linting targets:"
	@echo "    lint, lint-all  - Run all linters"
	@echo "    lint-asm        - Lint assembly files"
	@echo "    lint-c          - Lint C files"
	@echo "    lint-cpp        - Lint C++ files"
	@echo ""
	@echo "  other targets:"
	@echo "    format          - Format C/C++ code"
	@echo "    install-linters - Install linting tools"
	@echo "    clean           - Clean build directory"
	@echo "    help            - Show this help"
