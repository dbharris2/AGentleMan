# AGentleMan - macOS Agent Session Manager

# List available recipes
default:
    @just --list

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build the app (regenerates project first)
build: generate
    xcodebuild -scheme AGentleMan -configuration Debug build

# Run the app (builds first, kills existing instance)
run: build
    -pkill -x AGentleMan
    @open "$( xcodebuild -scheme AGentleMan -configuration Debug -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}' )/AGentleMan.app"

# Open the app without rebuilding
open:
    -pkill -x AGentleMan
    @open "$( xcodebuild -scheme AGentleMan -configuration Debug -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}' )/AGentleMan.app"

# Run SwiftFormat to auto-fix formatting
format:
    swiftformat .

# Run SwiftLint with auto-fix
lint-fix:
    swiftlint --fix

# Check formatting and linting without modifying files
lint:
    swiftformat . --lint
    swiftlint

# Run unit tests
test: generate
    xcodebuild -scheme AGentleMan -configuration Debug -destination 'platform=macOS' test

# Clean build artifacts
clean:
    xcodebuild -scheme AGentleMan -configuration Debug clean
    rm -rf ~/Library/Developer/Xcode/DerivedData/AGentleMan-*

# Open project in Xcode
xcode: generate
    open AGentleMan.xcodeproj
