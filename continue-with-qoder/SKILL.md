---
name: continue-with-qoder
description: 把当前会话的完整工作状态无缝交接给 Qoder（阿里 AI IDE，国际版/CN 版均可，含 CLI）。当用户说"交接给 Qoder / 迁移到 Qoder / 换 Qoder 继续 / handoff to qoder / work with qoder / 把工作转给 Qoder"时使用。收集会话上下文、项目概况、当前进度、任务规划，在项目内生成 .handoff/ 交接包，并确保 Qoder 全局一键继续命令（/continue）就位，让用户在 Qoder 中零成本接续工作。
---

# continue-with-qoder：把当前工作无缝交接给 Qoder

目标：让用户在本会话停下的地方，到 Qoder 里一条命令原地接续——不丢上下文、不重复解释、不返工调研。

**产出物**：

```
<项目目录>/.handoff/                        # 项目内：交接数据
├── HANDOFF.md                              # 交接主文档（接手模型的核心输入）
└── attachments/                            # 大体积证据：diff、文件摘录（按需）

~/.qoder/commands/continue.md               # 全局：一键继续命令（一次安装，所有项目通用）
~/.qoder-cn/commands/continue.md            # CN 版（检测到 ~/.qoder-cn/ 时也装）
```

**一句话原则**：HANDOFF.md 的读者是一个**对本项目零背景**的 Qoder agent。写它的标准是——那个 agent 读完文档 + 核对 git 现状后，不需要再向用户问任何交接文档本可回答的问题。

---

## Step 0：预检

1. 确认目标项目目录：默认当前工作目录。若用户明确指定了别的项目，以用户指定为准。
2. 检查 Qoder 是否安装（IDE 或 CLI 任一即可）：

```bash
command -v qoder; ls -d ~/.qoder ~/.qoder-cn /opt/Qoder-CN 2>/dev/null
```

- 任一存在：继续（记录装的是哪个版本，Step 4 装对应全局目录）。
- 全部不存在：告知下载地址（qoder.com），**询问用户是否仍继续打包**（交接包照常生成）。

## Step 1：机械收集（并行执行）

这些是事实性数据，直接跑命令拿，不要凭记忆编造：

```bash
# git 现状（非 git 项目则跳过 git 部分，在 HANDOFF.md 中注明）
git status --short
git log --oneline -15
git branch --show-current
git diff --stat

# 未提交改动较多（>200 行）时存为附件，正文只引用
git diff > .handoff/attachments/git-diff.patch
```

```bash
# 项目识别：看根目录有什么，读关键清单文件
ls -la
# 按存在与否读其一或多个：README*、package.json、pyproject.toml、Cargo.toml、go.mod、
# Makefile、docker-compose*.yml、.env.example
```

从关键清单文件中提取：技术栈、包管理器、build / test / lint / dev 命令、主要依赖。

目录结构快照（2 层即可，排除 node_modules/.git/.venv 等噪音）。

## Step 2：会话自省提炼（质量核心）

从**当前对话**中提炼以下内容（你能记住对话，这是任何 harness 都可行的普适路径）：

- **任务背景与目标**：用户到底要什么？为什么做？
- **关键决策**：做了哪些技术/方案选择，各自的 why（没有 why 的决策会在接手后被推翻）
- **当前进度**：已完成 ✅ / 进行中 🔄 / 阻塞 ⛔，各自落到具体文件与状态
- **任务规划**：下一步行动清单，每条动词开头、可独立执行
- **用户偏好与约束**：明确的工作方式要求、不可破坏的东西、踩过的坑

**硬性要求**：这一步产出的内容必须具体到文件路径、行号、命令。禁止出现"完成了一些优化""继续完善功能"这类空话——接手模型无法执行空话。

**行号必须核对**：文档中每个 `文件:行号` 引用在写入前用 `grep -n`（或读文件）实际确认，**不要凭记忆写行号**——实测凭记忆写的行号普遍漂移 2-5 行，会直接误导接手模型。

各节的详细模板与写作要求见 `references/handoff-format.md`（写 HANDOFF.md 前必读）。

## Step 3：写交接包

1. `mkdir -p .handoff/attachments`
2. 按 `references/handoff-format.md` 的模板写 `HANDOFF.md`。
3. 把 Step 1 收集到的大体积证据写入 `attachments/`；小而关键的信息直接内联进正文，不要拆文件。
4. **增量交接**：若 `.handoff/HANDOFF.md` 已存在，先读旧文档，把仍然有效的历史要点继承进新文档，标注本轮交接时间戳，覆盖写入。
5. 若项目尚无 `.gitignore` 条目覆盖 `.handoff/`，建议用户追加（一次性个人上下文，默认不入库）。

## Step 4：确保全局一键继续命令就位

命令是**通用的**（读当前项目的 `.handoff/HANDOFF.md`），一次安装、所有项目通用，不要往项目里写命令文件。注意 Qoder 的**用户级会覆盖项目级**——全局装好后项目内的同名命令不会生效，正合本 skill 意图。

对检测到的每个版本目录（`~/.qoder/commands/`；存在 `~/.qoder-cn/` 时加 `~/.qoder-cn/commands/`）：

- `continue.md` 已存在且内容引用 `.handoff/HANDOFF.md` → 已就位，跳过（不要覆盖用户的自定义修改）
- 否则写入：

```markdown
---
name: continue
description: 读取交接文档继续上一个 AI 工具的工作
---
请按以下步骤接手当前项目的工作：

1. 用读文件工具完整读取项目根目录的 `.handoff/HANDOFF.md`——这是从另一个 AI 编码工具交接过来的工作上下文。
2. 文中引用的 `.handoff/attachments/` 附件逐个打开查看，不要跳过。
3. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
4. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。

用户若有补充说明，以其为准调整工作顺序与重点。
```

若项目内存在旧版 `.qoder/commands/continue.md`（指向其他路径的历史产物），删除它并告知用户——虽然用户级优先，但留着会混淆。

## Step 5：输出使用说明

交接完成后，向用户输出以下内容（替换 `<项目目录>` 为实际绝对路径）：

**方式一（推荐）：Qoder IDE 内一键继续**

在 Qoder 中打开项目目录，Agent 对话框输入：

```
/continue
```

**方式二：CLI 无头接管**（装了 Qoder CLI 时）

```bash
cd <项目目录> && qoder -p '/continue'
```

**方式三：Deeplink 预填对话**（在终端或浏览器打开，Qoder 会新建对话并预填文本，回车即发送）：

```
qoder://aicoding.aicoding-deeplink/chat?text=%2Fcontinue&mode=agent&isNewChat=true
```

**方式四：兜底提示词**（命令未生效时任何形态可用）

在 Qoder 对话框粘贴：

```
@file .handoff/HANDOFF.md 请先读取该文件恢复工作上下文（引用的 attachments 一并查看），然后按其中「任务规划」继续。
```

**恢复历史会话**：IDE 在会话列表恢复；CLI 用 `qoder -c`（继续最近）或 `qoder -r <session-id>`，`--list-sessions` 可列出。

## Step 6：自检

写完后**重读** `HANDOFF.md` 并逐项核对：

- [ ] 文中引用的每个文件路径真实存在（不存在 → 修正或删除）
- [ ] 每个行号引用与实际文件一致（用 `grep -n` 抽查核对）
- [ ] 无占位符残留（`TODO`、`<...>`、`...`）
- [ ] 「任务规划」每条都是可独立执行的动词开头条目
- [ ] 「关键文件」每条都说明了作用与入口位置
- [ ] 全局命令文件 frontmatter 完整（description 必填），正文引用 `.handoff/HANDOFF.md`
- [ ] 使用说明中的 `<项目目录>` 已替换为实际路径

---

## 常见陷阱

- **不要把交接内容写进 `.qoder/rules/` 或 AGENTS.md**：规则/AGENTS.md 每次调用自动注入（活跃规则合计 10 万字符上限），一次性交接会永久占用上下文。交接只放 `.handoff/`。
- **不要尝试注入会话库**：Qoder IDE 会话日志 RSA+AES 加密本地不可读，CLI JSONL 格式未承诺稳定——交接载体只能是项目内文件。
- **命令装全局不装项目级**：用户级 `~/.qoder/commands/` 会覆盖项目级同名命令；一次安装全项目通用。
- **Qoder 的引用语法是 `@`**（`@file`/`@folder`/`@rule`），不是 Trae 的 `#`——兜底提示词与文档引用一律用 `@file`。
- **CN 版与国际版全局目录可能不同**（`~/.qoder-cn/` vs `~/.qoder/`）：按预检结果装对应的。
- **HANDOFF.md 是快照不是活文档**：Qoder 侧工作推进后文档会过时，用户再次换工具时重跑本 skill 即可。
- Qoder 机制细节（CLI 参数/rules/deeplink/Quest）见 `references/qoder-cheatsheet.md`。
