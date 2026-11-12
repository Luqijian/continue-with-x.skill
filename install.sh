#!/usr/bin/env bash
# continue-with-* 系列 skill 一键安装脚本
# 幂等：重复运行安全；已存在的目标工具才安装对应一键命令
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SKILLS="$HOME/.agents/skills"
ZCODE_SKILLS="$HOME/.zcode/skills"
SKILLS=(
  continue-with-opencode
  continue-with-trae
  continue-with-qoder
  continue-with-workbuddy
  continue-with-zcode
  continue-with-claude
  continue-with-deepseek
)

echo "==> 安装打包侧 skill（实体 → ~/.agents/skills/）"
mkdir -p "$AGENTS_SKILLS"
for s in "${SKILLS[@]}"; do
  rm -rf "$AGENTS_SKILLS/$s"
  cp -r "$REPO_DIR/$s" "$AGENTS_SKILLS/"
  echo "  ✓ $s"
done

echo "==> 创建 ZCode 软链（~/.zcode/skills/ → 实体）"
if [ -d "$HOME/.zcode" ]; then
  mkdir -p "$ZCODE_SKILLS"
  for s in "${SKILLS[@]}"; do
    ln -sfn "../../.agents/skills/$s" "$ZCODE_SKILLS/$s"
  done
  echo "  ✓ 7 个软链就绪"
else
  echo "  - 未检测到 ~/.zcode，跳过软链（~/.agents/skills 已被 ZCode 官方支持）"
fi

echo "==> 安装目标工具全局一键命令（检测到才装）"
installed=0; skipped=0

# detect_and_install <检测目录> <模板文件> <目标目录> <工具名>
detect_and_install() {
  local detect="$1" tpl="$2" dest="$3" name="$4"
  if [ -d "$detect" ]; then
    mkdir -p "$dest"
    cp "$REPO_DIR/templates/$tpl" "$dest/continue.md"
    echo "  ✓ $name → $dest/continue.md"
    installed=$((installed + 1))
  else
    echo "  - $name 未检测到，跳过"
    skipped=$((skipped + 1))
  fi
}

detect_and_install "$HOME/.config/opencode" "continue-opencode.md" "$HOME/.config/opencode/commands" "OpenCode"
detect_and_install "$HOME/.trae-cn"          "continue-generic.md"  "$HOME/.trae-cn/commands"        "Trae CN"
detect_and_install "$HOME/.trae"             "continue-generic.md"  "$HOME/.trae/commands"           "Trae（国际版）"
detect_and_install "$HOME/.qoder"            "continue-generic.md"  "$HOME/.qoder/commands"          "Qoder"
detect_and_install "$HOME/.qoder-cn"         "continue-generic.md"  "$HOME/.qoder-cn/commands"       "Qoder CN"
detect_and_install "$HOME/.zcode"            "continue-zcode.md"    "$HOME/.zcode/commands"          "ZCode"
detect_and_install "$HOME/.claude"           "continue-claude.md"   "$HOME/.claude/commands"         "Claude Code"

# DeepSeek Harness：无文件式命令机制（slash 命令为插件注册制），不安装任何全局文件
if command -v dsh >/dev/null 2>&1 || [ -d "${DSH_HOME:-$HOME/deepseek-harness}" ] || [ -d "$HOME/.dsh" ]; then
  echo "  ✓ DeepSeek Harness → 无需安装命令文件；交接用 dsh headless 一行命令（见 skill）"
  installed=$((installed + 1))
else
  echo "  - DeepSeek Harness 未检测到，跳过"
  skipped=$((skipped + 1))
fi

# WorkBuddy：唯一用全局 skill（无 command 机制）
if [ -d "$HOME/.workbuddy" ]; then
  mkdir -p "$HOME/.workbuddy/skills/continue"
  cp "$REPO_DIR/templates/continue-workbuddy-SKILL.md" "$HOME/.workbuddy/skills/continue/SKILL.md"
  echo "  ✓ WorkBuddy → ~/.workbuddy/skills/continue/SKILL.md"
  installed=$((installed + 1))
else
  echo "  - WorkBuddy 未检测到，跳过"
  skipped=$((skipped + 1))
fi

echo
echo "==> 完成：打包侧 skill 7 个；一键命令安装 $installed 个、跳过 $skipped 个（未安装的工具）"
echo "    之后在新项目中交接时无需重跑本脚本——skill 会自动检测并复用全局命令。"
echo "    验证：新开会话说「交接给 OpenCode / Trae / Qoder / WorkBuddy / ZCode / Claude / DeepSeek」即可触发。"
