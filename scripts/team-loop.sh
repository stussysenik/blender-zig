#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASK_FILE="${TASK_FILE:-tasks/zig-rewrite.md}"
TEAM_ROLES="${TEAM_ROLES:-architect,executor,verifier,release-manager}"
AGENT_CMD="${AGENT_CMD:-codex exec --full-auto}"
SESSION="${TEAM_SESSION:-blender-zig}"
USE_TMUX=1

usage() {
  cat <<'EOF'
Usage: scripts/team-loop.sh [--task-file PATH] [--roles role,role] [--no-tmux]
EOF
}

next_tasks() {
  awk '
    /^- \[ \] / {
      sub(/^- \[ \] /, "");
      print;
    }
  ' "$ROOT/$TASK_FILE"
}

roles_as_array() {
  IFS=, read -r -a ROLES <<<"$TEAM_ROLES"
}

safe_shell_word() {
  printf '%q' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-file)
      TASK_FILE="$2"
      shift 2
      ;;
    --roles)
      TEAM_ROLES="$2"
      shift 2
      ;;
    --no-tmux)
      USE_TMUX=0
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

roles_as_array
mapfile -t TASKS < <(next_tasks)
if [[ "${#TASKS[@]}" -eq 0 ]]; then
  printf 'No pending tasks in %s\n' "$TASK_FILE"
  exit 0
fi

if command -v tmux >/dev/null 2>&1 && [[ "$USE_TMUX" -eq 1 ]]; then
  tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"
  first_cmd="cd $(safe_shell_word "$ROOT") && ROLE=$(safe_shell_word "${ROLES[0]}") TASK_FILE=$(safe_shell_word "$TASK_FILE") AGENT_CMD=$(safe_shell_word "$AGENT_CMD") bash $(safe_shell_word "$ROOT/scripts/ralph-loop.sh") --task $(safe_shell_word "${TASKS[0]}") --role $(safe_shell_word "${ROLES[0]}") --once"
  tmux new-session -d -s "$SESSION" -n team "$first_cmd"
  for i in "${!ROLES[@]}"; do
    [[ "$i" -eq 0 ]] && continue
    [[ -z "${TASKS[$i]:-}" ]] && break
    pane_cmd="cd $(safe_shell_word "$ROOT") && ROLE=$(safe_shell_word "${ROLES[$i]}") TASK_FILE=$(safe_shell_word "$TASK_FILE") AGENT_CMD=$(safe_shell_word "$AGENT_CMD") bash $(safe_shell_word "$ROOT/scripts/ralph-loop.sh") --task $(safe_shell_word "${TASKS[$i]}") --role $(safe_shell_word "${ROLES[$i]}") --once"
    tmux split-window -t "$SESSION:team" -h "$pane_cmd"
  done
  tmux select-layout -t "$SESSION:team" tiled
  tmux attach -t "$SESSION"
  exit 0
fi

for i in "${!ROLES[@]}"; do
  [[ -z "${TASKS[$i]:-}" ]] && break
  ROLE="${ROLES[$i]}" TASK_FILE="$TASK_FILE" AGENT_CMD="$AGENT_CMD" bash "$ROOT/scripts/ralph-loop.sh" --task "${TASKS[$i]}" --role "${ROLES[$i]}" --once &
done
wait
