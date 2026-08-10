from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "appclaw_regression.py"
SPEC = importlib.util.spec_from_file_location("appclaw_regression", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
appclaw_regression = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = appclaw_regression
SPEC.loader.exec_module(appclaw_regression)


class AppClawRegressionTests(unittest.TestCase):
    def test_manifest_has_unique_p0_cases_with_existing_flows_and_deletion_lock(self) -> None:
        cases = appclaw_regression.load_cases()

        self.assertGreaterEqual(len(cases), 6)
        self.assertEqual(len({case.id for case in cases}), len(cases))
        for case in cases:
            self.assertEqual(case.tier, "p0")
            self.assertTrue(case.flow.is_file())
            self.assertIn(appclaw_regression.DELETION_DISABLED_ARGUMENT, case.launch_arguments)
            flow_text = case.flow.read_text(encoding="utf-8")
            self.assertIn("\n  - done\n", flow_text)
            self.assertNotIn("- done:", flow_text)

    def test_capabilities_apply_two_deletion_guards_and_case_arguments(self) -> None:
        case = appclaw_regression.load_cases()[0]

        capabilities = appclaw_regression.build_capabilities(case, "http://127.0.0.1:8100", "device-123")
        ios = capabilities["ios"]

        self.assertEqual(ios["appium:bundleId"], "app.truekeep.ios")
        self.assertEqual(ios["appium:udid"], "device-123")
        self.assertEqual(ios["appium:webDriverAgentUrl"], "http://127.0.0.1:8100")
        self.assertEqual(ios["appium:processArguments"]["args"], list(case.launch_arguments))
        self.assertEqual(ios["appium:processArguments"]["env"]["TRUEKEEP_DISABLE_PHOTO_DELETION"], "1")
        self.assertTrue(ios["appium:shouldTerminateApp"])

    def test_command_is_strict_dom_flow_for_selected_device(self) -> None:
        case = appclaw_regression.load_cases()[0]
        caps = Path("/tmp/caps.json")

        command = appclaw_regression.appclaw_command(
            "/usr/local/bin/appclaw",
            case,
            caps,
            "real",
            "device-123",
        )
        environment = appclaw_regression.appclaw_environment()

        self.assertIn("--strict", command)
        self.assertEqual(command[command.index("--udid") + 1], "device-123")
        self.assertEqual(command[command.index("--flow") + 1], str(case.flow))
        self.assertEqual(environment["AGENT_MODE"], "dom")
        self.assertEqual(environment["VISION_MODE"], "never")
        self.assertEqual(environment["GEMINI_API_KEY"], "")

    def test_unknown_case_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unknown AppClaw case"):
            appclaw_regression.select_cases(appclaw_regression.load_cases(), ["missing-case"])

    def test_managed_wda_commands_do_not_hardcode_a_device_or_bundle(self) -> None:
        launch = appclaw_regression.launch_wda_command("device-123", "com.example.WDARunner", 8100)
        proxy = appclaw_regression.iproxy_command("device-123", 8200, 8100)

        self.assertIn("device-123", launch)
        self.assertEqual(launch[-1], "com.example.WDARunner")
        self.assertEqual(proxy, ["iproxy", "--udid", "device-123", "8200:8100"])

    def test_default_case_timeout_prevents_unbounded_device_runs(self) -> None:
        args = appclaw_regression.parse_args(["--udid", "device-123"])

        self.assertEqual(args.case_timeout, 180)


if __name__ == "__main__":
    unittest.main()
