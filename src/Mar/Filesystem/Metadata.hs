module Mar.Filesystem.Metadata (
    inspectEntry,
    listDirectoryEntries,
) where

import Control.Exception (IOException, try)
import Data.Text (pack)
import Mar.Core.Path (isHiddenName, normalizePath)
import Mar.Core.Types (Entry (..), EntryType (..))
import System.Directory (
    Permissions,
    doesDirectoryExist,
    executable,
    getFileSize,
    getModificationTime,
    getPermissions,
    listDirectory,
    readable,
    writable,
 )
import System.FilePath (takeDirectory, takeExtension, takeFileName, (</>))

inspectEntry :: FilePath -> IO (Either IOException Entry)
inspectEntry path = try $ do
    directory <- doesDirectoryExist path
    permissions <- getPermissions path
    size <- if directory then pure Nothing else Just <$> getFileSize path
    modified <- getModificationTime path
    let normalized = normalizePath path
        name = takeFileName normalized
        extension = case takeExtension name of
            "" -> Nothing
            value -> Just (pack value)
        kind = if directory then Directory else RegularFile
    pure
        Entry
            { entryPath = normalized
            , entryName = pack name
            , entryParent = takeDirectory normalized
            , entryType = kind
            , entryExtension = extension
            , entrySize = size
            , entryModified = Just modified
            , entryCreated = Nothing
            , entryPermissions = Just (pack (permissionText permissions))
            , entryIsHidden = isHiddenName name
            }

listDirectoryEntries :: FilePath -> IO [Entry]
listDirectoryEntries directory = do
    names <- listDirectory directory
    results <- mapM (inspectEntry . (directory </>)) names
    pure [entry | Right entry <- results]

permissionText :: Permissions -> String
permissionText permissions =
    concat
        [ if readable permissions then "r" else "-"
        , if writable permissions then "w" else "-"
        , if executable permissions then "x" else "-"
        ]
