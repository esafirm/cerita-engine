# Common tasks for the Cerita workspace. Run `make` to list them.

FLUTTER_PACKAGES := packages/cerita_flutter packages/cerita_ui example samples/last_seen
LAST_SEEN := samples/last_seen
LAST_SEEN_ID := id.twk.lastseen
# RevenueCat keys from the git-ignored revenuecat.json, when it exists. TESTER=1 builds play every day without buying
# (playtest APKs only, never a store upload).
LAST_SEEN_KEYS := $(if $(wildcard $(LAST_SEEN)/revenuecat.json),--dart-define-from-file=revenuecat.json,)
LAST_SEEN_DEFINES := $(LAST_SEEN_KEYS) $(if $(TESTER),--dart-define=LAST_SEEN_TESTER=true,)
# A RevenueCat Test Store key (test_...) works in debug builds only. The SDK crashes on purpose in any other build
# that uses one, so the store bundle refuses it. Other non-debug builds ignore it and keep the store off.
LAST_SEEN_TEST_KEY := $(shell grep -s '"test_' $(LAST_SEEN)/revenuecat.json)
# Target device for run/install, e.g. `make install DEVICE=emulator-5554`. Empty picks the only one.
DEVICE ?=
DEVICE_FLAG := $(if $(DEVICE),-d $(DEVICE),)
ADB := adb $(if $(DEVICE),-s $(DEVICE),)
APP_ID := id.twk.fsse

.DEFAULT_GOAL := help
.PHONY: help get analyze test test-core test-tools test-flutter lint-story story-graph check run install apk web clean story story-check placeholders voice run-last-seen install-last-seen

help: ## List the available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-14s %s\n", $$1, $$2}'

get: ## Resolve dependencies for the whole workspace
	flutter pub get

analyze: get ## Analyze every package and the example
	flutter analyze packages example samples

test: test-core test-tools test-flutter ## Run every test suite

test-core: get ## Test the pure Dart engine
	cd packages/cerita_core && dart test

test-tools: get ## Test the story authoring toolkit (compiles Wrong Number from its script)
	cd packages/cerita_tools && dart test

test-flutter: get ## Test the Flutter packages and the example
	@set -e; for dir in $(FLUTTER_PACKAGES); do echo "==> $$dir"; (cd $$dir && flutter test); done

lint-story: get ## Check the demo story for broken targets, typos and missing files
	dart run cerita_core:cerita lint --strict example/assets/story

story-graph: get ## Print the demo story as a Mermaid flowchart
	@dart run cerita_core:cerita graph example/assets/story

check: analyze test lint-story story-check ## Analyze, test and lint both stories, like CI

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
	@for dir in packages/cerita_core packages/cerita_tools $(FLUTTER_PACKAGES); do (cd $$dir && flutter clean); done

# --- Last Seen (samples/last_seen) ---

story: get ## Last Seen: compile the scripts, then lint and measure them
	dart run cerita_tools compile $(LAST_SEEN)/story
	dart run cerita_tools lint $(LAST_SEEN)/story --release
	dart run cerita_tools stats $(LAST_SEEN)/story

story-check: get ## Last Seen: fail if the compiled JSON is stale or the scripts have errors
	dart run cerita_tools compile $(LAST_SEEN)/story --check
	dart run cerita_tools lint $(LAST_SEEN)/story --release

placeholders: get ## Last Seen: fill every missing image and sound with a placeholder
	$(LAST_SEEN)/tools/placeholders.sh

voice: get ## Last Seen: render missing voice lines with Gemini TTS (ARGS="--dry-run" to quote first)
	node $(LAST_SEEN)/tools/voice.mjs $(ARGS)

run-last-seen: get ## Last Seen: run the app (DEVICE=<id> to pick a device)
	cd $(LAST_SEEN) && flutter run $(DEVICE_FLAG) $(LAST_SEEN_DEFINES)

install-last-seen: get ## Last Seen: build a profile APK, install it and launch it
	cd $(LAST_SEEN) && flutter build apk --profile $(LAST_SEEN_DEFINES)
	$(ADB) install -r $(LAST_SEEN)/build/app/outputs/flutter-apk/app-profile.apk
	$(ADB) shell am start -n $(LAST_SEEN_ID)/.MainActivity

release-last-seen: get ## Last Seen: build the store bundle and a release APK (signed with android/key.properties if present, TESTER=1 for playtest APKs only)
	$(if $(and $(LAST_SEEN_TEST_KEY),$(if $(TESTER),,1)),$(error revenuecat.json holds a RevenueCat Test Store key. Put the production keys in for a store build or use TESTER=1 for a playtest APK))
	$(if $(TESTER),@echo "TESTER=1 skips the store bundle: playtest APKs only",cd $(LAST_SEEN) && flutter build appbundle --release $(LAST_SEEN_KEYS))
	cd $(LAST_SEEN) && flutter build apk --release --split-per-abi $(LAST_SEEN_DEFINES)
	ls -lh $(if $(TESTER),,$(LAST_SEEN)/build/app/outputs/bundle/release/*.aab) $(LAST_SEEN)/build/app/outputs/flutter-apk/*-release.apk
