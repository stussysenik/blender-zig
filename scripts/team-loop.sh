#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$SCRIPT_DIR/..")"
TASK_FILE="${TASK_FILE:-tasks/zig-rewrite.md}"
PHASE="${PHASE:-}"
TEAM_ROLES="${TEAM_ROLES:-architect,executor,verifier,release-manager}"
AGENT_CMD="${AGENT_CMD:-codex exec --full-auto}"
SESSION="${TEAM_SESSION:-blender-zig}"
USE_TMUX=1
DRY_RUN=0
LIST_PHASES=0

usage() {
  cat <<'EOF'
Usage: scripts/team-loop.sh [--task-file PATH] [--phase N] [--roles role,role] [--list-phases] [--no-tmux] [--dry-run]
EOF
}

list_phases() {
  awk '
    /^## Phase [0-9]+: / {
      sub(/^## /, "");
      print;
    }
  ' "$ROOT/$TASK_FILE"
}

phase_title() {
  local phase="$1"
  awk -v phase="$phase" '
    $0 ~ "^## Phase " phase ": " {
      sub(/^## Phase [0-9]+: /, "");
      print;
      exit 0;
    }
  ' "$ROOT/$TASK_FILE"
}

phase_label() {
  local phase="$1"
  local title
  title="$(phase_title "$phase")"
  if [[ -n "$title" ]]; then
    printf '%s: %s' "$phase" "$title"
  else
    printf '%s' "$phase"
  fi
}

phase_exists() {
  local phase="$1"
  awk -v phase="$phase" '
    $0 ~ "^## Phase " phase ": " {
      found = 1;
      exit 0;
    }
    END {
      exit(found ? 0 : 1);
    }
  ' "$ROOT/$TASK_FILE"
}

collect_tasks() {
  if [[ -z "$PHASE" ]]; then
    awk '
      /^- \[ \] / {
        sub(/^- \[ \] /, "");
        print;
      }
    ' "$ROOT/$TASK_FILE"
    return 0
  fi

  awk -v phase="$PHASE" '
    BEGIN { in_phase = 0 }
    /^## Phase [0-9]+: / {
      in_phase = ($0 ~ "^## Phase " phase ": ");
      next;
    }
    in_phase && /^- \[ \] / {
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

preview_plan() {
  local workdir="$1"
  printf 'Task file: %s\n' "$TASK_FILE"
  printf 'Roles: %s\n' "$TEAM_ROLES"
  printf 'Workdir: %s\n' "$workdir"
  printf 'Tasks selected: %s\n' "${#TASKS[@]}"
  printf 'Roles available: %s\n' "${#ROLES[@]}"
  if command -v tmux >/dev/null 2>&1 && [[ "$USE_TMUX" -eq 1 ]]; then
    printf 'Execution: tmux-backed team session\n'
  else
    printf 'Execution: background shell fan-out\n'
  fi
  if [[ -n "$PHASE" ]]; then
    printf 'Phase: %s\n' "$(phase_label "$PHASE")"
  else
    printf 'Phase: all pending tasks\n'
  fi
  printf 'Assignments:\n'
  for i in "${!ROLES[@]}"; do
    local task="${TASKS[$i]:-}"
    [[ -z "$task" ]] && break
    printf '  %s -> %s\n' "${ROLES[$i]}" "$task"
  done
  if [[ "${#TASKS[@]}" -gt "${#ROLES[@]}" ]]; then
    printf '  ... %s more task(s) queued beyond the current role set\n' "$(( ${#TASKS[@]} - ${#ROLES[@]} ))"
  fi
}

build_role_command() {
  local role="$1"
  local task="$2"
  printf 'cd %s && ROLE=%s TASK_FILE=%s AGENT_CMD=%s bash %s --task %s --role %s --once' \
    "$(safe_shell_word "$ROOT")" \
    "$(safe_shell_word "$role")" \
    "$(safe_shell_word "$TASK_FILE")" \
    "$(safe_shell_word "$AGENT_CMD")" \
    "$(safe_shell_word "$ROOT/scripts/ralph-loop.sh")" \
    "$(safe_shell_word "$task")" \
    "$(safe_shell_word "$role")"
  if [[ -n "$PHASE" ]]; then
    printf ' --phase %s' "$(safe_shell_word "$PHASE")"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-file)
      TASK_FILE="$2"
      shift 2
      ;;
    --phase)
      PHASE="$2"
      shift 2
      ;;
    --roles)
      TEAM_ROLES="$2"
      shift 2
      ;;
    --list-phases)
      LIST_PHASES=1
      shift
      ;;
    --no-tmux)
      USE_TMUX=0
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

if [[ "$LIST_PHASES" -eq 1 ]]; then
  list_phases
  exit 0
fi

if [[ -n "$PHASE" ]] && ! phase_exists "$PHASE"; then
  printf 'Phase %s not found in %s\n' "$PHASE" "$TASK_FILE" >&2
  exit 1
fi

roles_as_array
TASKS=()
while IFS= read -r task; do
  TASKS+=("$task")
done < <(collect_tasks)
if [[ "${#TASKS[@]}" -eq 0 ]]; then
  if [[ -n "$PHASE" ]]; then
    printf 'No pending tasks in phase %s (%s)\n' "$PHASE" "$(phase_title "$PHASE")"
  else
    printf 'No pending tasks in %s\n' "$TASK_FILE"
  fi
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  preview_plan "$ROOT"
  for i in "${!ROLES[@]}"; do
    [[ -z "${TASKS[$i]:-}" ]] && break
    printf '  command[%s]: %s\n' "${ROLES[$i]}" "$(build_role_command "${ROLES[$i]}" "${TASKS[$i]}")"
  done
  exit 0
fi

if command -v tmux >/dev/null 2>&1 && [[ "$USE_TMUX" -eq 1 ]]; then
  tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"
  first_cmd="$(build_role_command "${ROLES[0]}" "${TASKS[0]}")"
  tmux new-session -d -s "$SESSION" -n team "$first_cmd"
  for i in "${!ROLES[@]}"; do
    [[ "$i" -eq 0 ]] && continue
    [[ -z "${TASKS[$i]:-}" ]] && break
    pane_cmd="$(build_role_command "${ROLES[$i]}" "${TASKS[$i]}")"
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
