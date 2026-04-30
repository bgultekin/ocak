.PHONY: build build-wrapped run run-watch lint test reset-state

build:
	swift build --package-path macos

run:
	swift run --package-path macos

build-wrapped:
	swift build --package-path macos
	@./scripts/wrap-debug-bundle.sh

run-watch:
	./scripts/run-macos-app-and-watch.sh

lint:
	swift package --package-path macos plugin swiftlint

test:
	swift test --package-path macos

reset-state:
	./scripts/reset-macos-app-state.sh
