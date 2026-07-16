# Mobile Development Workflow

## Overview

Delwaqty uses a mobile-first development workflow optimized for Android development.

## Development Stack

```
Acode (Code Editor)
    ↓
OpenCode (AI Assistant)
    ↓
Flutter SDK
    ↓
Hot Reload
    ↓
Android Device/Emulator
```

## Quick Start

### Prerequisites
1. Flutter SDK 3.44.6+
2. Android SDK (API 33+)
3. Device connected via USB or WiFi
4. Acode with Flutter plugin (optional)

### First-Time Setup
```bash
# Clone the repository
git clone <repo-url>
cd delwaqty

# Install dependencies
flutter pub get

# Copy environment configuration
cp .env.example .env.dev

# Run on connected device
flutter run --dart-define-from-file=.env.dev
```

## Development Commands

### Running the App
```bash
# Debug mode (hot reload enabled)
flutter run

# With specific environment
flutter run --dart-define-from-file=.env.dev

# On specific device
flutter run -d <device-id>

# With verbose logging
flutter run -v
```

### Hot Reload
- Save any file in `lib/` to trigger hot reload
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

### Code Generation
```bash
# Generate Freezed/JSON code
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-generate on save)
dart run build_runner watch --delete-conflicting-outputs
```

## Device Setup

### Physical Android Device
1. Enable Developer Options (tap Build Number 7 times)
2. Enable USB Debugging
3. Connect via USB
4. Run `flutter devices` to verify

### Android Emulator
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator-name>

# Or use Android Studio's AVD Manager
```

### WiFi Debugging (Android 11+)
```bash
# Enable wireless debugging on device
# Pair with device
flutter run --device-id <device-ip>:<port>
```

## Acode Integration

### Setup
1. Install Acode from Play Store
2. Install Flutter/Dart plugin
3. Open project folder in Acode

### Workflow
1. Edit code in Acode
2. Save file (auto-triggers hot reload when Flutter is running)
3. View changes on device instantly

### Acode Shortcuts
- `Ctrl+Shift+S`: Save all files
- `Ctrl+P`: Quick file navigation
- `Ctrl+Shift+F`: Search in project

## OpenCode Integration

### Using AI Assistant
1. Open OpenCode in terminal
2. Ask for help with code
3. Get suggestions and implementations
4. Apply changes and see hot reload

### Common Commands
- "Help me implement [feature]"
- "Fix this error: [error message]"
- "Explain this code: [paste code]"
- "Write tests for [file]"

## Debugging

### Flutter Inspector
```bash
# Open DevTools
flutter pub run devtools

# Or in VS Code
# Open Command Palette → Flutter: Open DevTools
```

### Logging
```bash
# Filter logs
flutter run | grep -i "error"

# Verbose output
flutter run -v
```

### Performance
```bash
# Profile mode
flutter run --profile

# Check for jank
flutter run --profile --trace-skia
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Device not found | `flutter devices` → check USB connection |
| Hot reload not working | Press `R` for hot restart |
| Build fails | `flutter clean && flutter pub get` |
| Code gen errors | `dart run build_runner build --delete-conflicting-outputs` |
| App crashes on start | Check `.env.dev` configuration |

### Reset Development Environment
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Best Practices

1. **Always use hot reload** - Don't restart unless necessary
2. **Keep device connected** - Avoid frequent disconnects
3. **Use environment files** - Never hardcode credentials
4. **Run tests before commit** - `flutter test`
5. **Check analysis** - `flutter analyze`
6. **Use git branches** - Feature branches for new work
