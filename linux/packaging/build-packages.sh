#!/usr/bin/env bash
# Builds the Linux release files from a clean release build:
#   dist/clearly_<version>_amd64.deb
#   dist/Clearly-<version>-x86_64.AppImage
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
cp linux/packaging/clearly.desktop "$deb_root/usr/share/applications/clearly.desktop"
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
exec "$HERE/clearly" "$@"
EOF
chmod +x "$appdir/AppRun"
cp linux/packaging/clearly.desktop "$appdir/clearly.desktop"
cp linux/packaging/icons/hicolor/256x256/apps/clearly.png "$appdir/clearly.png"
cp "$appdir/clearly.png" "$appdir/.DirIcon"
ARCH=x86_64 "$tool" --appimage-extract-and-run "$appdir" \
  "$dist/Clearly-${version}-x86_64.AppImage"
rm -rf "$appdir"
ls -la "$dist"
