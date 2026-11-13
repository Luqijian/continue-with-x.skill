---
description: 读取交接文档继续上一个 AI 工具的工作（可附补充指令）
argument-hint: [补充指令]
---
!`cat .handoff/HANDOFF.md 2>/dev/null || echo '[提示] 当前项目没有 .handoff/HANDOFF.md 交接文件。如需交接，请在原 AI 工具中运行 continue-with-claude skill；或直接告诉我要做什么。'`

---
<!-- continue-with-x: protocol=2 -->

上面是从另一个 AI 编码工具交接过来的完整工作上下文。请：

1. **设备判定**：从上面元数据表「设备指纹」行读交出方指纹（形如 `3f2a9c1b7d4e` · linux-x64），用同一算法算本机指纹：

   ```bash
   fid_input="$(hostname)|$(whoami)|$(uname -s)|$(uname -m)"
   [ -r /etc/machine-id ] && fid_input="$(cat /etc/machine-id)|$fid_input"
   fid=$(printf '%s' "$fid_input" | sha256sum 2>/dev/null | cut -c1-12) \
     || fid=$(printf '%s' "$fid_input" | shasum -a 256 2>/dev/null | cut -c1-12) \
     || fid=$(printf '%s' "$fid_input" | python3 -c 'import sys,hashlib;print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])')
   echo "$fid"
   ```

   - 一致 → 本机交接，跳到第 3 步（跳过环境扫描；任务中真遇缺失再处理）
   - 不一致或元数据无该行 → 跨设备/跨用户交接，执行第 2 步
2. **跨设备环境检查**（仅当上一步判定不一致）：
   a. 先查本机缓存 `~/.continue-with-x/env-cache.md`：有「当前设备指纹 + 本次需求集」记录则复用结论与用户此前提供的路径，不再扫描
   b. 未命中 → 查当前工具持久记忆（如 CLAUDE.md / AGENTS.md / 工具 memory）是否已记录这些环境项；仍无 → 只逐条执行 7.1 清单的「检测命令」做一次快速检查，不做全盘探测
   c. 「必需」项全部满足 → 写回缓存（设备指纹、需求集指纹——对 7.1 的「类型|需求|必需」行去除空白后排序、换行拼接取 sha256 前 12 位、每项结论与实际版本/路径、日期）后继续
   d. 有必需项缺失 → **不要自行安装**。汇报缺失清单（附交出方已验证版本供参考），给三个选项等用户选择：**停止** / **安装后继续**（给出安装建议，用户装完重跑检测） / **用户提供环境路径**（记入缓存，后续优先于 PATH 探测）
   e. 7.1 清单不存在（旧版文档 / 非开发项目）→ 仅提示指纹差异，按普通接续继续
3. 通读上述交接内容。文中引用的 `.handoff/attachments/` 附件，用读文件工具打开查看，不要跳过。
4. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
5. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。

用户补充指令（可为空）：$ARGUMENTS
