.PHONY: build build-wrapped run run-watch lint test reset-state sync-assets

FONTS_SRC := assets/fonts
FONTS_DST := macos/Sources/Ocak/Resources/Fonts

sync-assets:
	@mkdir -p $(FONTS_DST)
	@rsync -a --delete --include='*.ttf' --include='*.otf' --exclude='*' $(FONTS_SRC)/ $(FONTS_DST)/

build: sync-assets
	swift build --package-path macos

run: sync-assets
	swift run --package-path macos

build-wrapped: sync-assets
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
