#!/bin/bash
set -euo pipefail

DIR="$HOME/gui_build/compressed"
VERSION="$(cat "$HOME/gui_build/data/version")"
TYPE="$(cat "$HOME/gui_build/data/type")"
case "$TYPE" in
    DEV) channel=dev; prerelease=true; latest=false; gui_asset=GUI_dev.tar.bz2 ;;
    PREVIEW) channel=preview; prerelease=true; latest=false; gui_asset=GUI_preview.tar.bz2 ;;
    STABLE) channel=stable; prerelease=false; latest=true; gui_asset=GUI.tar.bz2 ;;
    *) exit 0 ;;
esac
: "${GH_TOKEN:?GH_TOKEN is required to publish the release}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $VERSION" >&2; exit 1; }
cd "$DIR"
[[ -s "$gui_asset" ]] || { echo "Missing GUI archive: $gui_asset" >&2; exit 1; }
sha256sum --check SHA256SUMS
md5sum --check MD5SUMS
printf '%s\n' "$GITHUB_SHA" > SOURCE_COMMIT
printf '%s\n' "$channel" > CHANNEL
assets=( *.tar.bz2 SHA256SUMS MD5SUMS SOURCE_COMMIT CHANNEL )
# Authentication failures must not be interpreted as a missing release.
tags="$(gh api "repos/$GITHUB_REPOSITORY/releases" --paginate --jq '.[].tag_name')"
pointer="channel-$channel"
if printf '%s\n' "$tags" | grep -Fxq "$pointer"; then
    current="$(gh release download "$pointer" --repo "$GITHUB_REPOSITORY" --pattern latest.version --output -)"
    [[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
    greatest="$(printf '%s\n' "$VERSION" "$current" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)"
    [[ "$greatest" == "$VERSION" ]] || { echo "Refusing to downgrade $pointer from $current to $VERSION." >&2; exit 1; }
fi
if printf '%s\n' "$tags" | grep -Fxq "$VERSION"; then
    target="$(gh release view "$VERSION" --repo "$GITHUB_REPOSITORY" --json targetCommitish --jq .targetCommitish)"
    [[ "$target" == "$GITHUB_SHA" ]] || { echo "Version $VERSION already belongs to another commit." >&2; exit 1; }
    draft="$(gh release view "$VERSION" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft)"
    if [[ "$draft" == true ]]; then
        gh release upload "$VERSION" "${assets[@]}" --repo "$GITHUB_REPOSITORY" --clobber
    else
        # A retry may repair the channel pointer, but never replace published archives.
        recorded_commit="$(gh release download "$VERSION" --repo "$GITHUB_REPOSITORY" --pattern SOURCE_COMMIT --output -)"
        recorded_channel="$(gh release download "$VERSION" --repo "$GITHUB_REPOSITORY" --pattern CHANNEL --output -)"
        [[ "$recorded_commit" == "$GITHUB_SHA" && "$recorded_channel" == "$channel" ]] || exit 1
    fi
else
    gh release create "$VERSION" "${assets[@]}" --repo "$GITHUB_REPOSITORY" \
        --target "$GITHUB_SHA" --title "$VERSION" --notes "<!-- gui-build:$GITHUB_SHA:$channel -->" --draft --prerelease="$prerelease"
fi
gh release edit "$VERSION" --repo "$GITHUB_REPOSITORY" --draft=false --latest="$latest"

# Publish the pointer only after the complete versioned release is public.
printf '%s\n' "$VERSION" > latest.version
pointer="channel-$channel"
if printf '%s\n' "$tags" | grep -Fxq "$pointer"; then
    gh release upload "$pointer" latest.version --repo "$GITHUB_REPOSITORY" --clobber
else
    gh release create "$pointer" latest.version --repo "$GITHUB_REPOSITORY" \
        --target "$GITHUB_SHA" --title "GUI $channel update channel" \
        --notes "latest.version points to the complete versioned release for this channel." \
        --prerelease --latest=false
fi
