#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


GATE = Path(__file__).with_name("check-ios27-floor.sh")
MANIFESTS = (
    "BehavioralAISubstrate/Package.swift",
    "SampleHost/Package.swift",
    "QinaoRuntimeSDK/Package.swift",
)


class IOS27FloorGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.root = Path(self.temp_directory.name)

        for index, relative_path in enumerate(MANIFESTS):
            self.write(
                relative_path,
                self.manifest(
                    name=f"Fixture{index}",
                    platform_lines='        .iOS("27.0"),',
                ),
            )

        self.write(
            "BehavioralAISubstrate/DeviceTestApp/project.yml",
            """
deploymentTarget:
  iOS: "27.0"
settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: "27.0"
targets:
  App:
    entitlements:
      properties:
        com.apple.developer.kernel.increased-memory-limit: true
    info:
      properties:
        BGTaskSchedulerPermittedIdentifiers:
          - bas.sleep.consolidation
""".lstrip(),
        )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/"
            "BASDeviceTest.xcodeproj/project.pbxproj",
            "IPHONEOS_DEPLOYMENT_TARGET = 27.0;\n",
        )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/Resources/"
            "BASDeviceTestApp.entitlements",
            "<key>com.apple.developer.kernel.increased-memory-limit</key>\n",
        )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/Resources/Info.plist",
            "<key>BGTaskSchedulerPermittedIdentifiers</key>\n",
        )

    def write(self, relative_path: str, contents: str) -> None:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    @staticmethod
    def manifest(name: str, platform_lines: str) -> str:
        return f"""// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{name}",
    platforms: [
{platform_lines}
    ]
)
"""

    def run_gate(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(GATE), str(self.root)],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_valid_ios27_fixture_passes(self) -> None:
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_manifest_comment_cannot_spoof_legacy_floor(self) -> None:
        self.write(
            MANIFESTS[0],
            self.manifest(
                name="SpoofedLegacy",
                platform_lines='        .iOS(.v18), // .iOS("27.0")',
            ),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(MANIFESTS[0], result.stderr)

    def test_duplicate_legacy_manifest_floor_is_rejected(self) -> None:
        self.write(
            MANIFESTS[0],
            self.manifest(
                name="DuplicateLegacy",
                platform_lines=(
                    '        .iOS("27.0"),\n'
                    "        .iOS(.v18),"
                ),
            ),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(MANIFESTS[0], result.stderr)

    def test_yaml_comment_cannot_spoof_legacy_floor(self) -> None:
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/project.yml",
            """
iOS: "18.0" # iOS: "27.0"
IPHONEOS_DEPLOYMENT_TARGET: "18.0" # IPHONEOS_DEPLOYMENT_TARGET: "27.0"
  com.apple.developer.kernel.increased-memory-limit: true
  BGTaskSchedulerPermittedIdentifiers:
""".lstrip(),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project.yml", result.stderr)

    def test_generated_project_must_contain_ios27_target(self) -> None:
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/"
            "BASDeviceTest.xcodeproj/project.pbxproj",
            "PRODUCT_NAME = BASDeviceTest;\n",
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("generated project", result.stderr)


if __name__ == "__main__":
    unittest.main()
