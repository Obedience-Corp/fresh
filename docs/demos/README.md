# Fresh terminal demos

These VHS recordings show real Camp running against a disposable `site` project.
The setup recording opens `camp fresh configure`, adds `npm ci` and `npm run build`
through its forms, and saves them for the detected project. The cleanup recording
previews the saved workflow, removes a merged branch, and runs both follow-ups.

The fixture contains a small Node site with no external dependencies. Its build
copies the source page into `dist/`. No output is mocked. The recording script
checks the saved workflow after the TUI closes, then checks the branch, remote
alignment, clean Git status, and built file after cleanup.

## Re-record

Requirements: Docker, VHS, its terminal/browser dependencies, FFmpeg, Python 3,
and Linux builds of `camp` and `fest`. Use binaries matching the container
architecture; the default is `linux/amd64` (`CAMP_DEMO_PLATFORM` overrides it).

From the repository root:

```bash
CAMP_BIN_DIR=/absolute/path/to/linux-binaries bash docs/demos/record.sh
```

Choose an isolated Docker daemon through `DOCKER_HOST` if your development setup
uses one. The script mounts the binaries and this repository read-only. All Camp,
Git, and npm operations run inside a fresh container; the script removes that
container on exit. VHS writes only the recordings and stills into this directory.
It does not install or replace the host's Festival tools, or publish the recordings.

- [configure.tape](configure.tape): project setup through the TUI.
- [cleanup.tape](cleanup.tape): preview, cleanup, and saved follow-ups.
- [setup-fixture.sh](setup-fixture.sh): the isolated project and merged branch.
- [record.sh](record.sh): capture, persisted-state checks, and still extraction.

The GIFs play inline on GitHub and start near the result so static previews show
the workflow or cleanup outcome. MP4s preserve the original sequence and provide
playback controls when opened in a video viewer; the stills show the final saved
workflow and cleanup result. VHS's
hidden sections enter the container and clear the terminal before recording the
user-facing commands. The cleanup clip clears the preview before showing the run.

## Captured version

Recorded with VHS 0.11.0 and a development build of Camp from
[Camp PR #746](https://github.com/Obedience-Corp/camp/pull/746) on 2026-10-13.
The project is already linked to a camp before recording starts. The videos do
not demonstrate a released automatic-linking flow or an agent installation.
