# 输出选项 · 学-记-测 执行指引

`process.sh` 产出 `transcript.{srt,txt}`（路径见末行 `TRANSCRIPT_READY <dir>`）后，向用户展示以下选项并执行。**多选可叠加**，共享同一份缓存文稿，无需重复下载/转录。所有产出默认放 `library/<id>/output/`。

---

## 学

### 追问学习 · 自带
- **做法**：基于 transcript 回答用户问题；引用内容时附**时间戳**（"视频 03:12 处讲到…"）方便跳回原片
- **产出**：对话（可存 `output/chat.md`）
- **何时选**：用户想搞懂视频里某个点、追问细节、要例子

---

## 记

### 学霸笔记 · → 调 scholar-notes
- **前置**：读 `mapping-table.md` 选 Style A/B
- **做法**：把 transcript 作为内容传入，激活 scholar-notes 执行（它会自选布局/组件）
- **产出**：`output/note.html`
- **何时选**：深度整理、长期复习

### PPT 复习卡 · → 调 ppt-animation
- **前置**：读 `mapping-table.md` 选主题（dark-tech/clean-white/cyber-red/warm-paper/gradient-dark）
- **做法**：把 transcript 提炼为 5-10 页要点（每页一概念 + 图形化），激活 ppt-animation 指定主题
- **产出**：`output/slides.html`
- **何时选**：做成可分享、可翻页演示的成品

### 概念图 / 思维导图 · → 调 flowchart
- **前置**：读 `mapping-table.md` 选图表类型（流程图/对比图/原理演示/系统概览/时序图/时间线/概念图）
- **做法**：激活 flowchart，按选定类型把视频结构可视化
- **产出**：`output/diagram.html`
- **何时选**：理清结构、概念关系、原理流程

### 一页纸摘要 · 自带
- **做法**：提炼 TL;DR + 3-5 个关键点 + 核心术语表
- **产出**：`output/summary.md`
- **何时选**：快速回顾、分享要点

---

## 测

### 自测题 · 自带
- **做法**：基于 transcript 出 5-10 道选择题，附答案 + 解析（解析引用时间戳）
- **产出**：`output/quiz.md`
- **何时选**：检验是否真学会了

### 闪卡 / 抽认卡 · 自带
- **做法**：生成 Q/A 卡（正反面），格式兼容 Anki 导入
- **产出**：`output/flashcards.md`（或 `.csv`）
- **何时选**：间隔重复记忆

### 时间戳大纲 · 自带
- **做法**：从 srt 提取章节标题 + 起止时间，可点击跳转视频片段
- **产出**：`output/outline.md`
- **何时选**：快速定位视频内容、做目录

---

## 推荐组合

- **深度学习**：追问学习 → 学霸笔记 → 自测题
- **快速消化**：一页纸摘要 → 时间戳大纲
- **做分享成品**：PPT 复习卡（或概念图）
