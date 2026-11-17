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

# S1.3 (P1): headless rules-engine day — 4,000 birds, seed 1. The tool runs
# the full day twice and exits 1 unless both checkpoint hashes and the final
# hash match, so a green exit is the G1 determinism evidence. Budget: the
# reported dayCPU must stay <= 10 s (G1).
sim:
	swift build -c release --package-path Tools/sim
	Tools/sim/.build/out/Products/Release/sim --birds 4000 --seed 1

snapshot: gen
	xcodebuild test -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:Snapshots

perf: gen
	xcodebuild test -scheme MU -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug -only-testing:PerfTests

coverage:
	export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; \
	swift test --enable-code-coverage --package-path Packages/MUCore
	@xcrun llvm-cov report Packages/MUCore/.build/out/Products/Debug/MUCoreTests.xctest/Contents/MacOS/MUCoreTests \
		-instr-profile Packages/MUCore/.build/out/Products/Debug/codecov/default.profdata \
		> /tmp/mu-cov.txt || true
	@{ printf '# MUCore coverage (llvm-cov over the Debug test run)\n\n'; \
	   printf 'Gate G1 requires MUCore coverage >= 90%%. The gate metric is the\n'; \
	   printf 'line-coverage TOTAL below (Lines / Missed Lines / Cover columns:\n'; \
	   printf 'total, missed, percent). Columns per row: regions, functions, lines.\n\n'; \
	   printf '```\n'; \
	   grep -E 'TOTAL|^Sources/' /tmp/mu-cov.txt | sed 's|/Users.*/Sources/MUCore/|Sources/|'; \
	   printf '```\n'; } > docs/COVERAGE.md

todo:
	grep -rn 'TODO(' Packages/ App/ 2>/dev/null | sort || true
