<div align="center">

# learn-from-video-skill

**把任意视频变成「可追问 · 可复习 · 可自测」的学习成品**

一个 Agent Skill：丢一个视频链接（或本地视频）→ 自动下载转录成带时间戳文稿 → 用 AI_Animation 全家桶做成笔记 / PPT / 概念图 / 自测题。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](./LICENSE)
[![Engine](https://img.shields.io/badge/转录-whisper.cpp-green?style=flat-square)](https://github.com/ggerganov/whisper.cpp)
[![Spec](https://img.shields.io/badge/Skill-SKILL.md-black?style=flat-square)](./SKILL.md)

</div>

---

## 这是什么

一个**上游管道 skill**：核心能力是 `视频 → 结构化文本 + 时间索引`，呈现层全部外包给已有的 [AI_Animation](https://github.com/Unclecheng-li/AI_Animation) 合集（学霸笔记 / PPT / 概念图）。你不用从零造渲染，最大化复用。

> 完整工作流图见 [`learn-from-video-skill-preview.html`](./learn-from-video-skill-preview.html)（浏览器打开可看动画）。

## 特性

- 🔗 **双入口**：B站 / YouTube 等链接，或本地视频文件
- 📝 **字幕优先**：有官方字幕直接用（零成本、100% 准确），无字幕才 fallback 到 whisper.cpp
- 🎙️ **whisper.cpp 中文优先**：单二进制、跨平台、按硬件自动选模型档位
- 🔁 **学-记-测闭环**：追问学习 / 笔记·PPT·概念图 / 自测题·闪卡
- 📦 **首次自动配环境**：自动装 FFmpeg / whisper.cpp / yt-dlp + 下游 skill，之后免检
- 🌐 **跨平台分发**：不假设 npx/git，镜像站加速 fallback

## 快速开始

### 1. 安装 skill

把整个 `learn-from-video-skill/` 文件夹复制到你 Agent 的 skills 目录（见下方兼容表），重启 Agent。

### 2. 首次使用（自动配环境）

直接对 Agent 说：

```
用 learn-from-video 处理这个视频 https://www.bilibili.com/video/BVxxxxxxxx
```

首次会自动跑初始化（装三件套 + 下载模型 + 装下游 skill），完成后**重启一次 Agent**让下游 skill 被发现。

### 3. 日常使用

```
把这个视频做成学霸笔记：https://...        # 链接
帮我看懂这个本地视频讲的什么：D:/lesson.mp4  # 本地文件
用这个视频出一个自测题：https://...
```

同一个视频可以连续触发多个输出（先笔记、再自测），共享缓存文稿，不重复下载。

## 输出示例（学 / 记 / 测）

| 类别 | 输出 | 谁来做 |
|------|------|--------|
| **学** | 追问学习（RAG，带时间戳定位） | 本 skill 自带 |
| **记** | 学霸笔记 / PPT 复习卡 / 概念图 / 一页纸摘要 | 下游 skill（前 3）/ 自带（摘要） |
| **测** | 自测题 / 闪卡 / 时间戳大纲 | 本 skill 自带 |

样例产物见 [`examples/`](./examples/)。

## 平台兼容

| Agent / Runtime | skills 目录 | 状态 |
|---|---|---|
| Claude Code | `.claude/skills/<name>/` | ✅ 主要适配 |
| WorkBuddy | `~/.workbuddy/skills/<name>/` | ✅ 兼容 |
| Cursor / Trae | `.agents/skills/<name>/` | ✅ 兼容 |
| Codex CLI | `.codex/skills/<name>/` | ✅ 兼容 |

> 若自动探测的 skills 目录不对，设环境变量 `LFV_SKILLS_DIR=<你的目录>` 后重跑初始化。

## 技术栈

`whisper.cpp`（转录）· `yt-dlp`（下载）· `FFmpeg`（音频提取）· 下游 `scholar-notes` / `ppt-animation` / `flowchart`（渲染）

## 目录结构

```
learn-from-video-skill/
├── SKILL.md                 ← Agent 调度指令（核心）
├── dependencies.json        ← 依赖清单（三件套 + 下游 skill + 镜像站）
├── scripts/                 ← setup.sh / process.sh + lib/（公共函数）
├── references/              ← mapping-table.md(★兜底映射) / output-options / checklist / env-template
├── library/                 ← 运行时缓存（gitignore，按视频 ID 存）
├── examples/                ← 产出格式样例
└── learn-from-video-skill-preview.html  ← 工作流预览图
```

## 致谢

基于 [AI_Animation](https://github.com/Unclecheng-li/AI_Animation)（MIT, @Unclecheng-li）与 `note-skill` 的下游 skill 能力构建。脚本组织模式参考了其中的 `dynamic-archify`。

## License

MIT — 仅供学习用途。
