module Mar.CLI.Commands (runCommand) where

import Data.Version (showVersion)
import Database.SQLite.Simple (Connection)
import Mar.CLI.Output (printEntries, printEntryInfo, printIndexResult, printRoots, printStatus)
import Mar.CLI.Parser (Command (..), ListOptions (..), SearchOptions (..))
import Mar.Config.Paths (absolutePath, databasePath)
import Mar.Config.Version (marVersion)
import Mar.Core.Types (EntryInfo (..), EntryType (..), StatusInfo (..))
import qualified Mar.Core.Types as Types
import Mar.Index.Database
import Mar.Index.Query (searchEntries)
import Mar.Index.Updater (indexRoot, updateRoots)
import Mar.Search.Filters (Filters (..))
import System.Directory (doesDirectoryExist, doesPathExist, getFileSize)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

helpText :: String
helpText =
    unlines
        [ "mar - local filesystem indexer and search CLI"
        , "Usage:"
        , "  mar index <path>                 Index a directory recursively"
        , "  mar update                       Update all indexed roots"
        , "  mar search <query> [filters]     Search the index"
        , "  mar list <path> [options]        List indexed children"
        , "  mar info <path> [--json]         Show indexed metadata"
        , "  mar root add <path>              Add an indexed root"
        , "  mar root remove <path>           Remove an indexed root"
        , "  mar roots [--json]               List indexed roots"
        , "  mar status [--json]              Show index status"
        ]

runCommand :: Command -> IO ()
runCommand command = case command of
    Help -> putStr helpText
    Version -> putStrLn ("mar " ++ showVersion marVersion)
    Search query options -> withDb $ \connection -> do
        path <- resolveOptionalPath (optionPath options)
        entries <-
            searchEntries connection query (Filters (optionType options) (optionExtension options) (optionHidden options) path)
        printEntries (optionJson options) entries
    Index root -> do
        path <- requireDirectory root
        withDb (\connection -> indexRoot connection path >>= printIndexResult)
    Update -> withDb $ \connection -> mapM_ printIndexResult =<< updateRoots connection
    List path options -> do
        resolved <- requireExisting path
        withDb $ \connection -> do
            indexedPath <- indexedEntry connection resolved
            case indexedPath of
                Nothing -> failCommand ("path is not indexed: " ++ path)
                Just _ -> pure ()
            entries <- entriesUnder connection resolved
            let visible = filterList options entries
            printEntries (listJson options) visible
    Info path asJson -> do
        resolved <- requireExisting path
        withDb $ \connection -> do
            indexed <- indexedEntry connection resolved
            case indexed of
                Nothing -> failCommand ("path is not indexed: " ++ path)
                Just entry -> do
                    children <- childCount connection resolved
                    printEntryInfo asJson (EntryInfo entry True children)
    RootAdd path -> do
        resolved <- requireDirectory path
        withDb $ \connection -> do
            added <- addRoot connection resolved
            putStrLn ((if added then "Added indexed root:\n" else "Root already indexed:\n") ++ resolved)
    RootRemove path -> do
        resolved <- absolutePath path
        withDb $ \connection -> do
            removed <- removeRoot connection resolved
            if removed then putStrLn ("Removed indexed root:\n" ++ resolved) else failCommand ("root is not indexed: " ++ path)
    Roots asJson -> withDb $ \connection -> allRoots connection >>= printRoots asJson
    Status asJson -> withDb $ \connection -> do
        location <- databasePath
        (files, directories, total) <- countEntries connection
        roots <- allRoots connection
        size <- getFileSize location
        updated <- lastUpdate connection
        printStatus
            asJson
            StatusInfo
                { statusDatabase = location
                , statusRoots = length roots
                , statusFiles = files
                , statusDirectories = directories
                , statusTotal = total
                , statusDatabaseSize = size
                , statusLastUpdate = updated
                }
withDb :: (Connection -> IO a) -> IO a
withDb action = databasePath >>= (`withDatabase` action)

requireExisting :: FilePath -> IO FilePath
requireExisting path = do
    exists <- doesPathExist path
    if exists then absolutePath path else failCommand ("path does not exist: " ++ path)

requireDirectory :: FilePath -> IO FilePath
requireDirectory path = do
    exists <- doesDirectoryExist path
    if exists then absolutePath path else failCommand ("directory does not exist: " ++ path)

resolveOptionalPath :: Maybe FilePath -> IO (Maybe FilePath)
resolveOptionalPath = mapM absolutePath

filterList :: ListOptions -> [Types.Entry] -> [Types.Entry]
filterList options entries = filter include entries
  where
    include entry =
        (listHidden options || not (Types.entryIsHidden entry))
            && (not (listFilesOnly options) || Types.entryType entry == RegularFile)
            && (not (listDirectoriesOnly options) || Types.entryType entry == Directory)

failCommand :: String -> IO a
failCommand message = hPutStrLn stderr ("mar: " ++ message) >> exitFailure
