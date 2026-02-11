#!/usr/bin/env bash
# =============================================================================
# checksums.sh - 为 downloads/ 目录下所有文件生成 SHA256 并输出 checksums.json
# 用法: ./scripts/checksums.sh [downloads 目录路径]
# 默认 downloads 目录为脚本所在项目根目录下的 downloads/
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOWNLOADS_DIR="${1:-$PROJECT_ROOT/downloads}"
OUTPUT_JSON="$DOWNLOADS_DIR/checksums.json"
OUTPUT_TXT="$DOWNLOADS_DIR/checksums.txt"

# 人类可读文件大小（兼容 macOS 与 Linux）
human_size() {
  local path="$1"
  if [[ -f "$path" ]]; then
    if command -v stat &>/dev/null; then
      local bytes
      if [[ "$(uname -s)" == "Darwin" ]]; then
        bytes=$(stat -f%z "$path" 2>/dev/null || echo 0)
      else
        bytes=$(stat -c%s "$path" 2>/dev/null || echo 0)
      fi
      if command -v numfmt &>/dev/null; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
      else
        # macOS 等无 numfmt 时简单显示
        echo "${bytes}B"
      fi
    else
      echo ""
    fi
  else
    echo ""
  fi
}

# 文件修改时间（ISO 8601）
file_date() {
  local path="$1"
  if [[ -f "$path" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      date -r "$path" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo ""
    else
      date -d "@$(stat -c%Y "$path" 2>/dev/null)" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo ""
    fi
  else
    echo ""
  fi
}

if [[ ! -d "$DOWNLOADS_DIR" ]]; then
  echo "错误: 目录不存在: $DOWNLOADS_DIR" >&2
  exit 1
fi

# 排除 checksums.json / checksums.txt 和隐藏文件
shopt -s nullglob
FILES=()
for f in "$DOWNLOADS_DIR"/*; do
  [[ -f "$f" ]] || continue
  base=$(basename "$f")
  [[ "$base" == "checksums.json" || "$base" == "checksums.txt" ]] && continue
  FILES+=("$f")
done

echo "正在为 $DOWNLOADS_DIR 下 ${#FILES[@]} 个文件生成 SHA256 ..."

# 生成 JSON 数组
json_entries=()
while IFS= read -r -d '' line; do
  path="$line"
  name=$(basename "$path")
  sha256=$(sha256sum "$path" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$path" 2>/dev/null | awk '{print $1}')
  size=$(human_size "$path")
  date=$(file_date "$path")
  # 简单 JSON 转义
  name_escaped="${name//\\/\\\\}"; name_escaped="${name_escaped//\"/\\\"}"
  json_entries+=("{\"name\":\"$name_escaped\",\"sha256\":\"$sha256\",\"size\":\"$size\",\"date\":\"$date\"}")
done < <(printf '%s\0' "${FILES[@]}")

# 输出 checksums.json
printf '%s\n' "[" "$(IFS=,; echo "${json_entries[*]}")" "]" | jq -c '.' 2>/dev/null > "$OUTPUT_JSON" || {
  echo '[' > "$OUTPUT_JSON"
  for i in "${!json_entries[@]}"; do
    echo "${json_entries[$i]}$([[ $i -lt $((${#json_entries[@]} - 1)) ]] && echo ',' || true)" >> "$OUTPUT_JSON"
  done
  echo ']' >> "$OUTPUT_JSON"
}

# 输出 checksums.txt（便于命令行校验）
echo "SHA256 校验码 (checksums.txt)" > "$OUTPUT_TXT"
echo "生成时间: $(date -Iseconds 2>/dev/null || date)" >> "$OUTPUT_TXT"
echo "----------------------------------------" >> "$OUTPUT_TXT"
for f in "${FILES[@]}"; do
  name=$(basename "$f")
  sha256=$(sha256sum "$f" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
  echo "$sha256  $name" >> "$OUTPUT_TXT"
done

echo "已生成: $OUTPUT_JSON, $OUTPUT_TXT"
