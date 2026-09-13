module Mar.Core.Entry (
    sortEntries,
    visibleEntries,
) where

import Data.List (sortOn)
import Mar.Core.Types (Entry (..), EntryType (..), SortOrder (..))

sortEntries :: SortOrder -> [Entry] -> [Entry]
sortEntries SortByName = sortOn (\entry -> (entryType entry /= Directory, entryName entry))
sortEntries SortByModified = sortOn (\entry -> (entryModified entry, entryName entry))
sortEntries SortBySize = sortOn (\entry -> (entrySize entry, entryName entry))

visibleEntries :: Bool -> [Entry] -> [Entry]
visibleEntries showHidden = if showHidden then id else filter (not . entryIsHidden)
