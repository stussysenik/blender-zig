#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/blender-zig-clean-room.XXXXXX")"
WORKTREE_DIR="$SCRATCH_DIR/repo"
PATCH_PATH="$SCRATCH_DIR/current-tree.patch"

cleanup() {
  if [[ -d "$WORKTREE_DIR" ]]; then
    git -C "$ROOT_DIR" worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

git -C "$ROOT_DIR" rev-parse --verify HEAD >/dev/null 2>&1
git -C "$ROOT_DIR" worktree add --detach "$WORKTREE_DIR" HEAD >/dev/null

git -C "$ROOT_DIR" diff --binary HEAD >"$PATCH_PATH"
if [[ -s "$PATCH_PATH" ]]; then
  git -C "$WORKTREE_DIR" apply "$PATCH_PATH"
fi

while IFS= read -r -d '' relative_path; do
  mkdir -p "$WORKTREE_DIR/$(dirname "$relative_path")"
  cp -p "$ROOT_DIR/$relative_path" "$WORKTREE_DIR/$relative_path"
done < <(git -C "$ROOT_DIR" ls-files --others --exclude-standard -z)

(
  cd "$WORKTREE_DIR"
  BLENDER_ZIG_SKIP_CLEAN_ROOM=1 bash scripts/verify-phase-17.sh
)
