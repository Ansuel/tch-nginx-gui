#!/bin/bash
set -euo pipefail

last_log="$(cat last_log)"
if [[ "$last_log" =~ \[([0-9]+\.[0-9]+\.[0-9]+)\] ]]; then
    ver="${BASH_REMATCH[1]}"
    echo "Detected manual version: $ver"
else
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
    # Reuse a draft/published release from this exact commit and channel on reruns.
    channel="$(tr '[:upper:]' '[:lower:]' < ./type)"
    marker="<!-- gui-build:${GITHUB_SHA:?}:$channel -->"
    matched="$(gh api "repos/$GITHUB_REPOSITORY/releases" --paginate \
        --jq ".[] | select(.target_commitish == \"$GITHUB_SHA\") | select((.body // \"\") | contains(\"$marker\")) | .tag_name")"
    if [[ -n "$matched" ]]; then
        [[ "$matched" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Ambiguous release version for this commit." >&2; exit 1; }
        printf '%s\n' "$matched" > "$HOME/gui_build/data/version"
        echo "Reusing release version $matched"
        exit 0
    fi
    # Draft versions are reserved too, so a failed publication is not overwritten.
    versions="$(gh api "repos/$GITHUB_REPOSITORY/releases" --paginate --jq '.[].tag_name')"
    cur_ver="$(printf '%s\n' "$versions" | awk '/^[0-9]+\.[0-9]+\.[0-9]+$/' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
    if [[ -z "$cur_ver" ]]; then
        if [[ "${GITHUB_EVENT_NAME:-}" == pull_request ]]; then
            printf '%s\n' '0.0.0' > "$HOME/gui_build/data/version"
            echo "Using non-publishing PR version 0.0.0"
            exit 0
        fi
        echo "No numeric release found. Set the initial version with [x.y.z] in the commit message." >&2
        exit 1
    fi
    if [[ ! "$cur_ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)[[:space:]]*$ ]]; then
        echo "Invalid release version: $cur_ver" >&2
        exit 1
    fi
    major=$((10#${BASH_REMATCH[1]}))
    minor=$((10#${BASH_REMATCH[2]}))
    dev_num=$((10#${BASH_REMATCH[3]} + 1))
    if (( dev_num > 99 )); then
        dev_num=0
        minor=$((minor + 1))
        if (( minor > 99 )); then
            minor=0
            major=$((major + 1))
        fi
    fi
    ver="$major.$minor.$dev_num"
    echo "Incrementing $cur_ver to $ver"
fi
mkdir -p "$HOME/gui_build/data"
printf '%s\n' "$ver" > "$HOME/gui_build/data/version"
