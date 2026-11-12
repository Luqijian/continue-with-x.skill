# OpenCode 机制速查

本 skill 打包侧会用到的 OpenCode 事实速查。基于 OpenCode v2.x（本机 2.2.6 验证过安装；官方文档 opencode.ai/docs）。

## CLI 会话恢复

| 命令 | 作用 |
|---|---|
| `opencode [目录]` | 打开 TUI（位置参数是**项目目录**，不是 prompt） |
| `opencode --prompt "..."` | TUI + 初始 prompt |
| `cat file.md \| opencode --prompt "..."` | stdin 管道内容会拼进初始 prompt |
| `opencode -c` / `--continue` | 继续当前目录最近的根会话 |
| `opencode -s <id>` / `--session <id>` | 继续指定会话 |
| `opencode --fork -c` | 分叉后继续（保留原会话） |
| `opencode run "..."` | 无头单轮执行；同样支持 `-c`/`-s`/`--fork` |
| `opencode run --command <name> [args]` | 无头执行自定义命令，args 进入 `$ARGUMENTS` |
| `opencode -m provider/model` | 指定模型 |

## 自定义命令（slash command）

- 位置：项目级 `.opencode/commands/*.md`（**复数**；单数 `command/` 仅 legacy 兼容）；全局 `~/.config/opencode/commands/`。项目覆盖全局。保存即热重载。
- 文件名即命令名；嵌套目录成嵌套命令（`.opencode/commands/team/review.md` → `/team/review`）。

**Frontmatter 字段**：

| 字段 | 作用 |
|---|---|
| `description` | 命令列表中显示 |
| `agent` | 执行时选用的 agent |
| `model` | `provider/model` |
| `subagent: true` | 后台子会话运行（`subtask` 为其旧别名，勿用） |

**模板机制**（正文）：

- `$ARGUMENTS`：完整参数串原文。位置参数用 `$1`、`$2`...（缺失为空串）。
- `` !`shell命令` ``：**提交 prompt 前执行并把输出内联**。发生在 OpenCode 评估命令时、在 agent 工具权限流程之外。
- 模板不含任何占位符时，非空参数追加在模板后（空一行）。
- ⚠️ `@file` 引用在命令模板中**不展开**（按字面发送）。要引用文件内容：`!`cat` 注入，或指示 agent 用读文件工具打开。

## 项目上下文规则

- 自动读取：项目根 `AGENTS.md`（向 cwd 上层遍历）；全局 `~/.config/opencode/AGENTS.md`。
- 回退：无 AGENTS.md 时用 `CLAUDE.md`；同目录两者并存时 AGENTS.md 优先。
- 附加注入：`opencode.json` 的 `"instructions": ["glob", ...]`。
- ⚠️ AGENTS.md 里的 `@docs/x.md` 不自动展开——要么写明"先读该文件"，要么用 `instructions` glob。

## Agent 定义（了解即可）

`.opencode/agents/<name>.md`（复数），正文 = system prompt；`mode: primary | subagent | all`。

## 存储（未来扩展反向导出时用）

- 会话数据库：`~/.local/share/opencode/opencode.db`（SQLite，v1.2 起；旧 JSON 存储已迁移，`storage/` 为遗留）。
- 表：`session`（id/parent_id/directory/title/...）、`message`、`part`（data 列存 JSON）。
- 会话按项目目录归属；`-c`/`-s` 需在同一工作目录运行。
- 原生导入导出：`opencode session export <id>` / `opencode session import <file> --directory <path>`。

## 交接场景的推荐组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | TUI 内 `/continue`（全局 `~/.config/opencode/commands/continue.md` + `!`cat .handoff/HANDOFF.md``） |
| 终端直接带上下文启动 | `opencode --prompt "先阅读 .handoff/HANDOFF.md 并继续"` |
| 后台/CI 自动接管 | `opencode run --command continue "按交接文档继续"` |
| 会话内恢复 | `opencode -c` / `opencode --session <id>` |

注意：OpenCode 的项目级 `.opencode/commands/` 会覆盖全局命令；交接包数据在项目内 `.handoff/`，命令统一装全局。
