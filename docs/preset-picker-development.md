# Preset picker development workflow

The preset picker is a development-only interactive preview. `development.project.json` includes its direct-child client lifecycle root, so the existing `ClientMain` and ModuleLoader start it through the normal client path. `release.project.json` derives from the same complete mapping and excludes the bootstrap, the `PresetPickerDemo` implementation, and all authored UI Labs `*.story.luau` and `*.storybook.luau` files. It also excludes the dedicated Loadout story factory while retaining the Loadout runtime.

The mounted demo uses Charm as its domain state, mirrors Charm snapshots into one Fusion value, and renders the view through Fusion 0.3. A Janitor owns one protected composite teardown. The composite disconnects the Charm producer before cleaning the Fusion scope, attempts both steps when either throws, supports repeated destruction, and prevents later Charm writes from reaching a disposed Fusion graph.

Build and inspect the development place with:

```powershell
rojo build development.project.json --output .verify/preset-picker-development.rbxlx
```

Open that place in Studio and start a client play session. The normal loader creates `PlayerGui.PresetPickerDevelopmentPreview`, marked with the `DevelopmentOnly` attribute. Confirm the `LOADOUT PRESETS` marker before testing the search box and preset buttons with real pointer and keyboard input. Stop only the play session started for this check.

Verify both development inclusion and release exclusion with:

```sh
python tests/artifacts/verify_preset_picker_profiles.py
```

The repository-contained Python 3 check generates text place files and sourcemaps below `.verify/preset-picker-profiles`. It requires the normal client and server sentinels, the complete demo and authored story set in development, and the Loadout runtime in release. It forbids the demo plus every authored story and its dedicated factory in release, and asserts one `ReplicatedStorage` and one `ServerScriptService` in each artifact. The checker uses only the Python standard library and the repository's pinned Rojo executable on `PATH`.
