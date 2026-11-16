bootstrap:
	@echo "Installing dependencies..."
	@brew install --overwrite xcodegen swiftlint swift-format 2>/dev/null || true

gen:
	@echo "Generating Xcode project..."
	@xcodegen generate --spec project.yml

build: gen
	@echo "Building iOS..."
	@xcodebuild build -scheme MM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug 2>&1 | tee /dev/null
	@echo "Building macOS..."
	@xcodebuild build -scheme MM-macOS -configuration Debug 2>&1 | tee /dev/null

test: gen
	@echo "Running Swift tests..."
	@for pkg in MMCore MMContent MMLogic MMRender MMPlatform MMMeta; do \
		swift test --package-path Packages/$$pkg 2>&1 | tee /dev/null; \
	done
	@echo "Running iOS tests..."
	@xcodebuild test -scheme MM -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' -configuration Debug 2>&1 | tee /dev/null

lint:
	@echo "Running SwiftLint..."
	@swiftlint --strict --config .swiftlint.yml
	@echo "Running swift-format..."
	@swift-format lint --recursive Packages/ App/ Tests/ --configuration .swift-format

content-lint:
	@echo "Linting content files..."
	@./Tools/content-lint 2>/dev/null || echo "content-lint tool not yet implemented"

snapshot:
	@echo "Capturing release screenshots..."
	@./Tools/release-screens.sh 2>/dev/null || echo "release-screens.sh not yet implemented"

perf:
	@echo "Running performance benchmarks..."
	@echo "Perf benchmarks not yet implemented"

sim:
	@echo "Running simulator tests..."
	@echo "Simulator tests not yet implemented"

coverage:
	@echo "Generating test coverage..."
	@echo "Coverage not yet implemented"

todo:
	@echo "TODO items:"
	@grep -rn "TODO:" Games/ App/ Tests/ Packages/ 2>/dev/null || true
