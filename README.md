# Sidecar Connect

[中文文档](README.zh-CN.md)

A macOS command-line tool for managing Apple Sidecar display connections. It calls the private `SidecarCore.framework` to list, connect, and disconnect Sidecar devices from the terminal, with automatic mirror mode setup on connection.

## Features

- **List devices** — View all available Sidecar devices and their connection status
- **Connect** — Connect to a Sidecar device by name; automatically enables mirror mode after connecting
- **Disconnect** — Disconnect all active Sidecar connections
- **Auto-connect** — Launch at login via launchd or login item

## Requirements

- macOS 10.15 (Catalina) or later
- Xcode Command Line Tools (Swift 5.9+)

## Build

```bash
make build
```

The binary is output to `.build/release/SidecarConnect`.

## Install

```bash
make install
```

This will:

1. Build the release binary and install it to `~/bin/sidecar-connect`
2. Codesign the binary and clear extended attributes
3. Compile the AppleScript login item app to `/Applications/SidecarAutoConnect.app`
4. Add it as a macOS login item
5. Install the launchd plist to `~/Library/LaunchAgents/` and load it

## Uninstall

```bash
make uninstall
```

## Usage

```bash
# List available devices
sidecar-connect --list

# Connect to a device (case-insensitive)
sidecar-connect --connect iPad

# Disconnect all connections
sidecar-connect --disconnect
```

After a successful connection, the tool automatically sets the Sidecar display to mirror the main display.

## Auto-connect

After installation, the system will automatically run `sidecar-connect --connect iPad` at login via launchd.

For periodic reconnection every 60 seconds (useful for Bluetooth devices that intermittently disconnect), use `com.user.sidecar-auto.plist` instead:

```bash
cp com.user.sidecar-auto.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.sidecar-auto.plist
```

> **Note**: The two plists should not be enabled at the same time. Unload the existing one before switching.

Log files are located at `/tmp/sidecar-connect.log` and `/tmp/sidecar-connect.err`.

## Caveats

- This tool relies on the private `SidecarCore.framework`, which may break with macOS updates
- The default device name for auto-connect is `iPad`; modify the plist and script if your device has a different name
- Mirror mode mirrors all non-main displays to the main display

## License

[MIT](LICENSE)