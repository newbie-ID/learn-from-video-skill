#!/usr/bin/env bash
# detect.sh — 环境探测（平台 / Agent skills 目录 / 硬件）
# 被 setup.sh source。

# 探测 OS：win32 | darwin | linux | unknown
detect_os() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "win32" ;;
    Darwin)               echo "darwin" ;;
    Linux)                echo "linux" ;;
    *)                    echo "unknown" ;;
  esac
}

# 命令是否存在
cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# 探测当前 Agent 的标准 skills 目录（绝对路径）。
# 优先级：环境变量 LFV_SKILLS_DIR > 已安装 Agent 的目录探测 > 默认 ~/.claude/skills
detect_agent_skills_dir() {
  if [ -n "$LFV_SKILLS_DIR" ]; then echo "$LFV_SKILLS_DIR"; return 0; fi
  local pick=""
  [ -d "$HOME/.claude" ]   && pick="$HOME/.claude/skills"
  [ -z "$pick" ] && [ -d "$HOME/.workbuddy" ] && pick="$HOME/.workbuddy/skills"
  [ -z "$pick" ] && [ -d "$HOME/.trae" ]      && pick="$HOME/.trae/skills"
  [ -z "$pick" ] && [ -d "$HOME/.codex" ]     && pick="$HOME/.codex/skills"
  [ -z "$pick" ] && [ -d "$PWD/.agents" ]     && pick="$PWD/.agents/skills"
  # 都没明确检测到 → 用最通用的默认（setup 末尾会提示用户可用 LFV_SKILLS_DIR 覆盖）
  [ -z "$pick" ] && pick="$HOME/.claude/skills"
  echo "$pick"
}

# GPU 显存（MB），无 NVIDIA 则输出空
detect_gpu_vram_mb() {
  if cmd_exists nvidia-smi; then
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d '[:space:]'
  fi
}

# 物理内存（GB），best effort
detect_ram_gb() {
  case "$(detect_os)" in
    darwin) sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1073741824)}' ;;
    linux)  awk '/MemTotal/{print int($2/1048576)}' /proc/meminfo 2>/dev/null ;;
    win32)  powershell.exe -NoProfile -Command '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory' 2>/dev/null \
              | tr -d '\r' | awk '{print int($1/1073741824)}' ;;
  esac
}

# 按硬件选 whisper 模型档位：large-v3 | medium | small
pick_model_tier() {
  local vram ram
  vram=$(detect_gpu_vram_mb)
  ram=$(detect_ram_gb)
  if [ -n "$vram" ] && [ "$vram" -ge 6000 ] 2>/dev/null; then
    echo "large-v3"
  elif { [ -n "$vram" ] && [ "$vram" -ge 2000 ]; } 2>/dev/null; then
    echo "medium"
  elif [ -n "$ram" ] && [ "$ram" -ge 16 ] 2>/dev/null; then
    echo "medium"
  else
    echo "small"
  fi
}
