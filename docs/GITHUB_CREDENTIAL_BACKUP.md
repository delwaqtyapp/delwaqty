# GitHub Credential Backup Report

> **Generated:** 2026-07-15  
> **Purpose:** Pre-cleanup snapshot of all GitHub-related credentials stored in Windows Credential Manager  
> **No passwords, tokens, or secrets are exposed.**

---

## All GitHub-Related Credentials

| # | Credential Target | Type | Username | Scope | Persistence |
|---|---|---|---|---|---|
| 1 | `git:https://delwaqtyapp@github.com` | Generic | `delwaqtyapp` | Local machine | Permanent |
| 2 | `gh:github.com:elsayeddal` | Generic | `elsayeddal` | Local machine | Permanent |
| 3 | `git:https://github.com` | Generic | `elsayeddal` | Local machine | Permanent |
| 4 | `gh:github.com:` | Generic | *(empty)* | Local machine | Permanent |

---

## Credential Details

### Credential 1: `git:https://delwaqtyapp@github.com`
- **Target:** `LegacyGeneric:target=git:https://delwaqtyapp@github.com`
- **Type:** Generic (Windows Credential Manager)
- **Username:** `delwaqtyapp`
- **Purpose:** Git HTTPS authentication for `https://github.com/delwaqtyapp` organization
- **Created by:** Git Credential Manager (GCM)
- **Used by:** `git push`, `git pull`, `git fetch` to `delwaqtyapp/delwaqty` repository
- **Verdict:** ✅ **KEEP — This is the correct Delwaqty project credential**

### Credential 2: `gh:github.com:elsayeddal`
- **Target:** `LegacyGeneric:target=gh:github.com:elsayeddal`
- **Type:** Generic (Windows Credential Manager)
- **Username:** `elsayeddal`
- **Purpose:** GitHub CLI (`gh`) authentication for personal `elsayeddal` account
- **Created by:** GitHub CLI (`gh auth login`)
- **Used by:** `gh` commands (PRs, issues, etc.)
- **Verdict:** ❌ **REMOVE — Different account, not related to Delwaqty project**

### Credential 3: `git:https://github.com`
- **Target:** `LegacyGeneric:target=git:https://github.com`
- **Type:** Generic (Windows Credential Manager)
- **Username:** `elsayeddal`
- **Purpose:** Git HTTPS authentication for `github.com` (generic, non-org-scoped)
- **Created by:** Git Credential Manager (GCM)
- **Used by:** `git push`, `git pull`, `git fetch` — may match ANY GitHub repo
- **Verdict:** ❌ **REMOVE — Belongs to different account, causes credential conflict**

### Credential 4: `gh:github.com:`
- **Target:** `LegacyGeneric:target=gh:github.com:`
- **Type:** Generic (Windows Credential Manager)
- **Username:** *(empty)*
- **Purpose:** GitHub CLI (`gh`) fallback/default credential
- **Created by:** GitHub CLI or GCM
- **Used by:** Ambiguous — may match ANY GitHub operation
- **Verdict:** ❌ **REMOVE — Ambiguous empty credential, causes selection prompts**

---

## Non-GitHub Credentials (NOT touched)

| Target | Account | Purpose |
|---|---|---|
| `gemini:antigravity` | `antigravity` | Gemini API key |
| `Microsoft_OneDrive_Cookies_v2_*` | — | OneDrive browser cookies |
| `MicrosoftAccount:target=SSO_POP_*` | `eng.elsayed.daldal@gmail.com` | Microsoft SSO |
| `LegacyGeneric:target=MicrosoftAccount:*` | `eng.elsayed.daldal@gmail.com` | Microsoft account |
| `Olk/PushNotifications*` | — | Outlook push notifications |
| `install_secret_v1::*` | — | IPTV player trial |
| `trial_tombstone_v1::*` | — | IPTV player trial |
| `WindowsLive:target=virtualapp/didlogical` | `02ghzhkdqzzzlkhp` | Windows Live |

---

## Summary

- **Total GitHub credentials:** 4
- **To KEEP:** 1 (delwaqtyapp)
- **To REMOVE:** 3 (elsayeddal account + ambiguous)
- **Non-GitHub credentials:** 11 (untouched)
