#!/bin/bash
set -euo pipefail

branch_name="${GITHUB_BASE_REF:-${GITHUB_REF_NAME:-$(git branch --show-current)}}"
mkdir -p "$HOME/gui_build/data"
echo "Detected $branch_name build"
case "$branch_name" in
  stable) type=STABLE ;;
  preview) type=PREVIEW ;;
  master) type=DEV ;;
  *) type="$branch_name" ;;
esac
printf '%s\n' "$type" > "$HOME/gui_build/data/type"
git rev-parse --short HEAD > "$HOME/gui_build/data/short_commit_hash"
git log --oneline -n 1 > "$HOME/gui_build/data/last_log"
