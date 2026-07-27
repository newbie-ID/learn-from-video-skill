# scripts/

learn-from-video-skill 的可执行脚本。`SKILL.md` 通过它们驱动环境初始化与视频处理。

## 调用约定

| 命令 | 作用 | 何时用 |
|------|------|--------|
| `bash scripts/setup.sh --check` | 只检测是否已初始化，stdout 输出 `NOT_INITIALIZED` / `READY`(+env 路径) | SKILL.md 第一步判断走首次还是日常模式 |
| `bash scripts/setup.sh` | 完整初始化：检测→装三件套→选模型→装下游 skill→写 `env.local.json` | 首次使用 |
| `bash scripts/process.sh url <链接>` | 下载 URL 视频 → 字幕优先 / Whisper → 文稿 | 日常（链接） |
| `bash scripts/process.sh local <路径>` | 跳过下载 → Whisper 转录本地文件 → 文稿 | 日常（本地视频） |

## 设计原则（参照 dynamic-archify 的成熟模式）

1. **CWD 无关**：脚本内用 `BASH_SOURCE` 反推 skill 根，agent 在任意目录调用都能定位 `library/`、`models/`、`bin/`、`env.local.json`。
2. **stdout / stderr 分离**：返回路径的函数（`locate_whisper_cli` / `install_ytdlp` / `download_model`）只把**路径**输出到 stdout、状态日志走 stderr；这样 `setup.sh` 能用 `$(func)` 干净地捕获路径。
3. **LLM-friendly 错误**：每步打印 `[OK]/[FAIL]/[..]` 前缀状态行；失败时指明「哪一步 + 缺什么 + 怎么修」，外部工具原始输出存入 `library/<id>/process.log`。
4. **never-edit 硬规矩**：脚本失败时修输入参数重跑，**不要改 `lib/` 里的函数**。
5. **三级降级**：包管理器 / 预编译二进制优先 → 失败给清晰手动指引 → 用户手动补。

## 目录

```
scripts/
├── setup.sh          ← 首次初始化 orchestrator
├── process.sh        ← 日常 pipeline（url | local 双入口）
└── lib/              ← 公共函数（被 setup/process source）
    ├── detect.sh     ← 平台 / Agent skills 目录 / GPU·内存 检测 + 模型档位选择
    ├── mirrors.sh    ← 5 个 GitHub 镜像 fallback（download / clone）
    └── install.sh    ← FFmpeg / whisper.cpp / yt-dlp / 模型 / 下游 skill 安装
```

## 与 dependencies.json 的关系

`dependencies.json` 是**声明式真相源**（三件套、3 个下游 skill、模型 URL、镜像站）。
当前脚本为稳健起见，对可变 URL（模型下载、AI_Animation 仓库）采用**硬编码内置**，与 `dependencies.json` 保持同步——**修改 URL 时请同时更新两处**。未来可改用 `jq` 直接读取该文件。

## 环境变量

- `LFV_SKILLS_DIR`：手动指定下游 skill 的安装目录（覆盖自动探测）。当自动猜错 Agent 平台时用它。

## 手动安装兜底（脚本自动失败时）

| 工具 | 手动方式 |
|------|----------|
| FFmpeg | win: 静态版加入 PATH / mac: `brew install ffmpeg` / linux: `apt install ffmpeg` |
| whisper.cpp | https://github.com/ggerganov/whisper.cpp/releases 下载预编译版到 `bin/whisper.cpp/`（需含 `whisper-cli`） |
| yt-dlp | https://github.com/yt-dlp/yt-dlp/releases 下载单文件到 `bin/` 并赋予执行权限 |
| 模型 | 从 huggingface `ggerganov/whisper.cpp` 下载 `ggml-<tier>.bin` 到 `models/`（国内可用 hf-mirror.com） |
| 下游 skill | clone AI_Animation 合集，把 `skills/{scholar-notes,ppt-animation,flowchart}` 复制到你的 Agent skills 目录 |

手动装好后，删除 `env.local.json` 重跑 `setup.sh`，它会探测到已存在的工具并只补全快照。
