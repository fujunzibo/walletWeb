#!/usr/bin/env bash
# =============================================================================
# analyze-downloads.sh - 解析 Nginx access.log 统计下载量与流量
# 用法:
#   ./scripts/analyze-downloads.sh [access.log 路径]
#   ./scripts/analyze-downloads.sh /var/log/nginx/access.log
# 默认使用 /var/log/nginx/access.log；若不存在则尝试项目内 logs/access.log
# 输出: 控制台汇总 + 可选 CSV 报表
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${1:-/var/log/nginx/access.log}"
REPORT_DIR="${REPORT_DIR:-$PROJECT_ROOT/reports}"
REPORT_CSV="$REPORT_DIR/download-stats-$(date +%Y%m%d).csv"

# 若默认路径无权限或不存在，尝试项目内
if [[ ! -r "$LOG_FILE" ]]; then
  if [[ -r "$PROJECT_ROOT/logs/access.log" ]]; then
    LOG_FILE="$PROJECT_ROOT/logs/access.log"
  else
    echo "错误: 无法读取日志文件: $LOG_FILE" >&2
    echo "用法: $0 /path/to/access.log" >&2
    exit 1
  fi
fi

mkdir -p "$REPORT_DIR"

# 匹配 /downloads/ 的请求（常见 Nginx 组合/转义 log 格式）
# 示例 log 格式:  IP - - [date] "METHOD /downloads/xxx.exe HTTP/1.1" 200 size "referer" "ua"
download_pattern='"/downloads/[^"]*"'

echo "=============================================="
echo "下载流量统计"
echo "日志文件: $LOG_FILE"
echo "统计时间: $(date -Iseconds 2>/dev/null || date)"
echo "=============================================="

# Nginx combined: $1=ip $2=- $3=- $4=$5=time $6="METHOD /path HTTP/x.x" $7=status $8=body_bytes ...
total_requests=0
total_bytes=0
declare -A file_counts
declare -A file_bytes

while IFS= read -r line; do
  if [[ ! "$line" =~ $download_pattern ]]; then
    continue
  fi
  ((total_requests++)) || true
  # 从第 6 列提取路径（引号内 "GET /downloads/xxx HTTP/1.1"）
  path=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
  # combined 格式第 8 列为 body bytes
  bytes=$(echo "$line" | awk '{print $8}' | grep -E '^[0-9]+$' || echo "0")
  [[ -z "$bytes" ]] && bytes=0
  ((total_bytes += bytes)) || true
  name=$(basename "$path" 2>/dev/null || echo "$path")
  [[ -z "$name" ]] && name="/unknown"
  file_counts["$name"]=$((${file_counts["$name"]:-0} + 1))
  file_bytes["$name"]=$((${file_bytes["$name"]:-0} + bytes))
done < <(grep -E "$download_pattern" "$LOG_FILE" 2>/dev/null || true)

# 人类可读大小
human() {
  local num="$1"
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec-i --suffix=B "$num" 2>/dev/null || echo "${num}B"
  else
    echo "${num}B"
  fi
}

echo ""
echo "汇总:"
echo "  下载请求总数: $total_requests"
echo "  总流量: $(human "$total_bytes")"
echo ""
echo "按文件统计 (请求数 | 流量):"
for key in $(echo "${!file_counts[@]}" | tr ' ' '\n' | sort); do
  echo "  $key  |  ${file_counts[$key]}  |  $(human "${file_bytes[$key]:-0}")"
done
echo "=============================================="

# 输出 CSV
echo "文件,请求数,流量(字节),流量(可读)" > "$REPORT_CSV"
for key in $(echo "${!file_counts[@]}" | tr ' ' '\n' | sort); do
  echo "$key,${file_counts[$key]},${file_bytes[$key]:-0},$(human "${file_bytes[$key]:-0}")" >> "$REPORT_CSV"
done
echo "报表已保存: $REPORT_CSV"
