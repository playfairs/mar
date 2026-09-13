{-# LANGUAGE DeriveGeneric #-}

module Mar.Core.Types (
    EntryType (..),
    Entry (..),
    SortOrder (..),
) where

import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import System.FilePath (FilePath)

data EntryType = RegularFile | Directory | SymbolicLink | Other
    deriving (Eq, Ord, Show, Read, Generic)

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
    }
    deriving (Eq, Show, Generic)

data SortOrder = SortByName | SortByModified | SortBySize
    deriving (Eq, Ord, Show, Read, Generic)
