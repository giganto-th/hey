// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Hey",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "heynp", type: .dynamic, targets: ["HeyNowPlaying"]),
    ],
    targets: [
        .target(name: "HeyDomain"),
        // Tiny C library that /usr/bin/perl loads to read the system's Now Playing info (see heynp.h).
        .target(name: "HeyNowPlaying"),
        .executableTarget(
            name: "Hey",
            dependencies: ["HeyDomain"],
            exclude: ["Info.plist"],     // embedded by the linker below, not a resource
            // Gives the bare executable an identity and the camera/mic usage strings macOS insists on.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                "-Xlinker", "\(Context.packageDirectory)/Sources/Hey/Info.plist",
            ])]),
        .testTarget(name: "HeyDomainTests", dependencies: ["HeyDomain"]),
    ]
)
