# Learnings From This Chat (macOS Distribution + Updates)

## 1) Apple Developer Program vs "Free Apps"
- "Free to download" does not mean "free to publish without Apple trust."
- To remove most Gatekeeper friction for website-distributed apps, the usual path is:
  - Apple Developer Program ($99/year)
  - Developer ID signing + notarization (+ stapling)
- Electron vs Swift doesn't matter for Gatekeeper rules; Figma/VS Code are signed + notarized (they just pay the cost).

## 2) Unsigned Distribution Is Still Possible
- You can distribute an unsigned app from a website (or GitHub) as a `.dmg` and/or `.zip`.
- Users typically must do a one-time bypass on first launch:
  - Right-click (Control-click) the app in Applications → Open
  - After that, launches normally.
- New versions can sometimes trigger the one-time step again (macOS may treat it as a "new" app).

## 3) "Unsigned" Is Not a Runtime Permission
- The right-click → Open step is Gatekeeper/quarantine behavior, not an in-app permission prompt.
- You cannot "request trust" programmatically during onboarding because onboarding only runs after the app is allowed to launch.
- What onboarding *can* do:
  - Ask for Microphone permission (TCC)
  - Guide Accessibility permission enabling (TCC + System Settings)
  - Show instructions for the Gatekeeper step, but it can't automate it.

## 4) Microphone + Accessibility Are Separate From Signing
- Microphone permission:
  - Requested at runtime (e.g., `AVCaptureDevice.requestAccess`).
- Accessibility permission:
  - User must enable in System Settings (checked via `AXIsProcessTrusted...`).
- These are real permissions your onboarding already handles; they are not caused by being unsigned.

## 5) Auto-Update Without Apple Developer ID: Possible, But Needs Hosting
- True auto-update requires the app to download updates from somewhere.
- The standard macOS updater is Sparkle:
  - Uses its own cryptographic signing keys for update integrity.
  - Does not inherently require Apple Developer membership to *verify* updates.
- Unsigned apps can still auto-update, but the experience isn't as consistently smooth as notarized apps.

## 6) Your Chosen Model: Website for First Download, GitHub for Updates
- Website can link to GitHub so users always get the latest installer.
- Keep the website "latest DMG" without manual re-upload by linking to a stable GitHub URL:
  - `https://github.com/<owner>/<repo>/releases/latest/download/<asset-name>.dmg`
- For that to work reliably, each release should upload an asset with a consistent filename (e.g., `dhavnii.dmg`) in addition to any versioned filenames.

## 7) Versioning Must Be Consistent for Auto-Update
- Updaters compare the app's internal version (`CFBundleShortVersionString` / build number) to the feed's version.
- Packaging scripts that hardcode a different version than the app bundle can break update detection.
- Fix: ensure build pipeline updates the app's bundle version and the release artifacts consistently.

## 8) Final Constraints You Set
- No Mac App Store.
- App remains unsigned (no Apple Developer ID).
- Distribute the initial installer via your website.
- Auto-updates can be via GitHub.

## Next Implementation Plan (when edits are allowed)
- Add Sparkle 2 to the app and wire a "Check for Updates…" action.
- Decide appcast hosting:
  - GitHub Pages, or
  - A stable GitHub release asset URL for `appcast.xml`.
- Update CI/release workflow to:
  - Build `.zip` (for Sparkle updates) and `.dmg` (for first install).
  - Upload stable-named assets (`dhavnii.dmg`, `dhavnii.zip`, optionally `appcast.xml`) to each GitHub Release.
  - Ensure the app's bundle version matches the release version.

---

*Generated from distribution discussion on 2026-02-04*
