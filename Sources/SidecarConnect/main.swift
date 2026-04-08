import Foundation
import CoreGraphics

private let timeoutSeconds: UInt64 = 15_000_000_000

private func loadSidecarCore() throws -> NSObject {
    guard dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_LAZY) != nil else {
        fatalError("Failed to load SidecarCore.framework")
    }
    guard let cls = NSClassFromString("SidecarDisplayManager") as? NSObject.Type else {
        fatalError("SidecarDisplayManager class not found")
    }
    guard let manager = cls.perform(Selector(("sharedManager")))?.takeUnretainedValue() as? NSObject else {
        fatalError("Failed to get sharedManager instance")
    }
    return manager
}

private func stringProp(_ sel: String, of obj: NSObject) -> String? {
    let s = Selector((sel))
    guard obj.responds(to: s) else { return nil }
    return obj.perform(s)?.takeUnretainedValue() as? String
}

private func getDevices(_ manager: NSObject) throws -> [NSObject] {
    guard let devices = manager.perform(Selector(("devices")))?.takeUnretainedValue() as? [NSObject] else {
        fatalError("Failed to query devices")
    }
    return devices
}

private func getConnectedNames(_ manager: NSObject) -> [String] {
    let sel = Selector(("connectedDevices"))
    guard manager.responds(to: sel) else { return [] }
    guard let connected = manager.perform(sel)?.takeUnretainedValue() as? [NSObject] else { return [] }
    return connected.compactMap { stringProp("name", of: $0) }
}

private func findDevice(named name: String, in devices: [NSObject]) -> NSObject? {
    return devices.first { stringProp("name", of: $0)?.lowercased() == name.lowercased() }
}

@available(macOS 10.15, *)
private func connectDevice(_ device: NSObject, via manager: NSObject) async throws {
    let sel = Selector(("connectToDevice:completion:"))
    guard manager.responds(to: sel) else {
        fatalError("connectToDevice:completion: not available")
    }
    try await withCheckedThrowingContinuation { cont in
        let box = UnsafeMutablePointer<CheckedContinuation<Void, Error>?>.allocate(capacity: 1)
        box.initialize(to: cont)
        let closure: @convention(block) (NSError?) -> Void = { error in
            if let error = error {
                box.pointee?.resume(throwing: error)
            } else {
                box.pointee?.resume()
            }
            box.deinitialize(count: 1)
            box.deallocate()
        }
        manager.perform(sel, with: device, with: closure)
    }
}

@available(macOS 10.15, *)
private func disconnectDevice(_ device: NSObject, via manager: NSObject) async throws {
    let sel = Selector(("disconnectFromDevice:completion:"))
    guard manager.responds(to: sel) else {
        fatalError("disconnectFromDevice:completion: not available")
    }
    try await withCheckedThrowingContinuation { cont in
        let box = UnsafeMutablePointer<CheckedContinuation<Void, Error>?>.allocate(capacity: 1)
        box.initialize(to: cont)
        let closure: @convention(block) (NSError?) -> Void = { error in
            if let error = error {
                box.pointee?.resume(throwing: error)
            } else {
                box.pointee?.resume()
            }
            box.deinitialize(count: 1)
            box.deallocate()
        }
        manager.perform(sel, with: device, with: closure)
    }
}

private func setMirrorMode() {
    let mainDisplayID = CGMainDisplayID()
    let maxDisplays: UInt32 = 8
    var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else {
        fputs("Error: failed to get display list\n", stderr)
        return
    }
    for i in 0..<Int(displayCount) {
        let displayID = onlineDisplays[i]
        if displayID != mainDisplayID {
            var config: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&config) == .success else { continue }
            CGConfigureDisplayMirrorOfDisplay(config, displayID, mainDisplayID)
            let result = CGCompleteDisplayConfiguration(config, .permanently)
            if result == .success {
                print("Mirrored display \(displayID) to main display")
            } else {
                fputs("Warning: failed to mirror display \(displayID)\n", stderr)
            }
        }
    }
}

private func waitForSidecarAndMirror() {
    let mainDisplayID = CGMainDisplayID()
    let maxDisplays: UInt32 = 8
    let maxRetries = 30
    let retryInterval: useconds_t = 500_000

    for _ in 0..<maxRetries {
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else { continue }

        var hasExternal = false
        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplays[i]
            if displayID != mainDisplayID {
                hasExternal = true
                break
            }
        }
        if hasExternal {
            setMirrorMode()
            return
        }
        usleep(retryInterval)
    }
    fputs("Warning: timed out waiting for Sidecar display\n", stderr)
}

private func printUsage() {
    let name = CommandLine.arguments[0].components(separatedBy: "/").last ?? "sidecar-connect"
    print("""
    Usage:
      \(name) --list                    List available Sidecar devices
      \(name) --connect <device-name>   Connect to a device
      \(name) --disconnect              Disconnect all Sidecar devices
    """)
}

@available(macOS 10.15, *)
func main() async {
    let args = Array(CommandLine.arguments.dropFirst())

    guard let command = args.first else {
        printUsage()
        exit(1)
    }

    let manager: NSObject
    do {
        manager = try loadSidecarCore()
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    switch command {
    case "--list":
        do {
            let devices = try getDevices(manager)
            let connected = Set(getConnectedNames(manager))
            if devices.isEmpty {
                print("No Sidecar devices found.")
            } else {
                for d in devices {
                    if let name = stringProp("name", of: d) {
                        let status = connected.contains(name) ? " [connected]" : ""
                        print("  \(name)\(status)")
                    }
                }
            }
        } catch {
            fputs("Error listing devices: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

    case "--connect":
        guard args.count > 1 else {
            fputs("Error: --connect requires a device name\n", stderr)
            exit(1)
        }
        let targetName = args[1]
        do {
            let devices = try getDevices(manager)
            let connected = Set(getConnectedNames(manager))
            if connected.contains(where: { $0.lowercased() == targetName.lowercased() }) {
                print("Already connected to \(targetName)")
                exit(0)
            }
            guard let device = findDevice(named: targetName, in: devices) else {
                fputs("Device '\(targetName)' not found.\n", stderr)
                exit(1)
            }
            print("Connecting to \(targetName)...")
            try await connectDevice(device, via: manager)
            print("Connected to \(targetName)")
            waitForSidecarAndMirror()
        } catch {
            fputs("Connection failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

    case "--disconnect":
        do {
            let connectedNames = getConnectedNames(manager)
            if connectedNames.isEmpty {
                print("No active Sidecar connections")
                exit(0)
            }
            let devices = try getDevices(manager)
            for name in connectedNames {
                if let device = findDevice(named: name, in: devices) {
                    print("Disconnecting \(name)...")
                    try await disconnectDevice(device, via: manager)
                    print("Disconnected \(name)")
                }
            }
        } catch {
            fputs("Disconnect failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

    default:
        printUsage()
        exit(1)
    }
}

if #available(macOS 10.15, *) {
    await main()
} else {
    fputs("Requires macOS 10.15 or later\n", stderr)
    exit(1)
}
