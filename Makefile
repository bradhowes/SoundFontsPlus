PATH = /usr/bin:/bin:/usr/sbin:/sbin
PLATFORM_IOS = iOS Simulator,name=iPad mini (A17 Pro)
IOS_SIM = 8C8C409E-EDE8-4AC3-969D-449731DC9DA1
PLATFORM_MACOS = macOS
SCHEME = SoundFontsPlus
BUILD_FLAGS = -skipMacroValidation \
              -skipPackagePluginValidation \
              -enableCodeCoverage YES \
			  -workspace SoundFontsPlus.xcworkspace \
              -scheme $(SCHEME) \
			  -clonedSourcePackagesDirPath "$(WORKSPACE)"
WORKSPACE = $(PWD)/.workspace

ifeq ($(GITHUB_ENV),)
XCB = | xcbeautify --renderer github-actions
endif

XCB =

default: report

report: coverage-iOS # percentage-macOS
	@if [[ -n "$$GITHUB_ENV" ]]; then \
		echo "PERCENTAGE=$$(< coverage_iOS/percentage.txt)" >> $$GITHUB_ENV; \
	fi

coverage-iOS: test-iOS
	rm -rf coverage_iOS
	mkdir coverage_iOS
	cp -r $(PWD)/.DerivedData-iOS/Logs/Test/*.xcresult coverage_iOS/
	bash $(PWD)/scripts/coverage_reporter.sh > coverage_iOS/percentage.txt
	echo "iOS Coverage Pct:"
	cat coverage_iOS/percentage.txt

coverage-macOS: test-macOS
	rm -rf coverage_macOS
	mkdir coverage_macOS
	cp -r $(PWD)/.DerivedData-macOS/Logs/Test/*.xcresult coverage_macOS/
	bash $(PWD)/scripts/coverage_reporter.sh > coverage_macOS/percentage.txt
	echo "macOS Coverage Pct:"
	cat coverage_macOS/percentage.txt

test-iOS: clean
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

run:
	set -o pipefail && xcodebuild build \
		-skipMacroValidation -skipPackagePluginValidation -scheme $(SCHEME) \
		-derivedDataPath "$(PWD)/.DerivedData-iOS" \
		-destination platform="$(PLATFORM_IOS)" \
		| xcbeautify --renderer github-actions
	xcrun simctl install $(IOS_SIM) ./.DerivedData-iOS/Build/Products/Debug-iphonesimulator/SoundFontsPlus.app
	xcrun simctl launch $(IOS_SIM) com.braysoftware.SoundFontsPlus

clean:
	-rm -rf "$(PWD)/.DerivedData-iOS" "$(PWD)/.DerivedData-macOS" "$(WORKSPACE)" coverage_iOS coverage_macOS

.PHONY: report test-iOS test-macOS coverage-iOS coverage-macOS coverage-iOS percentage-macOS percentage-iOS
