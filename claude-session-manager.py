#!/usr/bin/env python3
"""
Claude Code Session Manager
Quản lý (xem, xóa) conversation sessions của Claude Code.

CÁCH CHẠY:
  python session-manager.py                      # list tất cả + xóa tương tác
  python session-manager.py --list               # chỉ xem danh sách
  python session-manager.py --project gramar     # lọc theo project (substring)
  python session-manager.py --project gramar --list

  # Xóa thẳng không cần nhập tương tác:
  python session-manager.py --delete 13          # xóa session số 13
  python session-manager.py --delete "1 3 5"     # xóa nhiều session
  python session-manager.py --delete 1-4         # xóa range
  python session-manager.py --delete 13 -y       # xóa không hỏi confirm

CÚ PHÁP CHỌN SESSION ĐỂ XÓA:
  2          -> xóa session số 2
  1 3 5      -> xóa nhiều session
  1-4        -> xóa range từ 1 đến 4
  p:gramar   -> xóa tất cả session của project chứa 'gramar'
"""

import json
import shutil
import argparse
import sys
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional

# Force UTF-8 output (needed on Windows where default is cp1252)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


PROJECTS_DIR = Path.home() / ".claude" / "projects"


def decode_project_name(folder_name: str) -> str:
    """Strip drive prefix from folder name: 'D--study-english-gramar-prac' -> 'study-english-gramar-prac'."""
    parts = folder_name.split("--", 1)
    return parts[1] if len(parts) == 2 else folder_name


def dir_size(path: Path) -> int:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


def get_session_size(project_folder: Path, session_id: str) -> int:
    total = 0
    jsonl = project_folder / f"{session_id}.jsonl"
    if jsonl.exists():
        total += jsonl.stat().st_size
    sub = project_folder / session_id
    if sub.exists() and sub.is_dir():
        total += dir_size(sub)
    return total


def parse_session(project_folder: Path, session_id: str) -> Optional[dict]:
    jsonl = project_folder / f"{session_id}.jsonl"
    if not jsonl.exists():
        return None

    title: Optional[str] = None
    last_prompt: Optional[str] = None
    dt: Optional[datetime] = None

    try:
        with open(jsonl, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if dt is None and "timestamp" in entry:
                    try:
                        ts = entry["timestamp"].replace("Z", "+00:00")
                        dt = datetime.fromisoformat(ts)
                    except (ValueError, AttributeError):
                        pass

                t = entry.get("type")
                if t == "ai-title" and entry.get("aiTitle"):
                    title = entry["aiTitle"]
                elif t == "last-prompt" and entry.get("lastPrompt"):
                    last_prompt = entry["lastPrompt"]
    except OSError:
        return None

    display_title = title or last_prompt or "(no title)"
    date_str = dt.strftime("%Y-%m-%d %H:%M") if dt else "(unknown)"
    size = get_session_size(project_folder, session_id)
    sub_dir = project_folder / session_id
    return {
        "id": session_id,
        "title": display_title,
        "date": date_str,
        "dt": dt,
        "size": size,
        "jsonl_path": jsonl,
        "dir_path": sub_dir if sub_dir.exists() else None,
        "_idx": 0,
    }


def fmt_size(n: int) -> str:
    if n >= 1024 * 1024:
        return f"{n / 1024 / 1024:.1f} MB"
    return f"{n / 1024:.0f} KB"


def load_all_sessions(project_filter: Optional[str] = None) -> list:
    if not PROJECTS_DIR.exists():
        print(f"Không tìm thấy thư mục projects: {PROJECTS_DIR}")
        return []

    all_sessions = []

    for project_folder in sorted(PROJECTS_DIR.iterdir()):
        if not project_folder.is_dir():
            continue

        project_name = decode_project_name(project_folder.name)
        if project_filter and project_filter.lower() not in project_name.lower():
            continue

        sessions = []
        for f in project_folder.iterdir():
            if f.suffix == ".jsonl" and f.is_file():
                s = parse_session(project_folder, f.stem)
                if s:
                    s["project"] = project_name
                    sessions.append(s)

        sessions.sort(
            key=lambda x: x["dt"] or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        all_sessions.extend(sessions)

    # Assign global indices after sorting
    for i, s in enumerate(all_sessions, start=1):
        s["_idx"] = i

    return all_sessions


def display_sessions(sessions: list) -> None:
    if not sessions:
        print("Không có session nào.")
        return

    # Group by project (preserve order)
    projects: dict = {}
    for s in sessions:
        p = s["project"]
        if p not in projects:
            projects[p] = []
        projects[p].append(s)

    for project, proj_sessions in projects.items():
        total_size = sum(s["size"] for s in proj_sessions)
        print(f"\nPROJECT: {project}  ({len(proj_sessions)} sessions, {fmt_size(total_size)})")
        print(f"  {'#':<4} {'Date':<17} {'Size':<9} Title")
        print(f"  {'-'*4} {'-'*17} {'-'*9} {'-'*52}")
        for s in proj_sessions:
            title = s["title"][:52] + "..." if len(s["title"]) > 52 else s["title"]
            print(f"  {s['_idx']:<4} {s['date']:<17} {fmt_size(s['size']):<9} {title}")

    print()
    total = sum(s["size"] for s in sessions)
    print(f"Tổng: {len(sessions)} sessions, {fmt_size(total)}")


def parse_selection(raw: str, sessions: list) -> list:
    max_idx = max(s["_idx"] for s in sessions) if sessions else 0
    idx_map = {s["_idx"]: s for s in sessions}
    selected: set = set()

    for part in raw.strip().split():
        if part.startswith("p:"):
            keyword = part[2:].lower()
            for s in sessions:
                if keyword in s["project"].lower():
                    selected.add(s["_idx"])
        elif "-" in part:
            try:
                a, b = part.split("-", 1)
                for i in range(int(a), int(b) + 1):
                    if 1 <= i <= max_idx:
                        selected.add(i)
            except ValueError:
                print(f"  Bỏ qua: '{part}' (không hợp lệ)")
        else:
            try:
                i = int(part)
                if 1 <= i <= max_idx:
                    selected.add(i)
                else:
                    print(f"  Bỏ qua: {i} (ngoài phạm vi 1-{max_idx})")
            except ValueError:
                print(f"  Bỏ qua: '{part}' (không hợp lệ)")

    return [idx_map[i] for i in sorted(selected) if i in idx_map]


def delete_sessions(to_delete: list) -> None:
    total_freed = 0
    deleted = 0
    for s in to_delete:
        try:
            s["jsonl_path"].unlink()
            if s["dir_path"] and s["dir_path"].exists():
                shutil.rmtree(s["dir_path"])
            total_freed += s["size"]
            deleted += 1
            title_short = s["title"][:50]
            print(f"  Đã xóa [{s['_idx']}] {title_short}")
        except OSError as e:
            print(f"  Lỗi khi xóa [{s['_idx']}]: {e}")

    print(f"\nĐã xóa {deleted} session, giải phóng {fmt_size(total_freed)}")


def main():
    parser = argparse.ArgumentParser(
        description="Claude Code Session Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Ví dụ:
  python session-manager.py                   # list + xóa tương tác
  python session-manager.py --list            # chỉ xem danh sách
  python session-manager.py --project gramar  # lọc project chứa 'gramar'

Cú pháp chọn session để xóa:
  1          -> xóa session số 1
  1 3 5      -> xóa session 1, 3, 5
  1-4        -> xóa session 1 đến 4
  p:gramar   -> xóa tất cả session của project chứa 'gramar'""",
    )
    parser.add_argument("--list", action="store_true", help="Chỉ hiển thị, không xóa")
    parser.add_argument("--project", metavar="NAME", help="Lọc theo tên project (substring)")
    parser.add_argument("--delete", metavar="SEL", help="Xóa thẳng không hỏi (VD: --delete 13  hoặc  --delete '1 3 5'  hoặc  --delete 1-4)")
    parser.add_argument("-y", "--yes", action="store_true", help="Bỏ qua confirm khi xóa")
    args = parser.parse_args()

    print("=== Claude Code Session Manager ===")

    sessions = load_all_sessions(project_filter=args.project)

    if not sessions:
        print("Không tìm thấy session nào.")
        return

    display_sessions(sessions)

    if args.list:
        return

    # --delete mode: xóa thẳng không cần nhập interactively
    if args.delete:
        selection = args.delete
    else:
        print("\nNhập số thứ tự session muốn xóa (VD: 1  hoặc  1 3 5  hoặc  1-4  hoặc  p:gramar)")
        print("Nhấn Enter để thoát.\n")
        try:
            selection = input("Xóa: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nHủy.")
            return

    if not selection:
        print("Không xóa gì.")
        return

    to_delete = parse_selection(selection, sessions)

    if not to_delete:
        print("Không có session hợp lệ được chọn.")
        return

    print(f"\nSẽ xóa {len(to_delete)} session:")
    for s in to_delete:
        print(f"  [{s['_idx']}] {s['date']}  {fmt_size(s['size'])}  {s['title'][:50]}")

    if not args.yes:
        try:
            confirm = input(f"\nXác nhận xóa {len(to_delete)} session? (y/N): ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\nHủy.")
            return
        if confirm != "y":
            print("Hủy.")
            return

    print()
    delete_sessions(to_delete)


if __name__ == "__main__":
    main()
