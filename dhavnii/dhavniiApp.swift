//
//  dhavniiApp.swift
//  OpenWispher
//
//  Main application entry point with Settings window and menu bar.
//

import SwiftUI
import SwiftData
import AppKit

@main
internal struct dhavniiApp: App {
    @State private var appState = AppState()
    @State private var permissionManager = PermissionManager()
    @State private var historyManager: HistoryManager?

    @State private var transcriptionService: TranscriptionService?
    @State private var hotkeyManager: HotkeyManager?
    @State private var notchController: NotchWindowController?
    @State private var ttsService: TextToSpeechService?
    @State private var ttsNotchController: TTSNotchWindowController?
    @State private var cliHandler: CLIHandler?
    
    // SwiftData container
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([TranscriptionRecord.self, HistoryPreferences.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    internal var body: some Scene {
        // Main Window Group
        WindowGroup {
            AppContentView(
                appState: appState,
                permissionManager: permissionManager,
                historyManagerRef: $historyManager,
                transcriptionService: $transcriptionService,
                ttsService: $ttsService,
                hotkeyManager: $hotkeyManager,
                notchController: $notchController,
                ttsNotchController: $ttsNotchController,
                cliHandler: $cliHandler
            )
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in
                permissionManager.checkPermissions()
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OpenWispher") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "OpenWispher",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                                "© 2025 OpenWispher",
                        ]
                    )
                }
            }

            CommandGroup(after: .appInfo) {
                SettingsLink {
                    Text("Settings...")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Settings Window Group
        Settings {
            SettingsViewWrapper(
                permissionManager: permissionManager,
                appState: appState
            )
            .preferredColorScheme(.light)
        }
    }

}

/// Content view that manages environment and setup
private struct AppContentView: View {
    @Bindable var appState: AppState
    var permissionManager: PermissionManager
    @Binding var historyManagerRef: HistoryManager?
    @Binding var transcriptionService: TranscriptionService?
    @Binding var ttsService: TextToSpeechService?
    @Binding var hotkeyManager: HotkeyManager?
    @Binding var notchController: NotchWindowController?
    @Binding var ttsNotchController: TTSNotchWindowController?
    @Binding var cliHandler: CLIHandler?
    
    @Environment(\.modelContext) private var modelContext
    @State private var hasSetup = false
    @State private var localHistoryManager: HistoryManager?
    
    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView(permissionManager: permissionManager) {
                    appState.hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    appState.hasMicrophonePermission = permissionManager.hasMicrophonePermission
                    appState.hasAccessibilityPermission = permissionManager.hasAccessibilityPermission
                }
            } else {
                HomeView(
                    appState: appState,
                    permissionManager: permissionManager,
                    historyManager: localHistoryManager,
                    ttsService: ttsService
                )
            }
        }
        .background(WindowConfigurator())
        .seamlessToolbarWindowBackground()
        .onAppear {
            if !hasSetup {
                performSetup()
                hasSetup = true
            }
        }
    }
    
    private func performSetup() {
        // Initialize history manager with shared context
        let manager = HistoryManager(modelContext: modelContext)
        localHistoryManager = manager
        historyManagerRef = manager
        
        // Load selected transcription provider from UserDefaults
        let savedProviderRaw = UserDefaults.standard.string(forKey: "selectedTranscriptionProvider")
        let selectedProvider = savedProviderRaw.flatMap { TranscriptionProviderType(rawValue: $0) } ?? .groq
        
        // Initialize transcription service with selected provider
        let service = TranscriptionService(appState: appState, selectedProvider: selectedProvider)
        service.historyManager = manager
        transcriptionService = service

        // Initialize TTS service with selected provider
        let savedTTSProvider = UserDefaults.standard.string(forKey: "selectedTTSProvider")
        let selectedTTSProvider = savedTTSProvider.flatMap { TTSProviderType(rawValue: $0) } ?? .groq
        let tts = TextToSpeechService(appState: appState, selectedProvider: selectedTTSProvider)
        ttsService = tts

        // Warm up keychain access so prompts happen on launch, not mid-request
        _ = SecureStorage.retrieveAPIKey(for: selectedProvider)
        _ = SecureStorage.retrieveTTSAPIKey(for: selectedTTSProvider)

        // Initialize notch overlay
        let controller = NotchWindowController(appState: appState)
        controller.show()
        notchController = controller

        // Initialize TTS notch overlay
        let ttsController = TTSNotchWindowController(appState: appState)
        ttsController.show()
        ttsNotchController = ttsController

        // Initialize CLI handler for TTS
        cliHandler = CLIHandler(ttsService: tts)

        // Install CLI tool if needed
        installCLIToolIfNeeded()

        // Initialize hotkey manager
        let hotkey = HotkeyManager(onTrigger: { [weak service, weak appState] in
            guard let service = service, let appState = appState else {
                print("❌ Hotkey triggered but service/appState is nil")
                return
            }

            print("🎯 Hotkey triggered. Current state: \(appState.recordingState)")

            switch appState.recordingState {
            case .recording:
                print("⏹️ Stopping recording...")
                service.stopRecording()
            case .idle:
                print("▶️ Starting recording...")
                service.startRecording()
            default:
                print("⚠️ Cannot toggle - state is \(appState.recordingState)")
            }
        })
        hotkey.startMonitoring()
        hotkeyManager = hotkey

        // Update permission state
        appState.hasMicrophonePermission = permissionManager.hasMicrophonePermission
        appState.hasAccessibilityPermission = permissionManager.hasAccessibilityPermission

        // Check if onboarding was completed before (properly persist this)
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        appState.hasCompletedOnboarding = hasCompleted

        // If onboarding is complete, still check permissions on launch
        if hasCompleted {
            permissionManager.checkPermissions()
        }
    }

    private func installCLIToolIfNeeded() {
        let installPath = "/usr/local/bin/openwispher-speak"
        let versionMarker = "OPENWISPHER_CLI_VERSION=2"

        // If the tool exists but is an older/broken version, reinstall.
        if FileManager.default.fileExists(atPath: installPath) {
            if let existing = try? String(contentsOfFile: installPath, encoding: .utf8),
               existing.contains(versionMarker) {
                return
            }
            print("🔄 Updating CLI tool at \(installPath)")
        }
        let cliScript = """
        #!/bin/bash
        #
        # openwispher-speak - CLI tool for triggering TTS in OpenWispher
        # \(versionMarker)
        #

        set -e

        TEXT=""
        PROVIDER=""
        FILE=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --provider)
              PROVIDER="$2"
              shift 2
              ;;
            --file)
              FILE="$2"
              shift 2
              ;;
            -*)
              echo "Unknown option: $1"
              exit 1
              ;;
            *)
              TEXT="$1"
              shift
              ;;
          esac
        done

        if [[ -n "$FILE" ]]; then
          if [[ ! -f "$FILE" ]]; then
            echo "File not found: $FILE"
            exit 1
          fi
          TEXT="$(cat "$FILE")"
        fi

        if [[ -z "$TEXT" ]]; then
          echo "Usage: openwispher-speak \\"text\\" [--provider groq|deepgram|elevenlabs|openai] [--file path]"
          exit 1
        fi

        if ! pgrep -x "dhavnii" > /dev/null; then
          echo "Error: OpenWispher is not running"
          exit 1
        fi

        TEXT_ENV="$TEXT"
        PROVIDER_ENV="$PROVIDER"

        TEXT="$TEXT_ENV" PROVIDER="$PROVIDER_ENV" /usr/bin/osascript -l JavaScript <<'JXA'
        ObjC.import('Foundation')

        var env = $.NSProcessInfo.processInfo.environment
        var text = ObjC.unwrap(env.objectForKey('TEXT')) || ''
        var provider = ObjC.unwrap(env.objectForKey('PROVIDER')) || ''

        var userInfo = $.NSMutableDictionary.alloc.init
        // JXA ObjC bridge uses underscore-suffixed selectors
        userInfo.setObject_forKey_($(text), $('text'))
        if (provider.length > 0) {
          userInfo.setObject_forKey_($(provider), $('provider'))
        }

        $.NSDistributedNotificationCenter.defaultCenter
          .postNotificationName_object_userInfo_options(
            $('OpenWispher.TTS.Request'),
            null,
            userInfo,
            0
          )
        JXA
        """

        guard let scriptData = cliScript.data(using: .utf8) else {
            print("❌ Failed to encode CLI script")
            return
        }
        let scriptBase64 = scriptData.base64EncodedString()
        let script = """
        do shell script "mkdir -p /usr/local/bin && echo '\(scriptBase64)' | /usr/bin/base64 -D > '\(installPath)' && chmod +x '\(installPath)'" with administrator privileges
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                print("❌ CLI install failed: \(error)")
            } else {
                print("✅ CLI tool installed at \(installPath)")
            }
        }
    }
}

// Note: MainView, StatusIndicator, TranscriptionPreview, PermissionWarningView, 
// PermissionInfoCard, TranscriptionHistoryList, and TranscriptionRowItem have been removed
// as they were legacy/dead code. The main UI now uses HomeView exclusively.

/// Wrapper for settings view to inject environment
private struct SettingsViewWrapper: View {
    var permissionManager: PermissionManager
    var appState: AppState
    
    @Environment(\.modelContext) private var modelContext
    @State private var historyManager: HistoryManager?
    
    var body: some View {
        SettingsView(
            permissionManager: permissionManager,
            appState: appState,
            historyManager: historyManager
        )
        .onAppear {
            if historyManager == nil {
                historyManager = HistoryManager(modelContext: modelContext)
            }
        }
    }
}
