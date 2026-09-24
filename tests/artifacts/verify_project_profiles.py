#!/usr/bin/env python3
"""Build and verify the project's development and release profiles."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path
from types import ModuleType


REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACT_ROOT = REPO_ROOT / ".verify" / "profiles"
CHECKER_PATH = REPO_ROOT / "scripts" / "check_rojo_artifact.py"

RUNTIME_REQUIRED_PATHS = (
    "ReplicatedStorage/ClientMain",
    "ReplicatedStorage/Client/Inventory",
    "ReplicatedStorage/Shared/Inventory/Definitions",
    "ReplicatedStorage/Shared/Inventory/PlayerData",
    "ReplicatedStorage/Shared/Inventory/PlayerDataSchema",
    "ReplicatedStorage/Shared/Inventory/Types",
    "ReplicatedStorage/Shared/Network/Client",
    "ReplicatedStorage/Shared/Network/Server",
    "ReplicatedStorage/Shared/Network/Types",
    "ServerScriptService/Server/Inventory",
    "ServerScriptService/ServerMain",
)

DEVELOPMENT_REQUIRED_PATHS = RUNTIME_REQUIRED_PATHS

PROTOTYPE_FORBIDDEN_FRAGMENTS = ("/WorldInspection", "/WorldLoot")
RELEASE_FORBIDDEN_FRAGMENTS = (*PROTOTYPE_FORBIDDEN_FRAGMENTS, ".story")


def load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("check_rojo_artifact", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load repository artifact checker: {CHECKER_PATH}")
    checker = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = checker
    spec.loader.exec_module(checker)
    return checker


def run_rojo(rojo: str, action: str, profile: str, output: Path) -> None:
    result = subprocess.run(
        [rojo, action, profile, "--output", str(output)],
        cwd=REPO_ROOT,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"rojo {action} failed for {profile}")


def build_profile(rojo: str, profile: str, label: str) -> tuple[Path, Path]:
    sourcemap = ARTIFACT_ROOT / f"{label}-sourcemap.json"
    place = ARTIFACT_ROOT / f"{label}.rbxlx"
    run_rojo(rojo, "sourcemap", profile, sourcemap)
    run_rojo(rojo, "build", profile, place)
    return sourcemap, place


def profile_failures(
    checker: ModuleType,
    artifacts: dict[str, object],
    *,
    required_paths: tuple[str, ...],
    forbidden_fragments: tuple[str, ...] = (),
) -> list[str]:
    return checker.check_artifacts(
        artifacts,
        required_paths=required_paths,
        forbidden_fragments=forbidden_fragments,
        singleton_classes=("ReplicatedStorage", "ServerScriptService"),
    )


def check_profile(
    checker: ModuleType,
    *,
    label: str,
    sourcemap: Path,
    place: Path,
    required_paths: tuple[str, ...],
    forbidden_fragments: tuple[str, ...] = (),
) -> bool:
    failures = profile_failures(
        checker,
        {
            "sourcemap": checker.read_sourcemap(sourcemap),
            "place": checker.read_rbxlx(place),
        },
        required_paths=required_paths,
        forbidden_fragments=forbidden_fragments,
    )
    if failures:
        for failure in failures:
            print(f"{label}: {failure}", file=sys.stderr)
        return False
    views = (checker.read_sourcemap(sourcemap), checker.read_rbxlx(place))
    print(
        f"{label}: OK ({len(views[0].paths)} sourcemap instances, "
        f"{len(views[1].paths)} place instances)"
    )
    return True


def main() -> int:
    rojo = shutil.which("rojo")
    if rojo is None:
        print("project profiles: rojo is not installed or not on PATH", file=sys.stderr)
        return 2

    ARTIFACT_ROOT.mkdir(parents=True, exist_ok=True)
    checker = load_checker()
    try:
        development_map, development_place = build_profile(
            rojo, "development.project.json", "development"
        )
        development_ok = check_profile(
            checker,
            label="development",
            sourcemap=development_map,
            place=development_place,
            required_paths=DEVELOPMENT_REQUIRED_PATHS,
            forbidden_fragments=PROTOTYPE_FORBIDDEN_FRAGMENTS,
        )

        release_map, release_place = build_profile(rojo, "release.project.json", "release")
        release_ok = check_profile(
            checker,
            label="release",
            sourcemap=release_map,
            place=release_place,
            required_paths=RUNTIME_REQUIRED_PATHS,
            forbidden_fragments=RELEASE_FORBIDDEN_FRAGMENTS,
        )
    except (OSError, RuntimeError, ValueError) as error:
        print(f"project profiles: {error}", file=sys.stderr)
        return 2

    if not development_ok or not release_ok:
        return 1
    print("PROJECT_PROFILE_VERIFY_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
