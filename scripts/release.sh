#!/usr/bin/env bash
# =============================================================================
# release.sh - 自动化软件发布：将构建产物复制到 downloads/ 并更新校验信息
# 用法:
#   ./scripts/release.sh                          # 交互选择要发布的文件
#   ./scripts/release.sh /path/to/app.apk          # 发布单个文件
#   ./scripts/release.sh /path/to/build/           # 发布目录下所有匹配文件
# 环境变量（可选）:
#   RELEASE_SOURCE_DIR - 默认构建产物目录，未传参时从此目录选文件
#   RELEASE_EXTENSIONS - 要复制的扩展名，逗号分隔，如 "apk,exe,zip,dmg"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOWNLOADS_DIR="$PROJECT_ROOT/downloads"
RELEASE_SOURCE_DIR="${RELEASE_SOURCE_DIR:-$PROJECT_ROOT/build}"
RELEASE_EXTENSIONS="${RELEASE_EXTENSIONS:-apk,exe,zip,dmg,msi,AppImage,deb,rpm}"

mkdir -p "$DOWNLOADS_DIR"

# 备份旧版本（可选：保留上一版到 downloads/archive/）
archive_old() {
  local name="$1"
  local dst="$DOWNLOADS_DIR/$name"
  if [[ -f "$dst" ]]; then
    local archive_dir="$DOWNLOADS_DIR/archive"
    mkdir -p "$archive_dir"
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "bak")
    cp -a "$dst" "$archive_dir/${name}.${stamp}"
    echo "已备份旧版本到 $archive_dir/${name}.${stamp}"
  fi
}

# 复制并发布单个文件
release_file() {
  local src="$1"
  local name
  name=$(basename "$src")
  if [[ ! -f "$src" ]]; then
    echo "错误: 文件不存在: $src" >&2
    return 1
  fi
  archive_old "$name"
  cp -a "$src" "$DOWNLOADS_DIR/$name"
  echo "已发布: $name -> $DOWNLOADS_DIR/"
}

# 发布目录下所有匹配扩展名的文件
release_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "错误: 目录不存在: $dir" >&2
    return 1
  fi
  IFS=, read -ra exts <<< "$RELEASE_EXTENSIONS"
  local count=0
  for ext in "${exts[@]}"; do
    ext="${ext// /}"
    for f in "$dir"/*."$ext" "$dir"/*."${ext,,}" "$dir"/*."${ext^^}"; do
      [[ -f "$f" ]] || continue
      release_file "$f"
      ((count++)) || true
    done
  done
  if [[ $count -eq 0 ]]; then
    echo "未在 $dir 下找到扩展名为 ($RELEASE_EXTENSIONS) 的文件"
  fi
}

# 交互选择
interactive_select() {
  if [[ ! -d "$RELEASE_SOURCE_DIR" ]]; then
    echo "未设置 RELEASE_SOURCE_DIR 且默认目录不存在: $RELEASE_SOURCE_DIR"
    echo "请使用: $0 /path/to/file.apk 或 $0 /path/to/build/"
    exit 1
  fi
  local candidates=()
  while IFS= read -r -d '' f; do
    candidates+=("$f")
  done < <(find "$RELEASE_SOURCE_DIR" -maxdepth 3 -type f \( -name "*.apk" -o -name "*.exe" -o -name "*.zip" -o -name "*.dmg" -o -name "*.msi" -o -name "*.AppImage" \) -print0 2>/dev/null)
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "在 $RELEASE_SOURCE_DIR 下未找到可发布文件"
    exit 1
  fi
  echo "请选择要发布的文件 (输入序号，多选用空格分隔，如 1 3):"
  for i in "${!candidates[@]}"; do
    echo "  $((i+1))) ${candidates[$i]}"
  done
  read -r -a choice
  for c in "${choice[@]}"; do
    idx=$((c - 1))
    if [[ $idx -ge 0 && $idx -lt ${#candidates[@]} ]]; then
      release_file "${candidates[$idx]}"
    fi
  done
}

# 入口
if [[ $# -eq 0 ]]; then
  interactive_select
elif [[ -d "$1" ]]; then
  release_dir "$1"
else
  release_file "$1"
fi

# 统一更新 checksums
"$SCRIPT_DIR/checksums.sh" "$DOWNLOADS_DIR"
echo "发布完成，校验信息已更新。"
