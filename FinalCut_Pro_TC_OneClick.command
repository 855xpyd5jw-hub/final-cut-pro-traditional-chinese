#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="/Applications/Final Cut Pro.app"
BUILDER="$SCRIPT_DIR/scripts/build_app_localizations.py"
INSTALLER="$SCRIPT_DIR/Install_FinalCut_Pro_TC.command"
OUTPUT_DIR="$SCRIPT_DIR/dist/FinalCut_Pro_TC_FullPayload"
DEFAULT_OPENCC="/Users/vic/Documents/Codex/2026-06-03/byvoid-opencc-https-github-com-byvoid/work/opencc/local/bin/opencc"
DEFAULT_OPENCC_CONFIG="/Users/vic/Documents/Codex/2026-06-03/byvoid-opencc-https-github-com-byvoid/work/opencc/local/share/opencc/s2twp.json"

print_line() {
  printf '%s\n' "$1"
}

pause() {
  print_line ""
  read -r -p "按 Return 結束..." _ || true
}

fail() {
  print_line ""
  print_line "未完成：$1"
  pause
  exit 1
}

choose_app_path() {
  print_line "找不到 /Applications/Final Cut Pro.app"
  print_line "請輸入 Final Cut Pro.app 的完整路徑，或直接按 Return 取消。"
  read -r -p "路徑：" custom_path
  if [ -z "$custom_path" ]; then
    fail "沒有指定 Final Cut Pro.app。"
  fi
  APP_PATH="$custom_path"
}

find_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  elif [ -x /usr/bin/python3 ]; then
    PYTHON_BIN="/usr/bin/python3"
  else
    fail "找不到 python3。請先安裝 Apple Command Line Tools，或安裝 Python 3。"
  fi
}

find_opencc() {
  OPENCC_ARG="auto"
  OPENCC_CONFIG="s2twp.json"

  if [ -x "$DEFAULT_OPENCC" ] && [ -f "$DEFAULT_OPENCC_CONFIG" ]; then
    OPENCC_ARG="$DEFAULT_OPENCC"
    OPENCC_CONFIG="$DEFAULT_OPENCC_CONFIG"
    return
  fi

  if command -v opencc >/dev/null 2>&1; then
    OPENCC_ARG="$(command -v opencc)"
  fi
}

print_line "Final Cut Pro 一鍵繁體中文化"
print_line "----------------------------"
print_line ""

if [ ! -d "$APP_PATH" ]; then
  choose_app_path
fi

if [ ! -d "$APP_PATH/Contents" ]; then
  fail "指定的位置不是有效的 Final Cut Pro.app。"
fi

if [ ! -f "$BUILDER" ]; then
  fail "找不到轉換工具：$BUILDER"
fi

if [ ! -x "$INSTALLER" ]; then
  fail "找不到安裝工具，或檔案不能執行：$INSTALLER"
fi

find_python
find_opencc

print_line "正在從這台 Mac 的 Final Cut Pro 產生繁體中文語系..."
print_line "來源：$APP_PATH"
if [ "$OPENCC_ARG" = "auto" ]; then
  print_line "OpenCC：自動偵測；若找不到會使用內建轉換表"
else
  print_line "OpenCC：$OPENCC_ARG"
fi
print_line ""

"$PYTHON_BIN" "$BUILDER" \
  --app "$APP_PATH" \
  --output "$OUTPUT_DIR" \
  --opencc "$OPENCC_ARG" \
  --opencc-config "$OPENCC_CONFIG" \
  --clean

print_line ""
print_line "語系已產生，接著開始安裝。"
print_line "如果 macOS 要求密碼，請輸入這台 Mac 的登入密碼。"
print_line ""

"$INSTALLER"
