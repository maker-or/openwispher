# OpenWispher

Opensource alternative to wisprflow and superwhisper

---

## What's New

### New Features & Improvements

**Flexible Recording Activation**
Choose how you trigger recordings in Settings. Use **Click to Start / Click to Stop** (toggle mode) for hands-free dictation, or **Press and Hold** to record only while the hotkey is held down — the transcription is sent the moment you release.

**Escape to Cancel**
Changed your mind mid-sentence? Press **Escape** at any point during an active recording to immediately discard the audio. Nothing is transcribed and nothing is pasted — it's as if you never started.

**Automatic Fallback Provider**
Configure a secondary provider in Settings under Providers. If your primary provider returns an error, times out, or gets rate-limited, OpenWispher automatically retries your request through the fallback provider — no interruption to your workflow.

**50+ Models Across ElevenLabs & Deepgram**
When using ElevenLabs or Deepgram, you can now browse and select from the full catalog of models each provider offers — including Nova-2, Nova-3, Flux (Deepgram) and Scribe v1/v2 (ElevenLabs) — along with fine-grained language selection.

**Bulk Export**
Added an Export button to both the transcription history view and Settings > History. Export all your transcriptions at once to a plain `.txt` file.

---

## What It Does

1. Press your global hotkey (default `⌥ Space`)
2. Speak
3. Release / press again / the app transcribes via your chosen AI provider
4. The text is automatically copied to your clipboard and pasted into whatever app is in focus

A floating notch overlay shows you the current state: **Listening → Processing → Copied!**

---

## Requirements

| Requirement | Minimum |
|---|---|
| macOS | 14 Sonoma |
| Xcode | 15+ |
| Swift | 5.9+ |
| API Key | At least one of: Groq, ElevenLabs, or Deepgram |

---

## Supported Providers

| Provider | Models | Languages |
|---|---|---|
| **Groq** | `whisper-large-v3` | English |
| **ElevenLabs** | `scribe_v1`, `scribe_v2` | Auto-detect + 90+ languages |
| **Deepgram** | `nova-3` (default), `nova-2`, `flux` | Auto-detect + 40+ locale variants (`flux` is English-only) |

API keys are stored securely in the macOS Keychain. During development, you can also set them via environment variables (`GROQ_API_KEY`, `DEEPGRAM_API_KEY`, `ELEVENLABS_API_KEY`).

---

## Features

- **Global hotkey** — fully customizable, default `⌥ Space`
- **Two activation modes** — toggle (click to start, click to stop) or hold-to-record
- **Escape to cancel** — discard a recording at any point without transcribing
- **Notch overlay** — animated status pill anchored to the MacBook notch
- **Auto-paste** — pastes transcribed text into the active app via Accessibility API
- **Transcription history** — persistent local storage with 30-day auto-cleanup; favorites are never deleted
- **Bulk export** — export all history to a `.txt` file
- **Fallback provider** — automatic failover to a secondary provider on error or timeout
- **50+ model choices** — full model + language selection for ElevenLabs and Deepgram
- **Auto-updater** — checks GitHub Releases for new versions and verifies DMG integrity via SHA-256
- **Launch at Login** — optional background agent mode
- **Privacy-first analytics** — PostHog with `personProfiles = .never`; no PII collected

---

## Project Structure

```text
dhavnii/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Build check on every PR / push to main
│       └── release.yml         # DMG + latest.json published on version tags
├── Scripts/
│   ├── build_release.sh        # Local release build
│   ├── reset_permissions.sh    # Clears UserDefaults + resets mic/accessibility
│   └── generate_icons.sh       # Regenerates app icon set
├── dhavnii.xcodeproj/          # Xcode project (scheme: openwispher)
├── dhavnii/                    # Main app source
│   ├── App/
│   │   └── AppState.swift      # Global app state observable
│   ├── Core/
│   │   ├── Feedback/           # User-facing feedback system
│   │   ├── Security/           # Keychain wrapper (SecureStorage)
│   │   └── UI/                 # Shared UI constants, animations, window helpers
│   └── Features/
│       ├── Clipboard/          # Auto-paste via CGEvent + NSPasteboard
│       ├── History/            # SwiftData models, retention, export
│       ├── Home/               # Main window (HomeView + ViewModel)
│       ├── Hotkeys/            # Carbon global hotkey registration + Escape monitor
│       ├── Notch/              # Floating notch overlay window + animated view
│       ├── Onboarding/         # 5-step first-run flow
│       ├── Permissions/        # Microphone + Accessibility permission management
│       ├── Settings/           # Full settings UI (5 sections)
│       └── Transcription/      # Audio recording, provider clients, fallback orchestrator
└── openwispher/
    ├── openwispherApp.swift    # @main entry point, hotkey wiring, lifecycle
    └── AnalyticsManager.swift  # PostHog analytics
```

---

## Architecture

- **Pattern**: Feature-based folder structure with MVVM inside each feature
- **State**: `@Observable` (Swift 5.9 macro) throughout; `@MainActor` for all UI-touching code
- **Persistence**: SwiftData (`TranscriptionRecord`, `HistoryPreferences` models)
- **API clients**: Swift actors (`GroqAPIClient`, `ElevenLabsAPIClient`, `DeepgramAPIClient`) — one per provider, isolated for thread safety
- **Audio**: AVFoundation recording to a temp `.m4a` (AAC, 16 kHz mono) deleted after transcription
- **Hotkeys**: macOS Carbon Event Manager (`RegisterEventHotKey`) for the global hotkey; `NSEvent` local monitor for Escape
- **Keychain**: All API keys stored under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/maker-or/openwispher.git
cd dhavnii
```

### 2. Open in Xcode

```bash
open dhavnii.xcodeproj
```

Select the **openwispher** scheme and your Mac as the destination.

### 3. Set up API keys (development)

You can supply keys via environment variables so you don't have to go through onboarding on every run. In Xcode, edit the scheme (`Product → Scheme → Edit Scheme → Run → Arguments`) and add:

```text
GROQ_API_KEY=<your key>
DEEPGRAM_API_KEY=<your key>
ELEVENLABS_API_KEY=<your key>
```

Or just run the app and complete onboarding normally.

### 4. PostHog (optional for local dev)

Analytics is a no-op if no PostHog key is present. For CI/release builds, set the following secrets in your GitHub repository:

- `POSTHOG_API_KEY`
- `POSTHOG_HOST`

### 5. Build & run

Press `⌘R` in Xcode. The app will walk you through onboarding on first launch.

---

## Development Scripts

| Script | Purpose |
|---|---|
| `Scripts/build_release.sh` | Build a release DMG locally |
| `Scripts/reset_permissions.sh` | Reset all UserDefaults and revoke mic/accessibility permissions — useful when testing onboarding |
| `Scripts/generate_icons.sh` | Regenerate the app icon set from a source image |

See `Scripts/README.md` for full usage details.

---



## Contributing

Contributions are welcome. Here's how to get set up and what to keep in mind.

### Before You Start

1. Fork the repository and create a branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make sure the project builds cleanly before making changes (`⌘B` in Xcode).
3. Run `Scripts/reset_permissions.sh` if you need to test the onboarding flow from scratch.

### Code Style

- **Swift**: Follow standard Swift API Design Guidelines. Use `@Observable` and structured concurrency (`async/await`, actors) — no completion handlers or Combine for new code.
- **SwiftUI**: Prefer small, composable views. Avoid putting business logic in views — extract to a `@Observable` view model or a service.
- **Actors**: API clients (`GroqAPIClient`, etc.) are Swift actors. Keep all network calls inside them.
- **`@MainActor`**: All code that touches SwiftUI state or AppKit must be `@MainActor`.
- **Keychain**: Store all secrets via `SecureStorage` — never in `UserDefaults` or `Info.plist`.
- **Analytics**: Add a `AnalyticsManager.shared.track*()` method for any new user-facing action. Always call `captureAndFlush` so events send immediately.

### Adding a New Provider

1. Add a case to `TranscriptionProviderType` in `TranscriptionProvider.swift`.
2. Create `<Provider>APIClient.swift` in `Features/Transcription/` as a Swift actor conforming to `TranscriptionProvider`.
3. Register the provider in `TranscriptionService.swift` inside `makeClient(for:)`.
4. Add model and language enums / arrays as needed.
5. Add API key fields to `SecureStorage` and wire them into `SettingsView` and `OnboardingView`.

### Submitting a Pull Request

1. Ensure the project builds without warnings on the `openwispher` scheme.
2. Test manually:
   - Onboarding flow (use `reset_permissions.sh` to start fresh)
   - Recording in both toggle and hold modes
   - Escape-to-cancel
   - Fallback provider triggering (you can force this by entering a bad API key as primary)
   - History export
3. Open a PR against `main` with a clear description of what changed and why.
4. The CI workflow will run an unsigned build automatically — fix any build failures before requesting review.

### Reporting Issues

Please include:
- macOS version
- Which provider you are using
- Steps to reproduce
- Expected vs. actual behaviour
- Any relevant output from Console.app (filter by process name `openwispher`)

---
