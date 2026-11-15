SHELL := /bin/bash
.PHONY: bootstrap gen build test lint snapshot perf coverage sim content-lint todo

bootstrap:
	brew install --overwrite xcodegen swiftlint swift-format 2>/dev/null || true

gen:
	xcodegen generate --spec project.yml

build: gen
	xcodebuild build -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug
	xcodebuild build -scheme NM-macOS -destination 'platform=macOS' -configuration Debug

test: gen
	swift test --package-path Packages/NMCore
	swift test --package-path Packages/NMContent
	swift test --package-path Packages/NMAI
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug

lint:
	swiftlint --strict --config .swiftlint.yml
	swift-format lint --recursive Packages/ App/ --configuration .swift-format

content-lint:
	swift run --package-path Tools/content-lint content-lint Resources/Content/

snapshot: gen
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:Snapshots

perf: gen
	xcodebuild test -scheme NM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:PerfTests

# Headless rules-engine check (S1.3): N seeded nights, invariants, deterministic.
sim:
	swift build -c release --package-path Tools/sim
	swift run -c release --package-path Tools/sim sim --invariant-sweep $(or $(N),1000)

# Line-coverage summary into docs/COVERAGE.md (Core target: >= 90%).
coverage:
	swift test --enable-code-coverage --package-path Packages/NMCore
	@xcrun llvm-cov report Packages/NMCore/.build/out/Products/Debug/NMCoreTests.xctest/Contents/MacOS/NMCoreTests \
		-instr-profile Packages/NMCore/.build/out/Products/Debug/codecov/default.profdata \
		> /tmp/nm-cov.txt
	@grep -E 'TOTAL' /tmp/nm-cov.txt | sed 's|/Users.*/Sources/|Sources/|' > docs/COVERAGE.md
	@grep -E 'Sources' /tmp/nm-cov.txt | sed 's|/Users.*/Sources/|Sources/|' >> docs/COVERAGE.md

todo:
	grep -rn 'TODO(' Packages/ App/ 2>/dev/null | sort || true
