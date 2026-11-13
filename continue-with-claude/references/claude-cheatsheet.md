# Claude Code 机制速查

本 skill 打包侧会用到的 Claude Code 事实速查。基于官方公开文档与本机安装取证（`~/.claude/`）。

## CLI 入口

- TUI：`claude`（项目目录内启动）；`claude --version` 验证。
- 无头单发：`claude -p "..."`（print 模式，输出后退出）。
- 会话恢复：`claude -c`（继续最近）；`claude --resume`（选择器）或 `claude --resume <session-id>`。
- 本机取证：`claude` 可能不在 PATH（用户经 npx / Desktop 方式使用），但 `~/.claude/` 活跃——**安装检测以 `~/.claude` 目录存在为准**，两者都缺失才判定未安装。

## 指令文件（勿污染）

- **CLAUDE.md**：用户级 `~/.claude/CLAUDE.md`、项目级 `./CLAUDE.md`（子目录亦会递归加载）。每轮会话自动注入——一次性交接内容写进去会永久污染，交接只放 `.handoff/`。
- `/init` 可生成项目 CLAUDE.md，与交接无关。

## Command 机制（一键继续的载体）

- 用户级 `~/.claude/commands/*.md`；项目级 `<repo>/.claude/commands/`。文件名即命令名（`continue.md` → `/continue`）。
- frontmatter 键：`description` / `argument-hint` / `allowed-tools` / `model`。
- **`$ARGUMENTS` 与 `$1..$n` 参数替换**：支持。
- **`` !`cmd` `` bash 注入**：Claude Code 原生行为，命令发送前预执行并把输出注入 prompt（仅交互模式生效）。⚠️ **Windows 上该块由 PowerShell 执行**，PS 5.1 不支持 `||`、`2>/dev/null`，带兜底的长命令会直接 ParserError——因此本仓库模板**不使用** `!` 注入，统一指示模型读文件。
- `@path` 引用会展开文件内容；但交接命令里附件一律写成"用读文件工具打开 <路径>"的明确指示，比 `@` 更稳。
- 项目级与全局同名命令**共存**（`/help` 中分别列出）：若项目内存在指向历史路径的旧版 continue.md，删除并告知用户，避免歧义。

## Skill 机制

- `~/.claude/skills/<name>/SKILL.md`（本机已证实该目录被 Claude Code 使用，含多个已装 skill）。
- 本 skill 打包侧（`~/.agents/skills/`）与 Claude Code 的 skill 发现相互独立，互不干扰。

## 会话存储

- `~/.claude/projects/<编码后 cwd>/<session-uuid>.jsonl`（本机证实 projects 目录按项目路径编码命名）。
- 交接场景**不依赖**会话恢复，靠 `.handoff/` 文件；jsonl 仅在 Step 2 可选补充提炼时读。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | `cd <项目> && claude` → `/continue`（全局 `~/.claude/commands/continue.md`；模板指示模型读 HANDOFF.md，不用 `!` 注入） |
| 无头单发 | `cd <项目> && claude -p "先完整阅读 .handoff/HANDOFF.md，按其「任务规划」继续交接工作"` |
| 兜底 | 对话粘贴「请完整读取 .handoff/HANDOFF.md，按其任务规划继续」 |
| 安装验证 | `ls ~/.claude/commands/continue.md` 应存在且引用 `.handoff/HANDOFF.md` |

## 实现备注

- Claude Code 与 OpenCode 都支持 `$ARGUMENTS`，两者模板同构；但 `!` 注入在 Windows/PowerShell 下不可用，故本仓库两版模板均改为读文件。ZCode 的 `!` 不预执行，同样不用。
- `~/.claude/settings*.json` 含 provider 凭据配置——交接产物与文档示例不要引用该目录下的配置文件。
