---
name: continue-with-workbuddy
description: 把当前会话的完整工作状态无缝交接给 WorkBuddy（腾讯 AI Agent 桌面应用）。当用户说"交接给 WorkBuddy / 迁移到 WorkBuddy / 换 WorkBuddy 继续 / handoff to workbuddy / work with workbuddy / 把工作转给 WorkBuddy"时使用。收集会话上下文、项目概况、当前进度、任务规划，在项目内生成 .handoff/ 交接包，并确保 WorkBuddy 全局一键继续 skill（/continue）就位，让用户在 WorkBuddy 中零成本接续工作。
---

# continue-with-workbuddy：把当前工作无缝交接给 WorkBuddy

目标：让用户在本会话停下的地方，到 WorkBuddy 里一条命令原地接续——不丢上下文、不重复解释、不返工调研。

**产出物**：

```
<项目目录>/.handoff/                        # 项目内：交接数据
├── HANDOFF.md                              # 交接主文档（接手模型的核心输入）
└── attachments/                            # 大体积证据：diff、文件摘录（按需）

~/.workbuddy/skills/continue/SKILL.md       # 全局：一键继续 skill（一次安装，所有项目通用）
```

**一句话原则**：HANDOFF.md 的读者是一个**对本项目零背景**的 WorkBuddy agent。写它的标准是——那个 agent 读完文档 + 核对 git 现状后，不需要再向用户问任何交接文档本可回答的问题。

---

## Step 0：预检

1. 确认目标项目目录：默认当前工作目录。若用户明确指定了别的项目，以用户指定为准。
2. 检查 WorkBuddy 是否安装：

```bash
ls -d /opt/apps/com.tencent.workbuddy ~/.workbuddy 2>/dev/null
```

- 任一存在：继续。
- 都不存在：告知需安装腾讯 WorkBuddy 桌面应用，**询问用户是否仍继续打包**（交接包照常生成）。

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

**硬性要求**：这一步产出的内容必须具体到文件路径、行号、命令。禁止出现"完成了一些优化""继续完善功能"这类空话——接手模型无法执行空话。

**行号必须核对**：文档中每个 `文件:行号` 引用在写入前用 `grep -n`（或读文件）实际确认，**不要凭记忆写行号**——实测凭记忆写的行号普遍漂移 2-5 行，会直接误导接手模型。

各节的详细模板与写作要求见 `references/handoff-format.md`（写 HANDOFF.md 前必读）。

## Step 3：写交接包

1. `mkdir -p .handoff/attachments`
2. 按 `references/handoff-format.md` 的模板写 `HANDOFF.md`。
3. 把 Step 1 收集到的大体积证据写入 `attachments/`；小而关键的信息直接内联进正文，不要拆文件。
4. **增量交接**：若 `.handoff/HANDOFF.md` 已存在，先读旧文档，把仍然有效的历史要点继承进新文档，标注本轮交接时间戳，覆盖写入。
5. **同步方式二选一询问**：问用户 `.handoff/` 打算怎么跨设备——
   - **git 提交 / 文件同步工具**（Syncthing、rsync 等）：不要加入 `.gitignore`，交接文档需随项目走（git 方式注意：文档只含设备指纹哈希、无主机名/用户名明文；介意者可只提交 `HANDOFF.md`、忽略 `attachments/`）
   - **仅本机使用**：建议把 `.handoff/` 加入 `.gitignore`（一次性个人上下文，默认不入库）

## Step 4：确保全局一键继续 skill 就位

WorkBuddy **没有自定义 command 机制**，但支持全局 skill（发现根含 `~/.workbuddy/skills/`，**不含项目级目录**）——所以一键入口只能装全局。这是对用户全局配置的修改，安装时明确告知。

检测 `~/.workbuddy/skills/continue/SKILL.md`：

- 已存在、内容引用 `.handoff/HANDOFF.md` 且含 `protocol=2` 标记 → 已就位，跳过（不要覆盖用户的自定义修改）
- 已存在但为旧版（无标记，不具备跨设备环境检查协议）→ 用下方模板覆盖升级，并告知用户
- 否则写入（`mkdir -p ~/.workbuddy/skills/continue`）：

```markdown
---
name: continue
description: 读取当前项目 .handoff/HANDOFF.md 交接文档，继续上一个 AI 编码工具的工作。当用户说"继续交接 / 接手之前的工作 / continue handoff"或输入 /continue 时使用。
userInvocable: true
---
<!-- continue-with-x: protocol=2 -->

1. 用读文件工具完整读取当前项目根目录的 `.handoff/HANDOFF.md`——这是从另一个 AI 编码工具交接过来的完整工作上下文。文件不存在时，告知用户需先在原 AI 工具中运行交接 skill 生成，不要凭空猜测任务。
2. **设备判定**：从元数据表「设备指纹」行读交出方指纹（形如 `3f2a9c1b7d4e` · linux-x86_64），用同一算法算本机指纹：

   ```bash
   fid_input="$(hostname)|$(whoami)|$(uname -s)|$(uname -m)"   # 不读 /etc 等外部文件，沙箱可用
      if command -v sha256sum >/dev/null 2>&1; then
     fid=$(printf '%s' "$fid_input" | sha256sum | cut -c1-12)
   elif command -v shasum >/dev/null 2>&1; then
     fid=$(printf '%s' "$fid_input" | shasum -a 256 | cut -c1-12)
   else
     fid=$(printf '%s' "$fid_input" | python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')
   fi
   echo "$fid"
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
     | awk -F'|' '{for(i=2;i<=6;i++) gsub(/^[ \t]+|[ \t]+$/,"",$i)} $2!="类型" && $2!~/^-+$/ {print $2"|"$3"|"$6}' | sort \
     | awk 'NR>1{printf "\n"} {printf "%s",$0}' \
     | { command -v sha256sum >/dev/null 2>&1 && sha256sum || { command -v shasum >/dev/null 2>&1 && shasum -a 256 || python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }; } | cut -c1-12)
   ```
4. 文中引用的 `.handoff/attachments/` 附件逐个打开查看，不要跳过。
5. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
6. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。
```

## Step 5：输出使用说明

交接完成后，向用户输出以下内容：

**方式一（推荐）：WorkBuddy 内一键继续**

在 WorkBuddy 中打开项目目录（作为工作区），对话输入：

```
/continue
```

或自然语言说「继续交接的工作」——skill 的 description 已含触发词，模型会自动匹配加载。

**方式二：兜底提示词**（skill 未加载时任何情况可用）

在 WorkBuddy 对话粘贴：

```
请完整读取当前项目的 .handoff/HANDOFF.md，按其「任务规划」继续交接的工作；文中引用的 .handoff/attachments/ 附件一并查看。
```

**恢复历史会话**：WorkBuddy 会话在桌面应用内历史列表恢复；新会话时项目结构（project_layout）会自动注入，`.handoff/` 目录在结构快照中可见，agent 容易自行发现。

## Step 6：自检

写完后**重读** `HANDOFF.md` 并逐项核对：

- [ ] 文中引用的每个文件路径真实存在（不存在 → 修正或删除）
- [ ] 每个行号引用与实际文件一致（用 `grep -n` 抽查核对）
- [ ] 无占位符残留（`TODO`、`<...>`、`...`）
- [ ] 「任务规划」每条都是可独立执行的动词开头条目
- [ ] 「关键文件」每条都说明了作用与入口位置
- [ ] 元数据表含设备指纹（12 位哈希 · OS-arch 明文，无主机名/用户名）
- [ ] 7.1 清单每条带幂等只读检测命令，且无任何密钥值
- [ ] 全局 skill frontmatter 完整（name/description/`userInvocable: true`），正文引用 `.handoff/HANDOFF.md`、含 `protocol=2` 标记
- [ ] 已向用户说明本次写入的是 WorkBuddy **全局** skill（一次安装，所有项目通用）

---

## 常见陷阱

- **不要把交接内容写进 `.workbuddy/memory/` 或项目 `MEMORY.md`**：这些是 WorkBuddy 的**持久记忆**，每轮会话注入——一次性交接会永久污染后续所有工作。交接只放 `.handoff/`。
- **skill 只能装全局**：WorkBuddy 的 skill 发现根（`~/.workbuddy`、`~/.workbuddy/skills`、市场目录、内置插件）不含项目级目录——项目内放 SKILL.md 不会被加载，不要尝试。
- **不要尝试内嵌 CLI 接管会话**：WorkBuddy 的 agent 引擎是内嵌 CodeBuddy CLI（`--resume`/`-p` 存在但与桌面会话存储的关系未验证，且独立运行时数据目录不同）——不要用它恢复 WorkBuddy 桌面会话，交接载体只能是项目内文件。
- **密钥只记位置不记值**：7.1 的 `env-var` 条目只记名称与存在性检测命令——HANDOFF.md 可能随 git 入库，写值等于泄密。
- **跨设备后项目路径以接收侧 cwd 为准**：元数据「项目路径」是交出方视角，跨设备时通常不同；接手侧以当前工作目录与 `git status` 实测为准。
- **指纹哈希不是安全边界**：只用于判定「同一设备+同一用户」；改 hostname 或换用户名会判为跨设备，后果仅是多一次环境检查；反之两台同名主机+同名用户的计算机会被判为同一设备（交给任务中的缺环境兜底）。
- **HANDOFF.md 是快照不是活文档**：WorkBuddy 侧工作推进后文档会过时，用户再次换工具时重跑本 skill 即可。
- WorkBuddy 机制细节（架构/skill 机制/记忆规则）见 `references/workbuddy-cheatsheet.md`。
