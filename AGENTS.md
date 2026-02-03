# AGENTS.md - Dhavnii Development Guide

This guide helps AI agents work effectively in the Dhavnii codebase.

## Project Overview

**Dhavnii** is a macOS voice transcription app built with SwiftUI, Swift 5, and SwiftData. It's a menu bar app with global hotkey activation (Option+Space) for speech-to-text transcription.

- **Language:** Swift 5.0
- **Platform:** macOS 26.2+
- **Architecture:** MVVM with Observable objects
- **Dependencies:** None (pure system frameworks)

## Build Commands

### Development Build
```bash
# Build from command line
xcodebuild -scheme dhavnii -configuration Debug build

# Open in Xcode for development
open dhavnii.xcodeproj
```

### Release Build & Install
```bash
# Full release build and install to /Applications
./Scripts/build_release.sh
```

### Reset Testing Environment
```bash
# Reset permissions for clean testing
./Scripts/reset_permissions.sh

# Restart app after permission changes
./Scripts/restart_app.sh
```

## Testing Commands

**Note:** This project uses manual/integration testing only. No automated unit tests exist.

### Manual Testing Workflow
```bash
# 1. Reset environment
./Scripts/reset_permissions.sh

# 2. Build and run
xcodebuild -scheme dhavnii -configuration Debug build && open dhavnii.xcodeproj

# 3. Test scenarios (see TESTING_GUIDE.md)
# - Permission flows
# - Hotkey activation (Option+Space)
# - Recording and transcription
# - Settings management
```

### Performance Testing
- Target: <5% CPU at idle, <15% during recording
- Animation target: 60fps
- Memory: <100MB typical usage

## Code Style Guidelines

### Access Control
- Use explicit `internal` for internal visibility
- Default to `internal` for types and members
- Use `private` for implementation details

### Naming Conventions
- **Types:** PascalCase (`HomeView`, `PermissionManager`)
- **Properties/Functions:** camelCase (`checkPermissions()`, `recordingState`)
- **Constants:** Static properties in enums (`UIConstants.Window.mainWidth`)
- **Files:** Suffix matches type (`*View.swift`, `*Manager.swift`, `*Service.swift`)

### Imports
```swift
import SwiftUI
import SwiftData  // For data persistence
import AVFoundation  // For audio
import Carbon.HIToolbox  // For hotkeys
```

### File Organization
Use MARK sections for organization:
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
```

### Header Format
```swift
//
//  Filename.swift
//  dhavnii
//
//  Brief description
//
```

### Type Conventions
- Use `@Observable` for data models (Swift 6 style)
- Use `@MainActor` for UI-related classes
- Use `@State` and `@Bindable` in Views
- Use structs for value types, classes for reference types with identity

### Error Handling
- Use the `FeedbackManager` for user-facing errors
- Log to console with emojis: `print("❌ Error: \(error)")`
- Provide actionable error messages in toasts

### Animation Patterns
```swift
// Use pre-configured spring animations
.smoothScale(isActive: isExpanded)
.smoothOpacity(isVisible: isShowing)

// Use constants from UIConstants
UIConstants.Animation.standard  // 0.3s
UIConstants.Spacing.large       // 16pt
```

## Architecture

### MVVM Structure
- **Views:** SwiftUI with `@State`, `@Binding`
- **ViewModels:** Observable classes (`PermissionManager`, `HistoryManager`)
- **Models:** SwiftData models (`TranscriptionRecord`, `HistoryPreferences`)

### Key Components
- `dhavniiApp.swift` - App entry point, DI container setup
- `HomeView.swift` - Main window UI
- `SettingsView.swift` - Settings tabs (Permissions, General, About)
- `NotchOverlayView.swift` - Recording overlay with animations
- `PermissionManager.swift` - Permission detection and monitoring
- `TranscriptionService.swift` - Recording/transcription orchestration
- `AnimationHelpers.swift` - Reusable animation modifiers
- `UIConstants.swift` - Centralized design system constants

### Design System
- **Colors:** Blue (mic), Purple (accessibility), Green (success), Red (errors)
- **Spacing:** 4, 8, 12, 16, 20, 24pt scale
- **Window Sizes:** Main 800x600, Onboarding 450x550
- **Icons:** SF Symbols (40pt standard, 80pt app icon)

## Entitlements & Security

Key entitlements in `dhavnii.entitlements`:
- `com.apple.security.device.microphone` = true
- `com.apple.security.network.client` = true
- Sandboxing disabled (for accessibility access)
- Hardened runtime enabled

## Common Tasks

### Adding a New View
1. Create `NewFeatureView.swift` in `dhavnii/`
2. Follow View suffix naming
3. Use `@Bindable` for state management
4. Add to appropriate parent view or window group

### Adding a New Manager
1. Create `NewFeatureManager.swift` in `dhavnii/`
2. Use `@Observable` class with `@MainActor`
3. Add to `dhavniiApp.swift` initialization
4. Inject via environment or bindings

### Working with SwiftData
```swift
@Environment(\.modelContext) private var modelContext

// Models must conform to @Model
@Model
class TranscriptionRecord {
    @Attribute(.unique) var id: UUID
    var text: String
    var timestamp: Date
}
```

### Adding Animations
```swift
// Use AnimationHelpers modifiers
.someView()
    .smoothScale(isActive: isExpanded, scale: 1.1)
    .smoothOpacity(isVisible: isShowing)
    .smoothSlide(edge: .top, isVisible: isPresented)
```

## File Structure

```
dhavnii/
├── dhavniiApp.swift          # App entry
├── HomeView.swift            # Main UI
├── SettingsView.swift        # Settings
├── OnboardingView.swift      # First-time flow
├── NotchOverlayView.swift    # Recording overlay
├── NotchWindowController.swift
├── AnimationHelpers.swift    # Animation system
├── UserFeedbackSystem.swift  # Toast notifications
├── PermissionManager.swift   # Permission handling
├── HotkeyManager.swift       # Global hotkey
├── AudioRecorder.swift       # Recording
├── TranscriptionService.swift # Orchestration
├── GroqAPIClient.swift       # Groq API
├── DeepgramAPIClient.swift   # Deepgram API
├── ElevenLabsAPIClient.swift # ElevenLabs API
├── HistoryManager.swift      # History logic
├── HistoryView.swift         # History UI
├── ClipboardManager.swift    # Pasteboard
├── AppState.swift            # App state
├── UIConstants.swift         # Design constants
├── TranscriptionHistory.swift # Models
├── TranscriptionProvider.swift # Data provider
└── ContentView.swift         # Legacy
```

## Scripts Reference

- `build_release.sh` - Full release build and install
- `generate_icons.sh` - Generate icon sizes from 1024px source
- `reset_permissions.sh` - Reset permissions for testing
- `restart_app.sh` - Restart after permission changes

## Documentation

- `TESTING_GUIDE.md` - Comprehensive testing procedures
- `DEPLOYMENT_GUIDE.md` - Release and distribution
- `QUICK_GUIDE.md` - User guide
- `CHANGELOG.md` - Version history
