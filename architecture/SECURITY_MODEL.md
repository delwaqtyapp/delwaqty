# SECURITY_MODEL.md — Security Architecture

> **Authority:** PROJECT_CONSTITUTION.md §10
> **Version:** 2.0

---

## Security Layers

```
┌──────────────────────────────┐
│     Transport Security       │  HTTPS/TLS everywhere
├──────────────────────────────┤
│     Authentication           │  Identity Engine
├──────────────────────────────┤
│     Authorization            │  RLS + IAM
├──────────────────────────────┤
│     Data Encryption          │  At rest + in transit
├──────────────────────────────┤
│     Input Validation         │  Domain validators
├──────────────────────────────┤
│     Audit Logging            │  Logging Engine
└──────────────────────────────┘
```

---

## Authentication

| Method | Provider | Status |
|--------|----------|--------|
| Email/Password | Supabase GoTrue | ✅ Active |
| Phone OTP | Supabase GoTrue | ✅ Active |
| Google OAuth | Supabase GoTrue | ✅ Active |
| Apple Sign In | Supabase GoTrue | ✅ Active |
| Anonymous | Supabase GoTrue | ✅ Active |
| Password Reset | Supabase GoTrue | ✅ Active |

---

## Authorization

### Row Level Security (RLS)

Every Supabase table has RLS enabled. Policies control access:

| Policy Type | Example |
|-------------|---------|
| Owner access | `USING (auth.uid() = user_id)` |
| Public read | `USING (true)` for SELECT |
| Role-based | `USING (auth.uid() IN (SELECT user_id FROM admin_users))` |

### Permission Model

```dart
enum Permission {
  // Merchant
  merchantCreate,
  merchantRead,
  merchantUpdate,
  merchantDelete,

  // Product
  productCreate,
  productRead,
  productUpdate,
  productDelete,

  // Order
  orderCreate,
  orderRead,
  orderUpdate,
  orderCancel,

  // Admin
  adminAccess,
  userManage,
  systemConfig,
}
```

---

## Data Security

| Concern | Solution |
|---------|----------|
| Secrets in code | Environment variables, .env.dev (gitignored) |
| API keys | Stored in .env.dev, never committed |
| Passwords | Hashed by Supabase GoTrue |
| Tokens | Stored in flutter_secure_storage |
| PII | Encrypted at rest in Supabase |
| Backups | Supabase automatic backups |

---

## Input Validation

All user input validated at domain layer:

```dart
class InputValidator {
  static ValidationResult validateEmail(String email) { ... }
  static ValidationResult validatePhone(String phone) { ... }
  static ValidationResult validatePassword(String password) { ... }
  static ValidationResult validateName(String name) { ... }
  static ValidationResult validateAmount(double amount) { ... }
}
```

---

## Security Logging

All security events logged:

| Event | Log Level |
|-------|-----------|
| Login success | INFO |
| Login failure | WARN |
| Unauthorized access attempt | WARN |
| Password change | INFO |
| Account deletion | INFO |
| Admin action | AUDIT |
| Suspicious activity | SECURITY |

---

## Current Security Posture

| Area | Status |
|------|--------|
| HTTPS enforced | ✅ |
| RLS on all tables | ✅ |
| Secrets not in code | ✅ |
| Tokens in secure storage | ✅ |
| Input validation | ✅ |
| Security logging | ⚠️ Partial |
| Rate limiting | ⚠️ Basic |
| Penetration testing | ❌ Not done |
| Security audit | ❌ Not done |
