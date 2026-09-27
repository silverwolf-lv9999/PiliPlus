#!/usr/bin/env bash
# build.ps1 的 bash 等价实现（仅 android 分支）
# 用法: bash lib/scripts/build.sh android [版本覆盖值，如 2.1.5.1]
set -euo pipefail

ARG="${1:-android}"
VERSION_OVERRIDE="${2:-}"

version_code=$(git rev-list --count HEAD)
commit_hash=$(git rev-parse HEAD)

base_version=$(grep -oP '^[[:space:]]*version:[[:space:]]*\K[0-9.]+' pubspec.yaml | head -1)
if [ -z "$base_version" ]; then
  echo "Prebuild Error: version not found" >&2
  exit 1
fi

if [ -n "$VERSION_OVERRIDE" ]; then
  # 显式指定的 fork 版本号（如 2.1.5.1），只用于展示/文件名，不写进 pubspec
  display_version="$VERSION_OVERRIDE"
else
  display_version="$base_version"
  if [ "$ARG" = "android" ]; then
    display_version="${display_version}-${commit_hash:0:9}"
  fi
fi

# 改写 pubspec.yaml：version: <三段版本>+<git提交数>
sed -i -E "s|^[[:space:]]*version:[[:space:]]*[0-9.]+.*|version: ${base_version}+${version_code}|" pubspec.yaml

echo "base_version=${base_version}"
echo "version_code=${version_code}"
echo "display_version=${display_version}"

build_time=$(date +%s)

cat > pili_release.json <<EOF
{"pili.name":"${display_version}","pili.code":${version_code},"pili.hash":"${commit_hash}","pili.time":${build_time}}
EOF

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "version=${display_version}+${version_code}"
    echo "BUILD_NAME=${display_version}"
    echo "BUILD_NUMBER=${version_code}"
  } >> "$GITHUB_ENV"
fi

cat pili_release.json
echo "pubspec version line: $(grep '^\s*version:' pubspec.yaml)"
