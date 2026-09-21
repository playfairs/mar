module Mar.Search.Filters (
    Filters (..),
    emptyFilters,
) where

import Data.Text (Text)
import Mar.Core.Types (EntryType)

data Filters = Filters
    { filterType :: Maybe EntryType
    , filterExtension :: Maybe Text
    , filterHidden :: Bool
    , filterPath :: Maybe FilePath
    }
    deriving (Eq, Show)

emptyFilters :: Filters
emptyFilters = Filters Nothing Nothing False Nothing
