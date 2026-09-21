#!/bin/zsh
set -eu
cd "${0:A:h}"
export DEVELOPER_DIR=${DEVELOPER_DIR:-$(xcode-select -p)}
[[ -d "$DEVELOPER_DIR/Platforms/MacOSX.platform" ]] || { print -u2 '需要完整 Xcode'; exit 1; }
MODE=${1:---archive}
[[ "$MODE" == --archive || "$MODE" == --install ]] || { print -u2 '用法: ./build.sh [--archive|--install]'; exit 1; }
# Never leave a second discoverable app in the source tree.
STAGE=$(mktemp -d /private/tmp/BatteryPalette.XXXXXX)
cleanup() {
  local app="$STAGE/DerivedData.noindex/Build/Products/Release/BatteryPalette.app"
  local ext="$STAGE/DerivedData.noindex/Build/Products/Release/BatteryPaletteWidget.appex"
  pluginkit -r "$app/Contents/PlugIns/BatteryPaletteWidget.appex" 2>/dev/null || true
  pluginkit -r "$ext" 2>/dev/null || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$app" 2>/dev/null || true
  rm -rf "$STAGE"
}
trap cleanup EXIT
xcodebuild -project BatteryPalette.xcodeproj -scheme BatteryPalette -configuration Release \
  -derivedDataPath "$STAGE/DerivedData.noindex" -destination 'platform=macOS' build
PRODUCT="$STAGE/DerivedData.noindex/Build/Products/Release/BatteryPalette.app"
codesign --verify --deep --strict "$PRODUCT"
mkdir -p build
ditto -c -k --keepParent "$PRODUCT" build/BatteryPalette.zip
if [[ "$MODE" == --install ]]; then
  DEST="$HOME/Applications/BatteryPalette.app"
  LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  killall BatteryPalette 2>/dev/null || true
  killall BatteryPaletteWidget 2>/dev/null || true
  if [[ -d "$DEST" ]]; then
    pluginkit -r "$DEST/Contents/PlugIns/BatteryPaletteWidget.appex" || true
    "$LSREGISTER" -u "$DEST" || true
    BACKUP=$(mktemp -d /private/tmp/BatteryPalette-backup.XXXXXX)
    mv "$DEST" "$BACKUP/previous.bundle"
  fi
  mkdir -p "$HOME/Applications"
  ditto "$PRODUCT" "$DEST"
  "$LSREGISTER" -f "$DEST"
  pluginkit -a "$DEST/Contents/PlugIns/BatteryPaletteWidget.appex"
  open -g "$DEST" --args --background
  print "已安装: $DEST"
fi
print "安装包: $PWD/build/BatteryPalette.zip"
