#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


REPO_ROOT = Path(__file__).resolve().parents[3]
APPCLAW_ROOT = REPO_ROOT / "iOS/TrueKeep/AppClaw"
CASES_FILE = APPCLAW_ROOT / "cases.json"
BUNDLE_ID = "app.truekeep.ios"
DELETION_DISABLED_ARGUMENT = "-TrueKeepDisablePhotoDeletion"
DEFAULT_WAIT_TIMEOUT_MS = "12000"


@dataclass(frozen=True)
class RegressionCase:
    id: str
    tier: str
    description: str
    flow: Path
    launch_arguments: tuple[str, ...]


def load_cases(path: Path = CASES_FILE) -> list[RegressionCase]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schemaVersion") != 1:
        raise ValueError(f"Unsupported AppClaw case schema in {path}")

    cases: list[RegressionCase] = []
    seen: set[str] = set()
    for raw in payload.get("cases", []):
        case_id = str(raw["id"])
        if case_id in seen:
            raise ValueError(f"Duplicate AppClaw case id: {case_id}")
        seen.add(case_id)
        launch_arguments = tuple(str(value) for value in raw["launchArguments"])
        if DELETION_DISABLED_ARGUMENT not in launch_arguments:
            raise ValueError(f"{case_id} must enable the photo deletion safety lock")
        flow = APPCLAW_ROOT / str(raw["flow"])
        if not flow.is_file():
            raise ValueError(f"Missing flow for {case_id}: {flow}")
        cases.append(
            RegressionCase(
                id=case_id,
                tier=str(raw["tier"]),
                description=str(raw["description"]),
                flow=flow,
                launch_arguments=launch_arguments,
            )
        )

    if not cases:
        raise ValueError(f"No AppClaw cases found in {path}")
    return cases


def select_cases(cases: list[RegressionCase], selected_ids: list[str] | None) -> list[RegressionCase]:
    if not selected_ids:
        return cases
    by_id = {case.id: case for case in cases}
    unknown = [case_id for case_id in selected_ids if case_id not in by_id]
    if unknown:
        raise ValueError(f"Unknown AppClaw case(s): {', '.join(unknown)}")
    return [by_id[case_id] for case_id in selected_ids]


def build_capabilities(
    case: RegressionCase,
    wda_url: str | None = None,
    udid: str | None = None,
) -> dict[str, Any]:
    ios: dict[str, Any] = {
        "appium:automationName": "XCUITest",
        "appium:bundleId": BUNDLE_ID,
        "appium:processArguments": {
            "args": list(case.launch_arguments),
            "env": {
                "TRUEKEEP_DISABLE_PHOTO_DELETION": "1",
                "TRUEKEEP_USE_SAMPLE_CLEANUP_DATA": "1",
            },
        },
        "appium:forceAppLaunch": True,
        "appium:shouldTerminateApp": True,
        "appium:shouldUseSingletonTestManager": False,
        "appium:wdaLaunchTimeout": 120000,
        "appium:wdaConnectionTimeout": 120000,
        "appium:noReset": True,
    }
    if udid:
        ios["appium:udid"] = udid
    if wda_url:
        ios["appium:webDriverAgentUrl"] = wda_url.rstrip("/")
    return {"ios": ios}


def appclaw_environment() -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(
        {
            "APPCLAW_TUI": "off",
            "AGENT_MODE": "dom",
            "VISION_MODE": "never",
            "LLM_PROVIDER": "ollama",
            "LLM_API_KEY": "",
            "GEMINI_API_KEY": "",
            "STARK_VISION_API_KEY": "",
            "STARK_VISION_BASE_URL": "",
            "STEP_DELAY": environment.get("STEP_DELAY", "400"),
            "WAIT_TIMEOUT": environment.get("WAIT_TIMEOUT", DEFAULT_WAIT_TIMEOUT_MS),
        }
    )
    return environment


def appclaw_command(
    executable: str,
    case: RegressionCase,
    capabilities_path: Path,
    device_type: str,
    udid: str,
) -> list[str]:
    return [
        executable,
        "--json",
        "--strict",
        "--platform",
        "ios",
        "--device-type",
        device_type,
        "--udid",
        udid,
        "--caps",
        str(capabilities_path),
        "--flow",
        str(case.flow),
    ]


def install_latest_command(team_id: str, udid: str) -> list[str]:
    return [
        sys.executable,
        str(REPO_ROOT / "iOS/TrueKeep/Scripts/device_smoke.py"),
        "--team-id",
        team_id,
        "--device-id",
        udid,
        "--skip-launch",
        "--execute",
    ]


def launch_wda_command(udid: str, bundle_id: str, device_port: int) -> list[str]:
    environment = {
        "USE_PORT": str(device_port),
        "WDA_PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
        "MJPEG_SERVER_PORT": str(device_port + 1000),
    }
    return [
        "xcrun",
        "devicectl",
        "device",
        "process",
        "launch",
        "--device",
        udid,
        "--terminate-existing",
        "--environment-variables",
        json.dumps(environment, separators=(",", ":")),
        bundle_id,
    ]


def iproxy_command(udid: str, local_port: int, device_port: int) -> list[str]:
    return ["iproxy", "--udid", udid, f"{local_port}:{device_port}"]


def wait_for_wda(wda_url: str, timeout_seconds: float = 30) -> None:
    status_url = wda_url.rstrip("/") + "/status"
    deadline = time.monotonic() + timeout_seconds
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(status_url, timeout=2) as response:
                payload = json.load(response)
            ready = payload.get("ready") is True or payload.get("value", {}).get("ready") is True
            if ready:
                return
            last_error = RuntimeError(f"WDA status is not ready: {payload}")
        except (OSError, urllib.error.URLError, ValueError) as error:
            last_error = error
        time.sleep(0.5)
    raise RuntimeError(f"WDA did not become ready at {status_url}: {last_error}")


def parse_local_wda_port(wda_url: str) -> int:
    parsed = urlparse(wda_url)
    if parsed.hostname not in {"127.0.0.1", "localhost"}:
        raise ValueError("Managed WDA requires a localhost --wda-url")
    if parsed.port is None:
        raise ValueError("Managed WDA requires an explicit port in --wda-url")
    return parsed.port


def shell_join(command: list[str]) -> str:
    return " ".join(quote(part) for part in command)


def quote(value: str) -> str:
    if not value:
        return "''"
    safe = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=,@")
    if all(char in safe for char in value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run deterministic TrueKeep AppClaw P0 regression cases with real deletion disabled.",
    )
    parser.add_argument("--udid", default=os.environ.get("DEVICE_UDID"), help="Target iPhone or simulator UDID.")
    parser.add_argument(
        "--device-type",
        choices=("real", "simulator"),
        default="real",
        help="AppClaw iOS device type (default: real).",
    )
    parser.add_argument("--case", action="append", dest="case_ids", help="Run one case id; repeat to select several.")
    parser.add_argument("--list", action="store_true", help="List available cases and exit.")
    parser.add_argument("--appclaw", default=shutil.which("appclaw") or "appclaw", help="AppClaw executable path.")
    parser.add_argument(
        "--wda-url",
        default=os.environ.get("APPCLAW_WDA_URL"),
        help="Reuse a reachable WDA, for example http://127.0.0.1:8100.",
    )
    parser.add_argument(
        "--wda-bundle-id",
        default=os.environ.get("APPCLAW_WDA_BUNDLE_ID"),
        help="Launch this already-installed WDA bundle and manage iproxy automatically (real device only).",
    )
    parser.add_argument("--wda-device-port", type=int, default=8100, help="WDA port on the iPhone (default: 8100).")
    parser.add_argument("--install-latest", action="store_true", help="Build and install the current checkout before regression.")
    parser.add_argument("--team-id", default=os.environ.get("DEVELOPMENT_TEAM"), help="Apple team for --install-latest.")
    parser.add_argument("--fail-fast", action="store_true", help="Stop after the first failed case.")
    parser.add_argument(
        "--case-timeout",
        type=int,
        default=180,
        help="Maximum seconds for one AppClaw case (default: 180).",
    )
    parser.add_argument("--execute", action="store_true", help="Execute device actions; omit for a dry-run preview.")
    return parser.parse_args(argv)


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        cases = load_cases()
        selected = select_cases(cases, args.case_ids)
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        return 2

    if args.list:
        for case in cases:
            print(f"{case.id:28} {case.tier.upper():3}  {case.description}")
        return 0

    if not args.udid:
        print("--udid or DEVICE_UDID is required", file=sys.stderr)
        return 2
    if args.install_latest and not args.team_id:
        print("--team-id or DEVELOPMENT_TEAM is required with --install-latest", file=sys.stderr)
        return 2
    if args.install_latest and args.device_type != "real":
        print("--install-latest currently supports a real device only", file=sys.stderr)
        return 2
    if args.wda_bundle_id and args.device_type != "real":
        print("--wda-bundle-id is only valid for a real device", file=sys.stderr)
        return 2
    if args.case_timeout <= 0:
        print("--case-timeout must be positive", file=sys.stderr)
        return 2
    if not 1 <= args.wda_device_port <= 65535:
        print("--wda-device-port must be between 1 and 65535", file=sys.stderr)
        return 2

    wda_url = args.wda_url
    if args.wda_bundle_id and not wda_url:
        wda_url = "http://127.0.0.1:8100"

    print(f"Selected {len(selected)} AppClaw case(s); photo deletion is force-disabled.")
    if args.install_latest:
        command = install_latest_command(args.team_id, args.udid)
        print("+ " + shell_join(command), flush=True)
        if args.execute:
            result = subprocess.run(command, cwd=REPO_ROOT)
            if result.returncode != 0:
                return result.returncode

    if not args.execute:
        print("Dry run only. Add --execute to run AppClaw against the selected device.")
        with tempfile.TemporaryDirectory(prefix="truekeep-appclaw-preview-") as temp_dir:
            for case in selected:
                caps_path = Path(temp_dir) / f"{case.id}.json"
                caps_path.write_text(
                    json.dumps(build_capabilities(case, wda_url, args.udid), ensure_ascii=False, indent=2) + "\n"
                )
                print("+ " + shell_join(appclaw_command(args.appclaw, case, caps_path, args.device_type, args.udid)))
        return 0

    if shutil.which(args.appclaw) is None and not Path(args.appclaw).is_file():
        print(f"AppClaw executable not found: {args.appclaw}", file=sys.stderr)
        return 2

    iproxy_process: subprocess.Popen[bytes] | None = None
    try:
        if args.wda_bundle_id:
            assert wda_url is not None
            local_port = parse_local_wda_port(wda_url)
            wda_command = launch_wda_command(args.udid, args.wda_bundle_id, args.wda_device_port)
            print("+ " + shell_join(wda_command), flush=True)
            subprocess.run(wda_command, cwd=REPO_ROOT, check=True)
            proxy_command = iproxy_command(args.udid, local_port, args.wda_device_port)
            print("+ " + shell_join(proxy_command), flush=True)
            iproxy_process = subprocess.Popen(proxy_command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            wait_for_wda(wda_url)
        elif wda_url:
            wait_for_wda(wda_url)

        results: list[tuple[str, int]] = []
        with tempfile.TemporaryDirectory(prefix="truekeep-appclaw-") as temp_dir:
            for index, case in enumerate(selected, start=1):
                caps_path = Path(temp_dir) / f"{case.id}.json"
                caps_path.write_text(
                    json.dumps(build_capabilities(case, wda_url, args.udid), ensure_ascii=False, indent=2) + "\n"
                )
                command = appclaw_command(args.appclaw, case, caps_path, args.device_type, args.udid)
                print(f"\n[{index}/{len(selected)}] {case.id}: {case.description}", flush=True)
                print("+ " + shell_join(command), flush=True)
                try:
                    completed = subprocess.run(
                        command,
                        cwd=REPO_ROOT,
                        env=appclaw_environment(),
                        stdin=subprocess.DEVNULL,
                        timeout=args.case_timeout,
                    )
                    returncode = completed.returncode
                except subprocess.TimeoutExpired:
                    returncode = 124
                    print(f"Case timed out after {args.case_timeout}s: {case.id}", file=sys.stderr)
                results.append((case.id, returncode))
                if returncode != 0 and args.fail_fast:
                    break

        print("\nTrueKeep AppClaw regression summary")
        for case_id, returncode in results:
            print(f"  {'PASS' if returncode == 0 else 'FAIL'}  {case_id}")
        failures = [case_id for case_id, returncode in results if returncode != 0]
        if failures:
            print(f"Failed {len(failures)} case(s): {', '.join(failures)}", file=sys.stderr)
            return 1
        print(f"Passed {len(results)}/{len(selected)} case(s). Reports: {REPO_ROOT / '.appclaw/runs'}")
        return 0
    except (OSError, subprocess.CalledProcessError, RuntimeError, ValueError) as error:
        print(f"AppClaw regression setup failed: {error}", file=sys.stderr)
        return 1
    finally:
        if iproxy_process is not None:
            iproxy_process.terminate()
            try:
                iproxy_process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                iproxy_process.kill()


def main() -> None:
    sys.exit(run())


if __name__ == "__main__":
    main()
