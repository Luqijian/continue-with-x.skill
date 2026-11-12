# Trae 机制速查

本 skill 打包侧会用到的 Trae 事实速查。基于 Trae v3.3.x（2026-05 时点官方文档与 changelog；国际版 trae.ai / CN 版 trae.com.cn）。

## 版本与目录

| | 国际版 | CN 版 |
|---|---|---|
| IDE 命令行 | `trae` | `trae-cn`（本机 `/usr/share/trae-cn/bin/trae-cn`） |
| 用户级配置目录 | `~/.trae/` | `~/.trae-cn/` |
| 全局命令目录 | `~/.trae/commands/` | `~/.trae-cn/commands/` |
| 全局技能目录 | `~/.trae/skills` | `~/.trae-cn/skills`（v3.3.63 起两版互通） |

项目级 `.trae/`（commands/rules/skills）两版通用，随仓库分发无差异。

## 自定义 slash command（一键继续的关键）

- 项目级 `.trae/commands/*.md`（最多 3 层嵌套）；全局 `~/.trae-cn/commands/`（国际版 `~/.trae/commands/`）。
- 文件格式：YAML frontmatter（`name`、`description`）+ `---` 分隔线 + 指令正文（给 AI 的自然语言指令）。
- 创建入口：设置 > 技能与命令 > 命令 > 创建（选全局/项目类型）；文件保存即生效。
- 调用：聊天框输入 `/` → 从 Commands 列表选择。
- **无参数替换机制**（无 `$ARGUMENTS`）：补充指令走后续对话。
- 内置命令：SOLO 的 `/plan`、`/spec`（系统内置，与自定义机制无关）。

## Rules（规则）

- 项目规则 `.trae/rules/`（v3.3.33 起支持多文件；v3.3.51 起支持子目录递归 3 层、任意子目录可放 `.trae/rules/`）；用户规则 `~/.trae-cn/user_rules.md` 类。
- 规则在**每次 AI 请求时自动注入**——一次性交接不要写进 rules。
- frontmatter 触发类型：`alwaysApply`（始终）/ `globs`（按文件匹配）/ `description`（AI 自行判断）/ 手动（`#Rule` 引用，优先级最高）/ `scene: git_message`（提交信息场景）。
- **AGENTS.md / CLAUDE.md 兼容**：需在 设置 > 规则 > 导入设置 打开对应开关（`includeAgentsMd` / `includeClaudeMd`）；默认关。
- v3.3.51 起支持读取子目录中的 AGENTS.md。

## Skills（技能）

- 格式与 Claude Code 同构：`SKILL.md` + YAML frontmatter（name/description）+ 指令正文；支持上传 SKILL.md/zip 导入。
- v3.3.24/25 起 IDE 模式与自定义智能体均可用技能；**v3.3.44 起支持从 `.agents/skills/` 自动加载**——同一目录可被 Trae/ZCode 等多个工具共享。
- 全局：`~/.trae-cn/skills`（国际版 `~/.trae/skills`）。

## `#` 上下文引用体系

`#Code`（函数/类级）、`#File`、`#Folder`、`#Workspace`（全库检索，依赖索引）、`#Doc`（文档集：仅 .md/.txt，单文件 ≤10MB、集合 ≤50MB）、`#Problems`、`#Web`、`#Rule`（优先级最高）、`#Past Chats`（引用本项目历史对话，设置 > Beta 开启）。

注意：`#File/#Folder/#Workspace` 依赖代码索引，冷启动可能提示"索引构建中"——交接场景优先让 agent 直接用读文件工具读 `.handoff/`，不要依赖 `#` 引用。

## 会话存储（不可外部注入）

- SQLite：`~/.config/Trae CN/ModularData/ai-agent/database.db`（国际版 `~/.config/Trae/...`；macOS 在 `~/Library/Application Support/`）。
- **CN 版 SQLCipher 加密 + 账号/设备绑定**，国际版社区报告为明文 SQLite 但无导入 API——**任何版本都无法从外部写入会话**，交接载体只能是项目内文件。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 日常接续（推荐默认） | `trae-cn <项目>` → 聊天框 `/continue`（全局 `~/.trae-cn/commands/continue.md`，指令 agent 读 `.handoff/HANDOFF.md`） |
| 兜底 | 聊天框粘贴固定提示词「请完整读取 .handoff/HANDOFF.md，按其任务规划继续」 |
| 大型资料补充 | `#Doc` 文档集挂 `.handoff/attachments/` 下的 md/txt |

## 实现备注

- Trae 命令文件格式来自官方文档（w3cschool 镜像，v3.3.x）：frontmatter name/description + 分隔线 + 指令。若某版本命令列表不显示，检查 frontmatter 是否被正确解析（回退：让用户经 设置 > 技能与命令 创建同名空命令，再把指令正文贴进去）。
- Rules 的 AGENTS.md 兼容开关默认关闭——不要依赖项目根 AGENTS.md 自动注入交接内容。
