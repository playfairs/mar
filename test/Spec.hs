module Main (main) where

import Control.Exception (IOException, try)
import Mar.Core.Path (isHiddenName, normalizePath)
import Mar.Core.Types (CrawlResult (..), Entry (..), EntryType (..), IndexResult (..))
import Mar.Filesystem.Metadata (inspectEntry)
import Mar.Index.Crawler (crawl)
import Mar.Index.Database (entriesUnder, indexedEntry, withDatabase)
import Mar.Index.Query (searchEntries)
import Mar.Index.Updater (indexRoot)
import Mar.Search.Filters (emptyFilters)
import System.Directory (createDirectory, getTemporaryDirectory, removeDirectoryRecursive, removeFile, renameFile)
import System.FilePath ((</>))
import Test.Hspec

main :: IO ()
main = hspec $ do
    describe "Mar.Core.Path" $ do
        it "normalizes repeated separators" $ normalizePath "foo//bar" `shouldBe` "foo/bar"
        it "detects dotfiles" $ do
            isHiddenName ".env" `shouldBe` True
            isHiddenName "visible" `shouldBe` False
    describe "filesystem metadata" $ do
        it "extracts file metadata" $ do
            temporary <- getTemporaryDirectory
            let directory = temporary </> "mar-test-metadata"
                path = directory </> "sample.txt"
            createDirectory directory
            writeFile path "hello"
            result <- inspectEntry path
            result `shouldSatisfy` isRegularFile
            removeDirectoryRecursive directory
        it "crawls nested files" $ do
            temporary <- getTemporaryDirectory
            let directory = temporary </> "mar-test-crawler"
                nested = directory </> "nested"
                path = nested </> "sample.txt"
            createDirectory directory
            createDirectory nested
            writeFile path "hello"
            result <- crawl directory
            map entryPath (crawledEntries result) `shouldContain` [path]
            removeDirectoryRecursive directory
    describe "SQLite index" $ do
        it "indexes, searches, updates, and removes stale entries" $ do
            temporary <- getTemporaryDirectory
            let directory = temporary </> "mar-test-index"
                database = temporary </> "mar-test-index.sqlite3"
                source = directory </> "src"
                hello = directory </> "hello.txt"
                hidden = directory </> ".hidden.txt"
                mainFile = source </> "main.rs"
                goodbye = directory </> "goodbye.txt"
                newFile = directory </> "new.txt"
            removeDirectoryIfExists directory
            createDirectory directory
            createDirectory source
            writeFile hello "hello"
            writeFile hidden "hidden"
            writeFile mainFile "fn main() {}"
            withDatabase database $ \connection -> do
                first <- indexRoot connection directory
                indexScanned first `shouldBe` 5
                children <- entriesUnder connection directory
                length children `shouldBe` 3
                matches <- searchEntries connection "hello" emptyFilters
                map entryPath matches `shouldBe` [hello]
                indexedEntry connection hello >>= (`shouldSatisfy` isJust)
            renameFile hello goodbye
            removeFile hidden
            writeFile newFile "new"
            withDatabase database $ \connection -> do
                second <- indexRoot connection directory
                indexAdded second `shouldBe` 2
                indexRemoved second `shouldBe` 2
                missingHello <- indexedEntry connection hello
                missingHello `shouldBe` Nothing
                indexedEntry connection goodbye >>= (`shouldSatisfy` isJust)
                missingHidden <- indexedEntry connection hidden
                missingHidden `shouldBe` Nothing
                indexedEntry connection newFile >>= (`shouldSatisfy` isJust)
            removeFileIfExists database
            removeDirectoryRecursive directory
  where
    isRegularFile (Right entry) = entryType entry == RegularFile
    isRegularFile _ = False

    isJust (Just _) = True
    isJust Nothing = False

    removeDirectoryIfExists path = do
        _ <- try (removeDirectoryRecursive path) :: IO (Either IOException ())
        pure ()

    removeFileIfExists path = do
        _ <- try (removeFile path) :: IO (Either IOException ())
        pure ()
