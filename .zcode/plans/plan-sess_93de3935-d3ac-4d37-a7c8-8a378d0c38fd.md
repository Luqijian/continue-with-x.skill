## Context

现有交接只在**同一台机器**上成立：`HANDOFF.md` 记录了任务/进度/环境事实，但不记录「这份文档从哪台机器、哪个用户来的」。用户把项目连同 `.handoff/` 同步到另一台设备（git / Syncthing / rsync）后，接收方 `/continue` 无法区分「本机接续」和「跨设备接续」，要么盲信旧文档里可能失效的环境描述，要么每次都重复扫描。

目标：交接文档携带**交出方设备指纹**；接收方 `/continue` 比对指纹，不一致即判定跨设备/跨用户交接，先查本机环境记忆、未命中再做一次**只按清单执行**的快速扫描，缺失环境时向用户汇报并给出「停止 / 安装后继续 / 提供路径」三选项。指纹一致则完全跳过环境扫描，行为与现在一致。

已确认决策：环境记忆用**专用缓存 + 工具原生 memory 兜底**；`.gitignore` 建议改为**按同步方式二选一询问**；指纹**只记哈希 + OS/arch 明文**（不写主机名/用户名）。

## 核心设计

### 1. 设备指纹（唯一算法，打包与接收两侧一致）

```bash
fid_input="$(hostname)|$(whoami)|$(uname -s)|$(uname -m)"
[ -r /etc/machine-id ] && fid_input="$(cat /etc/machine-id)|$fid_input"
fid=$(printf '%s' "$fid_input" | sha256sum 2>/dev/null | cut -c1-12) \
  || fid=$(printf '%s' "$fid_input" | shasum -a 256 2>/dev/null | cut -c1-12) \
  || fid=$(printf '%s' "$fid_input" | python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')
```

记录形态：`` `3f2a9c1b7d4e` · linux-x64 ``。边界：无 `/etc/machine-id`（macOS）退化为 hostname|user|OS|arch；改 hostname / 容器复制 machine-id 会误判为跨设备（仅多一次环境检查，无副作用）；旧文档无指纹 → 按「未知」处理（有 7.1 清单则扫一次，无则正常继续）。

### 2. 环境需求清单（HANDOFF 第 7 节拆 7.1/7.2）

7.1 表格：`| 类型 | 需求 | 检测命令 | 约束 | 必需 |`，类型枚举 runtime/pkgmgr/tool/service/env-var/path；每条带**幂等只读**检测命令；env-var 只记名称不记值；末行记交出方已验证版本。7.2 保留原自由文本。

### 3. 接收方协议（写进 5 个命令模板 + HANDOFF 第 0 节）

模板加 `<!-- continue-with-x: protocol=2 -->` 标记；正文插入第 0 步：读指纹 → 一致跳过 → 不一致先查 `~/.continue-with-x/env-cache.md`（设备指纹+需求集双命中即复用）→ 未命中查工具原生 memory → 仍无只跑清单内检测命令 → 全满足写缓存后继续 → 有缺失**不自行安装**，汇报并给三选项。协议同时写入 HANDOFF 第 0 节，兜底提示词路径也能生效。

## 改动清单

| 文件 | 改动 |
|---|---|
| `continue-with-*/references/handoff-format.md`（×7，改母本后复制同步） | 元数据表加「设备指纹」行；第 0 节加设备判定指令；第 7 节拆 7.1/7.2；指纹算法一节；增量交接加「指纹每轮重算」；篇幅控制加清单规范 |
| `continue-with-*/SKILL.md`（×7） | Step 1 加第三个 bash 块（指纹+已验证版本）与环境需求推导指引；Step 3 第 5 条改「同步方式二选一询问」；Step 4 检测升级为「含 `protocol=2` 才就位，旧版覆盖升级并告知」；Step 6 加指纹/清单自检项；常见陷阱加 3 条（密钥不记值、跨设备后路径以 cwd 为准、哈希非安全边界） |
| `templates/continue-{opencode,claude,zcode,generic,workbuddy-SKILL}.md` | 加 `protocol=2` 标记 + 第 0 步设备判定（注入族/读文件族按各自行文插入） |
| `install.sh` | 预建 `~/.continue-with-x/`；完成提示加跨设备说明 |
| `README.md` | 新增 `## 跨设备接续` 章节（场景、机制流程、同步方式二选一表、三选项交互、隐私注意）；更新交接包格式说明与 FAQ |
| `test-fixture/.handoff/HANDOFF.md` | 加演示指纹 + 7.1 清单（node/npm），第 0 节注明演示指纹会触发跨设备分支属预期 |

## 验证

1. `bash -n install.sh && bash install.sh` → 7 skill、9 命令、`~/.continue-with-x/` 创建
2. 一致性：`md5sum continue-with-*/references/handoff-format.md` 7 份全等；`grep -l 'protocol=2' templates/*` 命中 5；各 SKILL.md 含「设备指纹」
3. 指纹算法自测两次输出一致且为 12 位十六进制
4. test-fixture 用改过的演示指纹跑一次跨设备分支（消耗模型调用前先询问）；真实指纹回归本机分支
5. `git add -A && git commit && git push`