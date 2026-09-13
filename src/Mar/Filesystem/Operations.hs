module Mar.Filesystem.Operations (
    copyEntry,
    moveEntry,
    renameEntry,
    removeEntry,
    createFile,
    createDirectory,
    openEntry,
) where

import qualified System.Directory as Directory
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.Process (createProcess, proc)

copyEntry :: FilePath -> FilePath -> IO ()
copyEntry source destination = do
    directory <- Directory.doesDirectoryExist source
    if directory then copyDirectory source destination else Directory.copyFile source destination

moveEntry :: FilePath -> FilePath -> IO ()
moveEntry source destination = do
    directory <- Directory.doesDirectoryExist source
    if directory then Directory.renameDirectory source destination else Directory.renameFile source destination

renameEntry :: FilePath -> String -> IO FilePath
renameEntry source name = do
    let destination = takeDirectory source </> name
    moveEntry source destination
    pure destination

removeEntry :: FilePath -> IO ()
removeEntry path = do
    directory <- Directory.doesDirectoryExist path
    if directory then Directory.removeDirectoryRecursive path else Directory.removeFile path

createFile :: FilePath -> IO ()
createFile path = writeFile path ""

createDirectory :: FilePath -> IO ()
createDirectory = Directory.createDirectory

openEntry :: FilePath -> IO ()
openEntry path = do
    _ <- createProcess (proc "open" [path])
    pure ()

copyDirectory :: FilePath -> FilePath -> IO ()
copyDirectory source destination = do
    Directory.createDirectory destination
    names <- Directory.listDirectory source
    mapM_ (\name -> copyEntry (source </> name) (destination </> name)) names
