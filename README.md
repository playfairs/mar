# mar

mar is a fast local filesystem indexer and search CLI written in Haskell. It maintains a persistent SQLite index in the user's XDG data directory and never starts an interactive terminal UI.

## Development

```sh
nix develop
nix build
nix flake check
nix fmt
```

Use the command-line interface:

```sh
mar index ~/Projects
mar search "nox"
mar search "*.hs" --ext hs --json
mar list ~/Projects --directories
mar info ~/Projects/README.md --json
mar root add ~/Projects
mar update
mar status
mar roots
```

`index` and `update` scan real filesystem metadata into SQLite. `search`, `list`, and `info` query that persistent index without rescanning. `--json` is available on search, list, info, roots, and status for scripting.

The index is stored at `$XDG_DATA_HOME/mar/index.sqlite3` (or the platform XDG data directory when unset). Indexed roots are stored in the database.

## Layout

The executable lives under `app/mar`. Library modules are grouped by CLI, filesystem, index, search, configuration, and core responsibilities.
