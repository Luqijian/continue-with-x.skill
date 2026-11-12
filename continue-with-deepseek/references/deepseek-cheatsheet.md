# DeepSeek Harness 机制速查

本 skill 打包侧会用到的 DeepSeek Harness（`dsh`）事实速查。基于官方仓库 deepseek-ai/deepseek-harness 的文档与 CLI 帮助（2026-09 生成的 `docs/cli-help.md`）与本机安装取证（`~/deepseek-harness/`）。**当前为 developer preview，CLI flag 与 profile 组合可能随版本破坏性变更——给出的命令行以本机 `dsh --help` 实测为准。**

## 定位

- DeepSeek 官方开源的编码 agent **运行时**（不是模型）：把模型、工具、会话、沙箱、存储、调度、UI 以 Cordis 插件形式组合起来。
- "Everything is a Plugin"：模型适配器、工具注册表、会话日志、agent loop 乃至 slash 命令都是插件。
- 本机取证：`~/deepseek-harness/default-workspace/`（默认工作区目录，首次运行创建）。

## CLI 入口（官方 `dsh --help` 摘录）

| 命令 | 用途 | 交接相关要点 |
|---|---|---|
| `dsh web` | 浏览器工作台 | 默认 `127.0.0.1:3080`；`--no-open`、`--port <n>`；工作区在 UI 内选择 |
| `dsh headless "task"` | 单发任务 | 回答一次即退出；`-` 读 stdin；`--session-id <id>` 恢复持久 Session；`--permission-mode workspace-write`；`--add-dir <path>`；`--json` 输出事件流 |
| `dsh sdk` / `dsh sdk-minimal` | JSON-RPC stdio 服务 | SDK/自动化用，交接不用 |
| `dsh --profile acp` | ACP 自动化 | 交接不用 |
| `dsh plugin --profile <name> add <pkg>` | 装插件 | 内部转发 pnpm，npm 包级操作——本 skill 不使用 |
| `dsh --profile <name>` | 启动自定义 profile | profile 存于 `$DSH_HOME/profiles/`；`dsh tui` 属自定义 profile 场景，是否可用视版本而定 |
| `dsh --dump-config` | 打印组合树 | 排障用，不动运行时 |

## Slash 命令机制（为什么没有 /continue）

- 命令由插件在代码中注册：`ctx.commands.register({ name, description, input, handler })`。
- 命令在 **UI 命令层**执行，不产生模型消息；**未知 `/xxx` 被适配器拒绝**、不转成模型 prompt。
- **没有用户级命令文件目录**——不存在 `~/.dsh/commands/*.md` 这类文件发现机制，markdown 命令模板对 dsh 无效。
- 结论：一键继续只能靠 `.handoff/` 文件 + 一行 shell 命令（headless）或 web 内粘贴兜底提示词。**不要**尝试写命令文件或硬装命令插件。

## 会话与工作区

- 持久 Session 有 id；headless 用 `--session-id <id>` 把后续任务续在同一 Session（恢复会话的官方路径）。
- 工作区（workspace）即 dsh 运行的工作目录；headless 从**当前 cwd** 运行，交接时务必 `cd <项目目录>` 再执行。
- 权限：headless 默认权限预设偏保守（读多写少），写文件任务显式 `--permission-mode workspace-write`。

## 交接场景组合

| 场景 | 用法 |
|---|---|
| 无头接续（推荐默认） | `cd <项目> && dsh headless "先完整阅读 .handoff/HANDOFF.md，按其「任务规划」继续交接工作"` |
| 交互接续 | `cd <项目> && dsh web` → 工作区打开项目 → 粘贴兜底提示词 |
| 兜底 | 「请完整读取 .handoff/HANDOFF.md，按其任务规划继续」 |
| 冒烟验证 | `dsh headless "只输出 .handoff/HANDOFF.md 的各节一级标题清单，不要修改任何文件"` |
| 安装检测 | `command -v dsh` 或 `$DSH_HOME` / `~/deepseek-harness` |

## 实现备注

- install.sh 对 dsh **无文件可装**：只检测与提示，不产生任何全局产物；卸载也无需清理 dsh 侧。
- dsh 的配置与凭据在 `$DSH_HOME`（profile、provider key）——交接产物与文档示例不要引用该目录内容。
- 反向导出（dsh → 其他工具）未调研；dsh 的会话日志格式见官方 `docs/session-format-status.md`（仅记录，未实现导出）。
