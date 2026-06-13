import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "release_preflight.py"


def load_module():
    spec = importlib.util.spec_from_file_location("release_preflight", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class ReleasePreflightScriptTests(unittest.TestCase):
    def test_localized_copy_guard_fails_when_chinese_surfaces_use_review_bin(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            app_source = ios_root / "TrueKeep" / "Screens" / "ReviewBinView.swift"
            zh_description = ios_root / "AppStoreConnect" / "metadata" / "zh-Hans" / "description.txt"
            app_source.parent.mkdir(parents=True)
            zh_description.parent.mkdir(parents=True)
            app_source.write_text('Text("加入 Review Bin")\n', encoding="utf-8")
            zh_description.write_text("加入 Review Bin 后再确认删除。\n", encoding="utf-8")

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_localized_copy_guardrails()

        failures = [result for result in preflight.results if result.status == "FAIL"]
        self.assertEqual(len(failures), 1)
        self.assertEqual(failures[0].name, "localized-copy-guardrails")
        self.assertIn("ReviewBinView.swift", failures[0].detail)
        self.assertIn("description.txt", failures[0].detail)

    def test_localized_copy_guard_ignores_binary_assets(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            asset = ios_root / "TrueKeep" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "icon.png"
            zh_description = ios_root / "AppStoreConnect" / "metadata" / "zh-Hans" / "description.txt"
            listing = ios_root / "APP_STORE_LISTING.md"
            screenshot_script = ios_root / "Scripts" / "build_marketing_screenshots.py"
            asset.parent.mkdir(parents=True)
            zh_description.parent.mkdir(parents=True)
            listing.parent.mkdir(parents=True, exist_ok=True)
            screenshot_script.parent.mkdir(parents=True, exist_ok=True)
            asset.write_bytes(b"\x89PNG\r\n\x1a\n")
            zh_description.write_text("加入复核箱后再确认删除。\n", encoding="utf-8")
            listing.write_text("加入复核箱后再确认删除。\n", encoding="utf-8")
            screenshot_script.write_text('title = "先确认，再加入复核箱"\n', encoding="utf-8")

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_localized_copy_guardrails()

        self.assertEqual(preflight.results[0].status, "PASS")

    def test_localized_copy_guard_checks_only_zh_hans_listing_section(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            app_source = ios_root / "TrueKeep" / "Screens" / "ReviewBinView.swift"
            zh_description = ios_root / "AppStoreConnect" / "metadata" / "zh-Hans" / "description.txt"
            listing = ios_root / "APP_STORE_LISTING.md"
            screenshot_script = ios_root / "Scripts" / "build_marketing_screenshots.py"
            app_source.parent.mkdir(parents=True)
            zh_description.parent.mkdir(parents=True)
            screenshot_script.parent.mkdir(parents=True)
            app_source.write_text('Text("复核箱")\n', encoding="utf-8")
            zh_description.write_text("加入复核箱后再确认删除。\n", encoding="utf-8")
            screenshot_script.write_text('title = "先确认，再加入复核箱"\n', encoding="utf-8")
            listing.write_text(
                "## en-US Metadata Draft\n"
                "Requires a Review Bin before deletion.\n\n"
                "## zh-Hans Metadata Draft\n"
                "加入 Review Bin 后再确认删除。\n\n"
                "## Support And Privacy Pages\n",
                encoding="utf-8",
            )

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_localized_copy_guardrails()

            self.assertEqual(preflight.results[0].status, "FAIL")
            self.assertIn("APP_STORE_LISTING.md", preflight.results[0].detail)

            listing.write_text(
                "## en-US Metadata Draft\n"
                "Requires a Review Bin before deletion.\n\n"
                "## zh-Hans Metadata Draft\n"
                "加入复核箱后再确认删除。\n\n"
                "## Support And Privacy Pages\n",
                encoding="utf-8",
            )
            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_localized_copy_guardrails()

        self.assertEqual(preflight.results[0].status, "PASS")

    def test_localized_copy_guard_checks_chinese_design_docs_and_prototype(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            design_doc = root / "docs" / "08-mvp-trust-design-and-interaction.md"
            prototype = root / "docs" / "prototypes" / "mvp-trust-validation" / "index.html"
            design_doc.parent.mkdir(parents=True)
            prototype.parent.mkdir(parents=True)
            design_doc.write_text("点击加入 Review Bin 后二次确认。\n", encoding="utf-8")
            prototype.write_text("<button>加入 Review Bin</button>\n", encoding="utf-8")

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_localized_copy_guardrails()

        self.assertEqual(preflight.results[0].status, "FAIL")
        self.assertIn("08-mvp-trust-design-and-interaction.md", preflight.results[0].detail)
        self.assertIn("docs/prototypes/mvp-trust-validation/index.html", preflight.results[0].detail)

    def test_metadata_packet_guard_fails_when_copy_paste_file_differs_from_listing(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            metadata_root = ios_root / "AppStoreConnect" / "metadata"
            listing = ios_root / "APP_STORE_LISTING.md"
            (metadata_root / "en-US").mkdir(parents=True)
            (metadata_root / "zh-Hans").mkdir(parents=True)
            listing.write_text(sample_listing(), encoding="utf-8")
            write_metadata_packet(metadata_root)
            (metadata_root / "zh-Hans" / "subtitle.txt").write_text("不一致副标题\n", encoding="utf-8")

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root), patch.object(module, "APP_STORE_CONNECT", metadata_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_metadata_packet_matches_listing()

        self.assertEqual(preflight.results[0].status, "FAIL")
        self.assertIn("zh-Hans/subtitle.txt", preflight.results[0].detail)

    def test_metadata_packet_guard_passes_when_copy_paste_files_match_listing(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            metadata_root = ios_root / "AppStoreConnect" / "metadata"
            listing = ios_root / "APP_STORE_LISTING.md"
            (metadata_root / "en-US").mkdir(parents=True)
            (metadata_root / "zh-Hans").mkdir(parents=True)
            listing.write_text(sample_listing(), encoding="utf-8")
            write_metadata_packet(metadata_root)

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root), patch.object(module, "APP_STORE_CONNECT", metadata_root):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_metadata_packet_matches_listing()

        self.assertEqual(preflight.results[0].status, "PASS")

    def test_external_submission_placeholders_report_info_until_final_urls_exist(self):
        module = load_module()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ios_root = root / "iOS" / "TrueKeep"
            listing = ios_root / "APP_STORE_LISTING.md"
            support_doc = root / "docs" / "app-store" / "support.md"
            privacy_doc = root / "docs" / "app-store" / "privacy-policy.md"
            site_template = root / "docs" / "app-store" / "site-template"
            listing.parent.mkdir(parents=True)
            support_doc.parent.mkdir(parents=True)
            site_template.mkdir(parents=True)
            listing.write_text("- Support URL: pending.\n- Privacy Policy URL: pending.\n", encoding="utf-8")
            support_doc.write_text("Support contact: pending.\n", encoding="utf-8")
            privacy_doc.write_text("Support contact: pending.\n", encoding="utf-8")
            (site_template / "support.html").write_text("replace this notice with a monitored support email", encoding="utf-8")
            (site_template / "privacy.html").write_text("Support contact: replace before hosting", encoding="utf-8")

            with patch.object(module, "REPO_ROOT", root), patch.object(module, "IOS_ROOT", ios_root), patch.object(
                module, "SITE_TEMPLATE", site_template
            ):
                preflight = module.Preflight(run_xcode=False)
                preflight.check_external_submission_placeholders()

        self.assertEqual(preflight.results[0].status, "INFO")
        self.assertEqual(preflight.results[0].name, "external-submission-placeholders")
        self.assertIn("APP_STORE_LISTING.md", preflight.results[0].detail)
        self.assertIn("support.md", preflight.results[0].detail)
        self.assertIn("site-template/support.html", preflight.results[0].detail)

def sample_listing():
    return (
        "## en-US Metadata Draft\n\n"
        "- App name: `TrueKeep: AI Photo Cleaner`\n"
        "- Subtitle: `Private Camera Roll Cleanup`\n"
        "- Keywords: `duplicate,similar,blurry`\n"
        "- Promotional text:\n"
        "  `Find review-worthy cleanup candidates.`\n"
        "- Description:\n"
        "  `TrueKeep keeps cleanup review local.`\n\n"
        "## zh-Hans Metadata Draft\n\n"
        "- App name: `留真：AI 相册清理`\n"
        "- Subtitle: `本机复核重复照片`\n"
        "- Keywords: `截图,大视频,模糊`\n"
        "- Promotional text:\n"
        "  `在 iPhone 本机找出值得复核的清理候选。`\n"
        "- Description:\n"
        "  `留真用于本机复核相册中的清理候选。`\n\n"
        "## Support And Privacy Pages\n"
    )


def write_metadata_packet(metadata_root):
    values = {
        ("en-US", "name.txt"): "TrueKeep: AI Photo Cleaner\n",
        ("en-US", "subtitle.txt"): "Private Camera Roll Cleanup\n",
        ("en-US", "keywords.txt"): "duplicate,similar,blurry\n",
        ("en-US", "promotional_text.txt"): "Find review-worthy cleanup candidates.\n",
        ("en-US", "description.txt"): "TrueKeep keeps cleanup review local.\n",
        ("zh-Hans", "name.txt"): "留真：AI 相册清理\n",
        ("zh-Hans", "subtitle.txt"): "本机复核重复照片\n",
        ("zh-Hans", "keywords.txt"): "截图,大视频,模糊\n",
        ("zh-Hans", "promotional_text.txt"): "在 iPhone 本机找出值得复核的清理候选。\n",
        ("zh-Hans", "description.txt"): "留真用于本机复核相册中的清理候选。\n",
    }
    for (locale, filename), value in values.items():
        (metadata_root / locale / filename).write_text(value, encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
