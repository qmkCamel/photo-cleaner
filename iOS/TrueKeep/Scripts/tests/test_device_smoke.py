import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "device_smoke.py"


def load_module():
    spec = importlib.util.spec_from_file_location("device_smoke", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class DeviceSmokeScriptTests(unittest.TestCase):
    def test_build_command_uses_confirmed_team_and_device_without_committing_team(self):
        module = load_module()

        command = module.build_command(
            team_id="TEAM12345",
            device_id="DEVICE-UDID",
            derived_data="/tmp/Derived",
        )

        self.assertIn("DEVELOPMENT_TEAM=TEAM12345", command)
        self.assertIn("-destination", command)
        self.assertIn("platform=iOS,id=DEVICE-UDID", command)
        self.assertIn("-allowProvisioningUpdates", command)
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", command)

    def test_launch_command_forces_deletion_safety_lock(self):
        module = load_module()

        command = module.launch_command(device_id="DEVICE-UDID")

        self.assertEqual(command[:5], ["xcrun", "devicectl", "device", "process", "launch"])
        self.assertIn("--environment-variables", command)
        self.assertTrue(any('"TRUEKEEP_DISABLE_PHOTO_DELETION": "1"' in part for part in command))
        self.assertIn("-TrueKeepDisablePhotoDeletion", command)
        self.assertIn("app.truekeep.ios", command)

    def test_parse_args_requires_explicit_execute_for_mutating_install(self):
        module = load_module()

        args = module.parse_args(["--team-id", "TEAM12345", "--device-id", "DEVICE-UDID"])

        self.assertTrue(args.dry_run)
        self.assertFalse(args.execute)


if __name__ == "__main__":
    unittest.main()
