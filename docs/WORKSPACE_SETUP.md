# Workspace Setup

## Overview

This document describes the development workspace for Delwaqty.

## Project Location

- **Path:** /root/Projects/delwaqty
- **Platform:** Linux aarch64 (Termux/PRoot on Android)
- **Git:** 12 commits, master branch
- **GitHub:** https://github.com/delwaqtyapp/delwaqty

## Prerequisites

### Required
- Flutter SDK 3.44.6+
- Dart SDK ^3.12.2
- Android SDK (API 33+)
- Git 2.x+

### Optional
- Acode (code editor)
- OpenCode (AI assistant)
- VS Code with Flutter extension

## Setup Steps

### 1. Clone Repository
```bash
git clone https://github.com/delwaqtyapp/delwaqty.git
cd delwaqty
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment
```bash
cp .env.example .env.dev
# Edit .env.dev with your credentials
```

### 4. Generate Code
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run App
```bash
flutter run --dart-define-from-file=.env.dev
```

## Directory Structure

```
delwaqty/
├── lib/
│   ├── config/          # Configuration files
│   ├── core/            # Core utilities, themes, module system
│   ├── data/            # Data layer (repositories, datasources)
│   ├── domain/          # Domain layer (entities, repositories)
│   ├── features/        # Feature modules
│   ├── services/        # Platform services
│   └── main.dart
├── test/                # Test files
├── docs/                # Documentation
├── scripts/             # Build and utility scripts
├── releases/            # Built APKs and AABs
├── .env.dev             # Dev environment
├── .env.staging         # Staging environment
├── .env.prod            # Production environment
└── pubspec.yaml
```

## Available Scripts

| Script | Purpose |
|--------|---------|
| `./build.sh` | Build debug/release APK |
| `./scripts/build_all.sh` | Build all variants |
| `./scripts/test.sh` | Run tests |
| `./scripts/analyze.sh` | Run analysis |
| `./scripts/codegen.sh` | Generate code |
| `./scripts/git_status.sh` | Show git status |
| `./scripts/sprint_commit.sh` | Commit with sprint format |

## Troubleshooting

### "flutter: command not found"
```bash
export PATH="$PATH:$HOME/flutter/bin"
```

### "pub get" fails
```bash
flutter clean
flutter pub get
```

### Code generation fails
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```
