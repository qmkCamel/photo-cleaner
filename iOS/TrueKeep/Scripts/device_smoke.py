#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
PROJECT = "iOS/TrueKeep/TrueKeep.xcodeproj"
SCHEME = "TrueKeep"
BUNDLE_ID = "app.truekeep.ios"
APP_NAME = "TrueKeep.app"
DEFAULT_DERIVED_DATA = "/tmp/TrueKeepDeviceSmokeBuild"


def build_command(team_id: str, device_id: str, derived_data: str = DEFAULT_DERIVED_DATA) -> list[str]:
    return [
        "xcodebuild",
        "build",
        "-project",
        PROJECT,
        "-scheme",
        SCHEME,
        "-configuration",
        "Debug",
        "-destination",
        f"platform=iOS,id={device_id}",
        "-derivedDataPath",
        derived_data,
        "-allowProvisioningUpdates",
        f"DEVELOPMENT_TEAM={team_id}",
        "CODE_SIGN_STYLE=Automatic",
        "CODE_SIGN_IDENTITY=Apple Development",
    ]


def built_app_path(derived_data: str = DEFAULT_DERIVED_DATA) -> str:
    return str(Path(derived_data) / "Build" / "Products" / "Debug-iphoneos" / APP_NAME)


def install_command(device_id: str, derived_data: str = DEFAULT_DERIVED_DATA) -> list[str]:
    return [
        "xcrun",
        "devicectl",
        "device",
        "install",
        "app",
        "--device",
        device_id,
        built_app_path(derived_data),
    ]


def launch_command(device_id: str) -> list[str]:
    return [
        "xcrun",
        "devicectl",
        "device",
        "process",
        "launch",
        "--device",
        device_id,
        "--terminate-existing",
        "--environment-variables",
        json.dumps({"TRUEKEEP_DISABLE_PHOTO_DELETION": "1"}),
        BUNDLE_ID,
        "-TrueKeepDisablePhotoDeletion",
    ]


def list_devices_command() -> list[str]:
    return ["xcrun", "devicectl", "list", "devices"]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build, install, and launch TrueKeep on a physical iPhone with deletion disabled.",
    )
    parser.add_argument("--team-id", required=True, help="Confirmed Apple Developer Team ID.")
    parser.add_argument("--device-id", required=True, help="Physical iPhone device identifier from devicectl.")
    parser.add_argument("--derived-data", default=DEFAULT_DERIVED_DATA, help="DerivedData output path.")
    parser.add_argument("--skip-launch", action="store_true", help="Build and install only; do not launch the app.")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually run build/install/launch commands. Omit for dry-run command preview.",
    )
    args = parser.parse_args(argv)
    args.dry_run = not args.execute
    return args


def run_command(command: list[str]) -> None:
    print("+ " + shell_join(command), flush=True)
    subprocess.run(command, cwd=REPO_ROOT, check=True)


def shell_join(command: list[str]) -> str:
    return " ".join(quote(part) for part in command)


def quote(value: str) -> str:
    if not value:
        return "''"
    safe = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=,")
    if all(char in safe for char in value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    commands = [
        list_devices_command(),
        build_command(args.team_id, args.device_id, args.derived_data),
        install_command(args.device_id, args.derived_data),
    ]
    if not args.skip_launch:
        commands.append(launch_command(args.device_id))

    if args.dry_run:
        print("Dry run only. No build, install, or launch command was executed.")
        print("Re-run with --execute after the iPhone is available and Xcode signing is fixed.")
        for command in commands:
            print("+ " + shell_join(command))
        return 0

    for command in commands:
        run_command(command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
