# Dwell

Dwell is a macOS-native, dark-themed home automation desktop app that unifies devices across Apple Home, Google Nest, Alexa, Govee, Ring, and Wyze.

## Features
- Guided provider connection wizard
- Unified device dashboard and controls
- Cross-platform automation rules (`Ring motion -> Govee switch on`)
- Scene/group support
- Daily schedule support
- Execution log timeline

## Run

```bash
swift build
swift run DwellApp
```

## Test

```bash
swift test
```

## Notes
This implementation ships with mock provider adapters so the product can run end-to-end without external credentials. Adapter boundaries are designed for real API integrations.
