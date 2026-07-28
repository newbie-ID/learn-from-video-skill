#!/usr/bin/env bash
# setup.sh — learn-from-video-skill 首次初始化（一次性）
#
# 用法:
#   bash scripts/setup.sh            # 完整初始化（检测→装三件套→选模型→装下游skill→写 env.local.json）
#   bash scripts/setup.sh --check    # 只检测是否已初始化，stdout 输出 NOT_INITIALIZED / READY（+env路径）
#
# CWD 无关：脚本自动定位 skill 根。
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_ROOT/env.local.json"

. "$SCRIPT_DIR/lib/detect.sh"
. "$SCRIPT_DIR/lib/mirrors.sh"
. "$SCRIPT_DIR/lib/install.sh"

# ---- --check 模式（SKILL.md 第一步用它判断走哪条路）----
if [ "${1:-}" = "--check" ]; then
  if [ -f "$ENV_FILE" ]; then echo "READY"; echo "$ENV_FILE"; else echo "NOT_INITIALIZED"; fi
  exit 0
fi

echo "================================================"
echo " learn-from-video-skill · 首次初始化"
echo "================================================"

OS=$(detect_os)
SKILLS_DIR=$(detect_agent_skills_dir)
VRAM=$(detect_gpu_vram_mb); RAM=$(detect_ram_gb)
TIER="${LFV_MODEL_TIER:-$(pick_model_tier)}"
echo "[detect] 平台=$OS  显存=${VRAM:-无}MB  内存=${RAM:-未知}GB"
echo "[detect] Agent skills 目录=$SKILLS_DIR"
echo "[detect] 推荐模型档位=$TIER（中文优先）"
echo

# ---- [1/4] FFmpeg ----
echo "---- [1/4] FFmpeg ----"
FFMPEG_PATH="$(locate_ffmpeg)"
if [ -z "$FFMPEG_PATH" ]; then
  install_ffmpeg || { echo "[FAIL] ffmpeg 安装失败，初始化中止"; exit 1; }
  FFMPEG_PATH="$(locate_ffmpeg)"
fi
[ -n "$FFMPEG_PATH" ] || { echo "[FAIL] ffmpeg 不可用，初始化中止"; exit 1; }
echo "[OK] ffmpeg：$FFMPEG_PATH"

# ---- [2/4] whisper.cpp ----
echo "---- [2/4] whisper.cpp ----"
WHISPER_PATH="$(locate_whisper_cli)"
if [ -z "$WHISPER_PATH" ]; then
  install_whisper_cpp || { echo "[FAIL] whisper.cpp 安装失败，初始化中止"; exit 1; }
  WHISPER_PATH="$(locate_whisper_cli)"
fi
[ -n "$WHISPER_PATH" ] || { echo "[FAIL] whisper-cli 不可用，初始化中止"; exit 1; }
echo "[OK] whisper-cli：$WHISPER_PATH"

# ---- [3/4] yt-dlp ----
echo "---- [3/4] yt-dlp ----"
YTDLP_PATH="$(locate_ytdlp)"
[ -z "$YTDLP_PATH" ] && YTDLP_PATH="$(install_ytdlp)"
[ -n "$YTDLP_PATH" ] || { echo "[FAIL] yt-dlp 不可用，初始化中止"; exit 1; }
echo "[OK] yt-dlp：$YTDLP_PATH"

# ---- [4/4] 模型 + 下游 skill ----
echo "---- [4/4] whisper 模型 ($TIER) + 下游 skill ----"
MODEL_PATH="$(download_model "$TIER")"
[ -n "$MODEL_PATH" ] || { echo "[FAIL] 模型未就绪，初始化中止"; exit 1; }
ensure_downstream_skills "$SKILLS_DIR" || echo "[WARN] 部分下游 skill 安装失败（详见上方提示，可手动补装）"

# ---- 写 env.local.json ----
mkdir -p "$SKILLS_DIR"
cat > "$ENV_FILE" <<EOF
{
  "ffmpeg": "$FFMPEG_PATH",
  "whisper_cli": "$WHISPER_PATH",
  "whisper_model": "$MODEL_PATH",
  "model_tier": "$TIER",
  "ytdlp": "$YTDLP_PATH",
  "platform": "$OS",
  "agent_skills_dir": "$SKILLS_DIR",
  "downstream_skills": ["scholar-notes", "ppt-animation", "flowchart"]
}
EOF

echo
echo "================================================"
echo " [完成] 环境就绪"
echo "================================================"
echo " 工具:  ffmpeg / whisper-cli($TIER) / yt-dlp"
echo " 模型:  $MODEL_PATH"
echo " 快照:  $ENV_FILE"
echo " 下游:  $SKILLS_DIR/{scholar-notes,ppt-animation,flowchart}"
echo
echo " [下一步] 请重启你的 Agent，让新装的下游 skill 被发现。"
echo "          之后直接说「用 learn-from-video 处理这个视频 <链接或本地文件>」即可。"
echo
echo " [提示] 若 skills 目录猜错，删除 $ENV_FILE 后设环境变量"
echo "        LFV_SKILLS_DIR=<你的skills目录> 再重新运行 setup.sh"
