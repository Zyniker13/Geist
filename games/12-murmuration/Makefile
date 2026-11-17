SHELL := /bin/bash
.PHONY: bootstrap gen build test lint snapshot perf coverage sim content-lint spike todo

bootstrap:
	brew install --overwrite xcodegen swiftlint swift-format 2>/dev/null || true

gen:
	xcodegen generate --spec project.yml

build: gen
	xcodebuild build -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug
	xcodebuild build -scheme MU-macOS -destination 'platform=macOS' -configuration Debug

test: gen
	swift test --package-path Packages/MUCore
	swift test --package-path Packages/MUContent
	swift test --package-path Packages/MUAI
	swift test --package-path Packages/MURender
	swift test --package-path Packages/MUAudio
	swift test --package-path Packages/MUPlatform
	swift test --package-path Packages/MUMeta
	xcodebuild test -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug

lint:
	swiftlint --strict --config .swiftlint.yml
	swift-format lint --recursive Packages/ App/ Tests/ --configuration .swift-format
	./Tools/content-lint
	./Tools/check-imports.sh

content-lint:
	./Tools/content-lint

# MU-P0.1 spike: boid tick time on Mac Release (gate: <= 4 ms for 4,000 birds).
spike:
	swift build -c release --package-path Tools/spike
	swift run -c release --package-path Tools/spike spike --birds 4000 --ticks 300

# S1.3 (P1): headless rules-engine runs. Placeholder until the reducer lands.
sim:
	@echo "sim arrives with P1 (Tools/sim, S1.3)"

snapshot: gen
	xcodebuild test -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:Snapshots

perf: gen
	xcodebuild test -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:PerfTests

coverage:
	swift test --enable-code-coverage --package-path Packages/MUCore
	@xcrun llvm-cov report Packages/MUCore/.build/debug/MUCorePackageTests.xctest/Contents/MacOS/MUCorePackageTests \
		-instr-profile Packages/MUCore/.build/debug/codecov/default.profdata \
		> /tmp/mu-cov.txt || true
	@grep -E 'TOTAL|Sources' /tmp/mu-cov.txt | sed 's|/Users.*/Sources/|Sources/|' > docs/COVERAGE.md || true

todo:
	grep -rn 'TODO(' Packages/ App/ 2>/dev/null | sort || true
