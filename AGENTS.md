# AGENTS.md — Delwaqty Development Rules

> **Permanent project rules. Every AI agent and contributor MUST follow these.**
> Repository and documentation are the only source of truth (never rely on chat history).

---

## 1. Pre-Development Protocol

Before writing ANY code:

- [ ] Read `docs/HANDOFF/` (all files)
- [ ] Read `AGENTS.md` (this file)
- [ ] Read `SESSION_STATUS.md`
- [ ] Understand the current architecture

## 2. SESSION_STATUS.md — Continuous Update

Maintain `SESSION_STATUS.md` at the project root. Always reflect:

- **Current task** — what is actively being worked on
- **Files modified** — every file touched in the session
- **Decisions** — architectural or design choices made
- **Remaining work** — what is still pending
- **Next task** — what comes after the current work

## 3. Decision Logging

Every architectural decision MUST be written to:

```
docs/DECISION_LOG.md
```

Follow the existing ADR format (Context / Decision / Rationale / Consequences).

## 4. Roadmap Changes

Every roadmap change MUST update:

```
docs/ROADMAP.md
```

## 5. Architecture-First Development

- NEVER modify code before understanding the affected architecture.
- ALWAYS explain the root cause before implementing a fix.
- Prefer architectural solutions over temporary patches.
- Never introduce hardcoded logic where an abstraction belongs.

## 6. Feature Requirements

Every new feature MUST be:

- **Modular** — lives within its own feature module
- **Reusable** — components exposed for other modules
- **Automatically registered** — added to `lib/module_registry.dart`
- **Independently testable** — has its own test file

## 7. Pre-Commit Gate

Before EVERY commit, execute:

```bash
flutter pub get
flutter analyze
flutter test
```

If an Android device is connected:

```bash
flutter run
```

**Never commit failing code.**

## 8. GitHub Synchronization

Keep GitHub synchronized after every stable milestone:

```bash
git add .
git commit -m "sprint N: <description>"
git push origin master
```

## 9. Source of Truth

**Never ask for previous chat history.** The repository, documentation, and Git history are the only source of truth.

## 10. Autonomous Operation

Work autonomously as **Lead Software Architect**. Only stop when:

- Manual credentials are required (API keys, passwords)
- External services need configuration (Supabase, Cloudflare)
- Explicit user decisions are required (architecture pivots, scope changes)

## 11. Milestone Deliverables

Every major milestone MUST produce:

- [ ] Commit
- [ ] Git Push
- [ ] Sprint Report (in `docs/HANDOFF/`)
- [ ] Updated Documentation (HANDOFF, ROADMAP, DECISION_LOG)
- [ ] Updated `SESSION_STATUS.md`

## 12. Refactoring

If you discover a significantly better architecture, **refactor early** while preserving production quality.

## 13. Coding Standards

- No comments unless requested
- Prefer single quotes
- Require trailing commas
- Use Freezed for immutable models
- Use Riverpod for state management
- Test everything with mocktail
- Clean Architecture: Domain layer has no framework imports
- Follow `analysis_options.yaml` rules
- No `// ignore:` comments without justification

## 14. Commit Message Format

```
sprint N: <description>
```

- Use imperative mood ("add" not "added")
- Keep description under 72 characters
- Reference issues: `sprint 5: add login (#42)`

## 15. Branch Naming

| Prefix | Usage |
|--------|-------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `refactor/` | Code refactoring |
| `docs/` | Documentation |
| `test/` | Test additions |
| `chore/` | Maintenance |

---

## Quick Reference

| What | Where |
|------|-------|
| Project root | `E:\app\delwaqty` |
| Flutter SDK | `E:\app\flutter` (3.44.6, Dart 3.12.2) |
| Node.js | `E:\app\node-v24.16.0-win-x64` |
| Android SDK | `C:\Users\elsayed.daldal\AppData\Local\Android\sdk` |
| Device | DNP NX9 (`A3SQUT5A28003808`) |
| Git remote | `https://github.com/delwaqtyapp/delwaqty` |
| Session env | `$env:PUB_CACHE = "E:\app\pub-cache"` |
| Session env | `$env:GRADLE_USER_HOME = "E:\app\.gradle"` |
