# Dwell Architecture

## Layers
- `DwellApp` (SwiftUI): desktop UI and interaction flows
- `DwellCore`: domain models, provider adapter contracts, automation engine, scheduling, persistence, app state

## Key Components
- `ProviderRegistry`: resolves provider adapter for each ecosystem
- `MockProviderAdapter`: simulated connectors/devices for Apple Home, Google Nest, Alexa, Govee, Ring, Wyze
- `DeviceControlService`: provider-agnostic command dispatch
- `AutomationEngine`: trigger/action rule execution
- `Schedule`: recurrence model and next-run calculation
- `AppState`: orchestration boundary between UI and domain services

## Data Flow
1. User connects a provider in the wizard.
2. App discovers provider devices and normalizes into `Device` models.
3. User sends commands from dashboard; `DeviceControlService` routes to adapter.
4. Automation events are evaluated by `AutomationEngine` and actions dispatched.
5. Logs are recorded and surfaced in the logs tab.

## Persistence
`RuleStore` persists automation rules to JSON in local storage.
