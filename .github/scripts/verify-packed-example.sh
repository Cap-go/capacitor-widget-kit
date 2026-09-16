#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
case "$platform" in
  android | ios | web) ;;
  *)
    echo "Usage: $0 <android|ios|web>"
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${RUNNER_TEMP:-$(mktemp -d)}"
pack_dir="$tmp_root/plugin-package"
test_app="$tmp_root/plugin-example-app"

cd "$repo_root"

bun run build

rm -rf "$pack_dir" "$test_app"
mkdir -p "$pack_dir" "$test_app"
bun pm pack --destination "$pack_dir" --quiet

shopt -s nullglob
packed_packages=("$pack_dir"/*.tgz)
shopt -u nullglob
if [ "${#packed_packages[@]}" -ne 1 ]; then
  echo "Expected exactly one package tarball, found ${#packed_packages[@]}"
  exit 1
fi

plugin_name="$(bun -e 'console.log(require("./package.json").name)')"
cp -R example-app/. "$test_app/"
cd "$test_app"
bun remove "$plugin_name"
bun add "${packed_packages[0]}"
bun run build

case "$platform" in
  android)
    if [ -d android ]; then
      bunx cap sync android
    else
      bunx cap add android
      bunx cap sync android
    fi
    cd android
    ./gradlew build test
    ;;
  ios)
    if [ -d ios ]; then
      bunx cap sync ios
    else
      bunx cap add ios
      bunx cap sync ios
    fi
    pbxproj="ios/App/App.xcodeproj/project.pbxproj"
    if [ -f "$pbxproj" ]; then
      plugin_dir="$(bun -e 'console.log(require("path").dirname(require.resolve("@capgo/capacitor-widget-kit/package.json")))')"
      rel_plugin="$(python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), sys.argv[2]))' "$plugin_dir" "$PWD/ios/App")"
      python3 -c "
from pathlib import Path
import re
p = Path('ios/App/App.xcodeproj/project.pbxproj')
text = p.read_text()
text, n = re.subn(
    r'relativePath = \"[^\"]*capacitor-widget-kit[^\"]*\";',
    'relativePath = \"${rel_plugin}\";',
    text,
    count=1,
)
if n:
    p.write_text(text)
    print('Set CapgoCapacitorWidgetKit package path to ${rel_plugin}')
"
    fi
    rm -rf "$HOME/Library/Caches/org.swift.swiftpm/artifacts"/https___github_com_ionic_team_capacitor_swift_pm_releases_download_*
    xcodebuild \
      -project ios/App/App.xcodeproj \
      -scheme App \
      -destination generic/platform=iOS \
      -clonedSourcePackagesDirPath "$tmp_root/plugin-example-swiftpm" \
      -derivedDataPath "$tmp_root/plugin-example-derived-data" \
      CODE_SIGNING_ALLOWED=NO
    ;;
  web)
    ;;
esac
