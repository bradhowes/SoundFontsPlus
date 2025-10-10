PLATFORM_IOS = iOS Simulator,name=iPad mini (A17 Pro)
PLATFORM_MACOS = macOS
SCHEME = SoundFontsPlus
BUILD_FLAGS = -skipMacroValidation -skipPackagePluginValidation -enableCodeCoverage YES -scheme $(SCHEME) \
			  -clonedSourcePackagesDirPath "$(WORKSPACE)"
WORKSPACE = $(PWD)/.workspace
XCCOV = xcrun xccov view --report --only-targets

ifeq ($(GITHUB_ENV),)
XCB = | xcbeautify --renderer github-actions
endif

default: report

report: percentage-iOS # percentage-macOS
	@if [[ -n "$$GITHUB_ENV" ]]; then \
		echo "PERCENTAGE=$$(< coverage_iOS/percentage.txt)" >> $$GITHUB_ENV; \
	fi

coverage-iOS: coverage-iOS
	cp -r $(PWD)/.DerivedData-iOS/Logs/Test/*.xcresult coverage_iOS/
	bash coverage_reporter.sh > coverage_iOS/percentage.txt
	echo "iOS Coverage Pct:"
	cat coverage_iOS/percentage.txt

coverage-macOS: coverage-macOS
	cp -r $(PWD)/.DerivedData-macOS/Logs/Test/*.xcresult coverage_macOS/
	bash coverage_reporter.sh > coverage_macOS/percentage.txt
	echo "macOS Coverage Pct:"
	cat coverage_macOS/percentage.txt

test-iOS:
	echo "$(XCB)"
	make -v
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-iOS" \
		-destination platform="$(PLATFORM_IOS)" $(XCB)

test-macOS:
	echo "$(XCB)"
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-macOS" \
		-destination platform="$(PLATFORM_MACOS)" $(XCB)

clean:
	-rm -rf "$(PWD)/.DerivedData-iOS" "$(PWD)/.DerivedData-macOS" "$(WORKSPACE)" coverage_iOS coverage_macOS

.PHONY: report test-iOS test-macOS coverage-iOS coverage-macOS coverage-iOS percentage-macOS percentage-iOS
