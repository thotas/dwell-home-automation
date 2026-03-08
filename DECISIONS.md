# Technical Decisions

## Why SwiftUI + Swift Package Manager
- Native macOS UX requirement
- Fast iteration and testability with local package modules

## Why Local-First with Adapter Abstraction
- Keeps user data local and reduces infrastructure dependencies
- Supports gradual migration from mock to real provider APIs

## Why Mock Providers in v1
- Enables end-to-end development and testing immediately
- De-risks UI/domain logic before API credential and ecosystem onboarding

## Why Rule Templates
- Speeds onboarding for core use case
- Demonstrates cross-provider orchestration with minimal setup
