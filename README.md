<div align="center">

# learn-from-video-skill

**把视频 / 音频变成「可追问 · 可复习 · 可自测」的学习成品**

一个 Agent Skill：丢一个视频/音频链接或本地文件 → 自动转录成带时间戳文稿 → 做成学霸笔记 / PPT / 概念图 / 自测题。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](./LICENSE)
[![Engine](https://img.shields.io/badge/转录-whisper.cpp-green?style=flat-square)](https://github.com/ggerganov/whisper.cpp)
[![Spec](https://img.shields.io/badge/Skill-SKILL.md-black?style=flat-square)](./SKILL.md)

</div>

---

## 这是什么

一个**上游管道 skill**：核心能力是 `视频/音频 → 结构化文本 + 时间索引`，呈现层外包给 [AI_Animation](https://github.com/Unclecheng-li/AI_Animation) 合集（学霸笔记 / PPT / 概念图）。最大化复用、不造轮子。

**典型场景**：
- 📺 **视频学习**：B站 / YouTube 教程转笔记、转自测题
- 🎙️ **面试复盘**：面试录音 / 面试录屏转文稿，做复盘笔记、自测纠错、问答演练
- 📝 **录音转纪要**：会议、讲座、播客录音整理

> 完整工作流可视化（动画图）后续会发布到 GitHub Pages，本 README 暂不内嵌（GitHub 不渲染 HTML）。

## 特性

- 🔗 **多入口**：B站 / YouTube 等链接，或本地**视频 / 音频**文件（mp3 / wav / m4a / mp4 …）
- 🎙️ **面试/录音友好**：面试录屏、录音直接拖进来转文稿复盘
- 📝 **字幕优先**：有官方字幕直接用（零成本、100% 准确），无字幕才 whisper.cpp 转录
- 🎧 **whisper.cpp 中文优先**：单二进制、跨平台、按硬件自动选模型档位
- 🔁 **学-记-测闭环**：追问学习 / 笔记·PPT·概念图 / 自测题·闪卡
- 📦 **首次自动配环境**：自动装 FFmpeg / whisper.cpp / yt-dlp + 下游 skill，之后免检

## 快速开始

### 安装

对你的 Agent 说：

```
帮我安装 https://github.com/newbie-ID/learn-from-video-skill 这个 skill
如遇网络问题，尝试使用镜像站 https://gh-proxy.com/ 进行安装
```

首次使用会自动下载并配置 whisper.cpp / yt-dlp / FFmpeg + 下游 skill，完成后**重启 Agent** 让下游 skill 被发现。

### 用法

```
用 learn-from-video 处理这个视频 https://www.bilibili.com/video/BVxxxxxxxx
帮我把这段面试录音做成复盘笔记：D:/interview.m4a
这个面试录屏讲了什么，出几道自测题：D:/screen-record.mp4
```

同一个视频/音频可连续触发多个输出（先笔记、再自测），共享缓存文稿，不重复转录。

## 输出示例（学 / 记 / 测）

| 类别 | 输出 | 谁来做 |
|------|------|--------|
| **学** | 追问学习（带时间戳定位） | 本 skill 自带 |
| **记** | 学霸笔记 / PPT 复习卡 / 概念图 / 一页纸摘要 | 下游 skill（前 3）/ 自带（摘要） |
| **测** | 自测题 / 闪卡 / 时间戳大纲 | 本 skill 自带 |

样例产物见 [`examples/`](./examples/)。

## 转录性能（large-v3 模型）

> 实测设备：RTX 4070 SUPER（12GB 显存）。GPU 使用 cublas-12.4 build。

| 视频 | 时长 | CPU（估算） | GPU（实测） | 加速比 |
|---|---|---|---|---|
| 某面试录屏 | ~11.5 min | ~30–40 min | **122 s**（~2 min） | ~**15–20×** |
| 课程视频（CS336 Lecture 1） | ~80 min | ~150–240 min | **522 s**（~8.7 min） | ~**17–28×** |

> CPU 耗时基于 whisper.cpp large-v3 CPU build 通常 ~0.3–0.5× 实时估算，实际因 CPU 型号而异。

## 技术栈

`whisper.cpp`（转录 · CPU / cublas GPU 自动选择）· `yt-dlp`（下载）· `FFmpeg`（音频提取）· 下游 `scholar-notes` / `ppt-animation` / `flowchart`（渲染）

## 目录结构

```
learn-from-video-skill/
├── SKILL.md                 ← Agent 调度指令（核心）
├── dependencies.json        ← 依赖清单（三件套 + 下游 skill + 镜像站）
├── scripts/                 ← setup.sh / process.sh + lib/（公共函数）
├── references/              ← mapping-table.md(★兜底映射) / output-options / checklist / env-template
├── library/                 ← 运行时缓存（gitignore，按 ID 存）
└── examples/                ← 产出格式样例
```

## 致谢

基于 [AI_Animation](https://github.com/Unclecheng-li/AI_Animation)（MIT, @Unclecheng-li），感谢作者。

## License

MIT — 仅供学习用途。
