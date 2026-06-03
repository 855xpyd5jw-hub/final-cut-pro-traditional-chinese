# Final Cut Pro Traditional Chinese Localization

Language: [繁體中文](README.md) | **English**

This project creates a `zh_TW.lproj` Traditional Chinese localization for Final Cut Pro based on the official `zh_CN.lproj` resources already installed on the user's Mac.

This is not an official Apple product. The tool does not include any original Final Cut Pro localization files. All localized resources are generated locally from the user's own installed copy of Final Cut Pro.

## Preview

![Final Cut Pro Traditional Chinese preview](assets/final-cut-pro-tc-preview.png)

## For Users

Double-click:

```text
FinalCut_Pro_TC_OneClick.command
```

The tool will automatically:

1. Find `/Applications/Final Cut Pro.app`.
2. Read the official Simplified Chinese localization from the installed app.
3. Generate a full nested Traditional Chinese localization package.
4. Install every writable `zh_TW.lproj`.
5. Back up existing localization folders to `~/Movies/FinalCut_Pro_TC_Backups/`.

If macOS shows `Operation not permitted`, open System Settings -> Privacy & Security -> Full Disk Access, then allow Terminal. If your macOS has App Management, also allow Terminal to modify apps.

## Download And Install

This project is meant to share a one-click conversion tool, not a prebuilt `zh_TW.lproj`. A generated localization folder may contain original Final Cut Pro text, while this tool only generates files locally on each user's Mac.

### If You Just Want To Install It

1. Download [`FinalCut_Pro_TC_Public.zip`](downloads/FinalCut_Pro_TC_Public.zip).
2. Unzip the file.
3. Make sure Final Cut Pro is completely closed.
4. Double-click `FinalCut_Pro_TC_OneClick.command`.
5. Enter your Mac login password when prompted, then wait for the tool to finish.
6. Open Final Cut Pro again.

If macOS blocks the file, right-click it, choose Open, then choose Open again. If the installer shows `Operation not permitted`, open System Settings -> Privacy & Security -> Full Disk Access, then allow Terminal.

### If You Maintain This Project

Double-click:

```text
Create_Public_Package.command
```

The tool creates:

```text
release/FinalCut_Pro_TC_Public.zip
```

Copy that zip to `downloads/FinalCut_Pro_TC_Public.zip`, or upload it to GitHub Releases.

The public zip includes:

- `FinalCut_Pro_TC_OneClick.command`
- `Install_FinalCut_Pro_TC.command`
- `Uninstall_FinalCut_Pro_TC.command`
- `scripts/localize_zh_tw.py`
- `scripts/build_app_localizations.py`
- `README.md`

It does not include `zh_CN.lproj`, `zh_TW.lproj`, `dist`, or any generated Apple localization files.

## Developer Usage

```sh
python3 scripts/localize_zh_tw.py
```

If OpenCC is installed, the script will automatically use the `s2twp.json` Taiwan wording conversion. You can also specify it manually:

```sh
python3 scripts/localize_zh_tw.py --opencc /usr/local/bin/opencc --opencc-config s2twp.json
```

To use only the built-in fallback conversion table:

```sh
python3 scripts/localize_zh_tw.py --opencc off
```

This generates:

- `zh_TW.lproj`: the Traditional Chinese localization folder
- `reports/zh_tw_localization_report.json`: conversion and placeholder validation report

To audit remaining English text:

```sh
python3 scripts/audit_localization.py
```

The report is written to `reports/english_residue_report.csv`.

To reduce English text inside Final Cut Pro frameworks, plug-ins, and bundled templates, generate the full nested localization package:

```sh
python3 scripts/build_app_localizations.py \
  --app "/Applications/Final Cut Pro.app" \
  --output dist/FinalCut_Pro_TC_FullPayload \
  --opencc auto \
  --opencc-config s2twp.json \
  --clean
```

Then double-click `Install_FinalCut_Pro_TC.command`. The installer will detect the full payload and install all nested `zh_TW.lproj` folders it can write.

When publishing to GitHub, commit only the tool and scripts. Do not commit generated localization files. `.gitignore` excludes `zh_CN.lproj`, `zh_TW.lproj`, `dist`, `release`, and `reports`.

## Strategy

1. Use Apple's official Simplified Chinese localization as the base.
2. Preserve the original `.strings` and plist structure.
3. Apply Taiwan and editing-workflow terminology.
4. Convert Simplified Chinese to Traditional Chinese.
5. Verify that placeholders such as `%@`, `%d`, and `%1$@` are preserved.

## Maintenance

After Final Cut Pro updates, regenerate the localization from the new installed app. If a term feels unnatural, update `PHRASE_REPLACEMENTS` in `scripts/localize_zh_tw.py` instead of editing generated files by hand.

## Uninstall

Double-click:

```text
Uninstall_FinalCut_Pro_TC.command
```

The uninstall tool removes installed `zh_TW.lproj` folders that match the public package structure.
