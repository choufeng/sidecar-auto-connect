.PHONY: build install uninstall clean

BIN_DST := $(HOME)/bin/sidecar-connect
SCRIPT_SRC := sidecar-auto-connect.sh
APP_SRC := SidecarAutoConnect.app
APP_DST := /Applications/SidecarAutoConnect.app
PLIST_SRC := com.user.sidecar-connect.plist
PLIST_DST := $(HOME)/Library/LaunchAgents/$(PLIST_SRC)

build:
	swift build -c release

install: build
	cp .build/release/SidecarConnect $(BIN_DST)
	codesign --force --deep -s - $(BIN_DST)
	xattr -cr $(BIN_DST)
	chmod +x $(SCRIPT_SRC)
	rm -rf $(APP_DST)
	osacompile -o $(APP_DST) SidecarAutoConnect.applescript
	osascript -e 'tell application "System Events" to make login item at end with properties {path:"$(APP_DST)", hidden:true}' 2>/dev/null || true
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	cp $(PLIST_SRC) $(PLIST_DST)
	plutil -convert binary1 $(PLIST_DST)
	launchctl load $(PLIST_DST)

uninstall:
	launchctl unload $(PLIST_DST) 2>/dev/null || true
	rm -f $(PLIST_DST)
	osascript -e 'tell application "System Events" to delete login item "SidecarAutoConnect"' 2>/dev/null || true
	rm -rf $(APP_DST)
	rm -f $(BIN_DST)

clean:
	swift package clean
	rm -rf SidecarAutoConnect.app
