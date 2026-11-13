# continue-with-x.skill

**在任意 AI 编码工具里工作到一半，一句话把完整工作状态迁移到另一个工具，原地继续。**

本仓库包含 7 个 Agent Skill（`continue-with-*`）+ 各目标工具的全局一键继续命令。打包侧 skill 与目标工具解耦——在 ZCode、Claude Code、Codex CLI 等任何能读写文件、执行 shell 的 harness 中均可触发。

```
┌─────────────┐   触发 skill（如"交接给 OpenCode"）    ┌──────────────┐
│  任意 Harness │ ──收集 git/项目/会话上下文──▶ │ .handoff/    │   目标工具
│ (当前会话)    │   写交接文档 + 装全局命令          │  HANDOFF.md  │ ◀── /continue
└─────────────┘                                  └──────────────┘     原地接续
```

## 典型场景：赛博领鸡蛋

当代码人囤了 5 家 AI 编码工具、每家都送每日免费额度，问题就来了：**换一家签到时，工作现场全丢在上一家**——重新喂上下文、复述需求、解释项目，鸡蛋摔一地。

装好本仓库后，你可以像资深赛博养鸡户一样巡场：

| 时刻 | 动作 |
|---|---|
| 上午 · ZCode 写代码 | 今日份额度，稳稳产出 |
| 额度见底 | 一句「交接给 OpenCode」，工作现场整体打包，一只鸡蛋都不落地 |
| 下午 · OpenCode `/continue` | 原地接续，接着榨下一家额度 |
| 傍晚 · 意犹未尽 | Claude Code / DeepSeek Harness / Trae / Qoder / WorkBuddy，哪家没签到去哪家 |

同一份 `.handoff/HANDOFF.md` 七家通用，搬多少次家上下文都不会漂移——赛博养鸡的核心竞争力，就是**鸡蛋完好、随到随领**。

## 典型场景：跨设备接续（跨设备 / 跨用户）

上午在**家里台式机**写了一半，晚上换**公司笔记本**接着干；或者同一台机器换了个账号继续。Project 可以同步，但「上次做到哪、为什么这么做、这台机器缺不缺环境」不会自己跟过来。

本仓库的做法：交接文档自带**交出方设备指纹**。接收方 `/continue` 时比对指纹，自动区分两种情形——

| 判定的情形 | 接收方行为 |
|---|---|
| 指纹一致（同一设备 + 同一用户） | 视为本机交接，**完全跳过环境扫描**，行为与单机使用无差别 |
| 指纹不一致 / 文档无指纹 | 视为跨设备交接，先查本机环境记忆，再决定要不要扫描 |

```
设备 A 打包                          设备 B /continue
┌──────────────────┐   git / 同步   ┌──────────────────────────────┐
│ .handoff/        │ ─────────────▶ │ 读 HANDOFF.md                │
│  ├ HANDOFF.md    │                │  ├ 设备指纹 ≠ 本机            │
│  │  ·设备指纹 A  │                │  ├ 7.1 环境需求清单           │
│  │  ·7.1 环境需求 │                │  ▼                            │
│  └ attachments/  │                │ 查 ~/.continue-with-x/ 缓存   │
└──────────────────┘                │  → 工具原生 memory            │
                                    │  → 只按清单跑检测命令          │
                                    │ 缺失 → 三选项等用户裁决        │
                                    └──────────────────────────────┘
```

**跨设备时环境检查的完整链路**（都写在命令模板里，无需额外安装）：

1. 查本机缓存 `~/.continue-with-x/env-cache.md`——命中「当前设备 + 同一套环境需求」就复用结论，不再扫描
2. 未命中 → 查当前工具的持久记忆（CLAUDE.md / AGENTS.md / 工具 memory）有没有现成记录
3. 仍无 → 只逐条执行 7.1 清单里的检测命令（**不做全盘探测**），满足则把结果写进缓存
4. 有必需项缺失 → 不擅自安装，汇报后给三选一：**停止** / **安装后继续**（附安装建议）/ **用户提供环境路径**（记入缓存，后续优先于 PATH 探测）

**同步方式二选一**（打包时 skill 会主动问你）：

| 方式 | 做法 | 适合 / 代价 |
|---|---|---|
| **文件同步工具**（推荐） | Syncthing / rsync / 网盘只同步 `.handoff/`，项目仓库照旧忽略它 | 个人上下文与设备指纹不出本机；团队仓库保持干净 |
| **git** | 不忽略 `.handoff/`，把 `HANDOFF.md` 提交进仓库 | 零额外工具；介意上下文入库的话，可只提交 `HANDOFF.md`、单独忽略 `attachments/` |

隐私说明：设备指纹只写**哈希前 12 位 + OS/arch 明文**（如 `` `3f2a9c1b7d4e` · linux-x86_64 ``），不含主机名与用户名；哈希仅用于判断「同一设备+同一用户」，不是安全边界。环境清单只记变量名与检测命令，**任何密钥值都不会写进文档**。

注意：元数据里的「项目路径」是交出方视角，跨设备后通常不同——接收方以当前工作目录与 `git status` 实测为准。

## 支持的交接目标

| Skill | 目标工具 | 一键继续方式 | 全局命令安装位置 |
|---|---|---|---|
| `continue-with-opencode` | OpenCode | TUI 内 `/continue`、`opencode run --command continue`（无头） | `~/.config/opencode/commands/` |
| `continue-with-trae` | Trae（CN 版 / 国际版） | IDE 聊天框 `/continue` | `~/.trae-cn/commands/`、`~/.trae/commands/` |
| `continue-with-qoder` | Qoder（CN 版 / 国际版） | IDE `/continue`、CLI `qoder -p '/continue'`、Deeplink 预填 | `~/.qoder/commands/`、`~/.qoder-cn/commands/` |
| `continue-with-workbuddy` | WorkBuddy（腾讯桌面端） | 对话 `/continue` 或说「继续交接的工作」 | `~/.workbuddy/skills/continue/`（全局 skill） |
| `continue-with-zcode` | ZCode | 会话内 `/continue`（可带补充指令） | `~/.zcode/commands/` |
| `continue-with-claude` | Claude Code | TUI 内 `/continue`、`claude -p`（无头单发） | `~/.claude/commands/` |
| `continue-with-deepseek` | DeepSeek Harness（dsh） | `dsh headless` 一行命令、`dsh web` + 兜底提示词（无自定义命令机制） | 不装全局文件（见机制差异） |

## 一键安装

```bash
bash install.sh
```

脚本做的事（**幂等**，重复运行安全）：

1. 复制 7 个 skill 到 `~/.agents/skills/`（ZCode 等官方支持的跨工具位置），并在 `~/.zcode/skills/` 创建软链
2. **检测本机已安装的目标工具**，为其安装对应的全局一键命令（未安装的工具自动跳过）
3. 全局命令一次安装、所有项目通用——之后日常交接**无需再跑本脚本**（skill 会自动检测并复用）

<details>
<summary>手动安装（不用脚本）</summary>

```bash
# 1. 复制 skill
cp -r continue-with-opencode ~/.agents/skills/   # 其余 6 个同理

# 2. ZCode 软链
ln -sfn ../../.agents/skills/continue-with-opencode ~/.zcode/skills/continue-with-opencode

# 3. 全局命令（以 OpenCode 为例）
mkdir -p ~/.config/opencode/commands
cp templates/continue-opencode.md ~/.config/opencode/commands/continue.md
# Trae/Qoder 用 templates/continue-generic.md；ZCode 用 continue-zcode.md；Claude Code 用 continue-claude.md；
# WorkBuddy 用 continue-workbuddy-SKILL.md 装到 ~/.workbuddy/skills/continue/SKILL.md
# DeepSeek Harness 无命令文件可装，跳过此步（交接用 dsh headless 一行命令）
```

</details>

## 使用方法

**第 1 步 · 打包**（在当前 AI 工具中）：

```
交接给 OpenCode        # 或：迁移到 Trae / 换 Qoder 继续 / handoff to zcode …
```

skill 会自动：收集 git 状态与项目信息 → 从当前会话提炼任务背景/进度/规划 → 写入项目内 `.handoff/HANDOFF.md` → 确保目标工具全局命令就位 → 输出使用说明。

**第 2 步 · 接续**（在目标工具中打开同一项目目录）：

```
/continue              # OpenCode / Trae / Qoder / WorkBuddy / ZCode / Claude Code 统一入口
```

命令会把交接文档注入上下文，agent 核对 git 现状后从「任务规划」继续。可带补充指令聚焦本轮工作（如 `/continue 优先完成登录模块`）。

DeepSeek Harness 除外：dsh 无自定义命令机制，接续用 `dsh headless` 一行命令或 `dsh web` 粘贴兜底提示词（见其 skill 的使用说明）。

## 交接包格式（.handoff/）

```
.handoff/
├── HANDOFF.md      # 九节结构化交接文档
└── attachments/    # 大体积证据：git-diff.patch、文件摘录（按需）
```

`HANDOFF.md` 各节：给接手模型的指令（含设备判定）→ 任务背景与目标 → 项目概况 → 当前进度（✅/🔄/⛔）→ 任务规划（可执行清单）→ 关键决策与约束（含 why）→ 关键文件与代码入口 → 环境与工作流（7.1 环境需求清单 + 7.2 环境事实）→ 风险与已知坑 → 附件索引。元数据表另含**设备指纹**行。完整模板见 [continue-with-opencode/references/handoff-format.md](continue-with-opencode/references/handoff-format.md)（七者共享同一格式）。

7.1 环境需求清单是跨设备检查的唯一依据，形如：

```markdown
| 类型 | 需求 | 检测命令 | 约束 | 必需 |
|---|---|---|---|---|
| runtime | node | `node -v` | ≥22 | 是 |
| env-var | DATABASE_URL | `test -n "${DATABASE_URL:-}"` | 只记名称不记值 | 是 |
```

设计原则：**零背景可接手**——目标工具的 agent 读完文档 + 核对 git 后，无需再问交接文档本可回答的问题。`.handoff/` 是否加入 `.gitignore` 取决于同步方式：仅本机用则建议忽略；要跨设备同步则不要忽略（打包时 skill 会询问）。同项目重复交接时自动增量继承旧要点。

## 机制差异与限制（已内建于各 skill）

| 工具 | 一键载体 | 关键约束 |
|---|---|---|
| OpenCode | 全局 command（模板指示模型读文件） | `@file` 在模板中不展开；项目级命令会**覆盖**全局；不用 `!` 注入（Windows 会报错） |
| Trae | 全局 command（frontmatter + 指令） | 无参数替换机制；会话库 SQLCipher 加密，不可外部注入 |
| Qoder | 全局 command（description 必填） | 引用语法是 `@file` 非 `#`；用户级覆盖项目级；Deeplink 可预填对话 |
| WorkBuddy | 全局 skill（`userInvocable`） | **无 command 机制**；skill 发现根不含项目级目录；禁写 `.workbuddy/memory/`（持久记忆） |
| ZCode | 全局 command，`$ARGUMENTS` 支持 | `!` 注入块**不预执行**（降级为 Bash 审批），改为直接指示模型读文件 |
| Claude Code | 全局 command + `$ARGUMENTS`（模板不用 `!` 注入） | Windows 上 `!` 块走 PowerShell，`||` 会解析失败；CLAUDE.md 每轮注入勿污染；项目级与全局同名**共存** |
| DeepSeek Harness | **无全局命令可装**（slash 命令为插件注册制，未知 `/xxx` 被拒绝） | 一键载体是 `dsh headless` 一行命令 / `dsh web` + 兜底提示词；headless 单发即退出，写文件需 `--permission-mode workspace-write` |

所有工具的兜底方式统一：全局命令缺失/失效时，在目标工具粘贴固定提示词「**请完整读取 .handoff/HANDOFF.md，按其任务规划继续交接的工作**」。

## 目录结构

```
continue-with-x.skill/
├── README.md                     # 本文件
├── install.sh                    # 一键安装（幂等）
├── templates/                    # 目标工具全局命令模板
│   ├── continue-opencode.md
│   ├── continue-generic.md       # Trae / Qoder 通用
│   ├── continue-zcode.md
│   ├── continue-claude.md
│   └── continue-workbuddy-SKILL.md
├── continue-with-opencode/       # 7 个打包侧 skill（结构相同）
│   ├── SKILL.md                  #   主指令：预检→收集→自省→打包→装命令→自检
│   └── references/
│       ├── handoff-format.md     #   交接文档模板与写作要求（七者共享）
│       └── opencode-cheatsheet.md#   目标工具机制速查
├── continue-with-trae/           #   … references/trae-cheatsheet.md
├── continue-with-qoder/          #   … references/qoder-cheatsheet.md
├── continue-with-workbuddy/      #   … references/workbuddy-cheatsheet.md
├── continue-with-zcode/          #   … references/zcode-cheatsheet.md
├── continue-with-claude/         #   … references/claude-cheatsheet.md
├── continue-with-deepseek/       #   … references/deepseek-cheatsheet.md（无命令可装，见 SKILL）
└── test-fixture/                 # 演练项目（含已生成 .handoff/，可直接试跑）
```

## 验证安装

```bash
# ZCode：应列出 continue 命令与 7 个 skill
zcode skills list && zcode commands list

# 命令模板版本（应含 protocol=3，否则为旧版需重跑 install.sh）
grep -l 'protocol=3' ~/.config/opencode/commands/continue.md ~/.zcode/commands/continue.md \
  ~/.claude/commands/continue.md 2>/dev/null

# 设备指纹自测（同一设备连续两次输出应一致，12 位十六进制；不读 /etc，沙箱可用）
fid_input="$(hostname)|$(whoami)|$(uname -s)|$(uname -m)"
printf '%s' "$fid_input" | sha256sum | cut -c1-12

# OpenCode：无头冒烟（在含 .handoff/ 的项目里，会消耗一次模型调用）
opencode run --command continue "只输出你收到的交接内容的一级标题清单"

# Claude Code：命令文件就位 + 无头冒烟（会消耗一次模型调用）
ls ~/.claude/commands/continue.md && claude -p "只输出 .handoff/HANDOFF.md 的各节一级标题清单"

# DeepSeek Harness：无文件可验，无头冒烟即可（会消耗一次模型调用）
dsh headless "只输出 .handoff/HANDOFF.md 的各节一级标题清单，不要修改任何文件"
```

Trae / Qoder / WorkBuddy 为 GUI，打开任一含 `.handoff/` 的项目后输入 `/continue` 人工确认。

## 卸载

```bash
rm -rf ~/.agents/skills/continue-with-{opencode,trae,qoder,workbuddy,zcode,claude,deepseek} \
       ~/.zcode/skills/continue-with-{opencode,trae,qoder,workbuddy,zcode,claude,deepseek} \
       ~/.config/opencode/commands/continue.md \
       ~/.trae-cn/commands/continue.md ~/.trae/commands/continue.md \
       ~/.qoder/commands/continue.md ~/.qoder-cn/commands/continue.md \
       ~/.zcode/commands/continue.md \
       ~/.claude/commands/continue.md \
       ~/.workbuddy/skills/continue
```

项目内数据（`.handoff/`）随项目自行删除。DeepSeek Harness 无全局文件产生，无需清理。跨设备环境缓存按需保留（删掉只会在下次跨设备时重新扫描）：

```bash
rm -rf ~/.continue-with-x
```

## FAQ

- **重复运行 install.sh 会覆盖我的自定义修改吗？** 会——脚本以仓库模板为准整体刷新。若你手工改过全局命令，先备份；日常交接场景 skill 的幂等检测不会覆盖你的修改（仅本脚本会）。
- **同一个项目交接给多个工具？** 五个 skill 读写同一份 `.handoff/HANDOFF.md`，只有一份数据不会漂移；任意工具 `/continue` 皆可接续。
- **源工具必须在清单里吗？** 不必。打包侧只要求 harness 能读写文件与执行 shell；交接文档由模型从当前会话提炼，与具体 harness 无关。
- **跨设备接续会不会每次都扫环境？** 不会。指纹一致（同设备同用户）直接跳过；跨设备也只是「查缓存 → 查工具记忆 → 只跑清单里的检测命令」，命中缓存后连检测都省了。
- **改了主机名 / 换了容器，会被当成跨设备吗？** 会。指纹 = `hostname|用户名|OS|arch` 的哈希（不读 `/etc` 等外部文件，沙箱内也能算），这类变更会判为跨设备——代价只是多一次环境检查。反过来，两台同名主机 + 同名用户的机器会被判为同一设备，此时不扫环境，由任务中的缺环境兜底处理。
- **沙箱/无头模式下缓存还能用吗？** 缓存文件在 `~/.continue-with-x/`（项目外）。若 harness 拒绝访问项目外路径（如 `opencode run` 默认 auto-reject external_directory），协议会降级为「未命中 + 不写缓存」，其余照常。opencode 想启用缓存复用，在 `~/.config/opencode/opencode.json` 加：

  ```json
  { "permission": { "external_directory": { "~/.continue-with-x/*": "allow" } } }
  ```

  其他 harness 同理，放行该目录即可；交互式会话中通常只需在弹窗里点一次允许。
- **跨设备时项目路径不同怎么办？** 元数据里的路径只是交出方视角，接收方以当前 cwd 与 `git status` 为准；skill 也会提示不要照抄旧路径。
- **环境缓存会随项目同步走吗？** 不会。`~/.continue-with-x/env-cache.md` 在本机用户目录下，按「设备 + 需求集」两级缓存，不随 git、也不建议纳入任何同步工具。
- **自定义 `/continue` 会覆盖工具原生命令吗？** 不会。七个目标工具均无原生 `/continue` 斜杠命令（Claude Code 的恢复是 `/resume`，OpenCode 是 `/sessions`，DeepSeek Harness 连自定义命令机制都没有），互不冲突；`claude --continue`、`opencode -c` 那类是 shell flag，与 TUI 斜杠命令属不同命名空间。注意语义区分：本仓库的 `/continue` 指「按交接文档继续工作」，不是「恢复上次会话」——恢复会话请用各工具原生入口。
- **方向支持反向吗？** 当前仅单向（任意 harness → 5 个目标工具）。反向导出（OpenCode `session export`、WorkBuddy `~/.workbuddy/projects/` 的 jsonl 等）在 `references/*-cheatsheet.md` 中留有调研记录，尚未实现。
