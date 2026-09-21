#!/bin/bash
# sync.sh —— AJohn-Skills 三方状态同步检查（GitHub REST API 集成）
#
# 对比三方状态，发现漂移：
#   1. 本地仓库 vs GitHub 远端（提交是否同步、skills 目录是否一致）
#   2. 本地 skills/ vs 各工具已安装的符号链接（是否有漏装/漏更）
#
# 用法：
#   ./sync.sh            检查状态（只读，不改动任何东西）
#   ./sync.sh pull       拉取远端更新到本地（git pull --ff-only）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER_REPO="zzyAJohn/AJohn-Skills"
API="https://api.github.com/repos/$OWNER_REPO"
SKILLS_DIR="$REPO_DIR/skills"
TARGETS=("$HOME/.claude/skills" "$HOME/.codex/skills")

api() { # api <path> → 响应体
  local tok
  tok="$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null \
        | grep '^password=' | cut -d= -f2 || true)"
  if [ -n "$tok" ]; then
    curl -sf -H "Authorization: Bearer $tok" -H "Accept: application/vnd.github+json" "$API$1"
  else
    curl -sf -H "Accept: application/vnd.github+json" "$API$1" # 未登录：公共仓库只读仍可用（限流更低）
  fi
}

json_field() { # json_field <python 表达式，x 为解析后的 json> 从 stdin 读取
  python3 -c "import json,sys; x=json.load(sys.stdin); print($1)"
}

cmd_status() {
  echo "== 提交状态 =="
  local local_sha remote_sha dirty
  local_sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
  remote_sha="$(api "/commits/main" | json_field 'x["sha"]' || echo "")"
  if [ -z "$remote_sha" ]; then
    echo "  [警告] GitHub API 不可达或限流，跳过远端检查"
    remote_sha="$local_sha"
  fi
  dirty="$(git -C "$REPO_DIR" status --porcelain)"
  [ -n "$dirty" ] && echo "  注意：本地有未提交改动"
  if [ "$local_sha" = "$remote_sha" ]; then
    echo "  本地与远端 main 一致（$(echo "$local_sha" | cut -c1-7)）"
  else
    echo "  本地 $local_sha"
    echo "  远端 $remote_sha"
    echo "  → 不一致，跑 ./sync.sh pull 或 git push 对齐"
  fi

  echo
  echo "== skills 目录一致性（本地 vs GitHub 远端） =="
  local local_list remote_list
  local_list="$(cd "$SKILLS_DIR" && ls -1)"
  remote_list="$(api "/contents/skills" | json_field '"\n".join(i["name"] for i in x if i["type"]=="dir")' 2>/dev/null || echo "$local_list")"
  local only_local only_remote
  only_local="$(comm -23 <(echo "$local_list" | sort) <(echo "$remote_list" | sort))"
  only_remote="$(comm -13 <(echo "$local_list" | sort) <(echo "$remote_list" | sort))"
  if [ -z "$only_local" ] && [ -z "$only_remote" ]; then
    echo "  一致（$(echo "$local_list" | grep -c .) 个 skill）"
  else
    [ -n "$only_local" ] && { echo "  仅本地（未推送）："; echo "$only_local" | sed 's/^/    /'; }
    [ -n "$only_remote" ] && { echo "  仅远端（本地缺失）："; echo "$only_remote" | sed 's/^/    /'; }
  fi

  echo
  echo "== 安装链接状态 =="
  for target in "${TARGETS[@]}"; do
    local missing="" extra="" ok=0
    for skill in $local_list; do
      if [ -L "$target/$skill" ]; then ok=$((ok+1)); else missing="$missing $skill"; fi
    done
    for link in "$target"/*; do
      name="$(basename "$link")"
      [ -L "$link" ] || continue
      case "$(readlink "$link")" in
        "$SKILLS_DIR"*) echo "$local_list" | grep -qx "$name" || extra="$extra $name" ;;
      esac
    done
    echo "  ${target}：${ok} 个正常"
    [ -n "${missing:-}" ] && echo "    缺链接：${missing}（跑 ./install.sh）"
    [ -n "${extra:-}" ] && echo "    多余链接（本地已删）：$extra"
    unset missing extra
  done
}

case "${1:-status}" in
  status) cmd_status ;;
  pull)   git -C "$REPO_DIR" pull --ff-only ;;
  *) echo "用法: ./sync.sh [status|pull]" >&2; exit 1 ;;
esac
