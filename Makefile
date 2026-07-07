.PHONY: gen build test run clean release

DERIVED := build
DEST := -destination 'platform=macOS,arch=arm64'

gen: ## Regenerate CmdV.xcodeproj after adding/removing files
	xcodegen generate

build:
	xcodebuild -project CmdV.xcodeproj -scheme CmdV -configuration Debug \
	  $(DEST) -derivedDataPath $(DERIVED) build

test:
	xcodebuild -project CmdV.xcodeproj -scheme CmdV \
	  $(DEST) -derivedDataPath $(DERIVED) test

run: build
	pkill -x CmdV || true
	open $(DERIVED)/Build/Products/Debug/CmdV.app

clean:
	rm -rf $(DERIVED) dist

release: ## Usage: make release VERSION=1.0.0
	./scripts/release.sh $(VERSION)
