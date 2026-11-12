---
name: continue
description: 读取当前项目 .handoff/HANDOFF.md 交接文档，继续上一个 AI 编码工具的工作。当用户说"继续交接 / 接手之前的工作 / continue handoff"或输入 /continue 时使用。
userInvocable: true
---

1. 用读文件工具完整读取当前项目根目录的 `.handoff/HANDOFF.md`——这是从另一个 AI 编码工具交接过来的完整工作上下文。文件不存在时，告知用户需先在原 AI 工具中运行交接 skill 生成，不要凭空猜测任务。
2. 文中引用的 `.handoff/attachments/` 附件逐个打开查看，不要跳过。
3. 运行 `git status` 核对仓库现状与交接描述是否一致；有出入先向用户说明再动手。
4. 从「任务规划」的第一条未完成项开始继续工作。交接文档未覆盖的问题，先向用户确认。
