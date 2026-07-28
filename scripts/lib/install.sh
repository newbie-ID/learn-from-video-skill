#!/usr/bin/env bash
# install.sh — 三件套 + 模型 + 下游 skill 的安装函数（被 setup.sh source）
# 依赖：detect.sh（detect_os / cmd_exists）、mirrors.sh（download/clone_with_mirrors）
#
# 输出约定：
#   - 返回路径的函数（locate_whisper_cli / install_ytdlp / download_model）→ 路径走 stdout，状态走 stderr
#   - 只装不返回路径的函数（install_ffmpeg / install_whisper_cpp / ensure_downstream_skills）→ 全部走 stderr
#
# 策略：预编译二进制 / 包管理器 优先，失败给清晰手动指引（LLM-friendly），不强求 100% 自动。
# 说明：本文件内的可变 URL（模型下载、AI_Animation 仓库）与 dependencies.json 保持同步，
#       如需修改请同时更新两处。详见 scripts/README.md。

# ---------------- FFmpeg（只装，不返回路径；setup 用 command -v 取路径）----------------
install_ffmpeg() {
  local os; os=$(detect_os)
  echo "[..] 安装 ffmpeg（$os）" >&2
  case "$os" in
    darwin) cmd_exists brew && { brew install ffmpeg && return 0; } || { echo "[FAIL] brew 不可用，请手动: brew install ffmpeg" >&2; return 1; } ;;
    linux)  cmd_exists apt-get && { sudo apt-get update -qq && sudo apt-get install -y ffmpeg && return 0; } || { echo "[FAIL] 无 apt-get，请手动安装 ffmpeg" >&2; return 1; } ;;
    win32)
      # 优先下载 BtbN 预编译（GitHub，可走镜像加速，路径可控、不依赖 PATH 刷新）
      local ffd="$SKILL_ROOT/bin/ffmpeg"; mkdir -p "$ffd"
      local tmp="$ffd/_dl.zip"
      local url="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
      if download_with_mirrors "$url" "$tmp"; then
        { cd "$ffd" && unzip -oq _dl.zip && rm -f _dl.zip; } 2>/dev/null || \
        { cd "$ffd" && powershell.exe -NoProfile -Command "Expand-Archive -Force _dl.zip ." && rm -f _dl.zip; } 2>/dev/null
        locate_ffmpeg >/dev/null && return 0
        echo "[FAIL] ffmpeg 解压后未找到 ffmpeg.exe" >&2
      fi
      # fallback：winget（参数是 --accept-package-agreements，复数 -ments）
      if cmd_exists winget; then
        winget install --id=Gyan.FFmpeg -e --silent --accept-source-agreements --accept-package-agreements && return 0
      fi
      echo "[FAIL] ffmpeg 自动安装失败" >&2
      echo "[HINT] 手动下载 ffmpeg 静态版（gyan.dev 或 BtbN）解压，确保 PATH 含 ffmpeg" >&2
      return 1
      ;;
    *) echo "[FAIL] 未知平台，请手动安装 ffmpeg" >&2; return 1 ;;
  esac
}

# locate_ffmpeg → 路径走 stdout（系统 PATH 优先；否则在 bin/ffmpeg 下递归找，-type f 避免匹配目录名）
locate_ffmpeg() {
  cmd_exists ffmpeg && { command -v ffmpeg; return 0; }
  local f; f=$(find "$SKILL_ROOT/bin/ffmpeg" -type f \( -name ffmpeg.exe -o -name ffmpeg \) 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "$f"; return 0; }
  echo ""
}

# ---------------- whisper.cpp ----------------
# install_whisper_cpp → 装到 bin/whisper.cpp/，成功 exit 0（不返回路径，状态走 stderr）
install_whisper_cpp() {
  local os; os=$(detect_os)
  local dest="$SKILL_ROOT/bin/whisper.cpp"; mkdir -p "$dest"
  local tmp="$dest/_dl.zip"
  local base="https://github.com/ggerganov/whisper.cpp/releases/latest/download"
  [ "$os" = "darwin" ] && cmd_exists brew && { echo "[..] 安装 whisper.cpp（macOS brew）" >&2; brew install whisper-cpp && return 0; }
  # GPU 现状（v1.9.1）：release 无 Vulkan build；cublas(CUDA) build 需系统装匹配版本 CUDA runtime（不自带 dll），
  # 对"分发给小白"不友好。故默认 CPU build（稳定、所有机器能跑）。
  # 硬件有 GPU 的高级用户可自行换 cublas build（需匹配的 CUDA 12.x runtime）或等未来 Vulkan release。
  local asset=""
  case "$os" in
    win32) asset="whisper-bin-x64.zip" ;;
    linux) asset="whisper-linux-x64.zip" ;;
  esac
  echo "[..] 安装 whisper.cpp（$os · CPU build）→ $dest" >&2
  if [ -n "$asset" ] && download_with_mirrors "$base/$asset" "$tmp"; then
    { cd "$dest" && unzip -oq _dl.zip && rm -f _dl.zip; } 2>/dev/null || \
    { cd "$dest" && powershell.exe -NoProfile -Command "Expand-Archive -Force _dl.zip ." && rm -f _dl.zip; } 2>/dev/null
    locate_whisper_cli >/dev/null && return 0
  fi
  echo "[FAIL] whisper.cpp 安装失败" >&2
  echo "[HINT] 到 https://github.com/ggerganov/whisper.cpp/releases 手动下载 *-bin-x64.zip 解压到 $dest" >&2
  return 1
}

# locate_whisper_cli → 路径走 stdout（递归找，优先 whisper-cli 再 main；解压后常在 Release/ 子目录下）
locate_whisper_cli() {
  local dest="$SKILL_ROOT/bin/whisper.cpp" f
  f=$(find "$dest" -type f \( -name whisper-cli.exe -o -name whisper-cli \) 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "$f"; return 0; }
  f=$(find "$dest" -type f \( -name main.exe -o -name main \) 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "$f"; return 0; }
  cmd_exists whisper-cli && { command -v whisper-cli; return 0; }
  echo ""
}

# locate_ytdlp → 路径走 stdout（系统 PATH 优先；否则在 bin/ 下找 yt-dlp / yt-dlp.exe）
locate_ytdlp() {
  cmd_exists yt-dlp && { command -v yt-dlp; return 0; }
  local f; f=$(find "$SKILL_ROOT/bin" -maxdepth 1 -type f \( -name yt-dlp.exe -o -name yt-dlp \) 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "$f"; return 0; }
  echo ""
}

# ---------------- yt-dlp（单文件二进制 → bin/，路径走 stdout）----------------
install_ytdlp() {
  local os; os=$(detect_os)
  local bindir="$SKILL_ROOT/bin"; mkdir -p "$bindir"
  local base="https://github.com/yt-dlp/yt-dlp/releases/latest/download" asset out
  case "$os" in
    win32)  asset="yt-dlp.exe";   out="$bindir/yt-dlp.exe" ;;
    darwin) asset="yt-dlp_macos"; out="$bindir/yt-dlp" ;;
    linux)  asset="yt-dlp";       out="$bindir/yt-dlp" ;;
  esac
  echo "[..] 安装 yt-dlp（$os）→ $out" >&2
  if download_with_mirrors "$base/$asset" "$out"; then
    chmod +x "$out" 2>/dev/null
    echo "$out"
    return 0
  fi
  echo "[FAIL] 自动下载 yt-dlp 失败" >&2
  echo "[HINT] 手动下载 $base/$asset 到 $out 并赋予执行权限" >&2
  return 1
}

# ---------------- whisper 模型（路径走 stdout）----------------
download_model() {
  local tier="$1"
  local modelsdir="$SKILL_ROOT/models"; mkdir -p "$modelsdir"
  local fname="ggml-${tier}.bin"
  local out="$modelsdir/$fname"
  # 大小校验：模型至少 100MB，避免上次失败留下的残缺文件被误判"已存在"
  local sz=0; [ -f "$out" ] && sz=$(stat -c%s "$out" 2>/dev/null || echo 0)
  if [ "${sz:-0}" -gt 100000000 ]; then
    echo "[OK] 模型已存在（$((sz/1048576))MB）：$out" >&2; echo "$out"; return 0
  fi
  rm -f "$out"
  echo "[..] 下载 whisper 模型 $tier（$fname）→ $out" >&2
  # 候选源：hf-mirror（国内镜像，优先）+ huggingface 直连；--ssl-no-revoke 规避 Windows schannel 吊销检查
  local url
  for url in \
    "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/$fname" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fname"; do
    if curl -fL --ssl-no-revoke --connect-timeout 20 --max-time 7200 -o "$out" "$url"; then
      [ -s "$out" ] && { echo "[OK] 模型下载完成（$url）" >&2; echo "$out"; return 0; }
    fi
    rm -f "$out"
    echo "[..] 该源失败，尝试下一个…" >&2
  done
  echo "[FAIL] 模型下载失败" >&2
  echo "[HINT] 手动下载 $fname 到 $out（hf-mirror.com 或 huggingface.co）" >&2
  return 1
}

# ---------------- 下游 skill（从 AI_Animation 合集抽取 3 个，装到标准目录）----------------
ensure_downstream_skills() {
  local skills_dir="$1"; mkdir -p "$skills_dir"
  local want=("scholar-notes" "ppt-animation" "flowchart") missing=() s
  for s in "${want[@]}"; do [ -d "$skills_dir/$s" ] || missing+=("$s"); done
  if [ ${#missing[@]} -eq 0 ]; then
    echo "[OK] 3 个下游 skill 均已就位：$skills_dir" >&2
    return 0
  fi
  echo "[..] 缺少下游 skill：${missing[*]} → 从 AI_Animation 合集抽取" >&2
  local tmp="$SKILL_ROOT/bin/_ai_animation_$$"
  if ! clone_with_mirrors "https://github.com/Unclecheng-li/AI_Animation" "$tmp"; then
    rm -rf "$tmp"; return 1
  fi
  for s in "${missing[@]}"; do
    if [ -d "$tmp/skills/$s" ]; then
      cp -r "$tmp/skills/$s" "$skills_dir/$s"
      echo "[OK] 已安装 $s → $skills_dir/$s" >&2
    else
      echo "[WARN] 合集内未找到 skills/$s（上游结构可能变化）" >&2
    fi
  done
  rm -rf "$tmp"
  return 0
}
