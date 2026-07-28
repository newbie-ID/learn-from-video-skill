---
name: learn-from-video-skill
description: "下载视频或音频（B站/YouTube 链接，或本地视频/音频文件；支持面试录音、面试录屏复盘）并转录成带时间戳文稿，再基于文稿做：追问学习、学霸笔记/PPT复习卡/概念图、自测题与闪卡。用于：视频学习、面试复盘、录音转纪要、教程转复习材料。首次自动配置 whisper.cpp/yt-dlp/FFmpeg，字幕优先、无字幕用 whisper.cpp 转录（中文优先）。下游渲染复用 AI_Animation 合集（scholar-notes/ppt-animation/flowchart）。"
version: "0.1.0"
license: MIT
triggers:
  - "视频学习"
  - "视频笔记"
  - "看视频做笔记"
  - "视频转录"
  - "视频转文字"
  - "视频字幕"
  - "视频总结"
  - "视频转笔记"
  - "面试复盘"
  - "面试录音"
  - "面试录屏"
  - "录音转文字"
  - "音频转文字"
  - "learn-from-video"
  - "video to notes"
  - "audio to notes"
metadata:
  author: learn-from-video-skill contributors
  based_on: "AI_Animation (MIT, Unclecheng-li) + note-skill"
---

# learn-from-video-skill

把任意视频变成「可追问 · 可复习 · 可自测」的学习成品。**上游管道 skill**：视频 → 带时间戳文稿 → 缓存库 → 学/记/测输出。

---

## 双模式：先判断走哪条路

激活后，**第一步永远是检查环境快照**（脚本会自动定位 skill 根，CWD 无关）：

```bash
bash scripts/setup.sh --check
```

- **返回 `NOT_INITIALIZED`** → 走【模式一：首次初始化】（一次性）
- **返回 `READY`（并打印 env.local.json 路径）** → 走【模式二：日常使用】

> 不要手写 `env.local.json`，它必须由 setup 生成（含本机绝对路径）。

---

## 模式一：首次初始化（一次性）

```bash
bash scripts/setup.sh
```

`setup.sh` 会自动完成（每步打印 LLM 友好的状态行）：
1. **探测环境** — OS / GPU / 显存 / 内存 / 当前 Agent 的标准 skills 目录
2. **装三件套** — `ffmpeg` / `whisper.cpp` / `yt-dlp`（已存在则跳过；预编译二进制优先，包管理器兜底，全程镜像加速）
3. **选模型** — 按硬件自动选 `large-v3` / `medium` / `small`（中文优先）并下载 ggml 模型
4. **装下游 skill** — 检测 `scholar-notes` / `ppt-animation` / `flowchart` 是否在标准 skills 目录，缺则按 `dependencies.json` 拉取（git clone 优先，失败 fallback 下载 zip + 镜像）
5. **写快照** — 生成 `env.local.json`（工具路径 + 模型 + 参数 + 平台）

完成后向用户报告：装了什么、模型档位、下游 skill 在哪、**提示用户重启 Agent**（让新装的下游 skill 被发现），然后转入【模式二】。

---

## 模式二：日常使用 Pipeline

### Step 1 — 双入口判断

看用户给的是什么：
- 以 `http://` 或 `https://` 开头 → **URL 模式**（B站 / YouTube / yt-dlp 支持的任意平台）
- 否则，是本地文件路径（**视频或音频**，如面试录音 mp3/wav/m4a、面试录屏 mp4、会议录音）→ **本地模式**（跳过下载，直接转录）

> `process.sh` 对视频和音频输入都适用：音频文件直接转，视频文件先由 FFmpeg 提取音频再转。用户可能一次给多个链接/文件，逐个处理，每个生成独立文稿。

### Step 2 — 执行 process.sh（确定性机械步骤）

```bash
# URL 模式
bash scripts/process.sh url "<视频链接>"

# 本地模式
bash scripts/process.sh local "<文件路径>"
```

`process.sh` 自动做：
1. **取/算 ID** — URL 用视频 ID；本地文件用内容 hash 作 ID
2. **缓存命中检查** — `library/<id>/transcript.*` 已存在 → 直接复用，秒出，跳过后续所有步骤
3. **下载**（仅 URL 模式）— yt-dlp 下载视频，**同时尝试 `--write-subs` 拉官方字幕**
4. **字幕优先判断**：
   - ✅ 拿到官方字幕 → 直接采用（零成本、100% 准确），**跳过 Whisper**
   - ❌ 没有字幕 → FFmpeg 提取音频（16kHz 单声道 wav）→ whisper.cpp 转录（`-l zh`，输出 srt）
   - ⚠️ 本地视频通常无现成字幕 → 默认走 whisper.cpp
5. **生成文稿** — 输出 `library/<id>/transcript.{srt,txt,json}`（带时间戳）

脚本结束时会打印：`TRANSCRIPT_READY <library/<id> 绝对路径>`。把这条路径记下来，后续步骤都用它。

### Step 3 — 输出选项菜单

读取 `references/output-options.md`，向用户展示「学 / 记 / 测」选项并让其选择（可多选）：

| 类别 | 选项 | 谁来做 |
|------|------|--------|
| **学** | 追问学习（AI 带你看视频，带时间戳定位） | 本 skill 自带 |
| **记** | 学霸笔记 / PPT 复习卡 / 概念图·思维导图 / 一页纸摘要 | 下游 skill（前三个）/ 自带（摘要） |
| **测** | 自测题（选择题）/ 闪卡·抽认卡 / 时间戳大纲 | 本 skill 自带 |

### Step 4 — 执行选定选项

- **自带选项**（追问 / 摘要 / 自测题 / 闪卡 / 大纲）→ 直接基于 `transcript` 生成，产出放 `library/<id>/output/`。
- **下游 skill 选项**（学霸笔记 / PPT / 概念图）→ **先读 `references/mapping-table.md`**，按「视频类型 → 呈现形式 → 具体模板/主题」确定参数，再**激活对应下游 skill**（scholar-notes / ppt-animation / flowchart），把文稿内容作为输入传入执行。

> 下游 skill 的模板/主题选择由本 skill 的 mapping-table 兜底（尤其 ppt-animation 的主题选择，下游未明确，本 skill 指定）。详见该文件。

---

## 学-记-测 闭环

```
                    ┌─ 学：追问学习（带时间戳定位）              [自带]
文稿库 transcript ──┼─ 记：学霸笔记 / PPT复习卡 / 概念图 / 摘要  [下游skill / 自带]
                    └─ 测：自测题 / 闪卡 / 时间戳大纲            [自带]
```

一个视频可以连续触发多个选项（先做笔记、再出自测题），它们共享同一份缓存的 `transcript`，无需重复下载/转录。

---

## 硬规矩（参照 dynamic-archify 的 "never edit the renderer"）

1. **脚本失败时修输入参数重跑，绝不改 `scripts/lib/` 里的函数**。错误信息已设计成可直接消化的形式（指明哪一步、缺什么、怎么修）。
2. **`env.local.json` 只由 `setup.sh` 生成**，不手写、不直接编辑。
3. **下游 skill 只调用、不修改**——它们的模板/主题缺口由本 skill 的 `mapping-table.md` 兜底，绝不动上游文件。
4. **优先复用缓存**：同一视频/文件的 `transcript` 已存在就秒出，不重复下载/转录。

---

## 资源文件结构

```
learn-from-video-skill/
├── SKILL.md                  ← 本文件（调度指令）
├── dependencies.json         ← 下游 skill + 三件套 + 镜像站清单（setup 读它去装）
├── scripts/
│   ├── setup.sh              ← 首次初始化（--check 只检测不安装）
│   ├── process.sh            ← 日常 pipeline（url | local）
│   └── lib/                  ← 公共函数（detect / install / mirrors）
├── references/
│   ├── mapping-table.md      ← ★视频类型→呈现形式→模板/主题 兜底映射
│   ├── output-options.md     ← 学/记/测 各选项执行指引
│   ├── checklist.md          ← 质量自检清单
│   └── env-template.json     ← env.local.json 字段模板
├── library/                  ← 运行时缓存（gitignore，按 <id> 存视频+音频+文稿）
└── examples/                 ← 示例文稿（供参考字段形状）
```

**加载顺序**：SKILL.md → setup --check 判断模式 → (首次) setup.sh / (日常) process.sh → output-options.md 展示选项 → mapping-table.md 定模板 → 执行/激活下游 skill → checklist.md 自检。
