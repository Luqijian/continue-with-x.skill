---
description: 读取交接文档继续上一个 AI 工具的工作（可附补充指令）
argument-hint: [补充指令]
---
!`cat .handoff/HANDOFF.md 2>/dev/null || echo '[提示] 当前项目没有 .handoff/HANDOFF.md 交接文件。如需交接，请在原 AI 工具中运行 continue-with-claude skill；或直接告诉我要做什么。'`

---

上面是从另一个 AI 编码工具交接过来的完整工作上下文。请：

1. 通读上述交接内容。文中引用的 `.handoff/attachments/` 附件，用读文件工具打开查看，不要跳过。
2. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
3. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。

用户补充指令（可为空）：$ARGUMENTS
