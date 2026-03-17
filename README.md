# Dwell

Dwell is a macOS-native, dark-themed home automation desktop app that unifies devices across Apple Home, Google Nest, Alexa, Govee, Ring, and Wyze into a single, intuitive interface.

## Features

- **Guided Provider Connection**: Step-by-step wizard for connecting smart home providers
- **Credential Editor**: Secure storage and management of API credentials
- **Unified Dashboard**: View and control all your smart devices in one place
- **Automation Rules**: Create cross-provider automations (e.g., Ring motion -> Govee switch on)
- **Scene Management**: Group devices into scenes for one-tap control
- **Scheduling**: Set up daily schedules to trigger scenes automatically
- **Execution Logs**: Timeline view of all automation executions with status

## Provider Integration Modes

| Provider | Integration Method |
|----------|-------------------|
| Apple Home | HomeKit API (requires signed app with HomeKit entitlement) |
| Google Nest | Smart Device Management API (access token + enterprise/project id) |
| Govee | Govee Open API (API key) |
| Alexa, Ring, Wyze | Home Assistant bridge mode (Home Assistant URL + long-lived token) |

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)

## Building

```bash
# Clone and navigate to the project
cd Dwell

# Build the project
swift build

# Run in development
swift run DwellApp
```

## Testing

```bash
swift test
```

## App Icon

The app icon is generated programmatically using Python with Pillow. To regenerate:

```bash
python3 create_icon.py
```

This creates a high-resolution Apple-style icon with a gradient background and house symbol.

## Architecture

Dwell uses a modular architecture:

- **DwellCore**: Shared business logic, models, and provider adapters
- **DwellApp**: SwiftUI desktop application

### Key Components

- `ProviderAdapter`: Protocol for implementing new provider integrations
- `AutomationEngine`: Rule processing and execution
- `AppState`: Central state management with Combine
- `RuleStore`: Persistence for automation rules

## License

MIT
