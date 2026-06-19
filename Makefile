.PHONY: build test lint lint-fix clean resolve open build-evm-demo run-evm-demo docs

# Default task
all: build

# ==========================================
# User-configurable variables (uppercase)
# ==========================================

# Simulator destination for builds and tests
SIMULATOR_DEST := platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5

# Scheme names
SDK_SCHEME := CrossmintClientSDK
EVM_DEMO_SCHEME := SmartWalletsDemo

# External programs
XCODEBUILD := xcodebuild
XCRUN := xcrun
SWIFT := swift

# Bundle identifiers for demos
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

# ==========================================
# Test targets
# ==========================================

# Run all tests
test:
	@echo "Running tests..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(SDK_SCHEME) -destination "$(SIMULATOR_DEST)" test)

# CI sanity check and test running
ci-test:
	@echo "Resolving dependencies..."
	$(SWIFT) package resolve
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

# ==========================================
# Lint targets
# ==========================================

# Run SwiftLint using the SPM plugin
lint:
	@echo "Running SwiftLint via Swift Package Manager..."
	$(SWIFT) package plugin --allow-writing-to-package-directory swiftlint lint-strict || (echo "SwiftLint found issues. Please fix them before running tests." && exit 1)
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
# Docs targets
# ==========================================

DOCC_BUILD_DIR := /tmp/crossmint-swift-sdk-docc
DOCS_OUTPUT := docs/sdk-reference/wallets/swift

# Build the DocC archive and generate MDX files (override output with DOCS_OUTPUT).
# CrossmintClient is the umbrella module consumers import — its archive covers
# exactly the re-exported public API surface.
docs:
	@echo "Building DocC archives..."
	$(call run-with-xcbeautify,$(XCODEBUILD) docbuild \
		-scheme $(SDK_SCHEME) \
		-destination "$(SIMULATOR_DEST)" \
		-derivedDataPath $(DOCC_BUILD_DIR) \
		-skipPackagePluginValidation \
		OTHER_DOCC_FLAGS="--fallback-display-name CrossmintSDK --fallback-bundle-identifier com.crossmint.sdk --fallback-bundle-version 1")
	@archive="$(DOCC_BUILD_DIR)/Build/Products/Debug-iphonesimulator/CrossmintClient.doccarchive"; \
	if [ ! -d "$$archive" ]; then echo "Error: $$archive not found"; exit 1; fi; \
	echo "Generating MDX files from $$archive..."; \
	python3 scripts/docc-to-markdown.py "$$archive" --output $(DOCS_OUTPUT)

# ==========================================
# Demo run targets
# ==========================================

# Build and run SmartWalletsDemo (EVM)
run-evm-demo:
	@echo "Building and running $(EVM_DEMO_SCHEME)..."
	$(call run-with-xcbeautify,$(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -skipPackagePluginValidation build)
	@echo "Launching $(EVM_DEMO_SCHEME) in simulator..."
	$(XCRUN) simctl boot "iPhone 17 Pro" 2>/dev/null || true
	open -a Simulator
	$(XCRUN) simctl install "iPhone 17 Pro" "$$($(XCODEBUILD) -scheme $(EVM_DEMO_SCHEME) -destination "$(SIMULATOR_DEST)" -showBuildSettings 2>/dev/null | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $$3}')/$(EVM_DEMO_SCHEME).app"
	$(XCRUN) simctl launch "iPhone 17 Pro" $(EVM_BUNDLE_ID)