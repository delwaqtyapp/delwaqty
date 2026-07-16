# Contributing to Delwaqty

## Branch Naming

Use descriptive names with prefixes:

| Prefix | Usage |
|--------|-------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `refactor/` | Code refactoring |
| `docs/` | Documentation |
| `test/` | Test additions |
| `chore/` | Maintenance |

Examples:
- `feature/expense-export`
- `fix/login-redirect`
- `docs/api-setup`

## Commit Messages

Follow sprint-based format:

```
sprint N: <description>
```

- Use imperative mood ("add" not "added")
- Keep description under 72 characters
- Reference issues: `sprint 5: add login (#42)`

## Pull Request Process

1. **Create branch** from `master`:
   ```
   git checkout -b feature/my-feature master
   ```

2. **Make changes** and run tests:
   ```
   flutter test
   flutter analyze
   ```

3. **Commit** with standard message:
   ```
   sprint N: <description>
   ```

4. **Push** and open PR:
   ```
   git push -u origin feature/my-feature
   ```

5. **Fill PR template** completely

6. **Wait for CI** to pass (analyze + test)

7. **Request review** from maintainer

8. **Merge** after approval

## Code Standards

- Follow `analysis_options.yaml` rules
- No `// ignore:` comments without justification
- Max line length: 120 characters
- Document public APIs

## Environment Setup

```bash
cp .env.example .env
# Fill in credentials
flutter pub get
flutter run
```

## Reporting Issues

Use GitHub Issues with:
- Clear title
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
