#!/bin/bash
set -euo pipefail

cd "$HOME/gui_build"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -- 'decompressed/gui_file/www/lang/*.po'
if git diff --cached --quiet; then
    echo "No translation changes to commit."
    exit 0
fi
# Discard packaging/minification changes before rebasing the translation commit.
git commit -m "BuildBot: translation: update po file automatically" -m "[skip ci]"
git restore --worktree .
git fetch origin "${GITHUB_REF_NAME:?}"
git rebase FETCH_HEAD
git push origin "HEAD:refs/heads/$GITHUB_REF_NAME"
