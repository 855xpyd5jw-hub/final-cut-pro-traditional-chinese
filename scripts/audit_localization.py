#!/usr/bin/env python3
"""Report likely untranslated English strings in an lproj folder."""

from __future__ import annotations

import argparse
import csv
import plistlib
import re
from pathlib import Path
from typing import Any


CJK_RE = re.compile(r"[\u3400-\u9fff]")
ALPHA_RE = re.compile(r"[A-Za-z]{3,}")

ALLOWLIST_TERMS = {
    "Alpha",
    "Compressor",
    "Final Cut Pro",
    "Finder",
    "HDR",
    "IMF",
    "iMovie",
    "iPad",
    "iOS",
    "Logic",
    "Mac",
    "macOS",
    "Motion",
    "OpenGL",
    "ProRes Proxy",
    "RAW",
    "RED",
    "URL",
    "VR",
    "XML",
}

INTERNAL_TERMS = {
    "[Legal string - see CEWelcomeEULAFormatString]",
    "Org",
    "MainMenu",
    "OtherViews",
    "PESegmentationMaskEditorContainerModule",
    "Pro Box",
    "Table View Cell",
    "Text Cell",
    "Window",
}


def walk(obj: Any, file_name: str, key_path: str = "") -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if isinstance(obj, str):
        has_alpha = bool(ALPHA_RE.search(obj))
        has_cjk = bool(CJK_RE.search(obj))
        if has_alpha:
            allowed = any(term in obj for term in ALLOWLIST_TERMS)
            internal = obj in INTERNAL_TERMS or obj.startswith("PE_") or obj.startswith("http")
            severity = "review"
            if not has_cjk and not allowed and not internal:
                severity = "likely_untranslated"
            elif internal:
                severity = "internal_or_url"
            elif allowed:
                severity = "allowed_brand_or_format"
            rows.append(
                {
                    "severity": severity,
                    "file": file_name,
                    "key": key_path,
                    "value": obj,
                }
            )
    elif isinstance(obj, dict):
        for key, value in obj.items():
            child_key = f"{key_path}.{key}" if key_path else str(key)
            rows.extend(walk(value, file_name, child_key))
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            rows.extend(walk(value, file_name, f"{key_path}[{index}]"))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit likely untranslated strings.")
    parser.add_argument("--target", default="zh_TW.lproj", type=Path)
    parser.add_argument("--report", default="reports/english_residue_report.csv", type=Path)
    args = parser.parse_args()

    rows: list[dict[str, str]] = []
    for path in sorted(args.target.glob("*.strings")):
        with path.open("rb") as fh:
            rows.extend(walk(plistlib.load(fh), path.name))

    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=["severity", "file", "key", "value"])
        writer.writeheader()
        writer.writerows(rows)

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["severity"]] = counts.get(row["severity"], 0) + 1

    print(f"Audited {args.target}")
    for key in sorted(counts):
        print(f"{key}: {counts[key]}")
    print(f"Report: {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
