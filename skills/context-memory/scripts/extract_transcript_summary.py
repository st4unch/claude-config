#!/usr/bin/env python3
"""
extract_transcript_summary.py

Claude Code transcript.jsonl dosyasından yapısal metadata çıkarır.
Claude bunu memory oluştururken "nelerin değiştiğini" doğrulamak için
kullanır — asıl anlatı özeti Claude'un kendi kaleminden çıkar.

Kullanım:
    python3 extract_transcript_summary.py <transcript_path>

Çıktı: JSON
{
  "turn_count": int,
  "user_messages": int,
  "assistant_messages": int,
  "tool_uses": [{"tool": str, "count": int}, ...],
  "files_touched": [str, ...],       # Read/Write/Edit/str_replace/create_file gördüğü pathler
  "files_created": [str, ...],       # create_file / Write (yeni dosya sinyali)
  "files_edited": [str, ...],        # str_replace / Edit
  "files_read": [str, ...],          # Read / view
  "commands_run": [str, ...],        # bash/bash_tool komutları (ilk 200 karakter)
  "first_user_message": str,         # oturumun ne için başladığına dair ipucu
  "duration_estimate": str           # ilk→son mesaj arası (metadata varsa)
}
"""

import json
import sys
from collections import Counter
from pathlib import Path


def safe_json_loads(line: str):
    try:
        return json.loads(line)
    except json.JSONDecodeError:
        return None


def extract(transcript_path: str) -> dict:
    path = Path(transcript_path)
    if not path.exists():
        return {"error": f"transcript not found: {transcript_path}"}

    turn_count = 0
    user_count = 0
    assistant_count = 0
    tool_counter: Counter = Counter()
    files_read: set = set()
    files_edited: set = set()
    files_created: set = set()
    commands: list = []
    first_user_message = ""
    first_ts = None
    last_ts = None

    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = safe_json_loads(line)
            if not entry:
                continue

            turn_count += 1

            # Timestamp (varsa)
            ts = entry.get("timestamp") or entry.get("ts")
            if ts:
                if first_ts is None:
                    first_ts = ts
                last_ts = ts

            # Role
            msg = entry.get("message") or entry
            role = msg.get("role") or entry.get("type")

            if role == "user":
                user_count += 1
                # İlk user mesajını yakala
                if not first_user_message:
                    content = msg.get("content")
                    if isinstance(content, str):
                        first_user_message = content[:500]
                    elif isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get("type") == "text":
                                first_user_message = block.get("text", "")[:500]
                                break
                            if isinstance(block, str):
                                first_user_message = block[:500]
                                break

            elif role == "assistant":
                assistant_count += 1
                # Tool use blokları
                content = msg.get("content")
                if isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get("type") == "tool_use":
                            tool_name = block.get("name", "unknown")
                            tool_counter[tool_name] += 1
                            inp = block.get("input") or {}
                            categorize_tool_use(
                                tool_name, inp, files_read, files_edited,
                                files_created, commands,
                            )

    # Süre tahmini
    duration = ""
    if first_ts and last_ts and first_ts != last_ts:
        duration = f"{first_ts} → {last_ts}"

    return {
        "turn_count": turn_count,
        "user_messages": user_count,
        "assistant_messages": assistant_count,
        "tool_uses": [
            {"tool": name, "count": cnt}
            for name, cnt in tool_counter.most_common()
        ],
        "files_read": sorted(files_read),
        "files_edited": sorted(files_edited),
        "files_created": sorted(files_created),
        "files_touched": sorted(files_read | files_edited | files_created),
        "commands_run": commands[:50],  # ilk 50 komut
        "first_user_message": first_user_message,
        "duration_estimate": duration,
    }


def categorize_tool_use(
    name: str, inp: dict,
    files_read: set, files_edited: set,
    files_created: set, commands: list,
) -> None:
    """Tool adı + input'una bakarak dosya/komut bilgisini ayıklar."""
    name_lower = name.lower()
    path = inp.get("path") or inp.get("file_path") or inp.get("filename")

    # Okuma
    if name_lower in ("read", "view") or "read" in name_lower:
        if path:
            files_read.add(str(path))

    # Yeni dosya yazma
    elif name_lower in ("create_file", "write", "new_file"):
        if path:
            files_created.add(str(path))

    # Düzenleme
    elif name_lower in ("str_replace", "edit", "str_replace_editor", "multi_edit"):
        if path:
            files_edited.add(str(path))

    # Bash / komut çalıştırma
    elif name_lower in ("bash", "bash_tool", "shell", "run_command"):
        cmd = inp.get("command") or inp.get("cmd") or ""
        if cmd:
            commands.append(str(cmd)[:200])


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Usage: extract_transcript_summary.py <transcript_path>",
            file=sys.stderr,
        )
        return 1

    result = extract(sys.argv[1])
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
