module Mar.Navigation.State (
    AppState (..),
    InputMode (..),
    initialize,
    refreshState,
    selectedEntry,
    selectedPath,
    moveSelection,
    setCurrentPath,
    toggleHidden,
    cycleSort,
    beginRename,
    beginDelete,
    cancelInput,
) where

import Data.Text (Text)
import qualified Data.Text as Text
import Mar.Core.Entry (sortEntries, visibleEntries)
import Mar.Core.Path (normalizePath)
import Mar.Core.Types (Entry (..), SortOrder (..))
import Mar.Filesystem.Metadata (listDirectoryEntries)
import System.Directory (doesDirectoryExist)
import System.FilePath (takeDirectory)

data InputMode
    = NormalMode
    | ConfirmDeleteMode
    | RenameMode
    deriving (Eq, Show)

data AppState = AppState
    { currentPath :: FilePath
    , parentEntries :: [Entry]
    , currentEntries :: [Entry]
    , selectedIndex :: Int
    , showHidden :: Bool
    , sortOrder :: SortOrder
    , clipboard :: Maybe FilePath
    , inputMode :: InputMode
    , inputBuffer :: String
    , statusMessage :: Text
    , previewLines :: [Text]
    }
    deriving (Eq, Show)

initialize :: FilePath -> IO AppState
initialize requestedPath = do
    isDirectory <- doesDirectoryExist requestedPath
    let path = normalizePath (if isDirectory then requestedPath else takeDirectory requestedPath)
    refreshState
        AppState
            { currentPath = path
            , parentEntries = []
            , currentEntries = []
            , selectedIndex = 0
            , showHidden = False
            , sortOrder = SortByName
            , clipboard = Nothing
            , inputMode = NormalMode
            , inputBuffer = ""
            , statusMessage = Text.empty
            , previewLines = []
            }

refreshState :: AppState -> IO AppState
refreshState state = do
    entries <- listDirectoryEntries (currentPath state)
    parents <- listDirectoryEntries (takeDirectory (currentPath state))
    let filteredEntries = visibleEntries (showHidden state) (sortEntries (sortOrder state) entries)
        filteredParents = visibleEntries (showHidden state) (sortEntries (sortOrder state) parents)
        newIndex = min (selectedIndex state) (max 0 (length filteredEntries - 1))
    pure
        state
            { parentEntries = filteredParents
            , currentEntries = filteredEntries
            , selectedIndex = newIndex
            }

selectedEntry :: AppState -> Maybe Entry
selectedEntry state = atMay (currentEntries state) (selectedIndex state)

selectedPath :: AppState -> Maybe FilePath
selectedPath = fmap entryPath . selectedEntry

moveSelection :: Int -> AppState -> AppState
moveSelection amount state =
    state
        { selectedIndex = max 0 (min lastIndex (selectedIndex state + amount))
        }
  where
    lastIndex = max 0 (length (currentEntries state) - 1)

setCurrentPath :: FilePath -> AppState -> IO AppState
setCurrentPath path state =
    refreshState
        state
            { currentPath = normalizePath path
            , selectedIndex = 0
            , inputMode = NormalMode
            , inputBuffer = ""
            }

toggleHidden :: AppState -> IO AppState
toggleHidden state = refreshState state{showHidden = not (showHidden state), selectedIndex = 0}

cycleSort :: AppState -> IO AppState
cycleSort state =
    refreshState
        state
            { sortOrder = case sortOrder state of
                SortByName -> SortByModified
                SortByModified -> SortBySize
                SortBySize -> SortByName
            , selectedIndex = 0
            }

beginRename :: AppState -> AppState
beginRename state =
    state
        { inputMode = RenameMode
        , inputBuffer = maybe "" (showName . entryName) (selectedEntry state)
        }
  where
    showName = Text.unpack

beginDelete :: AppState -> AppState
beginDelete state = state{inputMode = ConfirmDeleteMode}

cancelInput :: AppState -> AppState
cancelInput state = state{inputMode = NormalMode, inputBuffer = ""}

atMay :: [a] -> Int -> Maybe a
atMay values index
    | index < 0 = Nothing
    | otherwise = case drop index values of
        value : _ -> Just value
        [] -> Nothing
