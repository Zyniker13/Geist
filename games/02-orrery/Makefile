SHELL := /bin/bash
.PHONY: bootstrap gen build test lint snapshot perf coverage content-lint sim todo

bootstrap:
	brew install --overwrite xcodegen swiftlint swift-format 2>/dev/null || true

gen:
	xcodegen generate --spec project.yml

build: gen
	xcodebuild build -scheme OR -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -configuration Debug
	xcodebuild build -scheme OR-macOS -destination 'platform=macOS' -configuration Debug

test: gen
	swift test --package-path Packages/ORCore
	swift test --package-path Packages/ORContent
	swift test --package-path Packages/ORAI
	swift test --package-path Packages/ORRender
	swift test --package-path Packages/ORAudio
	swift test --package-path Packages/ORPlatform
	swift test --package-path Packages/ORMeta
	xcodebuild test -scheme OR -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -configuration Debug

lint:
	swiftlint --strict --config .swiftlint.yml
	swift-format lint --recursive Packages/ App/ Tests/ --configuration .swift-format
	./Tools/content-lint
	./Tools/check-imports.sh

content-lint:
	./Tools/content-lint

# S1.3: headless rules-engine games (INV-4 two-pass hash agreement).
# N defaults to 5000 (the G1 gate count); override with make sim N=200.
N ?= 5000
SEED ?= 1
sim:
	swift build -c release --package-path Tools/sim
	Tools/sim/.build/out/Products/Release/sim --games $(N) --seed $(SEED)

snapshot: gen
	xcodebuild test -scheme OR -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -configuration Debug -only-testing:Snapshots

perf: gen
	xcodebuild test -scheme OR -destination 'platform=iOS Simulator,name=zGeist_bot-iPad-Pro-13' -configuration Debug -only-testing:PerfTests

coverage:
	swift test --enable-code-coverage --package-path Packages/ORCore
	@xcrun llvm-cov report Packages/ORCore/.build/debug/ORCorePackageTests.xctest/Contents/MacOS/ORCorePackageTests \
		-instr-profile Packages/ORCore/.build/debug/codecov/default.profdata \
		> /tmp/or-cov.txt || true
	@{ printf '# ORCore coverage (llvm-cov over the Debug test run)\n\n'; \
	   printf 'Gate G1 requires ORCore coverage >= 90%%.\n\n'; \
	   printf '```\n'; \
	   grep -E 'TOTAL|^Sources/' /tmp/or-cov.txt | sed 's|/Users.*/Sources/ORCore/|Sources/|'; \
	   printf '```\n'; } > docs/COVERAGE.md

todo:
	grep -rn 'TODO(' Packages/ App/ 2>/dev/null | sort || true
