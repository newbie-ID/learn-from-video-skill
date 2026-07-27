#!/usr/bin/env bash
# mirrors.sh — GitHub 加速 fallback 工具（被 install.sh / setup.sh source）
#
# 输出约定：状态/进度/错误一律走 stderr（>&2）；这些函数不向 stdout 返回值，
# 因此调用方用 $(...) 捕获别的函数路径时不会被这里的日志污染。
#
# 镜像前缀列表需与 dependencies.json 的 mirrors 字段保持一致。

_MIRRORS=(
  ""                              # 直连（空前缀 = 用原始 URL）
  "https://gh-proxy.com/"
  "https://ghproxy.net/"
  "https://ghproxy.homeboyc.cn/"
  "http://toolwa.com/github/"
  "https://github.akams.cn/"
)

_is_github_url() {
  [[ "$1" == https://github.com/* || "$1" == http://github.com/* ]]
}

# download_with_mirrors <url> <dest>  → 成功 exit 0，失败 exit 1（日志均走 stderr）
download_with_mirrors() {
  local url="$1" dest="$2" prefix cand tried=""
  for prefix in "${_MIRRORS[@]}"; do
    cand="${prefix}${url}"
    if curl -fL --connect-timeout 15 --max-time 1800 -o "$dest" "$cand" 2>/dev/null; then
      [ -s "$dest" ] && { echo "[OK] 下载成功：${prefix:-直连}" >&2; return 0; }
    fi
    tried="${tried}    - ${prefix:-直连}${url}"$'\n'
  done
  echo "[FAIL] 所有下载来源均失败，试过：" >&2
  printf '%s' "$tried" >&2
  echo "[HINT] 请手动下载原文件到：$dest" >&2
  echo "       原始地址：$url" >&2
  return 1
}

# clone_with_mirrors <repo_url> <dest_dir>  → 成功 exit 0，失败 exit 1（日志均走 stderr）
clone_with_mirrors() {
  local repo="$1" dest="$2" prefix cand
  if git clone --depth 1 "$repo" "$dest" 2>/dev/null; then
    echo "[OK] git clone 成功（直连）" >&2
    return 0
  fi
  echo "[..] git 直连失败，尝试镜像…" >&2
  for prefix in "${_MIRRORS[@]:1}"; do
    cand="${prefix}${repo}"
    if git clone --depth 1 "$cand" "$dest" 2>/dev/null; then
      echo "[OK] git clone 成功（镜像 $prefix）" >&2
      return 0
    fi
  done
  echo "[FAIL] git clone 全部失败（含镜像）" >&2
  echo "[HINT] 可手动下载 zip 解压：" >&2
  echo "       ${repo%.git}/archive/refs/heads/main.zip  →  $dest" >&2
  return 1
}
