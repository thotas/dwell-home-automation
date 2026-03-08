# Dwell

Dwell is a macOS-native, dark-themed home automation desktop app that unifies devices across Apple Home, Google Nest, Alexa, Govee, Ring, and Wyze.

## Features
- Guided provider connection wizard with credential editor
- Unified device dashboard and controls
- Cross-platform automation rules (`Ring motion -> Govee switch on`)
- Scene/group support
- Daily schedule support
- Execution log timeline

## Provider Integration Modes
- Apple Home: HomeKit API (requires signed app with HomeKit entitlement + `NSHomeKitUsageDescription`)
- Google Nest: Smart Device Management API (access token + enterprise/project id)
- Govee: Govee Open API (API key)
- Alexa, Ring, Wyze: Home Assistant bridge mode (Home Assistant URL + long-lived token + entity filters)

## Run

```bash
swift build
swift run DwellApp
```

## Test

```bash
swift test
```
