SHELL := /bin/bash
.PHONY: bootstrap gen build test lint snapshot perf coverage content-lint sim todo

bootstrap:
	brew install --overwrite xcodegen swiftlint swift-format 2>/dev/null || true

gen:
	xcodegen generate --spec project.yml

build: gen
	xcodebuild build -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug 2>&1 | tee /tmp/nm-ios-build.log
	xcodebuild build -scheme NM-macOS -destination 'platform=macOS' -configuration Debug 2>&1 | tee /tmp/nm-mac-build.log

test: gen
	swift test --package-path Packages/NMCore --parallel --enable-code-coverage 2>&1 | tee /tmp/nm-core-test.log
	swift test --package-path Packages/NMContent --parallel --enable-code-coverage 2>&1 | tee /tmp/nm-content-test.log
	swift test --package-path Packages/NMAI --parallel --enable-code-coverage 2>&1 | tee /tmp/nm-ai-test.log
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug 2>&1 | tee /tmp/nm-xcode-test.log

lint:
	swiftlint --strict --config .swiftlint.yml 2>&1
	swift-format lint --recursive Packages/ App/ --configuration .swift-format

content-lint:
	swift run --package-path Tools/content-lint content-lint Resources/Content/ 2>&1 || true

snapshot: gen
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:Snapshots 2>&1 | tee /tmp/nm-snapshot.log

perf: gen
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:PerfTests 2>&1 | tee /tmp/nm-perf.log

coverage:
	xcrun xccov report --workspace --all-targets /Users/agent/.hermes/profiles/geist/work/Geist/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/DerivedData/Geist-hjscgijzzwfyztbivsinfrtcjnmo/Build/Products/Debug-iphonesimulator/NMUITests*.xctest 2>&1 | tee docs/COVERAGE.md || true

sim: gen
	swift run --package-path Tools/sim sim --count 200 --seed 42 2>&1 || true

todo:
	grep -rn 'TODO(' Packages/ App/ 2>/dev/null | sort || true
