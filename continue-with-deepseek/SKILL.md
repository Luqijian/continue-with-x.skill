---
name: continue-with-deepseek
description: 把当前会话的完整工作状态无缝交接给 DeepSeek Harness（dsh，DeepSeek 官方开源编码 agent 运行时）。当用户说"交接给 DeepSeek / 迁移到 DeepSeek Harness / 换 dsh 继续 / handoff to deepseek / work with dsh / 把工作转给另一个工具"时使用。收集会话上下文、项目概况、当前进度、任务规划，在项目内生成 .handoff/ 交接包，并给出在 dsh web / dsh headless 中零成本接续的一行命令，让用户在 DeepSeek Harness 中接续工作。
---

# continue-with-deepseek：把当前工作无缝交接给 DeepSeek Harness

目标：让用户在本会话停下的地方，到 DeepSeek Harness（`dsh`）里原地接续——不丢上下文、不重复解释、不返工调研。

**产出物**：

```
<项目目录>/.handoff/                        # 项目内：交接数据
├── HANDOFF.md                              # 交接主文档（接手模型的核心输入）
└── attachments/                            # 大体积证据：diff、文件摘录（按需）
```

⚠️ **与其它目标不同：dsh 没有可部署的全局命令文件**。它的 slash 命令是插件注册制（代码注册，非 markdown 文件），未知 `/xxx` 会被交互适配器拒绝、不进入模型——所以一键继续的载体是 **一行 shell 命令**（`dsh headless` / `dsh web` + 兜底提示词），本 skill 不写任何 dsh 全局文件。

**一句话原则**：HANDOFF.md 的读者是一个**对本项目零背景**的 dsh agent。写它的标准是——那个 agent 读完文档 + 核对 git 现状后，不需要再向用户问任何交接文档本可回答的问题。

---

## Step 0：预检

1. 确认目标项目目录：默认当前工作目录。若用户明确指定了别的项目，以用户指定为准。
2. 检查 DeepSeek Harness 是否安装：

```bash
command -v dsh || ls -d "${DSH_HOME:-$HOME/deepseek-harness}" ~/.dsh 2>/dev/null
```

- 任一成功：继续。
- 都不存在：告知安装方式（官方 npm 包 `@deepseek-ai/dsh`，或克隆 deepseek-ai/deepseek-harness 源码构建），**询问用户是否仍继续打包**（交接包照常生成，装好后即可用）。

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

设备指纹与交出方环境（跨设备接续用，算法细节见 `references/handoff-format.md`）：

```bash
# 设备指纹（接收方接续时据此判定本机/跨设备；哈希入文档，明文仅 OS/arch）
fid_input="$(hostname)|$(whoami)|$(uname -s)|$(uname -m)"   # 不读 /etc 等外部文件，沙箱可用
if command -v sha256sum >/dev/null 2>&1; then
  fid=$(printf '%s' "$fid_input" | sha256sum | cut -c1-12)
elif command -v shasum >/dev/null 2>&1; then
  fid=$(printf '%s' "$fid_input" | shasum -a 256 | cut -c1-12)
else
  fid=$(printf '%s' "$fid_input" | python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')
fi
printf '指纹=%s · %s-%s\n' "$fid" "$(uname -s | tr 'A-Z' 'a-z')" "$(uname -m)"

# 交出方已验证版本（按项目技术栈选用，结果写进 7.1 末行）
node -v 2>/dev/null; npm -v 2>/dev/null; pnpm -v 2>/dev/null; python3 --version 2>/dev/null
```

环境需求推导（写 HANDOFF 7.1 清单）：从技术栈与常用命令推导接手**必需**项（通常 ≤6 条），类型枚举 runtime / pkgmgr / tool / service / env-var / path，每条配**幂等只读**检测命令（如 `node -v`、`pg_isready -h 127.0.0.1 -p 5432`、`test -n "${DATABASE_URL:-}"`）；`env-var` 只记名称，**禁止记录任何密钥/token/密码的值**。

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
3. 把 Step 1 收集到的大体积证据写入 `attachments/`（git-diff.patch、大文件摘录等）；小而关键的信息直接内联进正文，不要拆文件。
4. **增量交接**：若 `.handoff/HANDOFF.md` 已存在，先读旧文档，把仍然有效的历史要点（背景、决策、已完成项）继承进新文档，标注本轮交接时间戳，覆盖写入。旧 attachments 直接覆盖。
5. **同步方式二选一询问**：问用户 `.handoff/` 打算怎么跨设备——
   - **git 提交 / 文件同步工具**（Syncthing、rsync 等）：不要加入 `.gitignore`，交接文档需随项目走（git 方式注意：文档只含设备指纹哈希、无主机名/用户名明文；介意者可只提交 `HANDOFF.md`、忽略 `attachments/`）
   - **仅本机使用**：建议把 `.handoff/` 加入 `.gitignore`（一次性个人上下文，默认不入库）

## Step 4：确认接续入口可用（不安装任何全局文件）

dsh 的 slash 命令由插件在代码中注册（`ctx.commands.register()`），**没有用户级命令文件目录**——不要尝试写 `~/.dsh/commands/` 之类的文件，也不要尝试用 `dsh plugin add` 硬装命令插件（npm 包级操作，超出本 skill 轻量边界）。

只需验证 CLI 可用：

```bash
command -v dsh && dsh --version
```

`dsh --version` 失败但 `command -v dsh` 成功时（developer preview 版本行为可能差异），改跑 `dsh headless --help` 确认 headless profile 存在。都可用后，把 Step 5 的一行命令原样告诉用户即可。

## Step 5：输出使用说明

交接完成后，向用户输出以下内容（替换 `<项目目录>` 为实际绝对路径）：

**方式一（推荐）：dsh headless 一行接续（无头单发）**

```bash
cd <项目目录> && dsh headless "先完整阅读 .handoff/HANDOFF.md，按其「任务规划」继续交接工作"
```

- 单发任务、打印结果后退出。涉及写文件的任务追加 `--permission-mode workspace-write`。
- 想把后续任务续在同一个 Session：记下返回的 session id，之后 `dsh headless --session-id <id> "下一项任务"`。

**方式二：dsh web 交互接续**

```bash
cd <项目目录> && dsh web
```

浏览器工作台打开后（默认 `http://127.0.0.1:3080`，已启动则跳过 `--no-open`），把当前项目目录作为工作区打开，首次对话粘贴兜底提示词。**没有 `/continue` 可用**——dsh 不支持用户自定义 slash 命令，在输入框敲 `/continue` 会被拒绝。

**兜底提示词**（任何情况可用）：

```
请完整读取当前项目的 .handoff/HANDOFF.md，按其「任务规划」继续交接的工作；文中引用的 .handoff/attachments/ 附件一并查看。
```

## Step 6：自检

写完后**重读** `HANDOFF.md` 并逐项核对：

- [ ] 文中引用的每个文件路径真实存在（不存在 → 修正或删除）
- [ ] 每个行号引用与实际文件一致（用 `grep -n` 抽查核对）
- [ ] 无占位符残留（`TODO`、`<...>`、`...`）
- [ ] 「任务规划」每条都是可独立执行的动词开头条目
- [ ] 「关键文件」每条都说明了作用与入口位置
- [ ] 元数据表含设备指纹（12 位哈希 · OS-arch 明文，无主机名/用户名）
- [ ] 7.1 清单每条带幂等只读检测命令，且无任何密钥值
- [ ] 使用说明中的 `<项目目录>` 已替换为实际路径；一行命令中的引号完整
- [ ] 已向用户说明：dsh **没有** `/continue`，接续入口是 `dsh headless` / `dsh web` + 兜底提示词

可选冒烟验证（会真实调用一次模型，先询问用户是否执行）：

```bash
cd <项目目录> && dsh headless "只输出 .handoff/HANDOFF.md 的各节一级标题清单，不要修改任何文件"
```

输出应包含 HANDOFF.md 的各节标题——说明交接文件可读、链路完整。

---

## 常见陷阱

- **不要尝试写命令文件**：dsh 无用户级命令目录；未知 `/continue` 被适配器拒绝且不进模型，用户在 web 输入框敲 `/continue` 是无效操作。接续载体只有 `.handoff/` 文件 + 一行 shell 命令。
- **不要用 `dsh plugin add` 硬装命令插件**：那是 npm 包级的 Cordis 插件安装（`dsh plugin --profile <name> add <pkg>`，内部转发 pnpm），远超本 skill 的文件拖放边界，且 developer preview 的插件 API 随版本破坏性变更。
- **headless 是单发不是常驻**：`dsh headless` 回答一次就退出，长任务交互推进用 `dsh web`；要续会话用 `--session-id <id>`。
- **权限默认偏保守**：headless 默认权限预设可能禁止写文件，交接任务涉及改动时显式加 `--permission-mode workspace-write`（必要时 `--add-dir <path>`）。
- **密钥只记位置不记值**：7.1 的 `env-var` 条目只记名称与存在性检测命令——HANDOFF.md 可能随 git 入库，写值等于泄密。
- **跨设备后项目路径以接收侧 cwd 为准**：元数据「项目路径」是交出方视角，跨设备时通常不同；接手侧以当前工作目录与 `git status` 实测为准。
- **指纹哈希不是安全边界**：只用于判定「同一设备+同一用户」；改 hostname 或换用户名会判为跨设备，后果仅是多一次环境检查；反之两台同名主机+同名用户的计算机会被判为同一设备（交给任务中的缺环境兜底）。
- **HANDOFF.md 是快照不是活文档**：dsh 侧工作推进后文档会过时，用户再次换工具时重跑本 skill 即可。
- 反向导出（dsh → 其他工具）不在本 skill 范围；交接包格式保持工具中性，为未来扩展预留。
- DeepSeek Harness 机制细节与 CLI 参数速查见 `references/deepseek-cheatsheet.md`。
