# Roblox API definitions

`globalTypes.d.luau` is a vendored generated input for standalone `luau-lsp analyze` runs.

- Source: <https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.0/scripts/globalTypes.d.luau>
- luau-lsp pin: `JohnnyMorganz/luau-lsp@1.70.0` in `rokit.toml`
- SHA-256: `2B0DF788DC3FD1B572E71EE7FE9E1C55CC23882AFBD5024AECDEC30D9BD7520F`

Do not hand-edit this file. When the luau-lsp pin changes, download the definitions from the matching release tag, update the checksum and source URL here, then run `lute run scripts/verify.luau`.

The repository-root `roblox.yml` is the corresponding project-local Selene standard library. It was generated with the pinned Selene 0.28.0 by running `selene generate-roblox-std` from the repository root; its SHA-256 is `E6F87E583DAA7BB4D089B4C0301892AB5325DEB2CA888FAF27B46C5BE501DC4E`. Commit refreshed output and update the checksum when Roblox API changes need to be recognized. Keeping it in the repository prevents a fresh CI worker from depending on a machine-local Selene cache.
