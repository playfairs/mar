module Mar.Index.Crawler (crawl) where

import Control.Exception (IOException, try)
import Control.Monad (forM)
import Mar.Core.Types (CrawlResult (..), Entry (..), EntryType (..))
import Mar.Filesystem.Metadata (inspectEntry)
import System.Directory (listDirectory)
import System.FilePath ((</>))

crawl :: FilePath -> IO CrawlResult
crawl root = go root
  where
    go path = do
        inspected <- inspectEntry path
        case inspected of
            Left _ -> pure (CrawlResult [] [path])
            Right entry -> do
                if entryType entry /= Directory
                    then pure (CrawlResult [entry] [])
                    else do
                        result <- try (listDirectory path) :: IO (Either IOException [FilePath])
                        case result of
                            Left _ -> pure (CrawlResult [entry] [path])
                            Right children -> do
                                descendants <- forM children (go . (path </>))
                                pure (CrawlResult (entry : concatMap crawledEntries descendants) (concatMap crawlFailures descendants))
