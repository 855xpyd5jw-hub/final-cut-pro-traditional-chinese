#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_ROOT="$SCRIPT_DIR/release"
PACKAGE_DIR="$RELEASE_ROOT/FinalCut_Pro_TC_Public"
ZIP_PATH="$RELEASE_ROOT/FinalCut_Pro_TC_Public.zip"

print_line() {
  printf '%s\n' "$1"
}

pause() {
  print_line ""
  read -r -p "按 Return 結束..." _ || true
}

print_line "建立 Final Cut Pro 繁體中文化公開包"
print_line "------------------------------------"

/bin/rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
/bin/mkdir -p "$PACKAGE_DIR/scripts"
/bin/mkdir -p "$PACKAGE_DIR/assets"

/bin/cp "$SCRIPT_DIR/FinalCut_Pro_TC_OneClick.command" "$PACKAGE_DIR/"
/bin/cp "$SCRIPT_DIR/Install_FinalCut_Pro_TC.command" "$PACKAGE_DIR/"
/bin/cp "$SCRIPT_DIR/Uninstall_FinalCut_Pro_TC.command" "$PACKAGE_DIR/"
/bin/cp "$SCRIPT_DIR/README.md" "$PACKAGE_DIR/"
/bin/cp "$SCRIPT_DIR/LICENSE" "$PACKAGE_DIR/"
/bin/cp "$SCRIPT_DIR/assets/final-cut-pro-tc-preview.png" "$PACKAGE_DIR/assets/"
/bin/cp "$SCRIPT_DIR/scripts/localize_zh_tw.py" "$PACKAGE_DIR/scripts/"
/bin/cp "$SCRIPT_DIR/scripts/build_app_localizations.py" "$PACKAGE_DIR/scripts/"

/bin/chmod +x "$PACKAGE_DIR/FinalCut_Pro_TC_OneClick.command"
/bin/chmod +x "$PACKAGE_DIR/Install_FinalCut_Pro_TC.command"
/bin/chmod +x "$PACKAGE_DIR/Uninstall_FinalCut_Pro_TC.command"

(
  cd "$RELEASE_ROOT"
  /usr/bin/zip -qr "$ZIP_PATH" "FinalCut_Pro_TC_Public"
)

print_line ""
print_line "公開包已建立：$ZIP_PATH"
print_line "這個 zip 不包含 Final Cut Pro 原廠語系檔或已轉換完成的 zh_TW.lproj。"
pause
