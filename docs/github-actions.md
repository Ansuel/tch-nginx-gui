# Builds and releases

## Workflow

[Build and release GUI](https://github.com/Ansuel/tch-nginx-gui/actions/workflows/build.yml)
builds the GUI, verifies the archives and publishes updates through GitHub Releases.
It uses the automatic GitHub Actions token; no additional secrets are required.
Repository rules must allow the publishing job to create releases and commit translation updates.

| Branch | Channel | Publication |
| --- | --- | --- |
| `master` | DEV | Prerelease |
| `preview` | PREVIEW | Prerelease |
| `stable` | STABLE | Latest stable release |

Pushes to these branches publish automatically in `Ansuel/tch-nginx-gui`.
Pull requests only build and test, with read-only permissions.
For a manual build, select **Run workflow**; enable `publish` only to publish its output.
Build artifacts are available from the workflow run even without publication.

## Version numbers

Include `[x.y.z]` in the commit message to choose a version, for example:

```
[9.8.0] Migrate build and updates to GitHub Actions
```

Otherwise the workflow increments the greatest numeric release tag across all channels.
A retry reuses an existing draft or release for the same commit and channel.
Published archives are not overwritten, and a channel cannot move backwards.
Each version belongs to one commit and channel; use a new version for another channel.

Translation commits are created automatically with `[skip ci]`.
Pull the remote changes before preparing subsequent commits.

## Update downloads

Each numeric release contains the GUI archive, device-specific modules and checksums.
The GUI archive is named `GUI_dev.tar.bz2`, `GUI_preview.tar.bz2` or `GUI.tar.bz2`.

The releases `channel-dev`, `channel-preview` and `channel-stable` each provide a
`latest.version` file pointing to the current numeric release for that channel.
A channel is created on its first publication. Its pointer is updated after all
versioned assets are uploaded.

Routers use the existing `curl -k` and MD5 tools. Optional modules are downloaded
from the installed GUI's version. Keep older release assets available for this reason.
SHA-256 checksums are also published for verification on a computer.

DEV/PREVIEW updates continue with their verified archive if `channel-stable` has
not been published (HTTP 404). When stable exists, the updater keeps the version
comparison and recovery behavior. Network errors, invalid version metadata, missing
stable assets and checksum errors still stop installation. Updates on the STABLE
channel itself require a published stable release, as does the README's stable link.

## Existing installations

Older GUIs still use the previous update source. Install a release with the new
updater manually through the GUI's archive-upload function, or provide a final
transition build through the previous update source.

## Validation

Run the offline tests with:

```sh
python3 -m unittest discover -s tests -v
```

CI also checks archive contents, permissions, ownership, symlinks, embedded modules
and the stamped version. The build images are pinned by digest in the workflow.
A successful build does not replace testing installation and recovery on a modem.
