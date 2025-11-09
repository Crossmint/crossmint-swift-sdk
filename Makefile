.PHONY: build test lint lint-fix clean resolve open build-evm-demo build-solana-demo run-solana-demo run-evm-demo

# Default task
all: build

# ==========================================
# User-configurable variables (uppercase)
# ==========================================

# Simulator destination for builds and tests
SIMULATOR_DEST := platform=iOS Simulator,name=iPhone 16 Pro,OS=latest

# Scheme names
SDK_SCHEME := CrossmintClientSDK
SOLANA_DEMO_SCHEME := SolanaDemo
EVM_DEMO_SCHEME := SmartWalletsDemo

# External programs
XCODEBUILD := xcodebuild
XCRUN := xcrun
SWIFT := swift

# Bundle identifiers for demos
SOLANA_BUNDLE_ID := com.paella.SolanaDemo
EVM_BUNDLE_ID := com.paella.SmartWalletsDemo

# ==========================================
# Internal variables (lowercase)
# ==========================================

# SwiftLint binary from build artifacts
swiftlint_bin := .build/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/swiftlint-0.59.1-macos/bin/swiftlint

# ==========================================
# Functions
# ==========================================

# Define a function to run xcodebuild with xcbeautify
define run-with-xcbeautify
	@if command -v xcbeautify >/dev/null 2>&1; then \
		set -o pipefail && $(1) | xcbeautify; \
	else \
		$(1); \
	fi
endef

# ==========================================
# Build targets
# ==========================================

# Build the Swift package
build:
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation)

# Build with release configuration
release:
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) -destination "$(SIMULATOR_DEST)" archive -skipPackagePluginValidation)

# Build the EVM demo app (SmartWalletsDemo)
build-evm-demo:
	@echo "Building EVM demo app..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation)

# Build the Solana demo app
build-solana-demo:
	@echo "Building Solana demo app..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SOLANA_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation)

# ==========================================
# Test targets
# ==========================================

# Run all tests
test:
	@echo "Running tests..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) -destination "$(SIMULATOR_DEST)" test)

# CI sanity check and test running
ci-test:
	@echo "Checking if lint-fix would produce changes..."
	git diff --quiet || { echo "Working copy has uncommitted changes. Please commit or stash them first."; exit 1; }
	$(SWIFT) package plugin --allow-writing-to-package-directory swiftlint --fix
	git status
	@if [ -n "$$(git diff)" ]; then \
		echo "lint-fix produced changes to the working copy. Reverting changes and failing."; \
		git checkout -- .; \
		exit 1; \
	fi
	$(MAKE) lint
	@echo "Running tests..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) -destination "$(SIMULATOR_DEST)" test -skipPackagePluginValidation)
	@echo "Building demo apps..."
	$(MAKE) build-evm-demo
	$(MAKE) build-solana-demo

# ==========================================
# Lint targets
# ==========================================

# Run SwiftLint using the SPM plugin
lint:
	@echo "Running SwiftLint via Swift Package Manager..."
	$(SWIFT) package plugin --allow-writing-to-package-directory swiftlint lint-strict || (echo "SwiftLint found issues. Please fix them before running tests." && exit 1)
	@echo "Running SwiftLint on SolanaDemo..."
	@if [ -f "$(swiftlint_bin)" ]; then \
		$(swiftlint_bin) lint Examples/SolanaDemo/SolanaDemo --strict || (echo "SwiftLint found issues in SolanaDemo. Please fix them before running tests." && exit 1); \
	else \
		echo "SwiftLint binary not found. Run 'make build' first to download dependencies."; \
		exit 1; \
	fi
	@echo "Running SwiftLint on SmartWalletsDemo..."
	@if [ -f "$(swiftlint_bin)" ]; then \
		$(swiftlint_bin) lint Examples/SmartWalletsDemo/SmartWalletsDemo --strict || (echo "SwiftLint found issues in SmartWalletsDemo. Please fix them before running tests." && exit 1); \
	else \
		echo "SwiftLint binary not found. Run 'make build' first to download dependencies."; \
		exit 1; \
	fi

# Run SwiftLint with auto-fix option
lint-fix:
	@echo "Running SwiftLint with auto-fix option..."
	$(SWIFT) package plugin --allow-writing-to-package-directory swiftlint --fix
	@echo "Running SwiftLint auto-fix on SolanaDemo..."
	@if [ -f "$(swiftlint_bin)" ]; then \
		$(swiftlint_bin) --fix Examples/SolanaDemo/SolanaDemo; \
	else \
		echo "SwiftLint binary not found. Run 'make build' first to download dependencies."; \
		exit 1; \
	fi
	@echo "Running SwiftLint auto-fix on SmartWalletsDemo..."
	@if [ -f "$(swiftlint_bin)" ]; then \
		$(swiftlint_bin) --fix Examples/SmartWalletsDemo/SmartWalletsDemo; \
	else \
		echo "SwiftLint binary not found. Run 'make build' first to download dependencies."; \
		exit 1; \
	fi

# ==========================================
# Clean and utility targets
# ==========================================

# Clean build artifacts
clean:
	@echo "Cleaning $(SDK_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) clean)
	@echo "Cleaning $(SOLANA_DEMO_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SOLANA_DEMO_SCHEME) clean)
	@echo "Cleaning $(EVM_DEMO_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) clean)

# Resolve Swift package dependencies (downloads but doesn't update versions)
resolve:
	@echo "Resolving Swift package dependencies..."
	$(SWIFT) package resolve

# Open in Xcode (macOS only)
open:
	open *.xcworkspace

# ==========================================
# Demo run targets
# ==========================================

# Build and run SolanaDemo
run-solana-demo:
	@echo "Building and running $(SOLANA_DEMO_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SOLANA_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation build)
	@echo "Launching $(SOLANA_DEMO_SCHEME) in simulator..."
	$(XCRUN) simctl boot "iPhone 16 Pro" 2>/dev/null || true
	open -a Simulator
	$(XCRUN) simctl install "iPhone 16 Pro" "$$($(XCODEBUILD) -scheme $(SOLANA_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -showBuildSettings 2>/dev/null | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $$3}')/$(SOLANA_DEMO_SCHEME).app"
	$(XCRUN) simctl launch "iPhone 16 Pro" $(SOLANA_BUNDLE_ID)

# Build and run SmartWalletsDemo (EVM)
run-evm-demo:
	@echo "Building and running $(EVM_DEMO_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation build)
	@echo "Launching $(EVM_DEMO_SCHEME) in simulator..."
	$(XCRUN) simctl boot "iPhone 16 Pro" 2>/dev/null || true
	open -a Simulator
	$(XCRUN) simctl install "iPhone 16 Pro" "$$($(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -showBuildSettings 2>/dev/null | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $$3}')/$(EVM_DEMO_SCHEME).app"
	$(XCRUN) simctl launch "iPhone 16 Pro" $(EVM_BUNDLE_ID)