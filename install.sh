#!/bin/bash
# 将 skills/ 下的所有 skill 以符号链接方式安装到各工具的用户级 skill 目录。
#
# 用法：
#   ./install.sh            安装 / 更新符号链接
#   ./install.sh --remove   移除所有指向本仓库的符号链接（不影响 skill 本体）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO/skills"

# 工具的用户级 skill 目录，按需增删
TARGETS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
)

# 某个 skill 不想装到某个目录时排除，格式 "skill名:目录包含的关键字"
# 例：EXCLUDES=("my-skill:codex")
EXCLUDES=(
)

is_excluded() {
  local skill="$1" target="$2" e key
  for e in "${EXCLUDES[@]:-}"; do
    [ -z "$e" ] && continue
    key="${e%%:*}"
    if [ "$key" = "$skill" ] && [[ "$target" == *"${e#*:}"* ]]; then
      return 0
    fi
  done
  return 1
}

if [ "${1:-}" = "--remove" ]; then
  for target in "${TARGETS[@]}"; do
    [ -d "$target" ] || continue
    echo "==> 从 $target 移除指向本仓库的链接"
    for link in "$target"/*; do
      [ -L "$link" ] || continue
      if [[ "$(readlink "$link")" == "$SKILLS_DIR"/* ]]; then
        rm "$link"
        echo "    移除 $(basename "$link")"
      fi
    done
  done
  exit 0
fi

for target in "${TARGETS[@]}"; do
  echo "==> 安装到 $target"
  mkdir -p "$target"
  for skill in "$SKILLS_DIR"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    if is_excluded "$name" "$target"; then
      echo "    跳过 ${name}（已排除）"
      continue
    fi
    link="$target/$name"
    if [ -e "$link" ] || [ -L "$link" ]; then
      if [ -L "$link" ]; then
        ln -sfnh "$skill" "$link"
        echo "    更新 $name"
      else
        echo "    [警告] $name 已存在且不是符号链接，未覆盖，请手动处理" >&2
      fi
    else
      ln -s "$skill" "$link"
      echo "    安装 $name"
    fi
  done
done
