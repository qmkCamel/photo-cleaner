#!/usr/bin/env python3
"""Validate the repository's OpenSpec lifecycle invariants."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


REQUIRED_PROPOSAL_HEADINGS = (
    "## Why",
    "## What Changes",
    "## Capabilities",
    "## Impact",
)
ARCHIVE_TBD_MARKER = "TBD - created by archiving change"


def run_command(*args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    openspec_root = repo_root / "openspec"
    errors: list[str] = []

    if shutil.which("openspec") is None:
        print("ERROR: openspec CLI not found in PATH", file=sys.stderr)
        return 1

    validation = run_command(
        "openspec",
        "validate",
        "--all",
        "--strict",
        "--no-interactive",
        cwd=repo_root,
    )
    print(validation.stdout, end="")
    if validation.returncode != 0:
        errors.append("OpenSpec strict validation failed")

    listed = run_command("openspec", "list", "--json", cwd=repo_root)
    if listed.returncode != 0:
        print(listed.stdout, end="")
        errors.append("Unable to list active OpenSpec changes")
        active_changes: list[dict[str, object]] = []
    else:
        try:
            active_changes = json.loads(listed.stdout).get("changes", [])
        except (json.JSONDecodeError, AttributeError) as error:
            errors.append(f"Unable to parse active OpenSpec changes: {error}")
            active_changes = []

    for change in active_changes:
        name = str(change.get("name", ""))
        proposal_path = openspec_root / "changes" / name / "proposal.md"
        if not proposal_path.is_file():
            errors.append(f"Active change {name} is missing proposal.md")
            continue

        proposal = proposal_path.read_text(encoding="utf-8")
        missing_headings = [
            heading for heading in REQUIRED_PROPOSAL_HEADINGS if heading not in proposal
        ]
        if missing_headings:
            errors.append(
                f"Active change {name} is missing proposal headings: "
                + ", ".join(missing_headings)
            )

        shown = run_command(
            "openspec",
            "show",
            name,
            "--type",
            "change",
            "--json",
            "--no-interactive",
            cwd=repo_root,
        )
        if shown.returncode != 0:
            errors.append(f"Active change {name} cannot be parsed by openspec show")

        if change.get("status") == "complete":
            errors.append(
                f"Active change {name} has all tasks complete and must be archived"
            )

    for spec_path in sorted((openspec_root / "specs").glob("*/spec.md")):
        if ARCHIVE_TBD_MARKER in spec_path.read_text(encoding="utf-8"):
            errors.append(
                f"Accepted spec {spec_path.relative_to(repo_root)} still has an archive TBD Purpose"
            )

    if errors:
        print("\nOpenSpec lifecycle check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("OpenSpec lifecycle check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
