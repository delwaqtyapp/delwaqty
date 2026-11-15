#!/usr/bin/env python3
"""
Chat Memory Vault & Project Advisor Engine for Delwaqty Platform
---------------------------------------------------------------
Token-preserving incremental chat reader, full-text indexer, and persistent knowledge memory.
Once a chat turn or file is indexed, it is NEVER re-read from disk, preserving quota and context.
"""

import sys
import os
import json
import sqlite3
import argparse
from datetime import datetime

DEFAULT_BRAIN_DIR = "/data/user/0/com.agy/files/.gemini/antigravity-app/brain/44048a1f-c7c8-4e67-a559-f024f79e29bf"
TRANSCRIPT_PATH = os.path.join(DEFAULT_BRAIN_DIR, ".system_generated/logs/transcript.jsonl")
DB_PATH = os.path.join(DEFAULT_BRAIN_DIR, "chat_memory.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    with conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS chat_messages (
                step_index INTEGER PRIMARY KEY,
                msg_type TEXT,
                source TEXT,
                created_at TEXT,
                content TEXT,
                summary TEXT
            );
        """)
        conn.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS chat_fts USING fts5(
                content,
                summary,
                tokenize='unicode61'
            );
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS facts (
                key TEXT PRIMARY KEY,
                value TEXT,
                category TEXT,
                updated_at TEXT
            );
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS sync_meta (
                key TEXT PRIMARY KEY,
                value TEXT
            );
        """)
    return conn

def sync_transcript(verbose=False):
    """
    Incrementally reads new bytes from transcript.jsonl.
    Maintains last byte offset so lines are read exactly once.
    """
    if not os.path.exists(TRANSCRIPT_PATH):
        if verbose:
            print(f"[!] Transcript file not found at: {TRANSCRIPT_PATH}")
        return 0

    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT value FROM sync_meta WHERE key = 'last_offset'")
    row = cur.fetchone()
    last_offset = int(row['value']) if row else 0

    file_size = os.path.getsize(TRANSCRIPT_PATH)
    if last_offset >= file_size:
        if verbose:
            print(f"[✓] Already fully up to date ({file_size} bytes indexed).")
        return 0

    added_count = 0
    with open(TRANSCRIPT_PATH, 'r', encoding='utf-8', errors='ignore') as f:
        f.seek(last_offset)
        new_lines = f.readlines()
        current_offset = f.tell()

    for line in new_lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue

        step_index = entry.get("step_index")
        if step_index is None:
            continue

        msg_type = entry.get("type", "")
        source = entry.get("source", "")
        created_at = entry.get("created_at", "")
        content = entry.get("content", "") or ""
        
        # Summarize tool calls or content
        tool_calls = entry.get("tool_calls")
        summary_parts = []
        if tool_calls and isinstance(tool_calls, list):
            for tc in tool_calls:
                summary_parts.append(f"{tc.get('toolSummary', '')}: {tc.get('toolAction', '')}")
        summary = " | ".join(summary_parts)

        # Truncate content for DB if extremely long (>20000 chars) to keep queries lightning fast
        stored_content = content[:20000] if len(content) > 20000 else content

        with conn:
            conn.execute("""
                INSERT OR REPLACE INTO chat_messages (step_index, msg_type, source, created_at, content, summary)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (step_index, msg_type, source, created_at, stored_content, summary))
            
            # Index into FTS cleanly
            conn.execute("DELETE FROM chat_fts WHERE rowid = ?", (step_index,))
            conn.execute("""
                INSERT INTO chat_fts (rowid, content, summary)
                VALUES (?, ?, ?)
            """, (step_index, stored_content, summary))
            added_count += 1

    with conn:
        conn.execute("INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('last_offset', ?)", (str(current_offset),))
        conn.execute("INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('last_sync_time', ?)", (datetime.now().isoformat(),))

    if verbose:
        print(f"[✓] Indexed {added_count} new steps (Offset: {last_offset} -> {current_offset}).")
    return added_count

def search_chat(query, user_only=False, limit=5):
    sync_transcript(verbose=False)
    conn = get_db()
    cur = conn.cursor()

    if user_only:
        sql = """
            SELECT m.step_index, m.msg_type, m.source, m.created_at, m.content
            FROM chat_messages m
            WHERE m.source LIKE '%USER%' AND m.content LIKE ?
            ORDER BY m.step_index DESC LIMIT ?
        """
        cur.execute(sql, (f"%{query}%", limit))
    else:
        # FTS query with fallback to LIKE
        try:
            sql = """
                SELECT m.step_index, m.msg_type, m.source, m.created_at, m.content, m.summary
                FROM chat_fts f
                JOIN chat_messages m ON f.rowid = m.step_index
                WHERE chat_fts MATCH ?
                ORDER BY m.step_index DESC LIMIT ?
            """
            cur.execute(sql, (query, limit))
            results = cur.fetchall()
        except Exception:
            results = []

        if not results:
            sql = """
                SELECT m.step_index, m.msg_type, m.source, m.created_at, m.content, m.summary
                FROM chat_messages m
                WHERE m.content LIKE ? OR m.summary LIKE ?
                ORDER BY m.step_index DESC LIMIT ?
            """
            cur.execute(sql, (f"%{query}%", f"%{query}%", limit))
            results = cur.fetchall()

    if not results:
        print(f"No records found matching query: '{query}'")
        return

    print(f"=== Found {len(results)} matches for '{query}' ===")
    for r in results:
        step = r['step_index']
        src = r['source']
        ts = r['created_at']
        content = r['content'].strip()
        # Preview snippet
        preview = (content[:300] + '...') if len(content) > 300 else content
        preview = preview.replace('\n', ' ')
        print(f"\n[Step #{step}] ({src} @ {ts})")
        print(f"  {preview}")

def remember_fact(key, value, category="general"):
    conn = get_db()
    with conn:
        conn.execute("""
            INSERT OR REPLACE INTO facts (key, value, category, updated_at)
            VALUES (?, ?, ?, ?)
        """, (key, value, category, datetime.now().isoformat()))
    print(f"[✓] Remembered '{key}' (Category: {category})")

def recall_facts(key=None):
    conn = get_db()
    cur = conn.cursor()
    if key:
        cur.execute("SELECT * FROM facts WHERE key LIKE ?", (f"%{key}%",))
    else:
        cur.execute("SELECT * FROM facts ORDER BY category, key")
    rows = cur.fetchall()
    if not rows:
        print("[!] No matching facts stored in memory.")
        return
    print("=== Stored Project Knowledge ===")
    for r in rows:
        print(f"• [{r['category']}] {r['key']}: {r['value']} (Updated: {r['updated_at']})")

def show_recent_prompts(limit=5):
    sync_transcript(verbose=False)
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        SELECT step_index, created_at, content FROM chat_messages
        WHERE source LIKE '%USER%' AND length(content) > 0
        ORDER BY step_index DESC LIMIT ?
    """, (limit,))
    rows = cur.fetchall()
    print(f"=== Last {len(rows)} User Requests ===")
    for r in rows:
        content = r['content'].strip().replace('\n', ' ')
        snippet = (content[:250] + '...') if len(content) > 250 else content
        print(f"[Step #{r['step_index']}] {snippet}")

def show_advisor():
    print("================================================================")
    print("   DELWAQTY ARCHITECTURAL ADVISORY & PLATFORM STATUS")
    print("================================================================")
    print("Platform Baseline:")
    print("  • Flutter: 3.47.1 on Dart 3.13.2 (Custom Native AOT / ARM64)")
    print("  • Live Database: Supabase Project 'bttnlkmwhorjamzemwda'")
    print("  • Target Devices: Android Native via ADB (127.0.0.1:5555)")
    print("\nRecent Milestones Completed:")
    print("  [✓] Migration 115: Bulletproof member deletion RPC & phone-token fallback.")
    print("  [✓] Modernized Platform Intelligence Dashboard with glassmorphic cards & RTL navigation.")
    print("  [✓] Overhauled Member Operations Center with instant reactive filtering and role badges.")
    print("  [✓] Verified 55/55 contract quality tests & 0 flutter analyze warnings.")
    print("  [✓] Admin APK built, signed, installed & verified on live device.")
    print("\nStrategic Technical Roadmap:")
    print("  1. Customer App Polish: Complete home services booking flow and provider matching.")
    print("  2. Driver App Verification: Live geo-tracking and battery-optimized route streaming.")
    print("  3. Merchant Portal: Settlement reconciliation and instantaneous order acceptance.")
    print("  4. Security: Enforce search_path on all custom functions & isolate identity storage.")
    print("================================================================")

def show_stats():
    sync_transcript(verbose=False)
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) as count FROM chat_messages")
    total_msgs = cur.fetchone()['count']
    cur.execute("SELECT COUNT(*) as count FROM chat_messages WHERE source LIKE '%USER%'")
    user_msgs = cur.fetchone()['count']
    cur.execute("SELECT COUNT(*) as count FROM facts")
    facts_count = cur.fetchone()['count']
    db_size_kb = os.path.getsize(DB_PATH) / 1024 if os.path.exists(DB_PATH) else 0

    print("=== Chat Memory Vault Statistics ===")
    print(f"• Total Steps Indexed: {total_msgs}")
    print(f"• User Requests Indexed: {user_msgs}")
    print(f"• Facts in Permanent Memory: {facts_count}")
    print(f"• Database Size: {db_size_kb:.1f} KB")
    print(f"• Estimated Context Tokens Saved: ~{total_msgs * 180:,} tokens")

def init_default_facts():
    """Seeds foundational platform facts into memory if not already present."""
    defaults = [
        ("supabase_project_ref", "bttnlkmwhorjamzemwda", "database"),
        ("supabase_access_token", os.environ.get("SUPABASE_ACCESS_TOKEN", "configured_in_vault"), "credentials"),
        ("adb_connection", "127.0.0.1:5555", "environment"),
        ("primary_codebase", "/storage/emulated/0/delwaqty", "paths"),
        ("build_environment", "/data/data/com.termux/files/home/delwaqty", "paths"),
        ("admin_package_id", "com.delwaqty.admin", "packages"),
        ("customer_package_id", "com.delwaqty.app", "packages"),
        ("driver_package_id", "com.delwaqty.driver", "packages"),
        ("provider_package_id", "com.delwaqty.provider", "packages"),
        ("last_migration", "115_bulletproof_member_deletion.sql", "database"),
        ("contract_suite_count", "55 tests passing", "quality"),
    ]
    conn = get_db()
    with conn:
        for k, v, c in defaults:
            conn.execute("""
                INSERT OR IGNORE INTO facts (key, value, category, updated_at)
                VALUES (?, ?, ?, ?)
            """, (k, v, c, datetime.now().isoformat()))

def main():
    parser = argparse.ArgumentParser(description="Chat Memory Vault & Project Advisor Engine")
    subparsers = parser.add_subparsers(dest="command")

    # sync
    subparsers.add_parser("sync", help="Incrementally sync transcript to SQLite memory")

    # search
    search_p = subparsers.add_parser("search", help="Search past chat and commands")
    search_p.add_argument("query", help="Text or keyword to search")
    search_p.add_argument("--user-only", action="store_true", help="Search only user prompts")
    search_p.add_argument("-n", "--limit", type=int, default=5, help="Max results")

    # recent
    recent_p = subparsers.add_parser("recent", help="Show recent user requests")
    recent_p.add_argument("-n", "--limit", type=int, default=5, help="Number of prompts")

    # remember
    rem_p = subparsers.add_parser("remember", help="Save a permanent fact/decision")
    rem_p.add_argument("key", help="Fact key name")
    rem_p.add_argument("value", help="Fact value")
    rem_p.add_argument("-c", "--category", default="general", help="Category")

    # recall
    rec_p = subparsers.add_parser("recall", help="Retrieve saved facts")
    rec_p.add_argument("key", nargs="?", default=None, help="Specific key to lookup")

    # advise
    subparsers.add_parser("advise", help="Show architectural status and strategic advice")

    # stats
    subparsers.add_parser("stats", help="Show memory and token savings statistics")

    args = parser.parse_args()
    init_default_facts()

    if args.command == "sync":
        sync_transcript(verbose=True)
    elif args.command == "search":
        search_chat(args.query, user_only=args.user_only, limit=args.limit)
    elif args.command == "recent":
        show_recent_prompts(limit=args.limit)
    elif args.command == "remember":
        remember_fact(args.key, args.value, category=args.category)
    elif args.command == "recall":
        recall_facts(args.key)
    elif args.command == "advise":
        show_advisor()
    elif args.command == "stats":
        show_stats()
    else:
        # Default action: sync and show advisor
        sync_transcript(verbose=True)
        show_advisor()

if __name__ == "__main__":
    main()
