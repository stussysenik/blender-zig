#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK_FILE="${TASK_FILE:-tasks/zig-rewrite.md}"
ROLE="${ROLE:-executor}"
AGENT_CMD="${AGENT_CMD:-codex exec --full-auto}"
AUTO_COMPLETE="${AUTO_COMPLETE:-1}"
USE_WORKTREE="${USE_WORKTREE:-1}"
WORKTREE_BASE="${WORKTREE_BASE:-.worktrees}"
TASK_OVERRIDE=""
ONCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/ralph-loop.sh [--task-file PATH] [--task TEXT] [--role ROLE] [--once] [--dry-run]
EOF
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//'
}

next_task() {
  awk '
    /^- \[ \] / {
      sub(/^- \[ \] /, "");
      print;
      exit 0;
    }
  ' "$ROOT/$TASK_FILE"
}

mark_task_complete() {
  local task="$1"
  local file="$ROOT/$TASK_FILE"
  local tmp
  tmp="$(mktemp)"
  awk -v task="$task" '
    BEGIN { done = 0 }
    {
      if (!done && $0 ~ /^- \[ \] / && substr($0, 7) == task) {
        sub(/^- \[ \]/, "- [x]");
        done = 1;
      }
      print;
    }
    END { if (!done) exit 1 }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

load_role_prompt() {
  local codex_role_file="$ROOT/.codex/prompts/$ROLE.md"
  local legacy_role_file="$ROOT/roles/$ROLE.md"

  if [[ -f "$codex_role_file" ]]; then
    cat "$codex_role_file"
    return 0
  fi

  if [[ -f "$legacy_role_file" ]]; then
    cat "$legacy_role_file"
    return 0
  fi

  printf 'Role file missing: %s or %s\n' "$codex_role_file" "$legacy_role_file" >&2
  exit 1
}

build_prompt() {
  local task="$1"
  {
    load_role_prompt
    printf '\n## Task\n%s\n' "$task"
    printf '\n## Repo\n%s\n' "$ROOT"
    printf '\n## Instructions\n'
    printf 'Focus only on the task. Keep the patch small and mention verification clearly.\n'
  }
}

create_worktree() {
  local task="$1"
  if ! git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  local branch="zig-rewrite/$(slugify "$ROLE-$task")"
  local dir="$ROOT/$WORKTREE_BASE/$(slugify "$ROLE-$task")"
  mkdir -p "$ROOT/$WORKTREE_BASE"
  if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
    git worktree add -b "$branch" "$dir" HEAD >/dev/null
  fi
  printf '%s\n' "$dir"
}

run_agent() {
  local task="$1"
  local workdir="$2"
  local prompt
  prompt="$(build_prompt "$task")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s\n' "$prompt"
    return 0
  fi
  # shellcheck disable=SC2206
  local cmd=($AGENT_CMD)
  printf '%s\n' "$prompt" | "${cmd[@]}" -C "$workdir" -
}

task_loop() {
  local task="$1"
  local workdir="$ROOT"
  if [[ "$USE_WORKTREE" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    workdir="$(create_worktree "$task")"
  fi
  run_agent "$task" "$workdir"
  if [[ "$AUTO_COMPLETE" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    mark_task_complete "$task"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-file)
      TASK_FILE="$2"
      shift 2
      ;;
    --task)
      TASK_OVERRIDE="$2"
      shift 2
      ;;
    --role)
      ROLE="$2"
      shift 2
      ;;
    --once)
      ONCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown arg: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$TASK_OVERRIDE" ]]; then
  task_loop "$TASK_OVERRIDE"
  exit 0
fi

while :; do
  task="$(next_task || true)"
  if [[ -z "${task:-}" ]]; then
    printf 'No pending tasks in %s\n' "$TASK_FILE"
    exit 0
  fi
  task_loop "$task"
  [[ "$ONCE" -eq 1 ]] && exit 0
done
