# WorkBuddy 机制速查

本 skill 打包侧会用到的 WorkBuddy 事实速查。基于本机安装取证（WorkBuddy 5.6.2，Linux，/opt/apps/com.tencent.workbuddy/）。

## 架构

腾讯 **Electron 桌面应用**（"AI Agent Desktop Application"，URL scheme `workbuddy://`）。Agent 引擎是内嵌的**腾讯 CodeBuddy Code CLI**（`@tencent-ai/codebuddy-code` 2.147.0，bin 别名 `codebuddy`/`cbc`，位于 `app.asar.unpacked/cli/bin/`），桌面端以 sidecar 方式 spawn（`--serve` 起本地服务 + `--prewarm` 预热池）。

- 桌面安装：`/opt/apps/com.tencent.workbuddy/files/workbuddy`
- 数据目录：`~/.workbuddy/`
- **无独立 CLI 入口**（`workbuddy` 不在 PATH；内嵌 cbc 可独立运行但数据目录是 `~/.codebuddy`，与桌面会话存储不互通——不要用它接管桌面会话）

## `~/.workbuddy/` 结构要点

| 路径 | 作用 |
|---|---|
| `workbuddy.db` | SQLite 主数据库（会话/状态） |
| `skills/` | **全局 skill 发现根之一** |
| `sessions/<pid>.json` | 运行中 agent host 注册（endpoint/sessionId/heartbeat） |
| `projects/<cwd-slug>/<sessionId>.jsonl` | 会话 transcript（Claude Code 式，按 cwd 项目分桶） |
| `IDENTITY.md` / `SOUL.md` / `USER.md` / `BOOTSTRAP.md` | 身份文件，全文注入每轮上下文 |
| `memory/<userId>_memory.md` | 用户级记忆 |
| `settings.json` | 沙箱规则、插件开关等 |

## Skill 机制（一键继续的唯一入口）

- 格式：`SKILL.md` + YAML frontmatter（`name`/`description`/`allowedTools`/`version`/`userInvocable`/`disableModelInvocation`）。
- **发现根（实测 `.skill-list-cache.json`）**：`~/.workbuddy`、`~/.workbuddy/skills`、`~/.workbuddy/skills-marketplace`、内置插件目录。**不含项目级目录、不含 `~/.agents/skills`**——跨工具共享位置对 WorkBuddy 无效，一键 skill 必须装 `~/.workbuddy/skills/`。
- `userInvocable: true` → 用户可用 `/continue` 直接调用；description 写足触发词可让自然语言（"继续交接的工作"）也命中。
- 无自定义 slash command 机制（md 命令文件不适用）。

## 上下文注入（对交接有利/有害的机制）

**有利**：每轮 user message 前注入 `<project_layout>`（工作区结构快照）——`.handoff/` 目录会出现在结构快照里，agent 容易自行发现交接文档；`/continue` skill 正文直接指示读文件则更稳。

**有害（勿用）**：
- **项目记忆** `<项目>/.workbuddy/memory/YYYY-MM-DD.md` 每轮注入；项目 `MEMORY.md` 为长期事实——一次性交接写进去会永久污染。
- 身份文件（SOUL/IDENTITY 等）是用户个人配置，不要动。

## 会话与恢复

- 桌面会话在应用内历史列表恢复；`~/.workbuddy/projects/` 的 jsonl 可读（未来反向导出用）。
- 内嵌 cbc 有 `--continue/--resume/-p` 参数（字符串证据），但其默认数据目录是 `~/.codebuddy`，与 WorkBuddy 桌面会话（`~/.workbuddy`）的关系**未验证**——标为实验性，不作为交接路径。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | WorkBuddy 打开项目 → `/continue`（全局 skill 读 `.handoff/HANDOFF.md`） |
| 自然语言触发 | 「继续交接的工作」（skill description 触发词命中） |
| 兜底 | 粘贴固定提示词「请完整读取当前项目的 .handoff/HANDOFF.md，按其任务规划继续」 |
| 未来反向导出 | 读 `~/.workbuddy/projects/<cwd-slug>/<sessionId>.jsonl` |

## 实现备注

- 安装全局 skill 是对用户 `~/.workbuddy/` 的写入——skill 正文已要求向用户明确说明。
- `.skill-list-cache.json` 可能缓存 skill 列表，新装 skill 若未立即出现，重启 WorkBuddy 即可。
