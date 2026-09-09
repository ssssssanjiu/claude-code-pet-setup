#!/usr/bin/env python3
"""Fires on Claude Code Notification events (permission prompt / waiting for input).
Shows a macOS banner and plays a sound so you notice without watching the terminal."""
import sys
import json
import subprocess

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    data = {}

message = (data.get("message") if isinstance(data, dict) else "") or "需要你的确认"

subprocess.run([
    "osascript",
    "-e", "on run argv",
    "-e", 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"',
    "-e", "end run",
    message,
])
