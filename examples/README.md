# examples/

**格式样例**（非真实视频产物），供 agent 理解 transcript 与各类输出的字段形状 / 格式，照抄结构。

| 文件 | 说明 |
|------|------|
| `transcript.sample.srt` | `process.sh` 产出的带时间戳文稿（SRT 格式） |
| `transcript.sample.txt` | 去时间戳的纯文本（从 srt 生成） |
| `output/summary.sample.md` | 「一页纸摘要」自带选项的产出样例 |
| `output/quiz.sample.md` | 「自测题」自带选项的产出样例 |

> 真实产物在 `library/<id>/`（运行时按视频 ID 生成，已被 .gitignore 忽略）。
> 下游 skill 产物（学霸笔记 / PPT / 概念图 HTML）的格式见各自 skill 的 `examples/`。
