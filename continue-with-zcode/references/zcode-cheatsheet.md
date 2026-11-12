# ZCode 机制速查

本 skill 打包侧会用到的 ZCode 事实速查。基于官方 zcode-guide 插件文档与本机安装取证（/opt/ZCode，Electron 桌面 + CLI harness）。

## CLI 入口

- `/usr/bin/zcode` → `/opt/ZCode/zcode`（Electron）；URL scheme `zcode://`。
- 已证实子命令：`zcode login [zai|bigmodel]`、`zcode plugins <command>`、**`zcode skills [list|inspect <name>]`**、**`zcode commands [list|inspect <name>]`**（安装后验证用）。
- **未证实**：`-p/--print` headless、`--resume/--continue` 会话恢复——交接场景不要依赖这两类参数。

## 指令文件（Rules）

- **唯一指令文件是 AGENTS.md**（不支持 CLAUDE.md/ZCODE.md）：
  - 用户级 `~/.zcode/AGENTS.md` → 工作区 `<repo>/AGENTS.md`（从 cwd 向上找项目根），先用户级后工作区注入。
  - `/init` 命令生成工作区 AGENTS.md。
- 工作区配置：`<repo>/.zcode/config.json` 或 `<repo>/zcode.json`。

## Skill 机制

frontmatter：`name` / `description`（>1024 字符直接丢弃；触发靠 description，约前 250 字符呈现给模型）/ `when_to_use` / `license` / `metadata`。

**发现顺序（先者优先，同名先者加载、其余被 shadow）**：

1. 显式配置根
2. `~/.zcode/skills`
3. `~/.agents/skills`
4. `<repo>/.zcode/skills`（cwd 向上每级都算，更深优先）
5. `<repo>/.agents/skills`
6. 启用的插件根（最低）

同级内 `.zcode` 先于 `.agents`。**`~/.agents/skills/` 是 ZCode 官方支持的跨工具共享位置**（Trae v3.3.44+ 也读它）。

## Command 机制（一键继续的载体）

- 目录发现顺序同 skill：`~/.zcode/commands` → `~/.agents/commands` → 项目级（cwd 向上，`.zcode` 先于 `.agents`；先者优先，项目级**覆盖**用户级同名）。
- 文件名即命令名；嵌套目录映射为冒号（`review/code.md` → `/review:code`）。
- frontmatter 键：`description` / `argument-hint` / `allowed-tools` / `model` / `skills` / `disable-noninteractive`。
- **`$ARGUMENTS` / `$1` 参数替换**：支持。
- ⚠️ **`` !`cmd` `` 注入块不预执行**：改写成"让模型用 Bash 执行该命令"的指令（走工具调用 + 审批）。与 OpenCode 的预注入语义完全不同——交接命令直接指示模型用读文件工具读 `.handoff/HANDOFF.md`，不要用 `!`。

## 会话存储（不可外部恢复）

- `~/.zcode/cli/db/db.sqlite`（SQLite 主存储，含会话/事件）。
- 会话 id 形态：`sess_<uuid4>`（CLI）与 `session_<hex32>`；外围痕迹：`~/.zcode/cli/agents/sess_*/`、`~/.zcode/*.last-session.json`。
- CLI 层无已证实的 resume 参数——交接场景不依赖会话恢复，靠 `.handoff/` 文件。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | `cd <项目> && zcode` → `/continue`（全局 `~/.zcode/commands/continue.md`，指令 agent 读 `.handoff/HANDOFF.md`） |
| 兜底 | 对话粘贴「请完整读取 .handoff/HANDOFF.md，按其任务规划继续」 |
| 安装验证 | `zcode commands list` 应列出 `continue` |

## 实现备注

- ZCode 与本 skill（打包侧）同为 ZCode 环境运行——执行打包的会话本身就在 ZCode 里，Step 2 的会话自省即提炼当前对话，无障碍。
- 项目级 `.zcode/plans/` 是 ZCode 存放 plan 的位置，与交接无关，不要混淆。
- `~/.zcode/cli/config.json` 含 MCP 凭据——交接产物与文档示例不要引用该文件。
