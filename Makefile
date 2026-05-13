.PHONY: project open install reinstall clean

# Generate Cueline.xcodeproj from project.yml.
project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; }
	xcodegen generate

# Open the project in Xcode.
open: project
	open Cueline.xcodeproj

# Build a Release .app and install it to /Applications, replacing any prior copy.
# Quits a running instance first so menu-bar icons don't double up.
install: project
	xcodebuild -project Cueline.xcodeproj -scheme Cueline -configuration Release -derivedDataPath build clean build
	-pkill -x Cueline 2>/dev/null
	rm -rf /Applications/Cueline.app
	cp -R build/Build/Products/Release/Cueline.app /Applications/Cueline.app
	open /Applications/Cueline.app

# Same as install but skip the clean step — faster for iterative dev.
reinstall: project
	xcodebuild -project Cueline.xcodeproj -scheme Cueline -configuration Release -derivedDataPath build build
	-pkill -x Cueline 2>/dev/null
	rm -rf /Applications/Cueline.app
	cp -R build/Build/Products/Release/Cueline.app /Applications/Cueline.app
	open /Applications/Cueline.app

clean:
	rm -rf Cueline.xcodeproj build DerivedData
