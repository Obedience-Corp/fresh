# Development

[Back to Fresh](../README.md)

```bash
bash tests/run.sh
claude plugin validate .
claude plugin test .
```

The default tests use stub binaries and temporary directories. The Claude commands
validate the plugin and native Mod render trees; they require Claude Code.

For an optional check against real Camp/Fest builds, place Linux binaries named
`camp` and `fest` in `/absolute/linux-binaries`, then run from this repo:

```bash
docker run --rm --mount type=bind,src="$PWD",dst=/fresh,readonly \
  --mount type=bind,src=/absolute/linux-binaries,dst=/binaries,readonly \
  alpine:3.21 sh -c 'apk add --no-cache bash git python3 && PATH=/binaries:$PATH bash /fresh/tests/camp.integration.sh'
```

The integration check refuses to run outside a fresh Docker container. It verifies
configuration readback, preview without follow-up execution, merged-branch cleanup,
command order, skip, failure, continue-on-error, and inheritance.

## Check first use from a released Festival build

This optional check downloads the latest Festival release through the skill's
actual installer. Run it in a fresh container with no Festival binaries mounted:

```bash
docker run --rm --mount type=bind,src="$PWD",dst=/fresh,readonly \
  node:24-bookworm bash -c 'apt-get update -qq && apt-get install -y -qq python3 curl git && bash /fresh/tests/release.integration.sh'
```

It verifies installation of `camp` and `fest`, preview without linking, automatic
linking during cleanup, merged-branch removal, clean Git state, and a repeated
installer check. It then runs the existing follow-up integration tests against
the downloaded release. The test refuses to run outside Docker. It passed on
Linux ARM64 with Festival v0.3.21 (Camp v0.15.0, Fest v0.9.5) on 2026-10-13.

## Check Codex integration

With Codex CLI installed (verified with 0.162.1), run:

```bash
python3 tests/codex.integration.py
```

This creates a temporary Codex profile, installs the working-tree plugin, checks
both skills through the real app-server discovery API, checks bundled resources,
then removes the plugin and verifies its skills disappear. It needs no login or
model turn and does not invoke Festival or cleanup. Your normal Codex plugin
configuration is untouched. It is optional because the default suite needs no
Codex installation.

To check the README's Git marketplace route against the same skill sources on main:

```bash
FRESH_MARKETPLACE_SOURCE=Obedience-Corp/fresh python3 tests/codex.integration.py
```

## Record the demos

See [the VHS tapes and fixture](demos/README.md). Recordings run real Camp in a
disposable container, then verify saved settings and the cleanup result.
