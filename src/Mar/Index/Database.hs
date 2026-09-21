{-# LANGUAGE OverloadedStrings #-}

module Mar.Index.Database (
    withDatabase,
    initialize,
    insertEntry,
    entriesUnder,
    entriesInRoot,
    indexedEntry,
    childCount,
    allRoots,
    addRoot,
    removeRoot,
    countEntries,
    lastUpdate,
    markUpdated,
) where

import Control.Exception (bracket)
import Control.Monad (forM_)
import qualified Data.Text as Text
import Data.Time (UTCTime, getCurrentTime)
import Database.SQLite.Simple
import Database.SQLite.Simple.FromRow (RowParser)
import Database.SQLite.Simple.ToField (toField)
import Mar.Core.Types (Entry (..), Root (..))
import Mar.Index.Schema (schemaStatements)

withDatabase :: FilePath -> (Connection -> IO a) -> IO a
withDatabase path action = bracket (open path) close (\connection -> initialize connection >> action connection)

initialize :: Connection -> IO ()
initialize connection = forM_ schemaStatements (execute_ connection . Query . Text.pack)

instance FromRow Entry where
    fromRow = do
        path <- field
        name <- field
        extension <- field
        parent <- field
        kindText <- field
        size <- field
        modified <- field
        created <- field
        permissions <- field
        symlinkTarget <- field
        hidden <- field :: RowParser Int
        pure
            Entry
                { entryPath = path
                , entryName = name
                , entryParent = parent
                , entryType = read kindText
                , entryExtension = extension
                , entrySize = size
                , entryModified = modified
                , entryCreated = created
                , entryPermissions = permissions
                , entryIsHidden = hidden /= 0
                , entrySymlinkTarget = symlinkTarget
                }

instance FromRow Root where
    fromRow = Root <$> field <*> field

insertEntry :: Connection -> Entry -> IO ()
insertEntry connection entry =
    execute
        connection
        ( Query
            "INSERT INTO entries(path,name,extension,parent,kind,size,modified_at,created_at,permissions,hidden,symlink_target) VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(path) DO UPDATE SET name=excluded.name, extension=excluded.extension, parent=excluded.parent, kind=excluded.kind, size=excluded.size, modified_at=excluded.modified_at, created_at=excluded.created_at, permissions=excluded.permissions, hidden=excluded.hidden, symlink_target=excluded.symlink_target"
        )
        params
  where
    params =
        [ toField (entryPath entry)
        , toField (entryName entry)
        , toField (entryExtension entry)
        , toField (entryParent entry)
        , toField (show (entryType entry))
        , toField (entrySize entry)
        , toField (entryModified entry)
        , toField (entryCreated entry)
        , toField (entryPermissions entry)
        , toField (if entryIsHidden entry then (1 :: Int) else 0)
        , toField (entrySymlinkTarget entry)
        ]

entriesUnder :: Connection -> FilePath -> IO [Entry]
entriesUnder connection path =
    query
        connection
        "SELECT path,name,extension,parent,kind,size,modified_at,created_at,permissions,symlink_target,hidden FROM entries WHERE parent = ? ORDER BY kind, name"
        (Only path)

entriesInRoot :: Connection -> FilePath -> IO [Entry]
entriesInRoot connection root =
    query
        connection
        "SELECT path,name,extension,parent,kind,size,modified_at,created_at,permissions,symlink_target,hidden FROM entries WHERE path = ? OR path LIKE ? ORDER BY path"
        (root, root ++ "/%")

indexedEntry :: Connection -> FilePath -> IO (Maybe Entry)
indexedEntry connection path = do
    entries <-
        query
            connection
            "SELECT path,name,extension,parent,kind,size,modified_at,created_at,permissions,symlink_target,hidden FROM entries WHERE path = ?"
            (Only path)
    pure $ case entries of
        entry : _ -> Just entry
        [] -> Nothing

childCount :: Connection -> FilePath -> IO Int
childCount connection path = do
    [Only count] <- query connection "SELECT count(*) FROM entries WHERE parent = ?" (Only path)
    pure count

allRoots :: Connection -> IO [Root]
allRoots connection = query_ connection "SELECT path, added_at FROM roots ORDER BY path"

addRoot :: Connection -> FilePath -> IO Bool
addRoot connection path = do
    [Only exists] <- query connection "SELECT EXISTS(SELECT 1 FROM roots WHERE path = ?)" (Only path)
    now <- getCurrentTime
    if exists
        then pure False
        else execute connection "INSERT INTO roots(path, added_at) VALUES (?, ?)" (path, now) >> pure True

removeRoot :: Connection -> FilePath -> IO Bool
removeRoot connection path = do
    [Only exists] <- query connection "SELECT EXISTS(SELECT 1 FROM roots WHERE path = ?)" (Only path)
    if exists then execute connection "DELETE FROM roots WHERE path = ?" (Only path) >> pure True else pure False

countEntries :: Connection -> IO (Int, Int, Int)
countEntries connection = do
    [(files, directories, total)] <-
        query_
            connection
            "SELECT coalesce(sum(kind = 'RegularFile'), 0), coalesce(sum(kind = 'Directory'), 0), count(*) FROM entries"
    pure (files, directories, total)

lastUpdate :: Connection -> IO (Maybe UTCTime)
lastUpdate connection = do
    rows <- query connection "SELECT value FROM metadata WHERE key = 'last_update'" () :: IO [Only UTCTime]
    pure $ case rows of
        Only value : _ -> Just value
        _ -> Nothing

markUpdated :: Connection -> IO ()
markUpdated connection = do
    now <- getCurrentTime
    execute
        connection
        "INSERT INTO metadata(key, value) VALUES ('last_update', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value"
        (Only now)
