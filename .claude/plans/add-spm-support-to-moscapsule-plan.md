# Plan: Add SPM Support to Moscapsule

## Context
Moscapsule currently ships only as a CocoaPods pod. Adding a `Package.swift` lets consumers integrate it via Xcode's built-in SPM without CocoaPods. The upstream diamirio fork has no SPM support, so this is additive — the podspec stays untouched.

The main challenge is the three-layer dependency chain: OpenSSL (external) → Mosquitto C sources → ObjC bridge → Swift API.

## Target Structure

Swift 5.9 supports mixed Swift/Objective-C in a single SPM target (ObjC headers exposed via `include/`), so we need only two targets:

```
CMosquitto   (C)              mosquitto/lib/*.c + *.h
Moscapsule   (Swift + ObjC)   Moscapsule/Moscapsule.swift
                               Moscapsule/MosquittoCallbackBridge.m
                               Moscapsule/include/MosquittoCallbackBridge.h  ← move here
```

Dependencies: `CMosquitto ← Moscapsule`

## Files to Create/Modify

### 1. `Package.swift` (new)

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Moscapsule",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "Moscapsule", targets: ["Moscapsule"]),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/OpenSSL-Package", from: "1.1.1200"),
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
            ]
        ),
        .target(
            name: "Moscapsule",
            dependencies: ["CMosquitto"],
            path: "Moscapsule",
            publicHeadersPath: "include"
        ),
    ]
)
```

### 2. `mosquitto/lib/module.modulemap` (new)

Required so SPM exposes `mosquitto.h` as a proper C module that Swift/ObjC can import:

```
module CMosquitto {
    header "mosquitto.h"
    export *
}
```

### 3. `Moscapsule/include/` directory (new)

Move `MosquittoCallbackBridge.h` from `Moscapsule/` into a new `Moscapsule/include/` subdirectory. SPM uses `publicHeadersPath: "include"` to expose these headers so Swift code in the same target can see the ObjC declarations.

`Moscapsule.h` (the umbrella header used by CocoaPods) stays in place — it's not needed by SPM.

## Key Decisions

- **Swift 5.9 / iOS 13** — enables single mixed-language target; iOS 13 users on CocoaPods are unaffected.
- **`OpenSSL-Package` (krzyzanowskim)** — precompiled xcframeworks, drop-in equivalent to `OpenSSL-Universal` already in the podspec. Confirm product name (`OpenSSL` vs `OpenSSL_iOS`) at implementation time.
- **`publicHeadersPath: "."` for `CMosquitto`** — all `.h` files in `mosquitto/lib/` are internal; the module map controls what's actually exported.
- **One file move** — `MosquittoCallbackBridge.h` → `Moscapsule/include/MosquittoCallbackBridge.h`. The podspec `Moscapsule/*.{h,m,swift}` glob still picks it up if moved, or we add an explicit path; verify after moving.

## Merlin Consumption Notes

Merlin (`merlin-ios-app/Merlin/Swarovski/`) wraps Moscapsule in an `MQTTSession` singleton and a topic DSL — it never exposes Moscapsule types directly to the rest of the app. Current dependency is CocoaPods pointing at the `tailoredmedia` fork (aka `diamirio`) on the `openssl-update` branch (i.e., this repo/branch).

**API surface Merlin uses** (all must remain accessible after SPM restructure):
- `moscapsule_init()` / `moscapsule_cleanup()` — C functions exposed to Swift
- `MQTTConfig(clientId:host:port:keepAlive:)` + callback properties + `mqttWillOpts`, `mqttAuthOpts`, `mqttServerCert`
- `MQTT.newConnection(_:connectImmediately:)`
- `MQTTClient.isConnected`, `.publish(...)`, `.subscribe(...)`, `.unsubscribe(...)`, `.disconnect()`
- `MQTTMessage`, `MQTTWillOpts`, `MQTTAuthOpts`, `MQTTServerCert`, `MosqResult`, `ReturnCode`, `ReasonCode`

Updating Merlin's Podfile → SPM is a **follow-on task** (ME-889 AC item), not in scope here.

## Verification

```bash
# Resolve packages
swift package resolve

# Build for iOS simulator (requires Xcode)
xcodebuild build \
  -scheme Moscapsule \
  -destination 'generic/platform=iOS Simulator' \
  -clonedSourcePackagesDirPath .build

# Optional: generate Xcode project to inspect
swift package generate-xcodeproj
```

If the `MoscapsuleBridge` + `Moscapsule` sharing `path: "Moscapsule"` causes a conflict, fallback is moving `Moscapsule.swift` into a new `Sources/Moscapsule/` directory (or the reverse — moving the bridge). We'll try the no-move approach first.

## Wrap-Up (after implementation is verified)

1. **Reduce this plan** to a final checklist matching ME-889's acceptance criteria
2. **Update ME-889** (`clo-tech.atlassian.net/browse/ME-889`) — mark completed ACs and add a comment linking the OSS PR
3. **Open a PR** against `flightonary/Moscapsule` (or `diamirio/Moscapsule`, the immediate upstream OSS fork) from our branch
