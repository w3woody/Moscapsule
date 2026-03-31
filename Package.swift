// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Moscapsule",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Moscapsule", targets: ["Moscapsule"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/OpenSSL-Package", from: "3.3.2000"),
    ],
    targets: [
        .target(
            name: "CMosquitto",
            dependencies: [
                .product(name: "OpenSSL", package: "OpenSSL-Package"),
            ],
            path: "mosquitto/lib",
            publicHeadersPath: ".",
            cSettings: [
                .define("WITH_THREADING"),
                .define("WITH_TLS"),
                .define("WITH_TLS_PSK"),
                .headerSearchPath("../../Moscapsule"),  // for config.h (dummy header)
            ]
        ),
        .target(
            name: "CMoscapsuleBridge",
            dependencies: ["CMosquitto"],
            path: "MoscapsuleBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Moscapsule",
            dependencies: ["CMoscapsuleBridge"],
            path: "Moscapsule",
            sources: ["Moscapsule.swift"]
        ),
    ]
)
