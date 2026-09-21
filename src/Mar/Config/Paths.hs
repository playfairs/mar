module Mar.Config.Paths (databasePath, absolutePath) where

import System.Directory (XdgDirectory (XdgData), createDirectoryIfMissing, getXdgDirectory, makeAbsolute)
import System.FilePath (dropTrailingPathSeparator, normalise, (</>))

databasePath :: IO FilePath
databasePath = do
    directory <- getXdgDirectory XdgData "mar"
    createDirectoryIfMissing True directory
    pure (directory </> "index.sqlite3")

absolutePath :: FilePath -> IO FilePath
absolutePath path = dropTrailingPathSeparator . normalise <$> makeAbsolute path
