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
    win32)  cmd_exists winget && { winget install --id=Gyan.FFmpeg -e --accept-source-agreements --accept-package-agrees && return 0; } || { echo "[FAIL] 无 winget，请手动下载 ffmpeg 静态版加入 PATH" >&2; return 1; } ;;
    *)      echo "[FAIL] 未知平台，请手动安装 ffmpeg" >&2; return 1 ;;
  esac
}

# ---------------- whisper.cpp ----------------
# install_whisper_cpp → 装到 bin/whisper.cpp/，成功 exit 0（不返回路径，状态走 stderr）
install_whisper_cpp() {
  local os; os=$(detect_os)
  local dest="$SKILL_ROOT/bin/whisper.cpp"; mkdir -p "$dest"
  local tmp="$dest/_dl.zip"
  echo "[..] 安装 whisper.cpp（$os）→ $dest" >&2
  [ "$os" = "darwin" ] && cmd_exists brew && { brew install whisper-cpp && return 0; }
  local base="https://github.com/ggerganov/whisper.cpp/releases/latest/download" asset=""
  case "$os" in
    win32) asset="whisper-bin-x64.zip" ;;
    linux) asset="whisper-linux-x64.zip" ;;
  esac
  if [ -n "$asset" ] && download_with_mirrors "$base/$asset" "$tmp"; then
    { cd "$dest" && unzip -oq _dl.zip && rm -f _dl.zip; } 2>/dev/null || \
    { cd "$dest" && powershell.exe -NoProfile -Command "Expand-Archive -Force _dl.zip ." && rm -f _dl.zip; } 2>/dev/null
    return 0
  fi
  echo "[FAIL] 自动安装 whisper.cpp 失败（release 资源名可能已变）" >&2
  echo "[HINT] 到 https://github.com/ggerganov/whisper.cpp/releases 手动下载对应平台预编译版，" >&2
  echo "       解压到 $dest，确保含 whisper-cli（或 main）可执行文件" >&2
  return 1
}

# locate_whisper_cli → 路径走 stdout（未找到输出空行）
locate_whisper_cli() {
  local dest="$SKILL_ROOT/bin/whisper.cpp" name ext p
  for name in whisper-cli main; do
    for ext in "" ".exe"; do
      p="$dest/$name$ext"; [ -f "$p" ] && { echo "$p"; return 0; }
    done
  done
  cmd_exists whisper-cli && { command -v whisper-cli; return 0; }
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
  local fname="ggml-${tier}.bin" out="$modelsdir/$fname"
  [ -f "$out" ] && { echo "[OK] 模型已存在：$out" >&2; echo "$out"; return 0; }
  local url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fname"
  echo "[..] 下载 whisper 模型 $tier（$fname）→ $out" >&2
  if curl -fL --connect-timeout 20 --max-time 7200 -o "$out" "$url"; then
    [ -s "$out" ] && { echo "[OK] 模型下载完成" >&2; echo "$out"; return 0; }
  fi
  echo "[FAIL] 模型下载失败：$url" >&2
  echo "[HINT] 国内可用镜像（如 hf-mirror.com）下载 $fname 到 $out" >&2
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
