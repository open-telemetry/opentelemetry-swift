PROJECT_NAME="opentelemetry-swift-Package"

XCODEBUILD_OPTIONS_IOS=\
	-configuration Debug \
	-destination platform='iOS Simulator,name=iPhone 14,OS=latest' \
	-scheme $(PROJECT_NAME) \
	-workspace .

XCODEBUILD_OPTIONS_WATCHOS=\
	-configuration Debug \
	-destination platform='watchOS Simulator,name=Apple Watch Series 8 (45mm),OS=latest' \
	-scheme $(PROJECT_NAME) \
	-workspace .

.PHONY: setup_brew
setup_brew:
	brew update && brew install xcbeautify

.PHONY: build_ios
build_ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build | xcbeautify

.PHONY: build_for_testing_ios
build_for_testing_ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build-for-testing | xcbeautify

.PHONY: build_for_testing_watchos
build_for_testing_watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) build-for-testing | xcbeautify

.PHONY: test_ios
test_ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test | xcbeautify

.PHONY: test_without_building_ios
test_without_building_ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test-without-building | xcbeautify

.PHONY: test_without_building_watchos
test_without_building_watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) test-without-building | xcbeautify
