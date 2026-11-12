# Qoder 机制速查

本 skill 打包侧会用到的 Qoder 事实速查。基于 Qoder 官方文档（docs.qoder.com，2026-11 核实）。

## CLI 与 IDE

- CLI（2025-10 发布）：`curl -fsSL https://qoder.com/install | bash` 或 `npm install -g @qoder-ai/qodercli`；命令名 `qoder`（部分文档写 `qodercli`）。
- IDE：VS Code fork（阿里，通义灵码血统）。CN 版启动器 `/opt/Qoder-CN/qoder-cn`，配置 `~/.qoder-cn/`；国际版配置 `~/.qoder/`。
- CLI 工作目录 = 启动时所在目录（`cd <项目> && qoder`）。

**CLI 关键参数**：

| 参数 | 作用 |
|---|---|
| `-p` / `--print` | Headless 单轮执行；可执行自定义命令：`qoder -p '/continue'` |
| `-c` | 继续最近会话 |
| `-r <id>` / `--resume` | 恢复指定会话；`--list-sessions` 列出 |
| `--session-id`、`--fork-session` | 指定/分叉会话 |
| `-n "名称"` | 命名会话 |
| `--model`、`--add-dir`、`--remote` | 模型 / 额外信任目录 / 云端执行 |

## 自定义命令（一键继续的关键）

- **用户级 `~/.qoder/commands/<name>.md`**；项目级 `<项目>/.qoder/commands/<name>.md`。**同名时用户级覆盖项目级**（CLI 侧文档确认）。
- 文件格式：YAML frontmatter（`name` 可选展示名、`description` **必填**）+ 指令正文；子目录作命名空间（`commands/git/commit.md` → `/git:commit`）。
- 调用：IDE Agent 对话框输入 `/`；CLI `qoder -p '/命令名'`。
- 改动后 `/commands` 热加载；纯 prompt 注入，无其他条件字段。

## Rules 与 AGENTS.md

- 项目规则 `<项目>/.qoder/rules/`；触发四型：手动（`@rule`）/ 模型决策（按 description）/ 始终生效（注入所有请求）/ globs 文件匹配。
- 活跃规则合计 **10 万字符上限**（超出截断）——一次性交接不要写进 rules。
- **AGENTS.md 放项目根自动识别，无开关**；与 rules 冲突时规则内容优先。
- 用户级记忆：`~/.qoder/AGENTS.md`；项目级 `AGENTS.md` / `AGENTS.local.md`；`/init` 可生成。

## `@` 引用语法（注意：不是 `#`）

`@file`（含 `.qoder/rules` 下的规则文件）、`@folder`、`@attachments`（拖拽/粘贴 md/pdf/docx/xlsx/xmind/图片）、`@rule`。输入 `@` 实时模糊检索；`#` 不是 Qoder 的引用语法。

## Deeplink（外部一键入口）

Schema：`qoder://aicoding.aicoding-deeplink/<path>?<params>`（IDE ≥ 0.2.21；需用户确认；URL 上限 8,000 字符）：

| Deeplink | 作用 |
|---|---|
| `/chat?text=<URL编码>&mode=agent\|ask\|chat\|experts&isNewChat=true` | 新建对话并**预填文本**（不自动发送，用户回车） |
| `/command?name=&text=&description=&scope=user\|project` | 一键创建自定义命令（无需登录；project 需已打开工作区） |
| `/rule?name=&text=` | 一键导入规则 |
| `/mcp/add` | 添加 MCP 配置 |

交接示例：`qoder://aicoding.aicoding-deeplink/chat?text=%2Fcontinue&mode=agent&isNewChat=true`（预填 `/continue`）。

## 会话存储（不可外部注入）

- IDE：`~/Library/Application Support/Qoder/User/globalStorage/state.vscdb`（macOS）+ 日志目录 `logs/<date>/window<N>/encrypted/<sessionId>.log`——**RSA-2048 + AES-128-GCM 加密，本地不可读**。
- CLI：`~/.qoder/projects/<项目路径名>/<session-id>.jsonl`（明文）+ `state.json`；格式未承诺稳定，不要手写注入。

## Quest 模式（了解）

独立视窗工作台：Agent 模式（单智能体端到端）/ Experts 模式（多智能体专家团，可配自定义子智能体）。背景上下文靠 `@` 引用、知识中心（Repo Wiki/Memory）或 Spec 文档；任务创建后不能切换模式。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | IDE 打开项目 → `/continue`（用户级 `~/.qoder/commands/continue.md`，指令 agent 读 `.handoff/HANDOFF.md`） |
| CLI 无头接管 | `cd <项目> && qoder -p '/continue'` |
| 终端一键预填 | Deeplink `/chat?text=%2Fcontinue&mode=agent` |
| 兜底 | `@file .handoff/HANDOFF.md 请先读取该文件恢复工作上下文，然后按其中「任务规划」继续` |

## 实现备注

- CN 版用户级命令目录 `~/.qoder-cn/commands/` 为按惯例推断（官方文档只写 `~/.qoder/commands/`）；预检发现 `~/.qoder-cn/` 即同装一份，两处内容一致。
- Qoder 用户级命令覆盖项目级——项目内旧版 continue.md 不生效但仍会混淆，打包时顺带清理。
