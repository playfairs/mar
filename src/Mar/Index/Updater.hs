{-# LANGUAGE OverloadedStrings #-}

module Mar.Index.Updater (indexRoot, updateRoots) where

import Control.Monad (forM_, void)
import Data.List (find, isPrefixOf)
import Database.SQLite.Simple (Connection, Only (..), execute, withTransaction)
import Mar.Core.Types (CrawlResult (..), Entry (..), IndexResult (..), Root (..), crawledEntries)
import Mar.Index.Crawler (crawl)
import Mar.Index.Database (addRoot, allRoots, entriesInRoot, insertEntry, markUpdated)

indexRoot :: Connection -> FilePath -> IO IndexResult
indexRoot connection root = do
    crawlResult <- crawl root
    let entries = crawledEntries crawlResult
    existing <- entriesInRoot connection root
    let existingPaths = map entryPath existing
        newPaths = map entryPath entries
        added = length [path | path <- newPaths, path `notElem` existingPaths]
        updated = length [entry | entry <- entries, Just old <- [find ((== entryPath entry) . entryPath) existing], old /= entry]
        stalePaths = [path | path <- existingPaths, path `notElem` newPaths]
        removable = filter (not . blockedByFailure (crawlFailures crawlResult)) stalePaths
    withTransaction connection $ do
        _ <- addRoot connection root
        forM_ entries (insertEntry connection)
        forM_ removable $ \path -> void (execute connection "DELETE FROM entries WHERE path = ?" (Only path))
        markUpdated connection
    pure
        IndexResult
            { indexRootPath = root
            , indexScanned = length entries
            , indexAdded = added
            , indexUpdated = updated
            , indexRemoved = length removable
            , indexFailures = length (crawlFailures crawlResult)
            }

blockedByFailure :: [FilePath] -> FilePath -> Bool
blockedByFailure failures path = any (\failure -> failure == path || (failure ++ "/") `isPrefixOf` path) failures

updateRoots :: Connection -> IO [IndexResult]
updateRoots connection = do
    roots <- allRoots connection
    mapM (indexRoot connection . rootPath) roots
