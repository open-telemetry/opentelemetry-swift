PROJECT_NAME="opentelemetry-swift-Package"

XCODEBUILD_OPTIONS_IOS=\
	-configuration Debug \
	-destination 'platform=iOS Simulator,name=iPhone 16' \
	-scheme $(PROJECT_NAME) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

XCODEBUILD_OPTIONS_TVOS=\
	-configuration Debug \
	-destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
	-scheme $(PROJECT_NAME) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

XCODEBUILD_OPTIONS_WATCHOS=\
	-configuration Debug \
	-destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
	-scheme $(PROJECT_NAME) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

XCODEBUILD_OPTIONS_VISIONOS=\
	-configuration Debug \
	-destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=2.5' \
	-scheme $(PROJECT_NAME) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

.PHONY: setup-brew
setup-brew:
	brew update && brew install xcbeautify

.PHONY: build-ios
build-ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build | xcbeautify

.PHONY: build-tvos
build-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) build | xcbeautify

.PHONY: build-watchos
build-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) build | xcbeautify

.PHONY: build-visionOS
build-visionos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) build | xcbeautify

.PHONY: build-for-testing-ios
build-for-testing-ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build-for-testing | xcbeautify

.PHONY: build-for-testing-tvos
build-for-testing-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) build-for-testing | xcbeautify

.PHONY: build-for-testing-watchos
build-for-testing-watchos:
	set -o pipefail && xcodebuild OTHER_LDFLAGS="$(OTHER_LDFLAGS) -fprofile-instr-generate" $(XCODEBUILD_OPTIONS_WATCHOS) build-for-testing | xcbeautify

.PHONY: build-for-testing-visionos
build-for-testing-visionos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) build-for-testing | xcbeautify

.PHONY: test-ios
test-ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test | xcbeautify

.PHONY: test-tvos
test-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) test | xcbeautify

.PHONY: test-watchos
test-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) test | xcbeautify

.PHONY: test-visionos
test-visionos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) test | xcbeautify

.PHONY: test-without-building-ios
test-without-building-ios:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test-without-building | xcbeautify

.PHONY: test-without-building-tvos
test-without-building-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) test-without-building | xcbeautify

.PHONY: test-without-building-watchos
test-without-building-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) test-without-building | xcbeautify

.PHONY: test-without-building-visionos
test-without-building-visionos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) test-without-building | xcbeautify
