module Mar.Core.Types (
    EntryType (..),
    Entry (..),
    Root (..),
    IndexResult (..),
    EntryInfo (..),
    StatusInfo (..),
    CrawlResult (..),
) where

import Data.Text (Text)
import Data.Time (UTCTime)

data EntryType = RegularFile | Directory | SymbolicLink | Other
    deriving (Eq, Ord, Show, Read)

data Entry = Entry
    { entryPath :: FilePath
    , entryName :: Text
    , entryParent :: FilePath
    , entryType :: EntryType
    , entryExtension :: Maybe Text
    , entrySize :: Maybe Integer
    , entryModified :: Maybe UTCTime
    , entryCreated :: Maybe UTCTime
    , entryPermissions :: Maybe Text
    , entryIsHidden :: Bool
    , entrySymlinkTarget :: Maybe FilePath
    }
    deriving (Eq, Show)

data Root = Root
    { rootPath :: FilePath
    , rootAdded :: UTCTime
    }
    deriving (Eq, Show)

data IndexResult = IndexResult
    { indexRootPath :: FilePath
    , indexScanned :: Int
    , indexAdded :: Int
    , indexUpdated :: Int
    , indexRemoved :: Int
    , indexFailures :: Int
    }
    deriving (Eq, Show)

data EntryInfo = EntryInfo
    { infoEntry :: Entry
    , infoIndexed :: Bool
    , infoChildren :: Int
    }
    deriving (Eq, Show)

data StatusInfo = StatusInfo
    { statusDatabase :: FilePath
    , statusRoots :: Int
    , statusFiles :: Int
    , statusDirectories :: Int
    , statusTotal :: Int
    , statusDatabaseSize :: Integer
    , statusLastUpdate :: Maybe UTCTime
    }
    deriving (Eq, Show)

data CrawlResult = CrawlResult
    { crawledEntries :: [Entry]
    , crawlFailures :: [FilePath]
    }
    deriving (Eq, Show)
