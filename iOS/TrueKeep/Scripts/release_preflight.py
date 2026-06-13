#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[3]
IOS_ROOT = REPO_ROOT / "iOS" / "TrueKeep"
PROJECT = IOS_ROOT / "TrueKeep.xcodeproj"
SCHEME = "TrueKeep"
SIMULATOR_ID = "0157BFC9-C9C9-48DC-845E-AABED7B2DCE9"

CURRENT_SCREENSHOT_SET = IOS_ROOT / "MarketingScreenshots" / "2026-06-13-1811-photo-video-copy"
APP_STORE_69 = CURRENT_SCREENSHOT_SET / "app-store-6.9"
MARKETING_69 = CURRENT_SCREENSHOT_SET / "app-store-6.9-marketing"
SITE_TEMPLATE = REPO_ROOT / "docs" / "app-store" / "site-template"
APP_STORE_CONNECT = IOS_ROOT / "AppStoreConnect" / "metadata"

EXPECTED_SCREENSHOT_SIZE = (1320, 2868)
LOCALIZED_COPY_EXTENSIONS = {".md", ".py", ".strings", ".swift", ".txt"}
METADATA_FIELD_FILES = {
    "App name": "name.txt",
    "Subtitle": "subtitle.txt",
    "Keywords": "keywords.txt",
    "Promotional text": "promotional_text.txt",
    "Description": "description.txt",
}
METADATA_LOCALES = ("en-US", "zh-Hans")


@dataclass
class CheckResult:
    name: str
    status: str
    detail: str


class LocalLinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name in {"href", "src"} and value:
                if not value.startswith(("http://", "https://", "mailto:", "#")):
                    self.links.append(value)


class Preflight:
    def __init__(self, run_xcode: bool) -> None:
        self.run_xcode = run_xcode
        self.results: list[CheckResult] = []

    def pass_(self, name: str, detail: str) -> None:
        self.results.append(CheckResult(name, "PASS", detail))

    def fail(self, name: str, detail: str) -> None:
        self.results.append(CheckResult(name, "FAIL", detail))

    def info(self, name: str, detail: str) -> None:
        self.results.append(CheckResult(name, "INFO", detail))

    def run(self) -> int:
        self.check_required_files()
        self.check_plists()
        self.check_privacy_manifest()
        self.check_metadata_lengths()
        self.check_metadata_packet_matches_listing()
        self.check_screenshot_dimensions(APP_STORE_69, expected_count=8)
        self.check_screenshot_dimensions(MARKETING_69, expected_count=6)
        self.check_static_site_links()
        self.check_external_submission_placeholders()
        self.check_source_guardrails()
        self.check_localized_copy_guardrails()
        self.check_signing_state()

        if self.run_xcode:
            self.run_xcode_tests()
            self.run_unsigned_archive()
        else:
            self.info("xcode-full-regression", "Skipped. Run with --run-xcode for tests and unsigned archive.")

        return self.print_summary()

    def check_required_files(self) -> None:
        required = [
            IOS_ROOT / "project.yml",
            PROJECT / "project.pbxproj",
            IOS_ROOT / "TrueKeep" / "Resources" / "Info.plist",
            IOS_ROOT / "TrueKeep" / "Resources" / "PrivacyInfo.xcprivacy",
            IOS_ROOT / "TrueKeep" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "app-icon-1024.png",
            IOS_ROOT / "APP_STORE_LISTING.md",
            IOS_ROOT / "APP_STORE_REVIEW_NOTES.md",
            IOS_ROOT / "RELEASE_CHECKLIST.md",
            IOS_ROOT / "SUBMISSION_RUNBOOK.md",
            IOS_ROOT / "DEVICE_SIGNING.md",
            IOS_ROOT / "DECISIONS.md",
            IOS_ROOT / "Scripts" / "device_smoke.py",
            IOS_ROOT / "Scripts" / "release_preflight.py",
            REPO_ROOT / "docs" / "app-store" / "privacy-policy.md",
            REPO_ROOT / "docs" / "app-store" / "support.md",
            REPO_ROOT / "docs" / "app-store" / "compliance-answers.md",
            SITE_TEMPLATE / "index.html",
            SITE_TEMPLATE / "privacy.html",
            SITE_TEMPLATE / "support.html",
            SITE_TEMPLATE / "styles.css",
        ]
        missing = [str(path.relative_to(REPO_ROOT)) for path in required if not path.exists()]
        if missing:
            self.fail("required-files", "Missing: " + ", ".join(missing))
        else:
            self.pass_("required-files", f"{len(required)} required files exist")

    def check_plists(self) -> None:
        info_path = IOS_ROOT / "TrueKeep" / "Resources" / "Info.plist"
        privacy_path = IOS_ROOT / "TrueKeep" / "Resources" / "PrivacyInfo.xcprivacy"
        try:
            info = self.read_plist(info_path)
            self.read_plist(privacy_path)
        except Exception as exc:
            self.fail("plist-parse", str(exc))
            return

        errors = []
        plist_expected = {
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleShortVersionString": "$(MARKETING_VERSION)",
            "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        }
        for key, value in plist_expected.items():
            if info.get(key) != value:
                errors.append(f"{key}={info.get(key)!r}, expected build setting placeholder {value!r}")

        project_yml = (IOS_ROOT / "project.yml").read_text(encoding="utf-8")
        project_expected = {
            "PRODUCT_BUNDLE_IDENTIFIER": "app.truekeep.ios",
            "MARKETING_VERSION": "0.1.0",
            "CURRENT_PROJECT_VERSION": "1",
        }
        for key, value in project_expected.items():
            pattern = rf"{re.escape(key)}:\s+[\"']?{re.escape(value)}[\"']?"
            if not re.search(pattern, project_yml):
                errors.append(f"project.yml missing {key}: {value}")

        usage = info.get("NSPhotoLibraryUsageDescription", "")
        if "不会上传" not in usage or "删除前需要你确认" not in usage:
            errors.append("NSPhotoLibraryUsageDescription must mention no upload and confirmation before deletion")

        if errors:
            self.fail("info-plist", "; ".join(errors))
        else:
            self.pass_("info-plist", "plist placeholders, project build settings, and Photos usage string match release draft")

    def check_privacy_manifest(self) -> None:
        privacy_path = IOS_ROOT / "TrueKeep" / "Resources" / "PrivacyInfo.xcprivacy"
        try:
            privacy = self.read_plist(privacy_path)
        except Exception as exc:
            self.fail("privacy-manifest", str(exc))
            return

        tracking = privacy.get("NSPrivacyTracking")
        collected = privacy.get("NSPrivacyCollectedDataTypes")
        accessed = privacy.get("NSPrivacyAccessedAPITypes")
        tracking_domains = privacy.get("NSPrivacyTrackingDomains")
        if tracking is False and collected == [] and accessed == [] and tracking_domains == []:
            self.pass_("privacy-manifest", "declares no tracking, collected data, tracking domains, or required-reason APIs")
        else:
            self.fail("privacy-manifest", "privacy manifest no-collection/no-tracking assertion changed")

    def check_metadata_lengths(self) -> None:
        checks = [
            (APP_STORE_CONNECT / "en-US" / "name.txt", 30, "en-US name"),
            (APP_STORE_CONNECT / "en-US" / "subtitle.txt", 30, "en-US subtitle"),
            (APP_STORE_CONNECT / "en-US" / "keywords.txt", 100, "en-US keywords"),
            (APP_STORE_CONNECT / "zh-Hans" / "name.txt", 30, "zh-Hans name"),
            (APP_STORE_CONNECT / "zh-Hans" / "subtitle.txt", 30, "zh-Hans subtitle"),
            (APP_STORE_CONNECT / "zh-Hans" / "keywords.txt", 100, "zh-Hans keywords"),
        ]
        errors = []
        for path, limit, label in checks:
            if not path.exists():
                errors.append(f"{label} missing")
                continue
            value = path.read_text(encoding="utf-8").strip()
            if len(value) > limit:
                errors.append(f"{label} length {len(value)} > {limit}")
        if errors:
            self.fail("app-store-metadata-lengths", "; ".join(errors))
        else:
            self.pass_("app-store-metadata-lengths", "name, subtitle, and keyword lengths fit App Store limits")

    def check_metadata_packet_matches_listing(self) -> None:
        listing = IOS_ROOT / "APP_STORE_LISTING.md"
        if not listing.exists():
            self.fail("app-store-metadata-packet", "APP_STORE_LISTING.md missing")
            return

        listing_text = listing.read_text(encoding="utf-8")
        errors = []
        for locale in METADATA_LOCALES:
            section = metadata_section(listing_text, locale)
            if not section:
                errors.append(f"APP_STORE_LISTING.md missing {locale} metadata section")
                continue
            for label, filename in METADATA_FIELD_FILES.items():
                expected = listing_metadata_value(section, label)
                if expected is None:
                    errors.append(f"APP_STORE_LISTING.md missing {locale} {label}")
                    continue
                path = APP_STORE_CONNECT / locale / filename
                if not path.exists():
                    errors.append(f"{locale}/{filename} missing")
                    continue
                actual = path.read_text(encoding="utf-8").strip()
                if actual != expected:
                    errors.append(f"{locale}/{filename} differs from APP_STORE_LISTING.md")

        if errors:
            self.fail("app-store-metadata-packet", "; ".join(errors))
        else:
            self.pass_("app-store-metadata-packet", "copy-paste metadata files match APP_STORE_LISTING.md")

    def check_screenshot_dimensions(self, folder: Path, expected_count: int) -> None:
        if not folder.exists():
            self.fail(f"screenshot-dimensions:{folder.name}", "folder missing")
            return
        pngs = sorted(path for path in folder.glob("*.png") if path.name != "contact-sheet.png")
        errors = []
        if len(pngs) != expected_count:
            errors.append(f"found {len(pngs)} pngs, expected {expected_count}")
        for path in pngs:
            with Image.open(path) as image:
                if image.size != EXPECTED_SCREENSHOT_SIZE:
                    errors.append(f"{path.name} is {image.size}, expected {EXPECTED_SCREENSHOT_SIZE}")
        manifest = folder / "manifest.json"
        if manifest.exists():
            try:
                json.loads(manifest.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                errors.append(f"manifest json invalid: {exc}")
        if errors:
            self.fail(f"screenshot-dimensions:{folder.name}", "; ".join(errors))
        else:
            self.pass_(
                f"screenshot-dimensions:{folder.name}",
                f"{len(pngs)} screenshots verified at {EXPECTED_SCREENSHOT_SIZE[0]}x{EXPECTED_SCREENSHOT_SIZE[1]}",
            )

    def check_static_site_links(self) -> None:
        if not SITE_TEMPLATE.exists():
            self.fail("static-site-links", "site-template folder missing")
            return
        errors = []
        for path in sorted(SITE_TEMPLATE.glob("*.html")):
            parser = LocalLinkParser()
            parser.feed(path.read_text(encoding="utf-8"))
            for link in parser.links:
                if not (SITE_TEMPLATE / link).exists():
                    errors.append(f"{path.name}: missing {link}")
        if errors:
            self.fail("static-site-links", "; ".join(errors))
        else:
            self.pass_("static-site-links", "all local links in static support/privacy pages resolve")

    def check_external_submission_placeholders(self) -> None:
        paths = [
            IOS_ROOT / "APP_STORE_LISTING.md",
            REPO_ROOT / "docs" / "app-store" / "support.md",
            REPO_ROOT / "docs" / "app-store" / "privacy-policy.md",
            SITE_TEMPLATE / "support.html",
            SITE_TEMPLATE / "privacy.html",
        ]
        placeholder_patterns = [
            "Support URL: pending",
            "Privacy Policy URL: pending",
            "Support contact: pending",
            "replace this placeholder",
            "replace this notice",
            "replace before hosting",
            "not final until the support contact",
        ]
        hits = []
        for path in paths:
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8").lower()
            if any(pattern.lower() in text for pattern in placeholder_patterns):
                hits.append(str(path.relative_to(REPO_ROOT)))
        if hits:
            self.info(
                "external-submission-placeholders",
                "Final hosted URLs/support contact still required: " + ", ".join(hits),
            )
        else:
            self.pass_("external-submission-placeholders", "Support/Privacy URLs and support contact placeholders are resolved")

    def check_source_guardrails(self) -> None:
        swift_files = sorted((IOS_ROOT / "TrueKeep").rglob("*.swift"))
        forbidden = {
            "URLSession": "networking",
            "import WebKit": "web view",
            "import StoreKit": "payments",
            "import AdSupport": "advertising",
            "import AppTrackingTransparency": "tracking",
            "import CryptoKit": "custom crypto",
            "CommonCrypto": "custom crypto",
            "SecKey": "key management",
        }
        hits = []
        for path in swift_files:
            text = path.read_text(encoding="utf-8")
            for pattern, label in forbidden.items():
                if pattern in text:
                    hits.append(f"{path.relative_to(REPO_ROOT)} contains {pattern} ({label})")
        if hits:
            self.fail("source-privacy-guardrails", "; ".join(hits))
        else:
            self.pass_("source-privacy-guardrails", "no networking, ads, tracking, StoreKit, WebKit, or custom crypto patterns found")

    def check_localized_copy_guardrails(self) -> None:
        checks = [
            IOS_ROOT / "TrueKeep",
            IOS_ROOT / "AppStoreConnect" / "metadata" / "zh-Hans",
            IOS_ROOT / "Scripts" / "build_marketing_screenshots.py",
            REPO_ROOT / "docs" / "04-product-positioning-and-mvp.md",
            REPO_ROOT / "docs" / "05-privacy-safety-risk.md",
            REPO_ROOT / "docs" / "07-three-phase-roadmap.md",
            REPO_ROOT / "docs" / "08-mvp-trust-design-and-interaction.md",
            REPO_ROOT / "docs" / "prototypes" / "mvp-trust-validation" / "index.html",
        ]
        hits = []
        for root in checks:
            files = [root] if root.is_file() else sorted(
                path for path in root.rglob("*") if path.is_file() and path.suffix in LOCALIZED_COPY_EXTENSIONS
            )
            for path in files:
                text = path.read_text(encoding="utf-8")
                if "Review Bin" in text:
                    hits.append(str(path.relative_to(REPO_ROOT)))
        listing = IOS_ROOT / "APP_STORE_LISTING.md"
        if listing.exists() and "Review Bin" in zh_hans_section(listing.read_text(encoding="utf-8")):
            hits.append(str(listing.relative_to(REPO_ROOT)))
        if hits:
            self.fail("localized-copy-guardrails", "Use 复核箱 instead of Review Bin in Chinese surfaces: " + ", ".join(hits))
        else:
            self.pass_("localized-copy-guardrails", "Chinese UI, zh-Hans metadata, listing, design docs, prototype, and marketing screenshot copy use 复核箱")

    def check_signing_state(self) -> None:
        project_yml = (IOS_ROOT / "project.yml").read_text(encoding="utf-8")
        if 'DEVELOPMENT_TEAM: ""' in project_yml:
            self.pass_("development-team-policy", "DEVELOPMENT_TEAM remains empty in project.yml")
        else:
            self.fail("development-team-policy", "DEVELOPMENT_TEAM is no longer empty in project.yml")

        profiles_dir = Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles"
        profiles = []
        if profiles_dir.exists():
            profiles = list(profiles_dir.glob("*.mobileprovision")) + list(profiles_dir.glob("*.provisionprofile"))
        if profiles:
            self.info("local-provisioning-profiles", f"{len(profiles)} profile file(s) present; signing still needs explicit validation")
        else:
            self.info("local-provisioning-profiles", "none found; physical-device and distribution signing remain blocked")

    def run_xcode_tests(self) -> None:
        cmd = [
            "xcodebuild",
            "test",
            "-project",
            str(PROJECT.relative_to(REPO_ROOT)),
            "-scheme",
            SCHEME,
            "-destination",
            f"platform=iOS Simulator,id={SIMULATOR_ID}",
        ]
        result = self.run_command(cmd, timeout=None)
        if result.returncode == 0:
            self.pass_("xcode-tests", "xcodebuild test completed successfully")
        else:
            self.fail("xcode-tests", tail(result.stdout + result.stderr))

    def run_unsigned_archive(self) -> None:
        archive = "/tmp/TrueKeepReleasePreflightUnsigned.xcarchive"
        derived_data = "/tmp/TrueKeepReleasePreflightArchiveDerivedData"
        cmd = [
            "xcodebuild",
            "archive",
            "-project",
            str(PROJECT.relative_to(REPO_ROOT)),
            "-scheme",
            SCHEME,
            "-configuration",
            "Release",
            "-destination",
            "generic/platform=iOS",
            "-archivePath",
            archive,
            "-derivedDataPath",
            derived_data,
            "CODE_SIGNING_ALLOWED=NO",
            "SKIP_INSTALL=NO",
        ]
        result = self.run_command(cmd, timeout=None)
        if result.returncode == 0:
            self.pass_("unsigned-release-archive", f"archive succeeded at {archive}")
        else:
            self.fail("unsigned-release-archive", tail(result.stdout + result.stderr))

    def read_plist(self, path: Path) -> dict:
        with path.open("rb") as file:
            return plistlib.load(file)

    def run_command(self, cmd: list[str], timeout: int | None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )

    def print_summary(self) -> int:
        failures = [result for result in self.results if result.status == "FAIL"]
        for result in self.results:
            print(f"[{result.status}] {result.name}: {result.detail}")
        print()
        print(f"Summary: {len(self.results) - len(failures)} passed/info, {len(failures)} failed")
        return 1 if failures else 0


def tail(text: str, lines: int = 24) -> str:
    return "\n".join(text.splitlines()[-lines:])


def zh_hans_section(text: str) -> str:
    return metadata_section(text, "zh-Hans")


def metadata_section(text: str, locale: str) -> str:
    marker = f"## {locale} Metadata Draft"
    start = text.find(marker)
    if start == -1:
        return ""
    next_heading = text.find("\n## ", start + len(marker))
    return text[start:] if next_heading == -1 else text[start:next_heading]


def listing_metadata_value(section: str, label: str) -> str | None:
    block = re.search(rf"- {re.escape(label)}:\s*\n\s*`([^`]*)`", section)
    if block:
        return block.group(1)
    inline = re.search(rf"- {re.escape(label)}:\s*`([^`]*)`", section)
    if inline:
        return inline.group(1)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Run local TrueKeep release preflight checks.")
    parser.add_argument(
        "--run-xcode",
        action="store_true",
        help="Also run full xcodebuild test and unsigned Release archive checks.",
    )
    args = parser.parse_args()
    return Preflight(run_xcode=args.run_xcode).run()


if __name__ == "__main__":
    sys.exit(main())
