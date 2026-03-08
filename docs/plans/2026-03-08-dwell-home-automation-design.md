# Dwell Requirements and Design Document (Brainstormed)

- Date: 2026-03-08
- Product: Dwell
- Goal: End-to-end requirements for a macOS-native home automation platform
- Theme requirement: Dark-themed desktop experience

## 1. Problem Statement
Users with mixed smart-home ecosystems (Apple Home, Google Nest, Alexa, Govee, Ring, Wyze) have fragmented control and weak cross-platform automation. Dwell will provide one macOS-native control center to connect accounts, discover devices, control them, group them, and create schedules/automations across ecosystems.

## 2. Scope Summary

### In Scope
- Native macOS desktop app (SwiftUI-first)
- Dark-themed UI by default
- Connector setup for Apple Home, Google Nest, Alexa, Govee, Ring, Wyze
- Unified device control surface
- Scheduling and reusable group/scene management
- Cross-platform rules, e.g., `Ring motion detected -> turn on Govee switch`
- Easy onboarding flow for connecting systems

### Out of Scope (v1)
- iOS, Android, web clients
- Device firmware updates
- Hardware hub manufacturing
- Full voice assistant replacement

## 3. Brainstorming Session (6 Experts, 3 Rounds)

### 3.1 Expert Panel
1. Product Manager (PM): User journeys, prioritization, release slicing
2. macOS Architect: Native app architecture, system APIs, performance
3. Integrations Engineer: OAuth/API constraints across providers
4. Automation Engine Engineer: Rules model, scheduler, runtime reliability
5. Security/Privacy Engineer: Token handling, local secrets, consent/audit
6. UX Designer: Dark theme, onboarding simplicity, mental model

### 3.2 Round 1: User Value and Product Boundaries
- PM: The first release must solve "single pane of glass" for mixed homes.
- UX: Setup must feel guided; users should connect first provider in <3 minutes.
- Integrations: Providers differ; promise unified controls but surface capability gaps clearly.
- Security: Require explicit consent per provider and per home/location where applicable.
- Consensus:
  - MVP must include connect, discover, control, basic schedule, and cross-provider rule creation.
  - "Easy interface" means wizard-driven onboarding and a capability-aware device list.

### 3.3 Round 2: Architecture and Interoperability
- macOS Architect: Use layered architecture: UI -> Domain -> Adapter layer.
- Automation Engineer: Rules must use normalized events/actions and idempotent execution.
- Integrations Engineer: Build one adapter per provider with capability mapping and token refresh.
- Security: Isolate credentials in macOS Keychain; encrypt local cache at rest.
- Debate outcome:
  - Recommended architecture: Local-first macOS app with optional cloud relay service only when provider/webhook constraints require always-on event intake.
  - Keep provider-specific edge cases in adapters, not in UI or rule engine.

### 3.4 Round 3: Reliability, UX, and Delivery
- Automation Engineer: Add retry policy, dead-letter queue, and execution logs.
- UX: Rules need plain-language builder and visual validation (trigger/condition/action).
- PM: Include templated automations (e.g., motion-lighting).
- Security: Implement least-privilege scopes and explicit disconnect/revoke flow.
- Consensus:
  - Ship MVP with deterministic scheduling, audit logs, and connector health status.
  - Enforce clear "unsupported capability" handling instead of silent failures.

### 3.5 Decisions Locked After Round 3
- Dwell is a native macOS dark-themed desktop app.
- Unified control is implemented via normalized device model + provider adapters.
- Scheduling, grouping, and rule automation are first-class features.
- Onboarding is wizard-based and optimized for minimal friction.
- Reliability and transparency (logs, errors, adapter health) are release blockers.

### 3.6 Approaches Considered (with Trade-offs)
1. Local-only architecture (no backend services)
- Pros: simpler privacy story, lower ops cost, minimal infrastructure.
- Cons: weaker always-on event capture for providers requiring webhooks, reduced reliability when app is closed.

2. Cloud-first orchestration (backend as primary runtime)
- Pros: consistent event handling, always-on automations, centralized observability.
- Cons: higher cost/complexity, larger privacy/compliance surface, slower MVP.

3. Hybrid local-first (recommended)
- Pros: keeps primary control/local state on macOS while adding optional cloud relay only for provider/event constraints; balances privacy and reliability.
- Cons: more architecture complexity than local-only.

Recommendation: adopt Hybrid local-first to meet cross-provider automation reliability without forcing full cloud dependency in v1.

## 4. Product Goals and Success Criteria

### Goals
- G1: Connect at least one ecosystem in under 3 minutes median time.
- G2: Allow controlling any connected supported device from one dashboard.
- G3: Allow users to create cross-ecosystem automation rules in under 2 minutes.
- G4: Provide stable schedule and rule execution with observable logs.

### Success Metrics
- 90%+ successful first-time connector completion per provider (where credentials valid)
- 95%+ command delivery success for online devices
- <2% rule execution failure rate excluding provider outages
- CSAT >= 4.3/5 for setup and automation creation flows

## 5. User Personas
- Home Power User: Many devices across multiple brands, wants advanced automations.
- Household Admin: Wants simple shared routines and minimal maintenance.
- Installer/Integrator: Needs predictable setup and diagnostics.

## 6. Core User Journeys
1. Connect Providers
- Launch app -> onboarding wizard -> choose provider -> authorize -> confirm discovery.

2. Control Devices
- Browse by room/type/provider -> toggle, dim, lock, arm, etc. (capability dependent).

3. Create Group/Scene
- Select devices across providers -> define target states -> save as group/scene.

4. Create Rule
- Example: `Ring Motion Sensor (Front Door) detects motion` -> `Turn on Govee Porch Switch for 10 minutes`.

5. Create Schedule
- Time-based recurring action (daily/weekday/sunset offset where supported).

6. Troubleshoot
- View connector status, last sync, failed actions, rule execution history.

## 7. Functional Requirements

### 7.1 Platform and UX
- FR-001: App must be native macOS desktop (SwiftUI preferred).
- FR-002: Dark theme is default and fully supported across all screens.
- FR-003: UI must remain responsive during discovery/sync/action operations.
- FR-004: Accessibility baseline: keyboard navigation, VoiceOver labels, sufficient contrast.

### 7.2 Account and Identity
- FR-010: Support local profile with optional iCloud/private sync of app settings.
- FR-011: Require re-auth prompts on token expiration/permission changes.

### 7.3 Provider Connections
- FR-020: Connect/disconnect flows for Apple Home, Google Nest, Alexa, Govee, Ring, Wyze.
- FR-021: Each provider adapter must support token refresh, health checks, and scope display.
- FR-022: Connector wizard must show required permissions before authorization.
- FR-023: Surface provider-specific limitations during setup (not hidden).

### 7.4 Discovery and Device Model
- FR-030: Discover devices from each connected provider.
- FR-031: Normalize into a common model: `Device`, `Capability`, `Location`, `State`.
- FR-032: Preserve provider-native metadata and IDs for diagnostics.
- FR-033: Allow manual refresh and automatic periodic sync.

### 7.5 Device Control
- FR-040: Execute commands via unified controls for supported capabilities.
- FR-041: Show command result states: pending/success/failed with reason.
- FR-042: Batch control multiple devices atomically where provider allows, otherwise best-effort with partial-failure reporting.

### 7.6 Grouping and Scenes
- FR-050: User can create/edit/delete device groups across providers.
- FR-051: User can create scenes containing target states for multiple devices.
- FR-052: Scene activation should produce per-device execution status.

### 7.7 Scheduling
- FR-060: Time-based schedules: one-time, daily, weekly, custom recurrence.
- FR-061: Timezone-aware scheduling with DST-safe behavior.
- FR-062: Skip/disable/enable schedule controls.
- FR-063: Schedule conflict handling and preview of next run.

### 7.8 Automation Rules
- FR-070: Event trigger support (sensor motion/contact/state change) where provider exposes events.
- FR-071: Condition support: time window, device state, day-of-week.
- FR-072: Actions: device command, scene activation, delayed action.
- FR-073: Rule editor must support cross-provider trigger->action chains.
- FR-074: Rule simulator/test-run with dry-run diagnostics.

### 7.9 Logs and Notifications
- FR-080: Maintain action/rule execution logs with timestamps and provider details.
- FR-081: Provide toast/in-app alerts for critical failures (auth revoked, repeated failures).
- FR-082: Export logs for support.

### 7.10 Easy Connection UX
- FR-090: Onboarding wizard with provider tiles, progress stepper, and retry paths.
- FR-091: "Fix connection" CTA from any failed connector card.
- FR-092: Minimal-steps design: first provider connect <= 6 interactions after selecting provider.

## 8. Non-Functional Requirements
- NFR-001 Performance: initial dashboard load <= 2s after warm start (excluding live sync).
- NFR-002 Reliability: scheduler/rule engine crash-safe with persistent queue recovery.
- NFR-003 Security: secrets in macOS Keychain; tokens never logged.
- NFR-004 Privacy: local-first data storage; collect only required telemetry with opt-in.
- NFR-005 Observability: structured logs + connector/rule health metrics.
- NFR-006 Maintainability: provider adapters versioned and testable independently.

## 9. Technical Architecture (Recommended)

### 9.1 High-Level Components
1. `DwellApp` (SwiftUI): views, view models, navigation, dark design system
2. `Domain Core`: devices, capabilities, scenes, schedules, rules, validation
3. `Automation Runtime`: trigger ingestion, condition evaluation, action execution, retries
4. `Provider Adapter Layer`: Apple Home, Nest, Alexa, Govee, Ring, Wyze adapters
5. `Persistence`: SQLite/CoreData for local models; Keychain for secrets
6. `Connectivity Services`: webhook/polling/event listeners depending on provider capability

### 9.2 Data Model (Conceptual)
- `ProviderConnection(id, provider, status, scopes, tokenRef, lastSyncAt)`
- `Device(id, providerDeviceId, provider, name, type, room, online)`
- `Capability(id, deviceId, kind, writable, schema)`
- `Scene(id, name, actions[])`
- `Schedule(id, sceneOrRuleId, recurrence, timezone, enabled)`
- `Rule(id, trigger, conditions[], actions[], enabled)`
- `ExecutionLog(id, sourceType, sourceId, status, startedAt, endedAt, error)`

### 9.3 Data Flow
1. Connector auth -> token stored in Keychain -> adapter validates scopes.
2. Discovery sync -> normalized devices/capabilities persisted locally.
3. User action/rule trigger -> runtime builds execution plan.
4. Runtime dispatches to adapters -> collects responses -> writes logs/UI updates.

## 10. Provider Integration Requirements and Constraints

### 10.1 Required Adapter Contract
All provider adapters must implement:
- `authorize()`
- `refreshToken()`
- `discoverDevices()`
- `subscribeEvents()` or `pollEvents()`
- `executeCommand(device, capability, value)`
- `mapProviderError()`

### 10.2 Capability Matrix Requirement
- Must maintain a matrix of supported device types/capabilities per provider.
- UI/rule builder can only offer valid actions for selected device(s).
- Unsupported capabilities must show explicit reason and fallback guidance.

### 10.3 Feasibility Gates
Because provider APIs vary and may restrict full control:
- Gate-1: Validate official API access terms for each provider before sprint 2 ends.
- Gate-2: Mark unsupported/partner-only features as `Deferred` with rationale.
- Gate-3: Never market unsupported control paths as available.

## 11. Error Handling Requirements
- ER-001: Classify errors into auth, network, provider, validation, and runtime categories.
- ER-002: Every failed command must include user-actionable remediation.
- ER-003: Automatic retries for transient failures with exponential backoff.
- ER-004: Permanent failures go to dead-letter queue with re-run action.

## 12. Security and Privacy Requirements
- SEC-001: Store all provider tokens in Keychain only.
- SEC-002: Encrypt local cache/database at rest where practical.
- SEC-003: Least-privilege scopes per provider.
- SEC-004: Explicit disconnect/revoke function removes tokens and stops event subscriptions.
- SEC-005: Audit trail for auth, control actions, and automation changes.

## 13. Testing and Verification Strategy

### 13.1 Test Layers
- Unit tests: domain logic, rule condition evaluator, schedule calculator
- Adapter contract tests: each provider adapter against mocked provider responses
- Integration tests: end-to-end flows with simulated events
- UI tests: onboarding wizard, rule builder, dashboard control
- Resilience tests: offline recovery, token expiry, provider outage

### 13.2 Required Acceptance Tests
1. Connect each provider and discover at least one test device.
2. Execute direct control command and verify device state update in UI.
3. Create cross-provider rule (`Ring motion -> Govee switch on`) and verify execution.
4. Create recurring schedule and verify exact run timing across DST boundary simulation.
5. Revoke provider auth and verify app surfaces repair path.

## 14. Delivery Plan (Milestones)

### M1: Foundations (Weeks 1-3)
- App shell, dark design system, local persistence, connector framework

### M2: Core Integrations + Control (Weeks 4-8)
- Ship first adapters and unified dashboard control

### M3: Automation + Scheduling (Weeks 9-12)
- Rule builder, scheduler, execution runtime, logs

### M4: Hardening + UX polish (Weeks 13-16)
- Error handling, performance, accessibility, support tooling

## 15. Open Risks and Mitigations
- Risk: Provider API limitations for complete control coverage.
  - Mitigation: Capability matrix + transparent support status + phased adapter maturity.
- Risk: Event delivery inconsistency across providers.
  - Mitigation: Hybrid webhook/polling and idempotent runtime.
- Risk: Token churn or auth revocation.
  - Mitigation: proactive health checks and reconnect wizard.

## 16. Definition of Done (v1)
- All mandatory functional requirements FR-001 to FR-092 implemented or explicitly deferred with approval.
- At least one validated device type per provider connected in production-like environment.
- Cross-provider automation and schedule features pass acceptance tests.
- Security/privacy requirements SEC-001 to SEC-005 verified.
- Documentation available for architecture, setup, and support diagnostics.

## 17. Recommended Build Approach
Use a layered architecture with strict adapter boundaries and ship in vertical slices:
1. Dark-themed macOS app shell + connector onboarding
2. Unified discovery/control model
3. Scheduling and cross-provider rules
4. Reliability/security hardening and integration expansion

This sequence maximizes early user value while reducing integration risk.
