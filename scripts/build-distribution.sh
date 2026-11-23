#!/usr/bin/env bash
# Build the committed app and record the identity of the source, APK and signer.
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
expected_signer=${1:-}
if [[ ! $expected_signer =~ ^[[:xdigit:]]{64}$ || $# != 1 ]]; then
  echo 'Usage: scripts/build-distribution.sh <trusted-release-cert-sha256-without-colons>' >&2
  exit 2
fi
revision=$(git rev-parse --verify 'HEAD^{commit}')
if ! git diff --quiet HEAD -- || [[ -n $(git ls-files --others --exclude-standard) ]]; then
  echo 'Commit the reviewed source or run this command in a clean checkout.' >&2
  exit 1
fi
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/logs"
git archive --format=tar "$revision" | tar -x -C "$work/source"
flutter_cli=$(command -v "${FLUTTER_BIN:-flutter}")
flutter_cli=$(realpath "$flutter_cli")
sdk=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
[[ -n $sdk ]] || sdk=$(sed -n 's/^sdk.dir=//p' "$project_dir/android/local.properties")
[[ -d $sdk/build-tools ]] || { echo 'Set ANDROID_SDK_ROOT to the installed SDK.' >&2; exit 1; }
export ANDROID_SDK_ROOT="$sdk" FLUTTER_BIN="$flutter_cli" BLOCKREELS_OFFLINE=1
if [[ -z ${BLOCKREELS_KEY_PROPERTIES:-} && -f $project_dir/android/key.properties ]]; then
  export BLOCKREELS_KEY_PROPERTIES="$project_dir/android/key.properties"
fi
cd "$work/source"
version=$(sed -nE 's/^version: *([0-9.]+)\+([0-9]+) *$/\1+\2/p' pubspec.yaml)
[[ -n $version ]] || { echo 'Expected a Flutter version with a build number.' >&2; exit 1; }
printf 'sdk.dir=%s\nflutter.sdk=%s\nflutter.versionName=%s\nflutter.versionCode=%s\n' \
  "$sdk" "$(dirname "$(dirname "$flutter_cli")")" "${version%+*}" "${version##*+}" >android/local.properties
"$flutter_cli" pub get --offline --enforce-lockfile
VERIFY_LOG_DIR="$work/logs" scripts/verify-local.sh release
apk=build/app/outputs/apk/release/app-release.apk
[[ -s $apk && -s $work/logs/release-signature.log ]]
badging="$work/logs/release-badging.log"
expected_package="package: name='com.blockreels.app' versionCode='${version##*+}' versionName='${version%+*}'"
if ! grep -Fq "$expected_package" "$badging" || grep -q '^application-debuggable' "$badging"; then
  echo 'Unexpected release package, version or debugging flag.' >&2
  exit 1
fi
cert=$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' "$work/logs/release-signature.log")
[[ ${cert,,} == ${expected_signer,,} ]] || { echo 'Release signing identity did not match.' >&2; exit 1; }
if grep -q '^Signer #2 certificate SHA-256 digest:' "$work/logs/release-signature.log"; then
  echo 'Unexpected additional APK signer.' >&2; exit 1
fi
output_root="$project_dir/build/distribution"
mkdir -p "$output_root"
output=$(mktemp -d "$output_root/.staging.XXXXXX")
trap 'rm -rf -- "$work" "$output"' EXIT
cp "$apk" "$output/app-release.apk"
(cd "$output" && sha256sum app-release.apk >SHA256SUMS)
printf 'git_commit=%s\nversion=%s\nsigner_sha256=%s\n' "$revision" "$version" "$cert" >"$output/source.txt"
"$flutter_cli" --version --machine >"$output/flutter-version.json"
cp "$work/logs/release-permissions.txt" "$output/permissions.txt"
destination="$output_root/$revision"
mv -Tn -- "$output" "$destination"
[[ ! -d $output ]] || { echo 'An output for this commit already exists.' >&2; exit 1; }
printf 'Verified distribution and receipt: %s\n' "$destination"
