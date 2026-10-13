#!/usr/bin/env python3
"""Run camp fresh once, retaining its transcript and an in-app visual report."""
import argparse
import datetime
import html
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile

SCHEMA = "fresh-output/v1"
MAX_VIEW = 48000
# Strip terminal escape sequences from display text; the original bytes are retained.
ESCAPE = re.compile(r"\x1b(?:\][^\x07\x1b]*(?:\x07|\x1b\\)|\[[0-?]*[ -/]*[@-~]|[@-_])")


def display_text(text):
    text = ESCAPE.sub("", text).replace("\r\n", "\n").replace("\r", "\n")
    return "".join(c for c in text if c in "\n\t" or (ord(c) >= 32 and ord(c) != 127))


def line_color(line):
    trimmed = line.lstrip()
    if trimmed.startswith(("✗", "✘", "Error:")):
        return "#ff8b8b"
    if trimmed.startswith("✓"):
        return "#9ed99a"
    if trimmed.startswith(("⚠", "!", "Warning:")):
        return "#f6cf83"
    if "━━" in line:
        return "#c5a9ff"
    return "#e1e4ec"


def render(report):
    """An inert fragment works both in an inline visual and the HTML previewer."""
    esc = html.escape
    status = ("Preview failed" if report["preview"] else "Run failed") if report["exitCode"] else (
        "Preview" if report["preview"] else "Completed")
    tone = "#ff8b8b" if report["exitCode"] else ("#f6cf83" if report["preview"] else "#9ed99a")
    rows = "\n".join('<span style="color:' + line_color(line) + '">' + esc(line) + '</span>'
                     for line in report["output"].split("\n"))
    return f'''<meta charset="utf-8">
<section id="{esc(Path(report['htmlPath']).parent.name)}" aria-label="camp fresh output" style="background:#15171d;color:#e1e4ec;border:1px solid #343945;border-radius:12px;max-width:100%;overflow:hidden;font:14px/1.55 ui-monospace,SFMono-Regular,Consolas,monospace">
<header style="padding:16px 20px;border-bottom:1px solid #343945;display:flex;gap:16px;align-items:baseline;flex-wrap:wrap"><strong style="font-size:18px">camp fresh</strong><span style="color:{tone}">{status} · exit {report['exitCode']}</span></header>
<div style="padding:12px 20px;color:#afb7ca;overflow-wrap:anywhere">{esc(report['cwd'])}<br>{esc(report['startedAt'])}</div>
<pre aria-label="Command transcript" style="margin:0;padding:4px 20px 20px;overflow:auto;tab-size:4;white-space:pre;font:inherit">{rows}</pre>
<footer style="padding:10px 20px;border-top:1px solid #343945;color:#afb7ca">Captured command output. {'Preview only.' if report['preview'] else 'See the transcript for kept work and warnings.'}</footer>
</section>
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--camp", required=True, help="camp path printed by ensure-festival.sh")
    parser.add_argument("--output-dir", help="parent for a private, unique report directory (default: system temp)")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="after --, flags passed to camp fresh unchanged")
    args = parser.parse_args()
    flags = args.args[1:] if args.args[:1] == ["--"] else args.args
    command = [args.camp, "fresh", *flags]
    preview = False
    for flag in flags:
        if flag == "--":
            break
        if flag in ("--dry-run", "-n"):
            preview = True
        elif flag.startswith(("--dry-run=", "-n=")):
            preview = flag.split("=", 1)[1].lower() in ("true", "1", "t")
    # Allocate all required output storage before starting a potentially mutating run.
    try:
        directory = Path(tempfile.mkdtemp(prefix="fresh-output-", dir=args.output_dir)).resolve()
        raw = (directory / "transcript.txt").open("wb")
    except OSError as error:
        print(f"Cannot create Fresh report; camp was not run: {error}", file=sys.stderr)
        return 2
    report = {"schema": SCHEMA, "cwd": os.getcwd(), "command": command, "preview": preview,
              "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "transcriptPath": str(directory / "transcript.txt"),
              "htmlPath": str(directory / "output.html")}
    child = None
    interrupted = None

    def forward(signum, _frame):
        nonlocal interrupted
        interrupted = signum
        if child is not None:
            try:
                os.killpg(child.pid, signum)
            except ProcessLookupError:
                pass

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, forward)
    try:
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, start_new_session=True)
        for chunk in iter(lambda: child.stdout.read1(8192), b""):
            raw.write(chunk)
            raw.flush()
            # Keep the tool's ordinary progress/transcript visible while it runs.
            try:
                sys.stderr.buffer.write(chunk)
                sys.stderr.buffer.flush()
            except BrokenPipeError:
                pass
        code = child.wait()
        code = 128 - code if code < 0 else code
    except OSError as error:
        if child is not None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
            code = 1
        else:
            code = 127
        message = "\nFresh capture error: " + str(error) + "\n"
        print(message, file=sys.stderr)
        try:
            raw.write(message.encode())
        except OSError:
            pass
    finally:
        try:
            raw.close()
        except OSError:
            pass
    if interrupted:
        code = 128 + interrupted
    report["exitCode"] = code
    try:
        with (directory / "transcript.txt").open("rb") as stream:
            head = stream.read(MAX_VIEW + 1)
            if len(head) > MAX_VIEW:
                stream.seek(-MAX_VIEW // 2, os.SEEK_END)
                data = head[:MAX_VIEW // 2] + b"\n\n[Display shortened; complete output is in transcript.txt]\n\n" + stream.read()
                report["truncated"] = True
            else:
                data = head
                report["truncated"] = False
        report["output"] = display_text(data.decode("utf-8", errors="replace"))
        (directory / "output.html").write_text(render(report), encoding="utf-8")
        (directory / "report.json").write_text(json.dumps(report, ensure_ascii=False), encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False))
    except OSError as error:
        # Rendering failure must never conceal Camp's exit code or trigger a rerun.
        print(f"Fresh ran (exit {code}), but its visual report could not be saved: {error}. Transcript: {directory / 'transcript.txt'}", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
