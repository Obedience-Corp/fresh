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
