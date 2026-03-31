# Plan: Add SPM Support to Moscapsule

## Implementation: DONE

3-target `Package.swift` committed on `openssl-update` branch.

```
CMosquitto          mosquitto/lib/        C only
CMoscapsuleBridge   MoscapsuleBridge/     ObjC bridge
Moscapsule          Moscapsule/           Swift only
```

## Remaining

- [x] Integration test — builds and links successfully as a Swift Package
- [ ] Open PR against `flightonary/Moscapsule`
- [ ] Document PR status and maintainer response

