# Development Scripts

This directory contains helper scripts for developing, building, and deploying Dhavnii.

---

## 📜 Available Scripts

### `reset_permissions.sh`

Resets all app permissions and preferences for clean testing during development.

**What it does:**
- ✅ Clears all app preferences (UserDefaults)
- ✅ Removes app caches
- ✅ Resets microphone permission (forces re-prompt)
- ✅ Resets accessibility permission (forces re-prompt)

**Usage:**
```bash
./Scripts/reset_permissions.sh
```

**When to use:**
- Testing the onboarding flow
- Debugging permission detection issues
- After changing permission-related code
- When permissions get into a weird state

**Note:** After running, the app will show onboarding on next launch.

---

### `build_release.sh`

Builds a Release version of Dhavnii and installs it to `/Applications/`.

**What it does:**
- ✅ Cleans previous builds
- ✅ Creates Release archive
- ✅ Exports standalone app
- ✅ Installs to Applications folder
- ✅ Removes quarantine flags
- ✅ Opens Applications folder

**Usage:**
```bash
./Scripts/build_release.sh
```

**Result:** You'll have a production-ready app in `/Applications/dhavnii.app` that you can:
- Pin to your Dock
- Launch without Xcode
- Use like any other Mac app

---

### `generate_icons.sh`

Generates all required macOS icon sizes from a single 1024×1024 source image.

**What it does:**
- ✅ Takes your 1024×1024 PNG
- ✅ Creates all 10 required sizes (16px to 1024px)
- ✅ Saves to AppIcon.appiconset folder
- ✅ Ready for Xcode build

**Usage:**
```bash
./Scripts/generate_icons.sh ~/path/to/your-icon-1024.png
```

**Requirements:**
- Source must be 1024×1024 PNG
- High quality, clear design
- Transparent or solid background

---

## 🚀 Quick Start Guide

### First Time Setup
1. **Create your app icon** (see `../ICON_DESIGN_GUIDE.md`)
2. **Generate icon sizes:**
   ```bash
   ./Scripts/generate_icons.sh ~/Desktop/my-icon.png
   ```
3. **Build release version:**
   ```bash
   ./Scripts/build_release.sh
   ```
4. **Pin to Dock** and use!

### Daily Development
- **Reset permissions** when testing onboarding
- **Build release** when ready to use as standalone app
- **No Xcode needed** for daily use after initial build!

---

## 📚 Additional Resources

- **`../DEPLOYMENT_GUIDE.md`** - Complete deployment instructions
- **`../ICON_DESIGN_GUIDE.md`** - Icon design tips and templates

---

## 💡 Tips

**Icon not showing after build?**
```bash
sudo killall Finder Dock
```

**Want to distribute to others?**
See `DEPLOYMENT_GUIDE.md` for code signing instructions.

**Build failed?**
- Ensure Xcode Command Line Tools installed
- Try: `xcode-select --install`