#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/zh_TW.lproj"
FULL_PAYLOAD_DIR="$SCRIPT_DIR/dist/FinalCut_Pro_TC_FullPayload/Contents"
LEGACY_FULL_PAYLOAD_DIR="$SCRIPT_DIR/dist/FinalCut_Pro_TC_Payload/Contents"
APP_PATH="/Applications/Final Cut Pro.app"
BACKUP_ROOT="$HOME/Movies/FinalCut_Pro_TC_Backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
STAGING_ROOT="/tmp/FinalCut_Pro_TC_Install_$STAMP"
FAILED_INSTALLS=()

print_line() {
  printf '%s\n' "$1"
}

pause() {
  print_line ""
  read -r -p "按 Return 結束..." _ || true
}

fail() {
  print_line ""
  print_line "安裝未完成：$1"
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

validate_payload() {
  if [ -d "$FULL_PAYLOAD_DIR" ]; then
    print_line "偵測到完整巢狀語系包，將安裝所有 zh_TW.lproj。"
    PAYLOAD_MODE="full"
  elif [ -d "$LEGACY_FULL_PAYLOAD_DIR" ]; then
    FULL_PAYLOAD_DIR="$LEGACY_FULL_PAYLOAD_DIR"
    print_line "偵測到完整巢狀語系包，將安裝所有 zh_TW.lproj。"
    PAYLOAD_MODE="full"
  elif [ -d "$PAYLOAD_DIR" ]; then
    print_line "偵測到單一主程式語系包，將只安裝主程式 zh_TW.lproj。"
    PAYLOAD_MODE="single"
  else
    fail "找不到 zh_TW.lproj 或 dist/FinalCut_Pro_TC_Payload。請先產生語系包。"
  fi

  print_line "正在檢查繁體中文語系檔..."
  if [ "$PAYLOAD_MODE" = "full" ]; then
    scan_root="$FULL_PAYLOAD_DIR"
  else
    scan_root="$PAYLOAD_DIR"
  fi

  while IFS= read -r plist_file; do
    /usr/bin/plutil -lint "$plist_file" >/dev/null
  done < <(/usr/bin/find "$scan_root" \( -name '*.strings' -o -name '*.plist' -o -name '*.commandset' \) -type f)
}

validate_app() {
  if [ ! -d "$APP_PATH" ]; then
    choose_app_path
  fi

  if [ ! -d "$APP_PATH" ]; then
    fail "指定的位置不是 Final Cut Pro.app。"
  fi

  RESOURCES_DIR="$APP_PATH/Contents/Resources"
  if [ ! -d "$RESOURCES_DIR" ]; then
    fail "找不到 Final Cut Pro 的 Resources 資料夾。"
  fi
}

warn_if_running() {
  if /usr/bin/pgrep -x "Final Cut Pro" >/dev/null 2>&1; then
    print_line "偵測到 Final Cut Pro 正在執行。"
    print_line "請先關閉 Final Cut Pro，再回到這個視窗繼續。"
    read -r -p "已關閉後按 Return 繼續，或按 Control-C 取消..." _
  fi
}

install_localization() {
  /bin/mkdir -p "$BACKUP_DIR"
  /bin/mkdir -p "$STAGING_ROOT"
  trap '/bin/rm -rf "$STAGING_ROOT"' EXIT

  if [ "$PAYLOAD_MODE" = "full" ]; then
    print_line "正在安裝完整巢狀繁體中文語系..."
    install_index=0
    while IFS= read -r source_dir; do
      install_index=$((install_index + 1))
      relative_dir="${source_dir#$FULL_PAYLOAD_DIR/}"
      target_dir="$APP_PATH/Contents/$relative_dir"
      staging_dir="$STAGING_ROOT/$install_index/zh_TW.lproj"

      /bin/mkdir -p "$BACKUP_DIR/$(dirname "$relative_dir")"
      if [ -d "$target_dir" ]; then
        if ! /usr/bin/sudo /usr/bin/ditto "$target_dir" "$BACKUP_DIR/$relative_dir"; then
          FAILED_INSTALLS+=("$relative_dir（備份失敗）")
          print_line "略過：$relative_dir（無法備份）"
          continue
        fi
      fi

      /bin/rm -rf "$staging_dir"
      /bin/mkdir -p "$(dirname "$staging_dir")"
      /usr/bin/ditto "$source_dir" "$staging_dir"
      if [ -d "$target_dir" ]; then
        if ! /usr/bin/sudo /bin/rm -rf "$target_dir"; then
          FAILED_INSTALLS+=("$relative_dir（移除舊檔失敗）")
          print_line "略過：$relative_dir（系統拒絕移除舊語系）"
          continue
        fi
      fi
      if ! /usr/bin/sudo /bin/mkdir -p "$(dirname "$target_dir")"; then
        FAILED_INSTALLS+=("$relative_dir（建立目標資料夾失敗）")
        print_line "略過：$relative_dir（系統拒絕建立目標資料夾）"
        continue
      fi
      if ! /usr/bin/sudo /bin/mv "$staging_dir" "$target_dir"; then
        FAILED_INSTALLS+=("$relative_dir（安裝失敗）")
        print_line "略過：$relative_dir（系統拒絕寫入 Final Cut Pro.app）"
        continue
      fi
      /usr/bin/sudo /usr/sbin/chown -R root:wheel "$target_dir" || true
      /usr/bin/sudo /bin/chmod -R a+rX "$target_dir" || true
    done < <(/usr/bin/find "$FULL_PAYLOAD_DIR" -name 'zh_TW.lproj' -type d | /usr/bin/sort)
    return
  fi

  TARGET_DIR="$RESOURCES_DIR/zh_TW.lproj"
  STAGING_DIR="$STAGING_ROOT/zh_TW.lproj"

  if [ -d "$TARGET_DIR" ]; then
    print_line "正在備份既有 zh_TW.lproj..."
    /usr/bin/sudo /usr/bin/ditto "$TARGET_DIR" "$BACKUP_DIR/zh_TW.lproj"
  else
    print_line "目前 Final Cut Pro 內沒有 zh_TW.lproj，會新增一份。"
    printf '%s\n' "No existing zh_TW.lproj at install time." > "$BACKUP_DIR/README.txt"
  fi

  print_line "正在安裝主程式繁體中文語系..."
  /bin/rm -rf "$STAGING_DIR"
  /usr/bin/ditto "$PAYLOAD_DIR" "$STAGING_DIR"

  if [ -d "$TARGET_DIR" ]; then
    /usr/bin/sudo /bin/rm -rf "$TARGET_DIR"
  fi

  /usr/bin/sudo /bin/mkdir -p "$(dirname "$TARGET_DIR")"
  /usr/bin/sudo /bin/mv "$STAGING_DIR" "$TARGET_DIR"
  /usr/bin/sudo /usr/sbin/chown -R root:wheel "$TARGET_DIR"
  /usr/bin/sudo /bin/chmod -R a+rX "$TARGET_DIR"
}

print_line "Final Cut Pro 繁體中文化一鍵安裝"
print_line "--------------------------------"
print_line "來源：$PAYLOAD_DIR"
print_line "目標：$APP_PATH"
print_line ""

validate_payload
validate_app
warn_if_running
install_localization

print_line ""
if [ "${#FAILED_INSTALLS[@]}" -eq 0 ]; then
  print_line "安裝完成。"
else
  print_line "安裝完成，但有 ${#FAILED_INSTALLS[@]} 個受保護項目無法寫入。"
  print_line "這通常是 macOS 的 App Management 或完整磁碟存取權限限制。"
  print_line "失敗清單："
  for failed_item in "${FAILED_INSTALLS[@]}"; do
    print_line "- $failed_item"
  done
fi
print_line "備份位置：$BACKUP_DIR"
print_line "如果介面沒有變成繁體中文，請確認 macOS 語言偏好設定已將繁體中文排在前面，然後重新開啟 Final Cut Pro。"
pause
