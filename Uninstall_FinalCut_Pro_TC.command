#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="/Applications/Final Cut Pro.app"
FULL_PAYLOAD_DIR="$SCRIPT_DIR/dist/FinalCut_Pro_TC_FullPayload/Contents"
LEGACY_FULL_PAYLOAD_DIR="$SCRIPT_DIR/dist/FinalCut_Pro_TC_Payload/Contents"
TARGET_DIR="$APP_PATH/Contents/Resources/zh_TW.lproj"

print_line() {
  printf '%s\n' "$1"
}

pause() {
  print_line ""
  read -r -p "按 Return 結束..." _ || true
}

fail() {
  print_line ""
  print_line "移除未完成：$1"
  pause
  exit 1
}

if [ ! -d "$APP_PATH" ]; then
  print_line "找不到 /Applications/Final Cut Pro.app"
  print_line "請輸入 Final Cut Pro.app 的完整路徑，或直接按 Return 取消。"
  read -r -p "路徑：" APP_PATH
  if [ -z "$APP_PATH" ]; then
    fail "沒有指定 Final Cut Pro.app。"
  fi
  TARGET_DIR="$APP_PATH/Contents/Resources/zh_TW.lproj"
fi

print_line "Final Cut Pro 繁體中文化移除工具"
print_line "--------------------------------"

if [ -d "$FULL_PAYLOAD_DIR" ]; then
  PAYLOAD_MODE="full"
elif [ -d "$LEGACY_FULL_PAYLOAD_DIR" ]; then
  FULL_PAYLOAD_DIR="$LEGACY_FULL_PAYLOAD_DIR"
  PAYLOAD_MODE="full"
else
  PAYLOAD_MODE="single"
fi

if [ "$PAYLOAD_MODE" = "full" ]; then
  REMOVE_COUNT=0
  while IFS= read -r source_dir; do
    relative_dir="${source_dir#$FULL_PAYLOAD_DIR/}"
    target_dir="$APP_PATH/Contents/$relative_dir"
    if [ -d "$target_dir" ]; then
      REMOVE_COUNT=$((REMOVE_COUNT + 1))
    fi
  done < <(/usr/bin/find "$FULL_PAYLOAD_DIR" -name 'zh_TW.lproj' -type d)

  if [ "$REMOVE_COUNT" -eq 0 ]; then
    fail "Final Cut Pro 內沒有可移除的 zh_TW.lproj。"
  fi

  print_line "準備移除完整繁體中文語系：$REMOVE_COUNT 個 zh_TW.lproj"
else
  if [ ! -d "$TARGET_DIR" ]; then
    fail "Final Cut Pro 內沒有 zh_TW.lproj。"
  fi
  print_line "準備移除：$TARGET_DIR"
fi

read -r -p "確定要移除繁體中文語系嗎？輸入 YES 繼續：" confirm
if [ "$confirm" != "YES" ]; then
  fail "使用者取消。"
fi

if [ "$PAYLOAD_MODE" = "full" ]; then
  while IFS= read -r source_dir; do
    relative_dir="${source_dir#$FULL_PAYLOAD_DIR/}"
    target_dir="$APP_PATH/Contents/$relative_dir"
    if [ -d "$target_dir" ]; then
      /usr/bin/sudo /bin/rm -rf "$target_dir"
    fi
  done < <(/usr/bin/find "$FULL_PAYLOAD_DIR" -name 'zh_TW.lproj' -type d)
else
  /usr/bin/sudo /bin/rm -rf "$TARGET_DIR"
fi

print_line ""
print_line "已移除 zh_TW.lproj。"
pause
