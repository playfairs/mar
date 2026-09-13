# mar

An indexed terminal file manager written in Haskell.

mar combines a keyboard-driven three-pane browser with a persistent SQLite filesystem index. The index is optional for browsing, while global search uses it when available.

## Development

```sh
nix develop
nix build
nix flake check
nix fmt
```

Run the browser with `nix run`, or use the command-line interface:

```sh
mar .
mar search "nox"
mar index ~/Projects
mar daemon
```

The initial implementation keeps configuration in `~/.config/mar/config` and the index in `~/.local/share/mar/index.sqlite3`.

## Layout

The executable lives under `app/mar`. Library modules are grouped by subsystem under `src/Mar`, with tests mirroring those boundaries.
