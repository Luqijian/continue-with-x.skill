---
name: continue-with-opencode
description: 把当前会话的完整工作状态无缝交接给 OpenCode。当用户说"交接给 OpenCode / 迁移到 OpenCode / 换 OpenCode 继续 / handoff to opencode / work with opencode / 把工作转给另一个工具"时使用。收集会话上下文、项目概况、当前进度、任务规划，在项目内生成 .handoff/ 交接包并确保 OpenCode 全局一键继续命令（/continue）就位，让用户在 OpenCode 中零成本接续工作。
---

# continue-with-opencode：把当前工作无缝交接给 OpenCode

目标：让用户在本会话停下的地方，到 OpenCode 里一条命令原地接续——不丢上下文、不重复解释、不返工调研。

**产出物**：

```
<项目目录>/.handoff/                        # 项目内：交接数据
├── HANDOFF.md                              # 交接主文档（接手模型的核心输入）
└── attachments/                            # 大体积证据：diff、文件摘录（按需）

~/.config/opencode/commands/continue.md     # 全局：一键继续命令（一次安装，所有项目通用）
```

**一句话原则**：HANDOFF.md 的读者是一个**对本项目零背景**的 OpenCode agent。写它的标准是——那个 agent 读完文档 + 核对 git 现状后，不需要再向用户问任何交接文档本可回答的问题。

---

## Step 0：预检

1. 确认目标项目目录：默认当前工作目录。若用户明确指定了别的项目，以用户指定为准。
2. 检查 OpenCode 是否安装：

```bash
command -v opencode && opencode --version
```

- 已安装：继续。
- 未安装：告知安装方式（`curl -fsSL https://opencode.ai/install | bash`），**询问用户是否仍继续打包**（交接包照常生成，装好 OpenCode 后即可用）。

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
# 设备指纹（接收方 /continue 据此判定本机/跨设备；哈希入文档，明文仅 OS/arch）
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

若当前 harness 提供了可读的会话 transcript 文件（如 `~/.zcode/`、`~/.claude/` 下的会话 jsonl），可选读取补充遗漏；读不到不影响——对话内提炼已足够。

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

## Step 4：确保全局一键继续命令就位

命令是**通用的**（读当前项目的 `.handoff/HANDOFF.md`），一次安装、所有项目通用，不要往项目里写命令文件。

检测 `~/.config/opencode/commands/continue.md`：

- 已存在、内容引用 `.handoff/HANDOFF.md` 且含 `protocol=3` 标记 → 已就位，跳过（不要覆盖用户的自定义修改）
- 已存在但为旧版（无标记，不具备跨设备环境检查协议）→ 用下方模板覆盖升级，并告知用户
- 不存在或为旧版 → 写入：

```markdown
---
description: 读取交接文档继续上一个 AI 工具的工作（可附补充指令）
---
<!-- continue-with-x: protocol=3 -->
请按以下步骤接手当前项目的工作：

1. 用读文件工具完整读取项目根目录的 `.handoff/HANDOFF.md`——这是从另一个 AI 编码工具交接过来的完整工作上下文。文件不存在时，告知用户需先在原 AI 工具中运行交接 skill 生成，不要凭空猜测任务。
2. **设备判定**：从元数据表「设备指纹」行读交出方指纹（形如 `3f2a9c1b7d4e` · linux-x86_64），用同一算法算本机指纹：

   ```bash
   fid_os=$(uname -s | tr 'A-Z' 'a-z')
   case "$fid_os" in mingw*|msys*|cygwin*) fid_os=windows ;; esac
   fid_input="$(hostname)|$(whoami)|$fid_os|$(uname -m)"
   if command -v sha256sum >/dev/null 2>&1; then
     fid=$(printf '%s' "$fid_input" | sha256sum | cut -c1-12)
   elif command -v shasum >/dev/null 2>&1; then
     fid=$(printf '%s' "$fid_input" | shasum -a 256 | cut -c1-12)
   else
     fid=$(printf '%s' "$fid_input" | python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')
   fi
   echo "$fid"
   ```

   Windows 没有 bash 时改用 PowerShell：

   ```powershell
   $os='windows'; $arch=$env:PROCESSOR_ARCHITECTURE.ToLower().Replace('amd64','x86_64')
   $s="$env:COMPUTERNAME|$env:USERNAME|$os|$arch"
   $h=[Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($s))
   ([BitConverter]::ToString($h) -replace '-','').ToLower().Substring(0,12)
   ```

   - 一致 → 本机交接，跳到第 4 步（跳过环境扫描；任务中真遇缺失再处理）
   - 不一致或元数据无该行 → 跨设备/跨用户交接，执行第 3 步
3. **跨设备环境检查**（仅当上一步判定不一致）：
   a. 先用 Bash `cat ~/.continue-with-x/env-cache.md` 查本机缓存（避免外部目录读工具限制）：有「当前设备指纹 + 本次需求集」记录则复用结论与用户此前提供的路径，不再扫描；该路径不可读写（沙箱/权限拒绝）时视为未命中，且本次不写缓存，直接继续
   b. 未命中 → 查当前工具持久记忆（如 CLAUDE.md / AGENTS.md / 工具 memory）是否已记录这些环境项；仍无 → 只逐条执行 7.1 清单的「检测命令」做一次快速检查，不做全盘探测
   c. 「必需」项全部满足 → 写回缓存（设备指纹、需求集指纹（见本步末规范片段）、每项结论与实际版本/路径、日期）后继续（写回失败只提示，不阻塞）
   d. 有必需项缺失 → **不要自行安装**。汇报缺失清单（附交出方已验证版本供参考），给三个选项等用户选择：**停止** / **安装后继续**（给出安装建议，用户装完重跑检测） / **用户提供环境路径**（记入缓存，后续优先于 PATH 探测）
   e. 7.1 清单不存在（旧版文档 / 非开发项目）→ 仅提示指纹差异，按普通接续继续

   **需求集指纹计算（规范片段：每行取「类型|需求|必需」，去首尾空白、排序、行间单个换行、末尾不加换行）**：

   ```bash
   reqid=$(sed -n '/^### 7\.1/,/^### 7\.2/p' .handoff/HANDOFF.md | grep '^|' \
     | awk -F'|' '{for(i=2;i<=6;i++) gsub(/^[ 	]+|[ 	]+$/,"",$i)} $2!="类型" && $2!~/^-+$/ {print $2"|"$3"|"$6}' | sort \
     | awk 'NR>1{printf "
"} {printf "%s",$0}' \
     | { command -v sha256sum >/dev/null 2>&1 && sha256sum || { command -v shasum >/dev/null 2>&1 && shasum -a 256 || python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }; } | cut -c1-12)
   ```
4. 文中引用的 `.handoff/attachments/` 附件逐个用读文件工具打开查看，不要跳过。
5. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
6. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。

用户补充指令（可为空）：$ARGUMENTS
```

**注意**：模板**不使用** `` !`cmd` `` 注入块——Windows 上该块由 PowerShell 执行，PS 5.1 不支持 `||` 与 `2>/dev/null`，会直接解析报错。改为直接指示模型读文件；`$ARGUMENTS` 必须保留。若目标项目内存在旧版 `.opencode/commands/continue.md`（指向 `.opencode/handoff/` 的历史打包产物），删除它并告知用户——项目级会覆盖全局，留着会让旧路径生效。

## Step 5：输出使用说明

交接完成后，向用户输出以下内容（替换 `<项目目录>` 为实际绝对路径）：

**方式一（推荐）：OpenCode TUI 内一键继续**

```bash
cd <项目目录> && opencode
```

打开后输入：

```
/continue
```

可带补充指令聚焦本轮工作：`/continue 优先完成 X`

**方式二：Shell 一条命令直接带上下文启动**

```bash
cd <项目目录> && opencode --prompt "先完整阅读 .handoff/HANDOFF.md，按其「任务规划」继续交接工作"
```

agent 会自行读取交接文档（不占初始 token，按需加载），随后直接开工。

**方式三：无头自动接管（不进交互界面，适合后台/CI）**

```bash
cd <项目目录> && opencode run --command continue "按交接文档继续"
```

`--command continue` 后的文本作为补充指令传入 `$ARGUMENTS`。

**恢复历史会话**（在 OpenCode 内工作过之后）：`opencode -c` 继续最近会话；`opencode --session <id>` 指定会话；`--fork` 可先分叉再继续。

## Step 6：自检

写完后**重读** `HANDOFF.md` 并逐项核对：

- [ ] 文中引用的每个文件路径真实存在（不存在 → 修正或删除）
- [ ] 每个行号引用与实际文件一致（用 `grep -n` 抽查核对）
- [ ] 无占位符残留（`TODO`、`<...>`、`...`）
- [ ] 「任务规划」每条都是可独立执行的动词开头条目
- [ ] 「关键文件」每条都说明了作用与入口位置
- [ ] 元数据表含设备指纹（12 位哈希 · OS-arch 明文，无主机名/用户名）
- [ ] 7.1 清单每条带幂等只读检测命令，且无任何密钥值
- [ ] 全局 `~/.config/opencode/commands/continue.md` 的 frontmatter 完整、正文引用 `.handoff/HANDOFF.md`、`$ARGUMENTS` 在位、含 `protocol=3` 标记、**无 `!` 注入块**
- [ ] 使用说明中的 `<项目目录>` 已替换为实际路径

可选冒烟验证（会真实调用一次模型，先询问用户是否执行）：

```bash
cd <项目目录> && opencode run --command continue "只输出你收到的交接内容的一级标题清单，不要修改任何文件"
```

输出应包含 HANDOFF.md 的各节标题——说明注入链路完整。

---

## 常见陷阱

- **不要把交接内容写进 AGENTS.md**：AGENTS.md 每轮会话自动注入，一次性交接会永久污染后续会话。交接只放 `.handoff/`。
- **不要往项目里写命令文件**：OpenCode 的项目级 `.opencode/commands/` 会**覆盖**全局命令。一键命令只装全局 `~/.config/opencode/commands/`；若项目里有旧版 continue.md（指向 `.opencode/handoff/` 的历史产物），删除并告知用户。
- **不要依赖 `@file` 引用**：OpenCode 命令模板与 AGENTS.md 中的 `@file` 不展开。附件引用一律写成"用读文件工具打开 <路径>"的明确指示。
- **`opencode` 的位置参数是项目目录**，不是 prompt。传初始 prompt 用 `--prompt`。
- **命令目录用复数 `commands/`**（单数 `command/` 仅 legacy 兼容）；同理 agent 定义目录是 `agents/`。
- **密钥只记位置不记值**：7.1 的 `env-var` 条目只记名称与存在性检测命令——HANDOFF.md 可能随 git 入库，写值等于泄密。
- **跨设备后项目路径以接收侧 cwd 为准**：元数据「项目路径」是交出方视角，跨设备时通常不同；接手侧以当前工作目录与 `git status` 实测为准。
- **指纹哈希不是安全边界**：只用于判定「同一设备+同一用户」；改 hostname 或换用户名会判为跨设备，后果仅是多一次环境检查；反之两台同名主机+同名用户的计算机会被判为同一设备（交给任务中的缺环境兜底）。
- **HANDOFF.md 是快照不是活文档**：OpenCode 侧工作推进后文档会过时，用户再次换工具时重跑本 skill 即可。
- 反向导出（OpenCode → 其他工具）不在本 skill 范围；交接包格式保持工具中性，为未来扩展预留。
- OpenCode 机制细节与 CLI 参数速查见 `references/opencode-cheatsheet.md`。
