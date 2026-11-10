# Common tasks for the Cerita workspace. Run `make` to list them.

FLUTTER_PACKAGES := packages/cerita_flutter packages/cerita_ui example
# Target device for run/install, e.g. `make install DEVICE=emulator-5554`. Empty picks the only one.
DEVICE ?=
DEVICE_FLAG := $(if $(DEVICE),-d $(DEVICE),)
ADB := adb $(if $(DEVICE),-s $(DEVICE),)
APP_ID := id.twk.fsse

.DEFAULT_GOAL := help
.PHONY: help get analyze test test-core test-flutter check run install apk web clean

help: ## List the available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-14s %s\n", $$1, $$2}'

get: ## Resolve dependencies for the whole workspace
	flutter pub get

analyze: get ## Analyze every package and the example
	flutter analyze packages example

test: test-core test-flutter ## Run every test suite

test-core: get ## Test the pure Dart engine
	cd packages/cerita_core && dart test

test-flutter: get ## Test the Flutter packages and the example
	@set -e; for dir in $(FLUTTER_PACKAGES); do echo "==> $$dir"; (cd $$dir && flutter test); done

check: analyze test ## Analyze and test, like CI

run: get ## Run the demo app (DEVICE=<id> to pick a device)
	cd example && flutter run $(DEVICE_FLAG)

# A profile build: debug builds compile code on first use and stutter through the transitions.
# adb install -r keeps the app data, so saves survive a reinstall (flutter install uninstalls first).
install: get ## Build a profile APK, install it on the device and launch it
	cd example && flutter build apk --profile
	$(ADB) install -r example/build/app/outputs/flutter-apk/app-profile.apk
	$(ADB) shell am start -n $(APP_ID)/.MainActivity

apk: get ## Build a release APK
	cd example && flutter build apk --release

web: get ## Build the demo for the web
	cd example && flutter build web

clean: ## Remove build output of every package
	@for dir in packages/cerita_core $(FLUTTER_PACKAGES); do (cd $$dir && flutter clean); done
