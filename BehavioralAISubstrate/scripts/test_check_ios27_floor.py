#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import plistlib
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


GATE = Path(__file__).with_name("check-ios27-floor.sh")
MANIFESTS = (
    "BehavioralAISubstrate/Package.swift",
    "QinaoRuntimeSDK/Package.swift",
    "SampleHost/Package.swift",
)
XCFRAMEWORK = (
    "BehavioralAISubstrate/Vendor/bas-rust-binaries/"
    "BASRustMemoryTracker.xcframework"
)
HOST_EVENT_LOG_TESTS = (
    "testEventLogHeadHasOneSourceOwnerAndNoGovernanceEntry",
    "testEventLogHeadOwnerGateRecognizesEveryDeclarationKind",
    "testEventLogHeadDeclarationSurfaceIsExactAndValueOnly",
)
IOS_EVENT_LOG_TESTS = (
    "testEntryConfidenceClampsAboveOne",
    "testEntryConfidenceClampsBelowZero",
    "testEntryCodableRoundTrip",
    "testEntryKindRawValueStability",
    "testEntryRiskBandRawValueStability",
    "testEventLogHeadGenesisUsesExactSentinelShape",
    "testEventLogHeadCodableHashableAndExactJSONKeys",
    "testEventLogHeadPreservesRawNoncanonicalProjectionValues",
    "testInMemoryAppendAssignsSequenceNumber",
    "testInMemoryAppendIsIdempotent",
    "testInMemorySessionOrderingPreserved",
    "testInMemoryMultipleSessionsTrackSeparateSequences",
    "testInMemorySinceTimestampFilter",
    "testInMemorySinceTimestampLimitApplied",
    "testSQLiteOpenCreatesSchema",
    "testSQLiteAppendThenFetch",
    "testSQLiteIdempotentRetry",
    "testSQLiteCrossSessionPersistence",
    "testSQLiteSchemaVersionPin",
    "testM896InMemoryPruneRemovesOldEvents",
    "testM896InMemoryPruneIdempotentOnRePrune",
    "testM896SQLitePruneRemovesOldEvents",
    "testM896RetentionPolicyCutoffComputation",
    "testM896RetentionPolicyZeroAgeMeansNoCutoff",
    "testM896RetentionPolicyPresets",
    "testM896RetentionPolicyMinCadenceClamp",
    "testReplaySessionFoldsEvents",
    "testReplaySkipsEventsWhenReducerReturnsNil",
    "testReplayEmptySessionReturnsInitial",
    "testReplaySinceTimestampRange",
    "testInMemoryAndSQLiteContractParity",
)
COREAI_IMPORT_FILES = (
    "App/BASCoreAIDecodeProbe.swift",
    "App/BASCoreAIDuetProbe.swift",
    "App/BASCoreAIMamba3DualProbe.swift",
    "App/BASCoreAIMamba3Probe.swift",
    "App/BASCoreAIMambaSaguaroProbe.swift",
    "App/BASCoreAIPrefillProbe.swift",
    "App/BASCoreAIStateLakeProbe.swift",
    "App/BASQwen35RdarProbe.swift",
    "Experiments/BASCoreAIGpuProbe.swift",
    "Experiments/BASRhoProbe.swift",
)
COREAI_GATED_TOKENS = (
    "AIModel",
    "InferenceFunction",
    "NDArray",
    "SpecializationOptions",
    "ComputeUnitKind",
    "BASCoreAIDecodeSession",
    "BASCoreAIHybridDecodeSession",
    "BASCoreAILayerSplitSession",
    "BASCoreAIMamba3DualSession",
    "BASCoreAIMamba3Session",
    "BASCoreAIMambaSession",
    "BASCoreAIPrefillSession",
    "BASSaguaroSpeculator",
    "BASStateLakeReader",
    "BASCoreAINLIVerifier",
)

FAKE_SWIFT = r"""#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

arguments = sys.argv[1:]
package_path = Path(arguments[arguments.index("--package-path") + 1])
contents = package_path.joinpath("Package.swift").read_text(encoding="utf-8")
contents = "\n".join(line.split("//", 1)[0] for line in contents.splitlines())
versions = []
for quoted, shorthand in re.findall(
    r"\.iOS\s*\(\s*(?:\"([0-9.]+)\"|\.v([0-9]+))\s*\)",
    contents,
):
    versions.append(quoted or shorthand + ".0")
print(
    json.dumps(
        {
            "platforms": [
                {"platformName": "ios", "version": version}
                for version in versions
            ]
        }
    )
)
"""

FAKE_RG = r"""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

arguments = sys.argv[1:]
log = Path(os.environ["QINAO_TEST_RG_LOG"])
with log.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(arguments) + "\n")
call = len(log.read_text(encoding="utf-8").splitlines())
fail_call = int(os.environ.get("QINAO_TEST_RG_FAIL_CALL", "0"))
if fail_call == call:
    status = int(os.environ.get("QINAO_TEST_RG_FAIL_STATUS", "2"))
    print(f"test-only rg failure on call {call}", file=sys.stderr)
    raise SystemExit(status)
real_rg = os.environ["QINAO_TEST_REAL_RG"]
os.execv(real_rg, [real_rg, *arguments])
"""

FAKE_XCODEBUILD = r"""#!/usr/bin/env python3
import json
import os
import plistlib
import sys
from pathlib import Path

arguments = sys.argv[1:]
log_path = os.environ.get("QINAO_TEST_XCODEBUILD_LOG")
if log_path:
    with Path(log_path).open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(arguments) + "\n")
requested_exit = int(os.environ.get("QINAO_TEST_XCODEBUILD_EXIT", "0"))
if requested_exit:
    print("test-only xcodebuild failure", file=sys.stderr)
    raise SystemExit(requested_exit)
if "-showdestinations" in arguments:
    print(
        "{ platform:iOS Simulator, "
        f"arch:{os.environ.get('QINAO_TEST_DESTINATION_ARCH', 'arm64')}, "
        f"id:{os.environ['QINAO_TEST_SIMULATOR_UDID']}, "
        f"OS:{os.environ.get('QINAO_TEST_DESTINATION_OS', '27.0')}, "
        "name:Test Only iPhone }"
    )
    raise SystemExit(0)
expected_simulator_destination = (
    "platform=iOS Simulator,"
    f"id={os.environ['QINAO_TEST_SIMULATOR_UDID']}"
)
actual_destination = (
    arguments[arguments.index("-destination") + 1]
    if "-destination" in arguments
    else ""
)
if (
    os.environ.get("QINAO_TEST_REJECT_SIMULATOR_SDK_OVERRIDE") == "1"
    and actual_destination == expected_simulator_destination
    and "-sdk" in arguments
):
    print(
        "test-only concrete simulator invocation must not pass -sdk",
        file=sys.stderr,
    )
    raise SystemExit(5)
if (
    "build-for-testing" in arguments
    and os.environ.get("QINAO_TEST_REQUIRE_CONCRETE_SIMULATOR") == "1"
):
    if (
        actual_destination.startswith("platform=iOS Simulator")
        and actual_destination != expected_simulator_destination
    ):
        print(
            "test-only simulator build requires concrete destination",
            file=sys.stderr,
        )
        raise SystemExit(3)
if "-enumerate-tests" in arguments:
    if actual_destination != expected_simulator_destination:
        print(
            "test-only enumeration used a different destination",
            file=sys.stderr,
        )
        raise SystemExit(4)
    names = [
        name
        for name in os.environ["QINAO_TEST_EVENTLOG_NAMES"].split(",")
        if name
    ]
    requested_count = int(
        os.environ.get("QINAO_TEST_EVENTLOG_COUNT", str(len(names)))
    )
    names = names[:requested_count]
    if os.environ.get("QINAO_TEST_EVENTLOG_INCLUDE_HOST") == "1":
        names[-1] = os.environ["QINAO_TEST_EVENTLOG_HOST_NAMES"].split(",")[0]
    if os.environ.get("QINAO_TEST_EVENTLOG_OMIT_REPRESENTATIVE") == "1":
        representative = "testInMemoryAppendAssignsSequenceNumber"
        names[names.index(representative)] = "testSyntheticReplacement"
    if os.environ.get("QINAO_TEST_ENUMERATION_JSON_ERROR") == "1":
        document = {
            "errors": ["test-only enumeration destination failure"],
            "values": [
                {
                    "name": "BASDeviceTests",
                    "kind": "target",
                }
            ],
        }
    else:
        document = {
            "values": [
                {
                    "name": "BASDeviceTests",
                    "children": [
                        {
                            "name": "BASEventLogTests",
                            "children": [
                                {"name": f"{name}()"} for name in names
                            ],
                        }
                    ],
                }
            ]
        }
    output = Path(
        arguments[arguments.index("-test-enumeration-output-path") + 1]
    )
    output.write_text(json.dumps(document), encoding="utf-8")
    raise SystemExit(0)
if "-sdk" in arguments:
    sdk = arguments[arguments.index("-sdk") + 1]
    variant = "iphoneos" if sdk == "iphoneos" else "iphonesimulator"
elif actual_destination == expected_simulator_destination:
    variant = "iphonesimulator"
else:
    print("test-only unable to infer build-settings variant", file=sys.stderr)
    raise SystemExit(6)
derived_data = Path(
    arguments[arguments.index("-derivedDataPath") + 1]
)
products = derived_data / "Build" / "Products" / f"Debug-{variant}"
floor = os.environ.get("QINAO_TEST_BUILD_FLOOR", "27.0")
if (
    "build-for-testing" in arguments
    and os.environ.get("QINAO_TEST_CREATE_BUILD_PRODUCTS") == "1"
):
    for wrapper in ("BASDeviceTestApp.app", "BASDeviceTests.xctest"):
        info = products / wrapper / "Info.plist"
        info.parent.mkdir(parents=True, exist_ok=True)
        with info.open("wb") as handle:
            plistlib.dump(
                {
                    "CFBundleIdentifier": (
                        f"test-only.{variant}.{wrapper}"
                    ),
                    "MinimumOSVersion": floor,
                },
                handle,
                sort_keys=True,
            )
if "-showBuildSettings" not in arguments:
    raise SystemExit(0)
print(
    json.dumps(
        [
            {
                "target": "BASDeviceTestApp",
                "buildSettings": {
                    "IPHONEOS_DEPLOYMENT_TARGET": floor,
                    "TARGET_BUILD_DIR": str(products),
                    "WRAPPER_NAME": "BASDeviceTestApp.app",
                },
            },
            {
                "target": "BASDeviceTests",
                "buildSettings": {
                    "IPHONEOS_DEPLOYMENT_TARGET": floor,
                    "TARGET_BUILD_DIR": str(products),
                    "WRAPPER_NAME": "BASDeviceTests.xctest",
                },
            },
        ]
    )
)
"""

FAKE_OTOOL = r"""#!/usr/bin/env python3
import os
import sys
from pathlib import Path

requested_exit = int(os.environ.get("QINAO_TEST_OTOOL_EXIT", "0"))
if requested_exit:
    print("test-only otool failure", file=sys.stderr)
    raise SystemExit(requested_exit)
archive = Path(sys.argv[-1])
platform = 7 if any("simulator" in part for part in archive.parts) else 2
versions = [
    line.strip()
    for line in archive.read_text(encoding="utf-8").splitlines()
    if line.strip()
]
for index, version in enumerate(versions, start=1):
    member_index = (
        1
        if os.environ.get("QINAO_TEST_DUPLICATE_MEMBER_NAMES") == "1"
        else index
    )
    print(f"{archive}(test-only-member-{member_index}.o):")
    if version == "missing":
        continue
    print("Load command 0")
    print("      cmd LC_BUILD_VERSION")
    print("  cmdsize 24")
    print(f" platform {platform}")
    print(f"    minos {version}")
    print("      sdk 27.0")
"""

FAKE_XCRUN = r"""#!/bin/sh
set -eu
if [ "$1" = "otool" ]; then
  shift
  exec "$QINAO_OTOOL" "$@"
fi
if [ "$1" = "simctl" ]; then
  if [ -n "${QINAO_TEST_SIMCTL_JSON:-}" ]; then
    printf '%s\n' "$QINAO_TEST_SIMCTL_JSON"
  else
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"isAvailable":true,"state":"Shutdown","name":"Test Only iPhone","udid":"%s"}]}}\n' "$QINAO_TEST_SIMULATOR_UDID"
  fi
  exit 0
fi
echo "test-only unsupported xcrun tool: $1" >&2
exit 2
"""


class IOS27FloorGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.root = Path(self.temp_directory.name)
        self.tools = self.root / "test-only-tools"
        self.tools.mkdir()
        self.injected_tools = self.root / "injected-only-tools"
        self.injected_tools.mkdir()
        self.runtime_tmp = self.root / "runtime-tmp"
        self.runtime_tmp.mkdir()
        self.rg_log = self.root / "rg-invocations.jsonl"
        self.xcodebuild_log = self.root / "xcodebuild-invocations.jsonl"
        self.real_rg = shutil.which("rg")
        self.assertIsNotNone(self.real_rg)

        self.write("test-only-tools/swift", FAKE_SWIFT, mode=0o755)
        self.write(
            "injected-only-tools/rg",
            FAKE_RG,
            mode=0o755,
        )
        self.write("test-only-tools/xcodebuild", FAKE_XCODEBUILD, mode=0o755)
        self.write("test-only-tools/otool", FAKE_OTOOL, mode=0o755)
        self.write("test-only-tools/xcrun", FAKE_XCRUN, mode=0o755)

        for index, relative_path in enumerate(MANIFESTS):
            self.write(
                relative_path,
                self.manifest(
                    name=f"Fixture{index}",
                    platform_lines='        .iOS("27.0"),',
                ),
            )
        # A pinned third-party manifest may retain its own lower floor. The
        # first-party shipping host, not vendored source, owns this gate.
        self.write(
            "BehavioralAISubstrate/Vendor/TestDependency/Package.swift",
            self.manifest(
                name="TestOnlyVendoredDependency",
                platform_lines="        .iOS(.v13),",
            ),
        )

        self.write(
            "BehavioralAISubstrate/DeviceTestApp/project.yml",
            """
deploymentTarget:
  iOS: "27.0"
packages:
  BehavioralAISubstrate:
    path: ..
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
  BASDeviceTests:
    sources:
      - path: ../Tests/BehavioralAISubstrateTests
        excludes:
          - "ExcludedFixtureTests.swift"
    dependencies:
      - package: BehavioralAISubstrate
        product: BASAppleEdgeWiring
""".lstrip(),
        )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/"
            "BASDeviceTest.xcodeproj/project.pbxproj",
            (
                "IPHONEOS_DEPLOYMENT_TARGET = 27.0;\n"
                "productName = BASAppleEdgeWiring;\n"
                "ABCDEF0123456789ABCDEF01 /* IncludedFixtureTests.swift */ = "
                "{isa = PBXFileReference; lastKnownFileType = "
                "sourcecode.swift; path = IncludedFixtureTests.swift; "
                'sourceTree = "<group>"; };\n'
                "ABCDEF0123456789ABCDEF02 "
                "/* BASEventLogHeadSyntaxAudit.swift */ = "
                "{isa = PBXFileReference; lastKnownFileType = "
                "sourcecode.swift; path = BASEventLogHeadSyntaxAudit.swift; "
                'sourceTree = "<group>"; };\n'
                "ABCDEF0123456789ABCDEF03 /* BASEventLogTests.swift */ = "
                "{isa = PBXFileReference; lastKnownFileType = "
                "sourcecode.swift; path = BASEventLogTests.swift; "
                'sourceTree = "<group>"; };\n'
            ),
        )
        self.write(
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "IncludedFixtureTests.swift",
            "import XCTest\n",
        )
        self.write(
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "BASEventLogHeadSyntaxAudit.swift",
            (
                "#if os(macOS)\n"
                "import SwiftParser\n"
                "import SwiftSyntax\n"
                "enum BASEventLogHeadSyntaxAudit {}\n"
                "#endif\n"
            ),
        )
        self.write(
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "BASEventLogTests.swift",
            self.event_log_tests_fixture(),
        )
        self.write(
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "ExcludedFixtureTests.swift",
            "import XCTest\n",
        )
        for index, relative_path in enumerate(COREAI_IMPORT_FILES):
            guarded_tokens = (
                "\n".join(
                    f"let coreAIToken{token}: {token}? = nil"
                    for token in COREAI_GATED_TOKENS
                )
                if index == 0
                else ""
            )
            self.write(
                "BehavioralAISubstrate/DeviceTestApp/Sources/"
                + relative_path,
                (
                    "#if canImport(CoreAI)\n"
                    "import CoreAI\n"
                    f"{guarded_tokens}\n"
                    "#endif\n"
                ),
            )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/Sources/App/"
            "BASProbeCommon.swift",
            "enum BASProbeCommonFixture {}\n",
        )
        # A version-shaped entitlement value must not be treated as a
        # deployment declaration.
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/Resources/"
            "BASDeviceTestApp.entitlements",
            (
                "<key>com.apple.developer.kernel.increased-memory-limit</key>\n"
                "<string>test-only-18.0-entitlement-value</string>\n"
            ),
        )
        self.write(
            "BehavioralAISubstrate/DeviceTestApp/Resources/Info.plist",
            "<key>BGTaskSchedulerPermittedIdentifiers</key>\n",
        )
        self.write(
            "BehavioralAISubstrate/scripts/build-rust-xcframework.sh",
            self.rust_build_script(),
            mode=0o755,
        )
        self.write(
            "BehavioralAISubstrate/scripts/export-test-app.sh",
            "#!/bin/sh\nxcodebuild -exportArchive \"$@\"\n",
            mode=0o755,
        )

        self.write_xcframework()
        for variant in ("iphoneos", "iphonesimulator"):
            products = (
                self.root
                / "DerivedData"
                / "Build"
                / "Products"
                / f"Debug-{variant}"
            )
            for wrapper in (
                "BASDeviceTestApp.app",
                "BASDeviceTests.xctest",
            ):
                self.write_plist(
                    products / wrapper / "Info.plist",
                    {
                        "CFBundleIdentifier": f"test-only.{variant}.{wrapper}",
                        "MinimumOSVersion": "27.0",
                    },
                )

    def write(
        self,
        relative_path: str | Path,
        contents: str,
        *,
        mode: int = 0o644,
    ) -> Path:
        path = (
            relative_path
            if isinstance(relative_path, Path)
            else self.root / relative_path
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        path.chmod(mode)
        return path

    @staticmethod
    def write_plist(path: Path, value: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as handle:
            plistlib.dump(value, handle, sort_keys=True)

    def write_floor_products(self, derived_data: Path) -> None:
        for variant in ("iphoneos", "iphonesimulator"):
            products = (
                derived_data
                / "Build"
                / "Products"
                / f"Debug-{variant}"
            )
            for wrapper in (
                "BASDeviceTestApp.app",
                "BASDeviceTests.xctest",
            ):
                self.write_plist(
                    products / wrapper / "Info.plist",
                    {
                        "CFBundleIdentifier": (
                            f"test-only.{variant}.{wrapper}"
                        ),
                        "MinimumOSVersion": "27.0",
                    },
                )

    def logged_derived_data_paths(self) -> set[str]:
        paths: set[str] = set()
        for line in self.xcodebuild_log.read_text(
            encoding="utf-8"
        ).splitlines():
            arguments = json.loads(line)
            if "-derivedDataPath" in arguments:
                paths.add(
                    arguments[arguments.index("-derivedDataPath") + 1]
                )
        return paths

    def write_xcframework(
        self,
        *,
        device_versions: tuple[str, ...] = ("27.0",),
        simulator_versions: tuple[str, ...] = ("27.0",),
        simulator_architectures: tuple[str, ...] = ("arm64",),
    ) -> None:
        root = self.root / XCFRAMEWORK
        libraries = [
            {
                "LibraryIdentifier": "ios-arm64",
                "LibraryPath": "libbas_memory_usage_tracker.a",
                "SupportedArchitectures": ["arm64"],
                "SupportedPlatform": "ios",
            },
            {
                "LibraryIdentifier": "ios-arm64-simulator",
                "LibraryPath": "libbas_memory_usage_tracker.a",
                "SupportedArchitectures": list(simulator_architectures),
                "SupportedPlatform": "ios",
                "SupportedPlatformVariant": "simulator",
            },
        ]
        self.write_plist(
            root / "Info.plist",
            {
                "AvailableLibraries": libraries,
                "CFBundlePackageType": "XFWK",
                "XCFrameworkFormatVersion": "1.0",
            },
        )
        self.write(
            root / "ios-arm64" / "libbas_memory_usage_tracker.a",
            "\n".join(device_versions) + "\n",
        )
        self.write(
            root
            / "ios-arm64-simulator"
            / "libbas_memory_usage_tracker.a",
            "\n".join(simulator_versions) + "\n",
        )

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

    @staticmethod
    def event_log_tests_fixture() -> str:
        runtime_before_host = IOS_EVENT_LOG_TESTS[:8]
        runtime_after_host = IOS_EVENT_LOG_TESTS[8:]
        lines = [
            "import XCTest",
            "",
            "final class BASEventLogTests: XCTestCase {",
            "    #if os(macOS)",
            "    private func removingSwiftLineComments() {}",
            "    private func regexCaptures() {}",
            "    private func regexMatchCount() {}",
            "    private func eventLogHeadDeclarationKinds() {}",
            "    private func eventLogHeadExtensionCount() {}",
            "    private func normalizedWhitespace() {}",
            "    #endif",
            "",
            "    override func setUpWithError() throws {}",
            "    override func tearDownWithError() throws {}",
            "    private func makeEntry() {}",
        ]
        lines.extend(
            f"    func {name}() {{}}" for name in runtime_before_host
        )
        lines.extend(
            [
                "",
                "    #if os(macOS)",
                f"    func {HOST_EVENT_LOG_TESTS[0]}() {{}}",
                f"    func {HOST_EVENT_LOG_TESTS[1]}() {{}}",
                f"    func {HOST_EVENT_LOG_TESTS[2]}() {{",
                '        let fixture = """',
                "        public static func genesis() {}",
                '        """',
                "    }",
                "    #endif",
                "",
            ]
        )
        lines.extend(
            f"    func {name}() {{}}" for name in runtime_after_host
        )
        lines.extend(["}", ""])
        return "\n".join(lines)

    @staticmethod
    def rust_build_script(
        *,
        floor: str = "27.0",
        include_toolchain_pin: bool = True,
        include_rust_source_preflight: bool = True,
        include_build_std: bool = True,
    ) -> str:
        lines = [
            "#!/bin/sh",
            f'export IPHONEOS_DEPLOYMENT_TARGET="{floor}"',
            f'export IPHONESIMULATOR_DEPLOYMENT_TARGET="{floor}"',
        ]
        if include_toolchain_pin:
            lines.append(
                'export RUSTUP_TOOLCHAIN="1.96.0-aarch64-apple-darwin"'
            )
        if include_rust_source_preflight:
            lines.extend(
                [
                    'PINNED_RUST_SOURCE="$(rustc --print sysroot)/'
                    'lib/rustlib/src/rust/library/Cargo.toml"',
                    'test -f "${PINNED_RUST_SOURCE}"',
                ]
            )
        if include_build_std:
            lines.append(
                "RUSTC_BOOTSTRAP=1 cargo build "
                "-Z build-std=std,panic_abort "
                "--target aarch64-apple-ios"
            )
        return "\n".join(lines) + "\n"

    def run_gate(
        self,
        *,
        overrides: dict[str, str] | None = None,
        unset: tuple[str, ...] = (),
    ) -> subprocess.CompletedProcess[str]:
        self.rg_log.write_text("", encoding="utf-8")
        self.xcodebuild_log.write_text("", encoding="utf-8")
        environment = dict(os.environ)
        environment.update(
            {
                "PATH": f"{self.tools}:{environment['PATH']}",
                "QINAO_SWIFT": str(self.tools / "swift"),
                "QINAO_RG": str((self.injected_tools / "rg").resolve()),
                "QINAO_XCODEBUILD": str(self.tools / "xcodebuild"),
                "QINAO_OTOOL": str(self.tools / "otool"),
                "QINAO_IOS27_DERIVED_DATA_PATH": str(
                    self.root / "DerivedData"
                ),
                "QINAO_TEST_ROOT": str(self.root),
                "QINAO_TEST_EVENTLOG_NAMES": ",".join(
                    IOS_EVENT_LOG_TESTS
                ),
                "QINAO_TEST_EVENTLOG_HOST_NAMES": ",".join(
                    HOST_EVENT_LOG_TESTS
                ),
                "QINAO_TEST_SIMULATOR_UDID": (
                    "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                ),
                "QINAO_IOS27_ENUMERATION_DESTINATION": (
                    "platform=iOS Simulator,"
                    "id=AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
                ),
                "QINAO_TEST_REAL_RG": str(self.real_rg),
                "QINAO_TEST_RG_LOG": str(self.rg_log),
                "QINAO_TEST_XCODEBUILD_LOG": str(self.xcodebuild_log),
                "QINAO_TEST_REQUIRE_CONCRETE_SIMULATOR": "1",
                "QINAO_TEST_REJECT_SIMULATOR_SDK_OVERRIDE": "1",
            }
        )
        environment.update(overrides or {})
        for name in unset:
            environment.pop(name, None)
        return subprocess.run(
            ["bash", str(GATE), str(self.root)],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_valid_ios27_fixture_passes_without_scanning_vendor_or_entitlements(
        self,
    ) -> None:
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_injected_rg_classifies_no_match_and_tool_error(self) -> None:
        cases = (
            (
                "no-match",
                {
                    "QINAO_TEST_RG_FAIL_CALL": "1",
                    "QINAO_TEST_RG_FAIL_STATUS": "1",
                },
                "has no deployment declaration",
            ),
            (
                "tool-error",
                {
                    "QINAO_TEST_RG_FAIL_CALL": "1",
                    "QINAO_TEST_RG_FAIL_STATUS": "2",
                },
                "scanner failed with exit 2",
            ),
            (
                "inverse-tool-error",
                {
                    "QINAO_TEST_RG_FAIL_CALL": "2",
                    "QINAO_TEST_RG_FAIL_STATUS": "2",
                },
                "scanner failed with exit 2",
            ),
            (
                "required-marker-tool-error",
                {
                    "QINAO_TEST_RG_FAIL_CALL": "7",
                    "QINAO_TEST_RG_FAIL_STATUS": "2",
                },
                "scanner failed with exit 2",
            ),
        )
        for label, overrides, diagnostic in cases:
            with self.subTest(label=label):
                result = self.run_gate(overrides=overrides)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_rg_override_rejects_empty_multiword_relative_and_symlink_values(
        self,
    ) -> None:
        symlink = self.injected_tools / "rg-alias"
        symlink.symlink_to(self.injected_tools / "rg")
        cases = {
            "empty": "",
            "multiword": f"{self.injected_tools / 'rg'} --hidden",
            "relative": "injected-only-tools/rg",
            "symlink": str(symlink),
        }
        for label, value in cases.items():
            with self.subTest(label=label):
                result = self.run_gate(overrides={"QINAO_RG": value})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("QINAO_RG", result.stderr)

        default_result = self.run_gate(unset=("QINAO_RG",))
        self.assertEqual(default_result.returncode, 0, default_result.stderr)

    def test_release_scan_uses_injected_rg_and_rejects_exit_two(self) -> None:
        valid = self.run_gate()
        self.assertEqual(valid.returncode, 0, valid.stderr)
        call_count = len(
            self.rg_log.read_text(encoding="utf-8").splitlines()
        )
        self.assertGreater(call_count, 7)

        result = self.run_gate(
            overrides={
                "QINAO_TEST_RG_FAIL_CALL": str(call_count),
                "QINAO_TEST_RG_FAIL_STATUS": "2",
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release fallback scanner failed with exit 2", result.stderr)

    def test_default_derived_data_path_is_fresh_for_every_run(self) -> None:
        overrides = {
            "QINAO_IOS27_DERIVED_DATA_PATH": "",
            "QINAO_TEST_CREATE_BUILD_PRODUCTS": "1",
            "TMPDIR": str(self.runtime_tmp),
        }
        first = self.run_gate(overrides=overrides)
        self.assertEqual(first.returncode, 0, first.stderr)
        first_paths = self.logged_derived_data_paths()
        self.assertEqual(len(first_paths), 1)

        second = self.run_gate(overrides=overrides)
        self.assertEqual(second.returncode, 0, second.stderr)
        second_paths = self.logged_derived_data_paths()
        self.assertEqual(len(second_paths), 1)

        self.assertNotEqual(first_paths, second_paths)

    def test_explicit_derived_data_override_is_preserved(self) -> None:
        expected = str(self.root / "DerivedData")

        result = self.run_gate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.logged_derived_data_paths(), {expected})

    def test_default_path_cannot_reuse_stale_legacy_derived_data(self) -> None:
        stale = self.runtime_tmp / "qinao-ios27-floor-derived-data"
        self.write_floor_products(stale)

        result = self.run_gate(
            overrides={
                "QINAO_IOS27_DERIVED_DATA_PATH": "",
                "TMPDIR": str(self.runtime_tmp),
            }
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("built product is missing", result.stderr)

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
        project_yml = (
            self.root
            / "BehavioralAISubstrate/DeviceTestApp/project.yml"
        )
        generated_project = (
            self.root
            / "BehavioralAISubstrate/DeviceTestApp/"
            "BASDeviceTest.xcodeproj/project.pbxproj"
        )
        valid_yml = project_yml.read_text(encoding="utf-8")
        valid_project = generated_project.read_text(encoding="utf-8")
        cases = {
            "missing-floor": (
                valid_yml,
                "productName = BASAppleEdgeWiring;\n",
                "generated project",
            ),
            "missing-imported-product-in-spec": (
                valid_yml.replace(
                    "        product: BASAppleEdgeWiring\n",
                    "        product: BASHostKit\n",
                ),
                valid_project,
                "BASAppleEdgeWiring",
            ),
            "missing-imported-product-in-generated-project": (
                valid_yml,
                valid_project.replace(
                    "productName = BASAppleEdgeWiring;\n",
                    "",
                ),
                "BASAppleEdgeWiring",
            ),
            "forbidden-swift-syntax-products-in-spec": (
                valid_yml.replace(
                    "        product: BASAppleEdgeWiring\n",
                    (
                        "        product: BASAppleEdgeWiring\n"
                        "      - package: BehavioralAISubstrate\n"
                        "        product: SwiftParser\n"
                        "      - package: BehavioralAISubstrate\n"
                        "        product: SwiftSyntax\n"
                    ),
                ),
                valid_project,
                "must not declare SwiftParser or SwiftSyntax",
            ),
            "forbidden-swift-syntax-products-in-generated-project": (
                valid_yml,
                (
                    valid_project
                    + "productName = SwiftParser;\n"
                    + "productName = SwiftSyntax;\n"
                ),
                "must not contain SwiftParser or SwiftSyntax",
            ),
            "direct-stripped-swift-syntax-root": (
                valid_yml.replace(
                    "  BehavioralAISubstrate:\n    path: ..\n",
                    (
                        "  BehavioralAISubstrate:\n"
                        "    path: ..\n"
                        "  SwiftSyntax:\n"
                        "    path: ../Vendor/swift-syntax\n"
                    ),
                ),
                valid_project,
                "direct SwiftSyntax package root",
            ),
            "missing-spec-included-source": (
                valid_yml,
                valid_project.replace(
                    "ABCDEF0123456789ABCDEF01 "
                    "/* IncludedFixtureTests.swift */ = "
                    "{isa = PBXFileReference; lastKnownFileType = "
                    "sourcecode.swift; path = IncludedFixtureTests.swift; "
                    'sourceTree = "<group>"; };\n',
                    "",
                ),
                "IncludedFixtureTests.swift",
            ),
            "excluded-source-leaked-into-project": (
                valid_yml,
                (
                    valid_project
                    + "ABCDEF0123456789ABCDEF02 "
                    "/* ExcludedFixtureTests.swift */ = "
                    "{isa = PBXFileReference; lastKnownFileType = "
                    "sourcecode.swift; path = ExcludedFixtureTests.swift; "
                    'sourceTree = "<group>"; };\n'
                ),
                "ExcludedFixtureTests.swift",
            ),
        }
        for label, (yml, project, diagnostic) in cases.items():
            with self.subTest(label=label):
                project_yml.write_text(yml, encoding="utf-8")
                generated_project.write_text(project, encoding="utf-8")

                result = self.run_gate()

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

        self.assertEqual(len(HOST_EVENT_LOG_TESTS), 3)
        self.assertEqual(len(IOS_EVENT_LOG_TESTS), 31)
        audit_path = (
            self.root
            / "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
            "BASEventLogHeadSyntaxAudit.swift"
        )
        event_log_path = audit_path.with_name("BASEventLogTests.swift")
        valid_audit = audit_path.read_text(encoding="utf-8")
        valid_event_log = event_log_path.read_text(encoding="utf-8")
        unguarded_host_tests = valid_event_log.replace(
            (
                "    #if os(macOS)\n"
                f"    func {HOST_EVENT_LOG_TESTS[0]}() {{}}\n"
            ),
            f"    func {HOST_EVENT_LOG_TESTS[0]}() {{}}\n",
        ).replace(
            (
                '        """\n'
                "    }\n"
                "    #endif\n"
            ),
            '        """\n'
            "    }\n",
        )
        runtime_name = "testInMemoryAppendAssignsSequenceNumber"
        source_cases = {
            "syntax-audit-not-macos-only": (
                valid_audit.replace(
                    "#if os(macOS)\n",
                    "",
                    1,
                ).replace(
                    "#endif\n",
                    "",
                    1,
                ),
                valid_event_log,
                "BASEventLogHeadSyntaxAudit.swift must be entirely guarded",
            ),
            "host-helpers-not-macos-only": (
                valid_audit,
                valid_event_log.replace(
                    "    #if os(macOS)\n",
                    "",
                    1,
                ).replace(
                    "    #endif\n",
                    "",
                    1,
                ),
                "host helper removingSwiftLineComments must be guarded",
            ),
            "host-gates-not-macos-only": (
                valid_audit,
                unguarded_host_tests,
                f"host gate {HOST_EVENT_LOG_TESTS[0]} must be guarded",
            ),
            "host-gate-missing": (
                valid_audit,
                valid_event_log.replace(
                    f"    func {HOST_EVENT_LOG_TESTS[1]}() {{}}\n",
                    "",
                ),
                f"host gate {HOST_EVENT_LOG_TESTS[1]} is missing",
            ),
            "runtime-test-accidentally-macos-only": (
                valid_audit,
                valid_event_log.replace(
                    f"    func {runtime_name}() {{}}\n",
                    (
                        "    #if os(macOS)\n"
                        f"    func {runtime_name}() {{}}\n"
                        "    #endif\n"
                    ),
                ),
                "expected 31 iOS BASEventLogTests",
            ),
        }
        for label, (audit, event_log, diagnostic) in source_cases.items():
            with self.subTest(label=label):
                project_yml.write_text(valid_yml, encoding="utf-8")
                generated_project.write_text(
                    valid_project,
                    encoding="utf-8",
                )
                audit_path.write_text(audit, encoding="utf-8")
                event_log_path.write_text(event_log, encoding="utf-8")

                result = self.run_gate()

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)

        with self.subTest(label="coreai-gated-token-escaped"):
            project_yml.write_text(valid_yml, encoding="utf-8")
            generated_project.write_text(valid_project, encoding="utf-8")
            audit_path.write_text(valid_audit, encoding="utf-8")
            event_log_path.write_text(valid_event_log, encoding="utf-8")
            escaped = (
                self.root
                / "BehavioralAISubstrate/DeviceTestApp/Sources/App/"
                "BASProbeCommon.swift"
            )
            escaped.write_text(
                "\n".join(
                    f"let escaped{token}: {token}? = nil"
                    for token in COREAI_GATED_TOKENS
                )
                + "\n",
                encoding="utf-8",
            )

            result = self.run_gate()

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "CoreAI-gated token escapes #if canImport(CoreAI)",
                result.stderr,
            )
            for token in COREAI_GATED_TOKENS:
                self.assertIn(token, result.stderr)

    def test_build_rust_script_floor_and_build_std_contract_is_required(
        self,
    ) -> None:
        cases = {
            "legacy-floor": (
                self.rust_build_script(floor="18.0"),
                "18.0",
            ),
            "missing-rust-src-preflight": (
                self.rust_build_script(
                    include_rust_source_preflight=False,
                ),
                "rust-src",
            ),
            "missing-pinned-toolchain": (
                self.rust_build_script(include_toolchain_pin=False),
                "1.96.0-aarch64-apple-darwin",
            ),
            "missing-build-std": (
                self.rust_build_script(include_build_std=False),
                "build-std",
            ),
        }
        for label, (contents, diagnostic) in cases.items():
            with self.subTest(label=label):
                self.write(
                    "BehavioralAISubstrate/scripts/"
                    "build-rust-xcframework.sh",
                    contents,
                    mode=0o755,
                )

                result = self.run_gate()

                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "build-rust-xcframework.sh",
                    result.stderr,
                )
                self.assertIn(diagnostic, result.stderr)

    def test_other_build_or_export_script_legacy_floor_is_rejected(self) -> None:
        self.write(
            "BehavioralAISubstrate/scripts/export-test-app.sh",
            (
                "#!/bin/sh\n"
                'IPHONEOS_DEPLOYMENT_TARGET="18.0" '
                "xcodebuild -exportArchive \"$@\"\n"
            ),
            mode=0o755,
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("export-test-app.sh", result.stderr)
        self.assertIn("18.0", result.stderr)

    def test_resolved_device_and_simulator_build_settings_must_be_ios27(
        self,
    ) -> None:
        result = self.run_gate(
            overrides={"QINAO_TEST_BUILD_FLOOR": "18.0"}
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("resolved", result.stderr)
        self.assertIn("18.0", result.stderr)

        discovery_cases = {
            "only-30-ios-tests": (
                {"QINAO_TEST_EVENTLOG_COUNT": "30"},
                "discovered 30 BASEventLogTests; expected 31",
            ),
            "host-gate-leaked-into-ios": (
                {"QINAO_TEST_EVENTLOG_INCLUDE_HOST": "1"},
                "discovered host-only BASEventLogTests",
            ),
            "representative-runtime-test-missing": (
                {"QINAO_TEST_EVENTLOG_OMIT_REPRESENTATIVE": "1"},
                "testInMemoryAppendAssignsSequenceNumber",
            ),
            "process-zero-json-error": (
                {"QINAO_TEST_ENUMERATION_JSON_ERROR": "1"},
                "test enumeration reported errors",
            ),
            "generic-simulator-destination": (
                {
                    "QINAO_IOS27_ENUMERATION_DESTINATION": (
                        "generic/platform=iOS Simulator"
                    )
                },
                "must use platform=iOS Simulator,id=<UDID>",
            ),
            "override-udid-not-available": (
                {
                    "QINAO_IOS27_ENUMERATION_DESTINATION": (
                        "platform=iOS Simulator,"
                        "id=FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
                    )
                },
                "override is not an available iOS 27+ simulator",
            ),
            "no-eligible-simulator": (
                {
                    "QINAO_IOS27_ENUMERATION_DESTINATION": "",
                    "QINAO_TEST_SIMCTL_JSON": (
                        '{"devices":{"com.apple.CoreSimulator.'
                        'SimRuntime.iOS-26-0":[{"isAvailable":true,'
                        '"state":"Shutdown","name":"Legacy",'
                        '"udid":"AAAAAAAA-BBBB-CCCC-DDDD-'
                        'EEEEEEEEEEEE"}]}}'
                    ),
                },
                "no available iOS 27+ simulator",
            ),
            "destination-is-not-arm64": (
                {"QINAO_TEST_DESTINATION_ARCH": "x86_64"},
                "is not an arm64 iOS 27+ simulator destination",
            ),
        }
        for label, (overrides, diagnostic) in discovery_cases.items():
            with self.subTest(label=label):
                discovery_result = self.run_gate(overrides=overrides)

                self.assertNotEqual(discovery_result.returncode, 0)
                self.assertIn(diagnostic, discovery_result.stderr)

    def test_each_built_product_minimum_os_version_is_checked(self) -> None:
        plist = (
            self.root
            / "DerivedData/Build/Products/Debug-iphonesimulator/"
            "BASDeviceTests.xctest/Info.plist"
        )
        self.write_plist(
            plist,
            {
                "CFBundleIdentifier": "test-only.legacy-product",
                "MinimumOSVersion": "18.0",
            },
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("BASDeviceTests.xctest", result.stderr)
        self.assertIn("MinimumOSVersion", result.stderr)

    def test_missing_built_product_is_not_vacuously_accepted(self) -> None:
        product = (
            self.root
            / "DerivedData/Build/Products/Debug-iphoneos/"
            "BASDeviceTestApp.app"
        )
        product.rename(product.with_name("removed.app"))

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("built product", result.stderr)
        self.assertIn("BASDeviceTestApp.app", result.stderr)

    def test_device_archive_minos_18_is_rejected(self) -> None:
        self.write_xcframework(device_versions=("18.0",))

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ios-arm64", result.stderr)
        self.assertIn("minos 18.0", result.stderr)

    def test_simulator_archive_minos_18_is_rejected(self) -> None:
        self.write_xcframework(simulator_versions=("18.0",))

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ios-arm64-simulator", result.stderr)
        self.assertIn("minos 18.0", result.stderr)

        self.write_xcframework(
            simulator_architectures=("arm64", "x86_64"),
        )

        architecture_result = self.run_gate()

        self.assertNotEqual(architecture_result.returncode, 0)
        self.assertIn("must remain arm64-only", architecture_result.stderr)

    def test_every_macho_member_in_an_archive_is_checked(self) -> None:
        self.write_xcframework(simulator_versions=("27.0", "18.0"))

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("test-only-member-2.o", result.stderr)
        self.assertIn("minos 18.0", result.stderr)

        self.write_xcframework(simulator_versions=("27.0", "missing"))

        duplicate_result = self.run_gate(
            overrides={"QINAO_TEST_DUPLICATE_MEMBER_NAMES": "1"}
        )

        self.assertNotEqual(duplicate_result.returncode, 0)
        self.assertIn("test-only-member-1.o", duplicate_result.stderr)
        self.assertIn("no LC_BUILD_VERSION", duplicate_result.stderr)

    def test_device_and_simulator_archives_are_both_required(self) -> None:
        archive = (
            self.root
            / XCFRAMEWORK
            / "ios-arm64-simulator"
            / "libbas_memory_usage_tracker.a"
        )
        archive.unlink()

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ios-arm64-simulator", result.stderr)
        self.assertIn("missing", result.stderr)

    def test_otool_error_is_not_reported_as_no_macho_match(self) -> None:
        result = self.run_gate(
            overrides={"QINAO_TEST_OTOOL_EXIT": "2"}
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("otool", result.stderr)
        self.assertIn("exit 2", result.stderr)

    def test_xcodebuild_error_is_not_reported_as_no_settings(self) -> None:
        result = self.run_gate(
            overrides={"QINAO_TEST_XCODEBUILD_EXIT": "2"}
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xcodebuild", result.stderr)
        self.assertIn("exit 2", result.stderr)


if __name__ == "__main__":
    unittest.main()
