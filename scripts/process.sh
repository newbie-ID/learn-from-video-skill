#!/usr/bin/env bash
# process.sh — 日常 pipeline：把视频/音频（URL 或本地文件）变成带时间戳文稿并缓存
#
# 用法:
#   bash scripts/process.sh url   "<视频链接>"     # B站/YouTube/yt-dlp 支持的任意平台
#   bash scripts/process.sh local "<本地文件路径>"  # 本地视频或音频（面试录音 mp3/wav/m4a、录屏 mp4 等），跳过下载直接转录
#
# 流程: 取ID → 缓存命中? → 下载(URL)/跳过 → 字幕优先(官方CC直用,否则whisper.cpp) → transcript.{srt,txt} → 缓存
# 成功时 stdout 末行输出: TRANSCRIPT_READY <library/<id> 绝对路径>
# CWD 无关。所有日志走 stdout 供 agent 阅读；外部工具详细输出存入 library/<id>/process.log。
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_ROOT/env.local.json"
LIBRARY="$SKILL_ROOT/library"

[ -f "$ENV_FILE" ] || { echo "[FAIL] 未初始化：找不到 $ENV_FILE，请先运行 setup.sh"; exit 1; }
. "$SCRIPT_DIR/lib/detect.sh"

# 读 env.local.json 的字符串字段（扁平 JSON，best effort，不依赖 jq）
envget() {
  grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$ENV_FILE" 2>/dev/null | head -1 \
    | sed -E 's/.*:[[:space:]]*"//; s/"[[:space:]]*$//'
}
FFMPEG=$(envget ffmpeg); WHISPER=$(envget whisper_cli); MODEL=$(envget whisper_model); YTDLP=$(envget ytdlp)

MODE="${1:-}"; INPUT="${2:-}"
{ [ "$MODE" = "url" ] || [ "$MODE" = "local" ]; } || { echo "用法: process.sh url <链接> | local <文件路径>"; exit 1; }
[ -n "$INPUT" ] || { echo "[FAIL] 缺少输入（$MODE 模式需要第二个参数）"; exit 1; }

# ---- 取/算 ID + 工作目录 ----
if [ "$MODE" = "url" ]; then
  ID="$("$YTDLP" --print id --no-download "$INPUT" 2>/dev/null | head -1)"
  [ -n "$ID" ] || ID=$(echo "$INPUT" | sed -E 's#^.*/##; s/[*?=&].*$//; s/[^A-Za-z0-9_-]/_/g')
  [ -n "$ID" ] || ID="video_$$"
else
  [ -f "$INPUT" ] || { echo "[FAIL] 本地文件不存在: $INPUT"; exit 1; }
  if cmd_exists md5sum; then ID=$(md5sum "$INPUT" | awk '{print $1}')
  elif cmd_exists shasum; then ID=$(shasum "$INPUT" | awk '{print $1}')
  elif cmd_exists certutil; then ID=$(certutil -hashfile "$INPUT" MD5 2>/dev/null | sed -n '2p' | tr -d ' \r')
  else ID="local_$$"; fi
fi
WORK="$LIBRARY/$ID"; mkdir -p "$WORK"
LOG="$WORK/process.log"

# ---- 缓存命中 ----
if [ -f "$WORK/transcript.srt" ]; then
  echo "[OK] 缓存命中，秒出：$WORK/transcript.srt"
  echo "TRANSCRIPT_READY $WORK"
  exit 0
fi

# ---- 下载（仅 URL）----
VIDEO=""
if [ "$MODE" = "url" ]; then
  echo "[..] 下载视频（同时尝试官方字幕）…"
  "$YTDLP" --ffmpeg-location "$(dirname "$FFMPEG")" -f "bv*+ba/b" --merge-output-format mp4 \
    --write-subs --write-auto-subs --sub-langs "zh-Hans,zh,en,best" --sub-format "srt/vtt/best" \
    -o "$WORK/video.%(ext)s" "$INPUT" >"$LOG" 2>&1 || {
      echo "[FAIL] yt-dlp 下载失败；日志末尾："; tail -n 8 "$LOG" 2>/dev/null
      echo "[HINT] 检查链接/网络；B站部分视频可能需要 cookies（--cookies）"; exit 1; }
  VIDEO=$(ls "$WORK"/video.* 2>/dev/null | grep -vE '\.(srt|vtt|ass)$' | head -1)
  [ -n "$VIDEO" ] || { echo "[FAIL] 未找到下载的视频文件"; exit 1; }
  echo "[OK] 已下载：$VIDEO"
else
  VIDEO="$INPUT"
  echo "[OK] 本地文件模式，跳过下载：$VIDEO"
fi

# ---- 字幕优先判断 ----
SUB=$(ls "$WORK"/*.srt 2>/dev/null | head -1)
if [ -z "$SUB" ]; then
  VTT=$(ls "$WORK"/*.vtt 2>/dev/null | head -1)
  if [ -n "$VTT" ]; then
    "$FFMPEG" -y -i "$VTT" "$WORK/_from_vtt.srt" >>"$LOG" 2>&1
    SUB="$WORK/_from_vtt.srt"
  fi
fi

if [ -n "$SUB" ] && [ -s "$SUB" ]; then
  echo "[OK] 使用官方字幕，跳过 Whisper：$SUB"
  [ "$SUB" != "$WORK/transcript.srt" ] && cp "$SUB" "$WORK/transcript.srt"
else
  echo "[..] 无官方字幕 → FFmpeg 提音频 + whisper.cpp 转录（中文）…"
  AUDIO="$WORK/audio.wav"
  "$FFMPEG" -y -i "$VIDEO" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$AUDIO" >>"$LOG" 2>&1 || {
    echo "[FAIL] FFmpeg 提取音频失败；日志末尾："; tail -n 8 "$LOG" 2>/dev/null; exit 1; }
  "$WHISPER" -m "$MODEL" -f "$AUDIO" -l zh -osrt -of "$WORK/transcript" >>"$LOG" 2>&1 || {
    echo "[FAIL] whisper.cpp 转录失败；日志末尾："; tail -n 8 "$LOG" 2>/dev/null; exit 1; }
  [ -f "$WORK/transcript.srt" ] || { echo "[FAIL] 未生成 transcript.srt"; exit 1; }
  echo "[OK] 转录完成"
fi

# ---- 生成纯文本（去时间戳/序号）----
sed -E '/^[0-9]+$/d; /^[0-9]{2}:[0-9]{2}/d; /^$/d' "$WORK/transcript.srt" > "$WORK/transcript.txt"

echo
echo "[OK] 文稿就绪："
echo "   $WORK/transcript.srt   (带时间戳)"
echo "   $WORK/transcript.txt   (纯文本)"
echo "TRANSCRIPT_READY $WORK"
