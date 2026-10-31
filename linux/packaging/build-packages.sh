#!/usr/bin/env bash
# Builds the Linux release files from a clean release build:
#   dist/clearly_<version>_amd64.deb
#   dist/Clearly-x86_64.AppImage  (+ .zsync when zsyncmake is installed)
# Usage: linux/packaging/build-packages.sh   (run from the repo root)
# The AppImage step needs appimagetool: set APPIMAGETOOL to its path, or it is
# downloaded to dist/.cache.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
version="$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
bundle="build/linux/x64/release/bundle"
dist="$root/dist"
mkdir -p "$dist"

flutter build linux --release --no-tree-shake-icons
test -x "$bundle/clearly"

# ---- .deb: the app in /opt/clearly, a launcher on the PATH, menu entry and icons
deb_root="$dist/.deb-root"
rm -rf "$deb_root"
mkdir -p "$deb_root/DEBIAN" "$deb_root/opt" "$deb_root/usr/bin" \
         "$deb_root/usr/share/applications"
cp -r "$bundle" "$deb_root/opt/clearly"
ln -s /opt/clearly/clearly "$deb_root/usr/bin/clearly"
cp linux/packaging/dev.clearly.clearly.desktop "$deb_root/usr/share/applications/dev.clearly.clearly.desktop"
cp -r linux/packaging/icons "$deb_root/usr/share/icons"
size_kb="$(du -sk "$deb_root" | cut -f1)"
cat > "$deb_root/DEBIAN/control" <<EOF
Package: clearly
Version: $version
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: $size_kb
Depends: libgtk-3-0t64 | libgtk-3-0
Maintainer: amandoti.win <hello@amandoti.win>
Homepage: https://seeclearly.app
Description: Free, open-source personal finance
 Clearly is personal finance for the desktop. Your data stays on your
 computer: no account, no server. Optional bank sync through SimpleFIN.
EOF
find "$deb_root" -type d -exec chmod 755 {} +
find "$deb_root" -type f ! -perm /111 -exec chmod 644 {} +
dpkg-deb --root-owner-group --build "$deb_root" "$dist/clearly_${version}_amd64.deb"
rm -rf "$deb_root"

# ---- AppImage: one file that runs on most Linux desktops
if [ "${SKIP_APPIMAGE:-0}" = 1 ]; then ls -la "$dist"; exit 0; fi
tool="${APPIMAGETOOL:-$dist/.cache/appimagetool-x86_64.AppImage}"
if [ ! -x "$tool" ]; then
  mkdir -p "$(dirname "$tool")"
  curl -fsSL -o "$tool" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$tool"
fi
appdir="$dist/.AppDir"
rm -rf "$appdir"
mkdir -p "$appdir"
cp -r "$bundle"/. "$appdir/"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
# First run: add Clearly to the app menu with its icon, so it can be pinned or
# put on the desktop like any installed app. Set CLEARLY_NO_INTEGRATE=1 to skip.
if [ -n "$APPIMAGE" ] && [ -z "$CLEARLY_NO_INTEGRATE" ]; then
  data="${XDG_DATA_HOME:-$HOME/.local/share}"
  desk="$data/applications/dev.clearly.clearly.desktop"
  icon="$data/icons/hicolor/256x256/apps/clearly.png"
  if ! grep -qsF "Exec=\"$APPIMAGE\"" "$desk"; then
    mkdir -p "$data/applications" "$(dirname "$icon")"
    cp "$HERE/clearly.png" "$icon"
    sed "s|^Exec=.*|Exec=\"$APPIMAGE\"|; s|^Icon=.*|Icon=$icon|" "$HERE/dev.clearly.clearly.desktop" > "$desk"
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" 2>/dev/null
  fi
fi
exec "$HERE/clearly" "$@"
EOF
chmod +x "$appdir/AppRun"
cp linux/packaging/dev.clearly.clearly.desktop "$appdir/dev.clearly.clearly.desktop"
cp linux/packaging/icons/hicolor/256x256/apps/clearly.png "$appdir/clearly.png"
cp "$appdir/clearly.png" "$appdir/.DirIcon"
# The release asset is always named Clearly-x86_64.AppImage, so the download link
# and the update information never change. The update information lets
# AppImageUpdate fetch only what changed; it needs the .zsync file uploaded
# next to the AppImage (made here when zsyncmake is installed).
ARCH=x86_64 "$tool" --appimage-extract-and-run \
  -u "gh-releases-zsync|amandoti-win|clearly-finance|latest|Clearly-x86_64.AppImage.zsync" \
  "$appdir" "$dist/Clearly-x86_64.AppImage"
mv -f Clearly-x86_64.AppImage.zsync "$dist/" 2>/dev/null || true
rm -rf "$appdir"
ls -la "$dist"
