from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path


CHECKER_PATH = Path(__file__).resolve().parents[2] / "scripts" / "check_rojo_artifact.py"
SPEC = importlib.util.spec_from_file_location("check_rojo_artifact", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CHECKER
SPEC.loader.exec_module(CHECKER)

VERIFIER_PATH = Path(__file__).with_name("verify_project_profiles.py")
VERIFIER_SPEC = importlib.util.spec_from_file_location(
    "verify_project_profiles", VERIFIER_PATH
)
assert VERIFIER_SPEC is not None and VERIFIER_SPEC.loader is not None
VERIFIER = importlib.util.module_from_spec(VERIFIER_SPEC)
sys.modules[VERIFIER_SPEC.name] = VERIFIER
VERIFIER_SPEC.loader.exec_module(VERIFIER)


def sourcemap(*, runtime: bool = True, preview: bool = False) -> dict[str, object]:
    children: list[dict[str, object]] = []
    if runtime:
        children.append({"name": "Runtime", "className": "ModuleScript"})
    if preview:
        children.append({"name": "Preview.story", "className": "ModuleScript"})
    return {
        "name": "Fixture",
        "className": "DataModel",
        "children": [
            {
                "name": "ReplicatedStorage",
                "className": "ReplicatedStorage",
                "children": [{"name": "Client", "className": "Folder", "children": children}],
            }
        ],
    }


def rbxlx(*, runtime: bool = True, preview: bool = False) -> str:
    modules = ""
    if runtime:
        modules += '<Item class="ModuleScript"><Properties><string name="Name">Runtime</string></Properties></Item>'
    if preview:
        modules += '<Item class="ModuleScript"><Properties><string name="Name">Preview.story</string></Properties></Item>'
    return f'''<roblox version="4">
<Item class="DataModel"><Properties><string name="Name">Fixture</string></Properties>
  <Item class="ReplicatedStorage"><Properties><string name="Name">ReplicatedStorage</string></Properties>
    <Item class="Folder"><Properties><string name="Name">Client</string></Properties>{modules}</Item>
  </Item>
</Item>
</roblox>'''


class ArtifactContractRegressionTests(unittest.TestCase):
    def assert_contract_result(
        self,
        expected_failures: int,
        *,
        map_runtime: bool = True,
        map_preview: bool = False,
        place_runtime: bool = True,
        place_preview: bool = False,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            map_path = root / "release-sourcemap.json"
            place_path = root / "release.rbxlx"
            map_path.write_text(
                json.dumps(sourcemap(runtime=map_runtime, preview=map_preview)), encoding="utf-8"
            )
            place_path.write_text(
                rbxlx(runtime=place_runtime, preview=place_preview), encoding="utf-8"
            )
            failures = CHECKER.check_artifacts(
                {
                    "sourcemap": CHECKER.read_sourcemap(map_path),
                    "place": CHECKER.read_rbxlx(place_path),
                },
                required_paths=("ReplicatedStorage/Client/Runtime",),
                forbidden_fragments=(".story",),
            )
            self.assertEqual(expected_failures, len(failures), failures)

    def test_detects_retention_loss_and_story_leak_in_built_place(self) -> None:
        self.assert_contract_result(1, place_runtime=False)
        self.assert_contract_result(1, place_preview=True)

    def test_accepts_retained_runtime_and_excluded_story(self) -> None:
        self.assert_contract_result(0)


class ProjectProfileContractTests(unittest.TestCase):
    @staticmethod
    def artifacts(paths: set[str]) -> dict[str, object]:
        view = CHECKER.ArtifactView(
            tuple(sorted(paths)),
            Counter({"ReplicatedStorage": 1, "ServerScriptService": 1}),
        )
        return {"sourcemap": view, "place": view}

    def assert_missing_in_both_artifacts(
        self, failures: list[str], missing_paths: tuple[str, ...]
    ) -> None:
        self.assertEqual(2 * len(missing_paths), len(failures), failures)
        for artifact_name in ("sourcemap", "place"):
            for missing_path in missing_paths:
                self.assertTrue(
                    any(
                        failure.startswith(f"{artifact_name}:") and repr(missing_path) in failure
                        for failure in failures
                    ),
                    (artifact_name, missing_path, failures),
                )

    def test_release_rejects_runtime_loss_when_entrypoints_remain(self) -> None:
        lost_runtime = (
            "ReplicatedStorage/Shared/Network/Client",
            "ReplicatedStorage/Shared/Network/Server",
            "ReplicatedStorage/Shared/Network/Types",
        )
        paths = set(VERIFIER.RUNTIME_REQUIRED_PATHS)
        for path in lost_runtime:
            paths.remove(path)
        self.assertIn("ReplicatedStorage/ClientMain", paths)
        self.assertIn("ServerScriptService/ServerMain", paths)

        failures = VERIFIER.profile_failures(
            CHECKER,
            self.artifacts(paths),
            required_paths=VERIFIER.RUNTIME_REQUIRED_PATHS,
            forbidden_fragments=VERIFIER.RELEASE_FORBIDDEN_FRAGMENTS,
        )
        self.assert_missing_in_both_artifacts(failures, lost_runtime)

    def test_release_rejects_inventory_loss_when_entrypoints_remain(self) -> None:
        lost_inventory = (
            "ReplicatedStorage/Client/Inventory",
            "ReplicatedStorage/Shared/Inventory/Definitions",
            "ReplicatedStorage/Shared/Inventory/PlayerData",
            "ReplicatedStorage/Shared/Inventory/PlayerDataSchema",
            "ReplicatedStorage/Shared/Inventory/Types",
            "ServerScriptService/Server/Inventory",
        )
        paths = set(VERIFIER.RUNTIME_REQUIRED_PATHS)
        for path in lost_inventory:
            paths.remove(path)
        self.assertIn("ReplicatedStorage/ClientMain", paths)
        self.assertIn("ServerScriptService/ServerMain", paths)

        failures = VERIFIER.profile_failures(
            CHECKER,
            self.artifacts(paths),
            required_paths=VERIFIER.RUNTIME_REQUIRED_PATHS,
            forbidden_fragments=VERIFIER.RELEASE_FORBIDDEN_FRAGMENTS,
        )
        self.assert_missing_in_both_artifacts(failures, lost_inventory)


if __name__ == "__main__":
    unittest.main()
