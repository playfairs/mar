{-# LANGUAGE OverloadedStrings #-}

module Mar.CLI.Output (
    printEntries,
    printEntryInfo,
    printRoots,
    printStatus,
    printIndexResult,
) where

import Data.Aeson (Value, encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as ByteString
import qualified Data.Text as Text
import Mar.Core.Types (Entry (..), EntryInfo (..), EntryType (..), IndexResult (..), Root (..), StatusInfo (..))

printEntries :: Bool -> [Entry] -> IO ()
printEntries asJson entries =
    if asJson then ByteString.putStrLn (encode (map entryObject entries)) else mapM_ (putStrLn . entryPath) entries

printEntryInfo :: Bool -> EntryInfo -> IO ()
printEntryInfo asJson info =
    if asJson then ByteString.putStrLn (encode (entryInfoObject info)) else mapM_ putStrLn linesToPrint
  where
    entry = infoEntry info
    linesToPrint =
        [ "Path:         " ++ entryPath entry
        , "Type:         " ++ displayType (entryType entry)
        , "Size:         " ++ maybe "-" (\size -> show size ++ " bytes") (entrySize entry)
        , "Extension:    " ++ maybe "-" Text.unpack (entryExtension entry)
        , "Modified:     " ++ maybe "-" show (entryModified entry)
        , "Hidden:       " ++ yesNo (entryIsHidden entry)
        , "Symlink:      " ++ yesNo (entryType entry == SymbolicLink)
        , "Indexed:      " ++ yesNo (infoIndexed info)
        , "Children:     " ++ show (infoChildren info)
        ]

printRoots :: Bool -> [Root] -> IO ()
printRoots asJson roots =
    if asJson then ByteString.putStrLn (encode (map rootObject roots)) else mapM_ (putStrLn . rootPath) roots

printStatus :: Bool -> StatusInfo -> IO ()
printStatus asJson status =
    if asJson then ByteString.putStrLn (encode (statusObject status)) else mapM_ putStrLn linesToPrint
  where
    linesToPrint =
        [ "Database:       " ++ statusDatabase status
        , "Roots:          " ++ show (statusRoots status)
        , "Files:          " ++ show (statusFiles status)
        , "Directories:    " ++ show (statusDirectories status)
        , "Total entries:  " ++ show (statusTotal status)
        , "Database size:  " ++ show (statusDatabaseSize status) ++ " bytes"
        , "Last update:    " ++ maybe "-" show (statusLastUpdate status)
        ]

printIndexResult :: IndexResult -> IO ()
printIndexResult result =
    mapM_
        putStrLn
        [ "Indexing " ++ indexRootPath result
        , "Scanned: " ++ show (indexScanned result)
        , "Added:   " ++ show (indexAdded result)
        , "Updated: " ++ show (indexUpdated result)
        , "Removed: " ++ show (indexRemoved result)
        , "Skipped: " ++ show (indexFailures result)
        ]

entryObject :: Entry -> Value
entryObject entry =
    object
        [ "path" .= entryPath entry
        , "name" .= entryName entry
        , "parent" .= entryParent entry
        , "type" .= displayType (entryType entry)
        , "extension" .= entryExtension entry
        , "size" .= entrySize entry
        , "modified" .= entryModified entry
        , "created" .= entryCreated entry
        , "permissions" .= entryPermissions entry
        , "hidden" .= entryIsHidden entry
        , "symlink_target" .= entrySymlinkTarget entry
        ]

entryInfoObject :: EntryInfo -> Value
entryInfoObject info =
    object
        [ "path" .= entryPath entry
        , "name" .= entryName entry
        , "parent" .= entryParent entry
        , "type" .= displayType (entryType entry)
        , "extension" .= entryExtension entry
        , "size" .= entrySize entry
        , "modified" .= entryModified entry
        , "created" .= entryCreated entry
        , "permissions" .= entryPermissions entry
        , "hidden" .= entryIsHidden entry
        , "symlink_target" .= entrySymlinkTarget entry
        , "indexed" .= infoIndexed info
        , "children" .= infoChildren info
        ]
  where
    entry = infoEntry info

rootObject :: Root -> Value
rootObject root = object ["path" .= rootPath root, "added" .= rootAdded root]

statusObject :: StatusInfo -> Value
statusObject status =
    object
        [ "database" .= statusDatabase status
        , "roots" .= statusRoots status
        , "files" .= statusFiles status
        , "directories" .= statusDirectories status
        , "total_entries" .= statusTotal status
        , "database_size" .= statusDatabaseSize status
        , "last_update" .= statusLastUpdate status
        ]

displayType :: (Show a) => a -> String
displayType value = case show value of
    "RegularFile" -> "file"
    "Directory" -> "directory"
    "SymbolicLink" -> "symlink"
    other -> other

yesNo :: Bool -> String
yesNo True = "yes"
yesNo False = "no"
