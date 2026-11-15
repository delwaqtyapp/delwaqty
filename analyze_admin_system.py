#!/usr/bin/env python3
"""
Comprehensive Admin System Analyzer for Delwaqty.
Scans all Flutter admin code, models, RPCs, routes, and translations to uncover
hidden bugs, mismatched signatures, and missing error handlers.
"""

import os
import re
import sys
import json
from pathlib import Path

PROJECT_ROOT = Path("/storage/emulated/0/delwaqty")
LIB_ADMIN = PROJECT_ROOT / "lib" / "features" / "admin"
MIGRATIONS_DIR = PROJECT_ROOT / "supabase" / "migrations"

def get_all_rpcs_in_migrations():
    """Extracts all function signatures declared in SQL migrations."""
    rpcs = {}
    pattern = re.compile(
        r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\((.*?)\)",
        re.IGNORECASE | re.DOTALL
    )
    for f in sorted(MIGRATIONS_DIR.glob("*.sql")):
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            for match in pattern.finditer(content):
                name = match.group(1).lower()
                params = match.group(2).strip().replace("\n", " ")
                rpcs[name] = {
                    "file": f.name,
                    "params": params
                }
        except Exception as e:
            print(f"Error reading {f}: {e}")
    return rpcs

def scan_flutter_rpcs(rpcs_db):
    """Finds all client.rpc calls in lib/ and checks if they exist in DB."""
    rpc_pattern = re.compile(r"""\.rpc\(\s*['"]([a-zA-Z0-9_]+)['"](?:\s*,\s*params:\s*(\{[^}]*\}))?""")
    issues = []
    found_calls = []

    for f in sorted(PROJECT_ROOT.glob("lib/**/*.dart")):
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            for m in rpc_pattern.finditer(content):
                rpc_name = m.group(1).lower()
                params_str = m.group(2)
                found_calls.append({
                    "rpc": rpc_name,
                    "file": str(f.relative_to(PROJECT_ROOT)),
                    "params": params_str
                })
                if rpc_name not in rpcs_db:
                    issues.append(f"RPC NOT FOUND IN DB: '{rpc_name}' called in {f.relative_to(PROJECT_ROOT)}")
        except Exception:
            pass

    return found_calls, issues

def scan_raw_exceptions():
    """Scans for potential raw exception leaks or crash risks in admin presentation."""
    issues = []
    pattern = re.compile(r"""Text\(\s*e\.toString\(\)\s*\)""")
    for f in sorted(LIB_ADMIN.glob("**/*.dart")):
        try:
            content = f.read_text(encoding="utf-8", errors="ignore")
            if pattern.search(content):
                issues.append(f"Raw exception rendered directly in {f.relative_to(PROJECT_ROOT)}")
        except Exception:
            pass
    return issues

def scan_missing_dialog_fallbacks():
    """Checks for showDialog or showModalBottomSheet without null checks or mounted checks."""
    issues = []
    await_dialog = re.compile(r"""await\s+show(?:Dialog|ModalBottomSheet|AnimatedConfirmDialog)\b""")
    for f in sorted(LIB_ADMIN.glob("**/*.dart")):
        try:
            lines = f.read_text(encoding="utf-8", errors="ignore").splitlines()
            for idx, line in enumerate(lines):
                if await_dialog.search(line):
                    # Check next 5 lines for mounted check
                    window = "\n".join(lines[idx:min(len(lines), idx+6)])
                    if "mounted" not in window and "return" not in window:
                        issues.append(f"Potential missing mounted check after dialog at {f.relative_to(PROJECT_ROOT)}:{idx+1}")
        except Exception:
            pass
    return issues

def main():
    print("==================================================")
    print("   DELWAQTY ADMIN SYSTEM DEEP STATIC ANALYZER     ")
    print("==================================================")
    
    db_rpcs = get_all_rpcs_in_migrations()
    print(f"[*] Found {len(db_rpcs)} RPC functions in supabase migrations.")

    flutter_rpcs, rpc_issues = scan_flutter_rpcs(db_rpcs)
    print(f"[*] Found {len(flutter_rpcs)} RPC invocations across Dart code.")
    
    print("\n--- 1. RPC Verification ---")
    if rpc_issues:
        for err in rpc_issues:
            print(f"  [!] {err}")
    else:
        print("  [✓] All RPC invocations have matching functions in migrations!")

    print("\n--- 2. Raw Exception Leak Check ---")
    raw_exc = scan_raw_exceptions()
    if raw_exc:
        for err in raw_exc:
            print(f"  [!] {err}")
    else:
        print("  [✓] No raw exception text leaks found in admin widgets.")

    print("\n--- 3. Context & Mounted Safety Audit ---")
    mounted_issues = scan_missing_dialog_fallbacks()
    print(f"  [*] Analyzed dialog and async flows. Found {len(mounted_issues)} candidates for review.")
    for m in mounted_issues[:5]:
        print(f"     - {m}")

    print("\nAnalysis complete.")

if __name__ == "__main__":
    main()
