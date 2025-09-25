PLATFORM_IOS = iOS Simulator,name=iPad mini (A17 Pro)
PLATFORM_MACOS = macOS
SCHEME = SoundFontsPlus
BUILD_FLAGS = -skipMacroValidation -skipPackagePluginValidation -enableCodeCoverage YES -scheme $(SCHEME) \
			  -clonedSourcePackagesDirPath "$(WORKSPACE)"
WORKSPACE = $(PWD)/.workspace
XCCOV = xcrun xccov view --report --only-targets

default: report

report: percentage-iOS # percentage-macOS
	@if [[ -n "$$GITHUB_ENV" ]]; then \
		echo "PERCENTAGE=$$(< percentage_iOS.txt)" >> $$GITHUB_ENV; \
	fi

percentage-iOS: coverage-iOS
	awk '/ SoundFontsPlus.app / { print $$4 }' coverage_iOS.txt > percentage_iOS.txt
	echo "iOS Coverage Pct:"
	cat percentage_iOS.txt

percentage-macOS: coverage-macOS
	awk '/ SoundFontsPlus.app / { print $$4 }' coverage_macOS.txt > percentage_macOS.txt
	echo "macOS Coverage Pct:"
	cat percentage_macOS.txt

coverage-iOS: test-iOS
	$(XCCOV) $(PWD)/.DerivedData-iOS/Logs/Test/*.xcresult > coverage_iOS.txt
	echo "iOS Coverage:"
	cat coverage_iOS.txt

coverage-macOS: test-macOS
	$(XCCOV) $(PWD)/.DerivedData-macOS/Logs/Test/*.xcresult > coverage_macOS.txt
	echo "macOS Coverage:"
	cat coverage_macOS.txt

test-iOS:
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-iOS" \
		-destination platform="$(PLATFORM_IOS)"

test-macOS:
	xcodebuild test \
		$(BUILD_FLAGS) \
		-derivedDataPath "$(PWD)/.DerivedData-macOS" \
		-destination platform="$(PLATFORM_MACOS)"

clean:
	-rm -rf "$(PWD)/.DerivedData-iOS" "$(PWD)/.DerivedData-macOS" "$(WORKSPACE)" coverage*.txt percentage*.txt

.PHONY: report test-iOS test-macOS coverage-iOS coverage-macOS coverage-iOS percentage-macOS percentage-iOS
