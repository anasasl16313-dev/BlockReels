#!/usr/bin/env bash
# Use a complete project-selected JDK without changing Flutter/global settings.
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n ${BLOCKREELS_JAVA_HOME:-} ]]; then
  jdk_candidates=("$BLOCKREELS_JAVA_HOME")
else
  jdk_candidates=("${JAVA_HOME:-}" "$HOME"/.gradle/jdks/* /usr/lib/jvm/*
    "$HOME/Downloads/android-studio/jbr" /opt/android-studio/jbr)
fi
selected_jdk=
for candidate in "${jdk_candidates[@]}"; do
  [[ -x "$candidate/bin/java" && -x "$candidate/bin/javac" ]] || continue
  compiler_version=$("$candidate/bin/javac" -version 2>&1) || continue
  [[ $compiler_version =~ ^javac\ (17|21)(\.|$) ]] || continue
  selected_jdk=$candidate
  break
done
if [[ -z $selected_jdk ]]; then
  echo 'No complete JDK 17/21 found. Set BLOCKREELS_JAVA_HOME to a JDK containing bin/java and bin/javac.' >&2
  exit 2
fi
export JAVA_HOME="$selected_jdk"
export PATH="$JAVA_HOME/bin:$PATH"
printf 'Using complete JDK: %s\n' "$JAVA_HOME" >&2
if [[ ${1:-} == --exec ]]; then shift; exec "$@"; fi
cd "$project_dir/android"
gradle_options=(--console=plain "-Dorg.gradle.java.home=$JAVA_HOME"
  "-Porg.gradle.java.installations.paths=$JAVA_HOME"
  -Porg.gradle.java.installations.auto-detect=false
  -Porg.gradle.java.installations.auto-download=false)
[[ ${BLOCKREELS_OFFLINE:-1} == 0 ]] || gradle_options+=(--offline)
exec ./gradlew "${gradle_options[@]}" "$@"
