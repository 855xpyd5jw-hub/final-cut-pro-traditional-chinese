#!/usr/bin/env python3
"""Build zh_TW.lproj folders for every zh_CN.lproj inside Final Cut Pro.app."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from localize_zh_tw import (
    CHAR_MAP,
    ENGLISH_UI_REPLACEMENTS,
    PHRASE_REPLACEMENTS,
    PLACEHOLDER_RE,
    POST_REPLACEMENTS,
)


TOKEN_NL = "\ue000NL\ue000"
TOKEN_CR = "\ue000CR\ue000"


def placeholders(value: str) -> list[str]:
    return PLACEHOLDER_RE.findall(value)


def pre_convert(value: str) -> str:
    converted = value
    for src, dst in PHRASE_REPLACEMENTS:
        converted = converted.replace(src, dst)
    return converted


def post_convert(value: str, original: str) -> str:
    converted = value
    for src, dst in POST_REPLACEMENTS:
        converted = converted.replace(src, dst)
    converted = ENGLISH_UI_REPLACEMENTS.get(converted, converted)
    if original == "Item" and converted == "專案":
        converted = "項目"
    return converted


def convert_batch(values: list[str], opencc_path: str | None, opencc_config: str) -> list[str]:
    prepared = [pre_convert(value).replace("\r", TOKEN_CR).replace("\n", TOKEN_NL) for value in values]
    if opencc_path:
        proc = subprocess.run(
            [opencc_path, "-c", opencc_config],
            input="\n".join(prepared),
            text=True,
            capture_output=True,
            check=True,
        )
        converted = proc.stdout.splitlines()
        if len(converted) != len(prepared):
            raise RuntimeError(
                f"OpenCC batch line count mismatch: expected {len(prepared)}, got {len(converted)}"
            )
    else:
        converted = [value.translate(CHAR_MAP) for value in prepared]

    return [
        post_convert(value.replace(TOKEN_NL, "\n").replace(TOKEN_CR, "\r"), original)
        for value, original in zip(converted, values)
    ]


def collect_strings(obj: Any, rows: list[tuple[str, str]]) -> None:
    if isinstance(obj, str):
        rows.append(("", obj))
    elif isinstance(obj, dict):
        for value in obj.values():
            collect_strings(value, rows)
    elif isinstance(obj, list):
        for value in obj:
            collect_strings(value, rows)


def replace_strings(obj: Any, iterator: Any) -> Any:
    if isinstance(obj, str):
        return next(iterator)
    if isinstance(obj, dict):
        return {key: replace_strings(value, iterator) for key, value in obj.items()}
    if isinstance(obj, list):
        return [replace_strings(value, iterator) for value in obj]
    return obj


def localize_file(source: Path, target: Path, report: dict[str, Any], opencc_path: str | None, opencc_config: str) -> None:
    if source.suffix in {".strings", ".plist", ".commandset"}:
        try:
            with source.open("rb") as fh:
                data = plistlib.load(fh)
            rows: list[tuple[str, str]] = []
            collect_strings(data, rows)
            originals = [value for _, value in rows]
            converted_values = convert_batch(originals, opencc_path, opencc_config) if originals else []
            converted = replace_strings(data, iter(converted_values))
            with target.open("wb") as fh:
                plistlib.dump(converted, fh, fmt=plistlib.FMT_BINARY, sort_keys=False)

            for original, converted_value in zip(originals, converted_values):
                report["total_strings"] += 1
                if original != converted_value:
                    report["converted_strings"] += 1
                before = placeholders(original)
                after = placeholders(converted_value)
                if before != after:
                    report["placeholder_mismatches"].append(
                        {
                            "file": str(source),
                            "source": original,
                            "converted": converted_value,
                            "source_placeholders": before,
                            "converted_placeholders": after,
                        }
                    )
            report["plist_files"].append(str(source))
            return
        except Exception as exc:
            report["copied_with_errors"].append({"file": str(source), "error": repr(exc)})

    shutil.copy2(source, target)
    report["copied_files"].append(str(source))


def build_lproj(
    source_dir: Path,
    target_dir: Path,
    report_path: Path,
    opencc_path: str | None,
    opencc_config: str,
) -> dict[str, Any]:
    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "source": str(source_dir),
        "target": str(target_dir),
        "plist_files": [],
        "copied_files": [],
        "copied_with_errors": [],
        "placeholder_mismatches": [],
        "total_strings": 0,
        "converted_strings": 0,
    }

    for source in sorted(source_dir.iterdir()):
        if source.is_file():
            localize_file(source, target_dir / source.name, report, opencc_path, opencc_config)

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Build nested Final Cut Pro zh_TW localizations.")
    parser.add_argument(
        "--app",
        default="/Applications/Final Cut Pro.app",
        type=Path,
        help="Path to Final Cut Pro.app.",
    )
    parser.add_argument(
        "--output",
        default="dist/FinalCut_Pro_TC_Payload",
        type=Path,
        help="Output payload root. It will contain a Contents folder.",
    )
    parser.add_argument(
        "--opencc",
        default="auto",
        help="Path to opencc, 'auto' to use it when available, or 'off' to use fallback conversion.",
    )
    parser.add_argument(
        "--opencc-config",
        default="s2twp.json",
        help="OpenCC config. Use s2twp.json for Taiwan wording.",
    )
    parser.add_argument("--clean", action="store_true", help="Delete output first.")
    args = parser.parse_args()

    contents = args.app / "Contents"
    if not contents.is_dir():
        print(f"Final Cut Pro Contents folder not found: {contents}", file=sys.stderr)
        return 1

    if args.opencc == "off":
        opencc_path = None
    elif args.opencc == "auto":
        opencc_path = shutil.which("opencc")
    else:
        opencc_path = args.opencc

    if args.output.exists() and args.clean:
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True, exist_ok=True)

    zh_cn_dirs = sorted(contents.rglob("zh_CN.lproj"))
    summary = {
        "app": str(args.app),
        "output": str(args.output),
        "opencc_used": bool(opencc_path),
        "opencc_path": opencc_path,
        "opencc_config": args.opencc_config if opencc_path else None,
        "localization_count": len(zh_cn_dirs),
        "total_strings": 0,
        "converted_strings": 0,
        "placeholder_mismatches": [],
        "folders": [],
    }

    for index, source_dir in enumerate(zh_cn_dirs, start=1):
        relative_parent = source_dir.parent.relative_to(contents)
        target_dir = args.output / "Contents" / relative_parent / "zh_TW.lproj"
        report_path = args.output / "reports" / f"{index:03d}_{'_'.join(relative_parent.parts) or 'Resources'}.json"

        report = build_lproj(
            source_dir,
            target_dir,
            report_path,
            opencc_path=opencc_path,
            opencc_config=args.opencc_config,
        )
        summary["total_strings"] += report["total_strings"]
        summary["converted_strings"] += report["converted_strings"]
        summary["placeholder_mismatches"].extend(report["placeholder_mismatches"])
        summary["folders"].append(
            {
                "source": str(source_dir),
                "target": str(target_dir),
                "report": str(report_path),
                "total_strings": report["total_strings"],
                "converted_strings": report["converted_strings"],
            }
        )
        print(f"[{index}/{len(zh_cn_dirs)}] {relative_parent}/zh_TW.lproj")

    summary_path = args.output / "reports" / "summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    print("")
    print(f"Built {len(zh_cn_dirs)} zh_TW.lproj folders.")
    print(f"Converted {summary['converted_strings']}/{summary['total_strings']} strings.")
    print(f"Placeholder mismatches: {len(summary['placeholder_mismatches'])}")
    print(f"Summary: {summary_path}")
    return 2 if summary["placeholder_mismatches"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
