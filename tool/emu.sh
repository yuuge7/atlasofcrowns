#!/usr/bin/env bash
# Drives the app on a running emulator or phone through adb.
#
#   tool/emu.sh install [debug|release]   build the APK and install it
#   tool/emu.sh start                     (re)launch the app
#   tool/emu.sh shot <file.png>           save a screenshot
#   tool/emu.sh tap <x> <y>               tap, in physical pixels
#   tool/emu.sh swipe <x1> <y1> <x2> <y2> [ms]
#   tool/emu.sh back                      press Back
#   tool/emu.sh log                       Flutter log lines since the last start
#   tool/emu.sh wipe                      clear the app's data (saves included)
#   tool/emu.sh uninstall                 remove the app (needed when switching
#                                         between debug- and release-signed builds)
#
# ADB_SERIAL picks the device when several are attached.
set -euo pipefail
PKG=com.ionel.atlasofcrowns
ADB="${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}/platform-tools/adb"
adb() { "$ADB" ${ADB_SERIAL:+-s "$ADB_SERIAL"} "$@"; }
cd "$(dirname "$0")/.."

case "${1:-}" in
  install)
    mode="${2:-debug}"
    flutter build apk "--$mode"
    adb install -r "build/app/outputs/flutter-apk/app-$mode.apk" || {
      echo "Install failed. If it says UPDATE_INCOMPATIBLE, the installed copy was signed with" >&2
      echo "another key: run 'tool/emu.sh uninstall' first (this deletes the saves on the device)." >&2
      exit 1
    }
    ;;
  start)
    adb shell am force-stop "$PKG"
    adb logcat -c
    adb shell am start -n "$PKG/.MainActivity" >/dev/null
    ;;
  shot) adb exec-out screencap -p > "$2" ;;
  tap) adb shell input tap "$2" "$3" ;;
  swipe) adb shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  back) adb shell input keyevent 4 ;;
  log) adb logcat -d -s flutter:V AndroidRuntime:E | tail -n "${2:-60}" ;;
  wipe) adb shell pm clear "$PKG" ;;
  uninstall) adb uninstall "$PKG" ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
