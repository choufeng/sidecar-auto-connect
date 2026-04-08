// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "sidecar-connect",
    targets: [
        .executableTarget(
            name: "SidecarConnect",
            path: "Sources/SidecarConnect"
        )
    ]
)
