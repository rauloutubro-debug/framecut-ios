#!/bin/bash
# Compile on macOS; the unsigned IPA must be signed before installation.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
  echo 'Requer macOS com Xcode completo selecionado em xcode-select.' >&2
  exit 1
fi
build_dir="$project_root/build"
xcodebuild -project "$project_root/FrameCut.xcodeproj" \
  -scheme FrameCut -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$build_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
app_path="$build_dir/DerivedData/Build/Products/Release-iphoneos/FrameCut.app"
[[ -d "$app_path" ]] || { echo 'Aplicativo compilado não encontrado.' >&2; exit 1; }
package_dir="$(mktemp -d "$build_dir/package.XXXXXX")"
trap 'rm -rf "$package_dir"' EXIT
mkdir -p "$package_dir/Payload"
ditto "$app_path" "$package_dir/Payload/FrameCut.app"
(cd "$package_dir" && /usr/bin/zip -qr "$build_dir/FrameCut-unsigned.ipa" Payload)
echo "IPA sem assinatura: $build_dir/FrameCut-unsigned.ipa"
echo 'Assine com sua conta Apple via AltStore/Sideloadly antes de instalar.'
