module Mar.Index.Schema (schemaStatements) where

schemaStatements :: [String]
schemaStatements =
    [ "CREATE TABLE IF NOT EXISTS roots (path TEXT PRIMARY KEY, added_at TEXT NOT NULL)"
    , "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
    , "CREATE TABLE IF NOT EXISTS entries (path TEXT PRIMARY KEY, name TEXT NOT NULL, extension TEXT, parent TEXT NOT NULL, kind TEXT NOT NULL, size INTEGER, modified_at TEXT, created_at TEXT, permissions TEXT, hidden INTEGER NOT NULL, symlink_target TEXT)"
    , "CREATE INDEX IF NOT EXISTS entries_parent_idx ON entries(parent)"
    , "CREATE INDEX IF NOT EXISTS entries_extension_idx ON entries(extension)"
    , "CREATE INDEX IF NOT EXISTS entries_kind_idx ON entries(kind)"
    , "CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(path, name, content='entries', content_rowid='rowid')"
    , "CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN INSERT INTO entries_fts(rowid, path, name) VALUES (new.rowid, new.path, new.name); END"
    , "CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN INSERT INTO entries_fts(entries_fts, rowid, path, name) VALUES('delete', old.rowid, old.path, old.name); END"
    , "CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN INSERT INTO entries_fts(entries_fts, rowid, path, name) VALUES('delete', old.rowid, old.path, old.name); INSERT INTO entries_fts(rowid, path, name) VALUES (new.rowid, new.path, new.name); END"
    ]
