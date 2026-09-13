module Mar.TUI.Application (
    launch,
) where

import Brick
import Brick.AttrMap (attrName)
import Brick.Types (EventM)
import Brick.Widgets.Border (borderWithLabel, vBorder)
import Brick.Widgets.Core (hLimitPercent, padAll, padLeftRight, str, txt, vBox)
import Control.Exception (IOException, try)
import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import Data.Text (pack, unpack)
import qualified Graphics.Vty as V
import Mar.Core.Types (Entry (..), EntryType (..))
import Mar.Filesystem.Operations (copyEntry, openEntry, removeEntry, renameEntry)
import Mar.Navigation.State
import Mar.Preview.Preview (previewEntry)
import System.FilePath (takeDirectory, takeFileName, (</>))

launch :: FilePath -> IO ()
launch path = do
    state <- initialize path >>= refreshWithPreview
    void (defaultMain app state)

app :: App AppState e ()
app =
    App
        { appDraw = drawUI
        , appChooseCursor = neverShowCursor
        , appHandleEvent = handleEvent
        , appStartEvent = pure ()
        , appAttrMap = const attributes
        }

drawUI :: AppState -> [Widget ()]
drawUI state =
    [ vBox
        [ hBox
            [ hLimitPercent 25 (entryPane "Parent" (parentEntries state) Nothing)
            , vBorder
            , hLimitPercent 35 (entryPane ("Current " ++ currentPath state) (currentEntries state) (Just (selectedIndex state)))
            , vBorder
            , previewPane state
            ]
        , statusPane state
        ]
    ]

entryPane :: String -> [Entry] -> Maybe Int -> Widget ()
entryPane title entries selected = borderWithLabel (withAttr titleAttr (str title)) $ padAll 1 $ vBox rendered
  where
    rendered = if null entries then [withAttr dimAttr (str "(empty)")] else zipWith renderEntry [0 ..] entries
    renderEntry index entry = withAttr (if Just index == selected then selectedAttr else normalAttr) (str (prefix index ++ unpack (entryName entry)))
    prefix index = if Just index == selected then "> " else "  "

previewPane :: AppState -> Widget ()
previewPane state = borderWithLabel (withAttr titleAttr (str "Preview")) $ padAll 1 $ vBox (map txt (previewLines state))

statusPane :: AppState -> Widget ()
statusPane state = withAttr statusAttr $ padLeftRight 1 $ str (statusText state)

statusText :: AppState -> String
statusText state = case inputMode state of
    NormalMode -> unpack (statusMessage state) ++ "  [j/k] move [h/l] navigate [y/p] copy/paste [r] rename [d] delete [.] hidden [s] sort [q] quit"
    ConfirmDeleteMode -> "Delete " ++ maybe "selected entry" takeFileName (selectedPath state) ++ "? [y] yes [n] no"
    RenameMode -> "Rename: " ++ inputBuffer state ++ " [Enter] save [Esc] cancel"

handleEvent :: BrickEvent () e -> EventM () AppState ()
handleEvent (VtyEvent event) = do
    state <- get
    case inputMode state of
        NormalMode -> normalEvent state event
        ConfirmDeleteMode -> confirmationEvent state event
        RenameMode -> renameEvent state event
handleEvent _ = pure ()

normalEvent :: AppState -> V.Event -> EventM () AppState ()
normalEvent state event = case event of
    V.EvKey (V.KChar 'q') [] -> halt
    V.EvKey (V.KChar 'j') [] -> putWithPreview (moveSelection 1 state)
    V.EvKey V.KDown [] -> putWithPreview (moveSelection 1 state)
    V.EvKey (V.KChar 'k') [] -> putWithPreview (moveSelection (-1) state)
    V.EvKey V.KUp [] -> putWithPreview (moveSelection (-1) state)
    V.EvKey (V.KChar 'h') [] -> goParent state
    V.EvKey V.KLeft [] -> goParent state
    V.EvKey (V.KChar 'l') [] -> activateSelection state
    V.EvKey V.KRight [] -> activateSelection state
    V.EvKey V.KEnter [] -> activateSelection state
    V.EvKey (V.KChar '.') [] -> putIO (toggleHidden state)
    V.EvKey (V.KChar 's') [] -> putIO (cycleSort state)
    V.EvKey (V.KChar 'y') [] -> copySelection state
    V.EvKey (V.KChar 'p') [] -> pasteSelection state
    V.EvKey (V.KChar 'r') [] -> put (beginRename state)
    V.EvKey (V.KChar 'd') [] -> put (beginDelete state)
    V.EvKey (V.KChar 'o') [] -> openSelection state
    _ -> pure ()

confirmationEvent :: AppState -> V.Event -> EventM () AppState ()
confirmationEvent state event = case event of
    V.EvKey (V.KChar 'y') [] -> deleteSelection state
    V.EvKey V.KEnter [] -> deleteSelection state
    V.EvKey (V.KChar 'n') [] -> put (cancelInput state)
    V.EvKey V.KEsc [] -> put (cancelInput state)
    _ -> pure ()

renameEvent :: AppState -> V.Event -> EventM () AppState ()
renameEvent state event = case event of
    V.EvKey V.KEnter [] -> commitRename state
    V.EvKey V.KEsc [] -> put (cancelInput state)
    V.EvKey V.KBS [] -> put state{inputBuffer = dropLast (inputBuffer state)}
    V.EvKey (V.KChar character) [] -> put state{inputBuffer = inputBuffer state ++ [character]}
    _ -> pure ()

activateSelection :: AppState -> EventM () AppState ()
activateSelection state = case selectedEntry state of
    Just entry | entryType entry == Directory -> putIO (setCurrentPath (entryPath entry) state)
    Just entry -> openSelection state
    Nothing -> pure ()

goParent :: AppState -> EventM () AppState ()
goParent state =
    let parent = takeDirectory (currentPath state)
     in if parent == currentPath state then pure () else putIO (setCurrentPath parent state)

copySelection :: AppState -> EventM () AppState ()
copySelection state = case selectedPath state of
    Nothing -> pure ()
    Just path -> put state{clipboard = Just path, statusMessage = pack ("Copied " ++ takeFileName path)}

pasteSelection :: AppState -> EventM () AppState ()
pasteSelection state = case clipboard state of
    Nothing -> put state{statusMessage = pack "Clipboard is empty"}
    Just source -> putIOWithStatus state $ do
        copyEntry source (currentPath state </> takeFileName source)
        pure ("Pasted " ++ takeFileName source)

deleteSelection :: AppState -> EventM () AppState ()
deleteSelection state = case selectedPath state of
    Nothing -> put (cancelInput state)
    Just path -> putIOWithStatus (cancelInput state) $ do
        removeEntry path
        pure ("Deleted " ++ takeFileName path)

commitRename :: AppState -> EventM () AppState ()
commitRename state = case selectedPath state of
    Nothing -> put (cancelInput state)
    Just path ->
        if null (inputBuffer state)
            then put (cancelInput state)
            else putIOWithStatus (cancelInput state) $ do
                _ <- renameEntry path (inputBuffer state)
                pure "Renamed"

openSelection :: AppState -> EventM () AppState ()
openSelection state = case selectedPath state of
    Nothing -> pure ()
    Just path -> putIOWithStatus state $ do
        openEntry path
        pure ("Opened " ++ takeFileName path)

putWithPreview :: AppState -> EventM () AppState ()
putWithPreview state = putIO (refreshWithPreview state)

putIO :: IO AppState -> EventM () AppState ()
putIO action = do
    state <- liftIO action
    put state

putIOWithStatus :: AppState -> IO String -> EventM () AppState ()
putIOWithStatus state action = do
    result <- liftIO (tryIO action)
    case result of
        Left errorValue -> put state{statusMessage = pack (show errorValue), inputMode = NormalMode, inputBuffer = ""}
        Right message -> do
            updated <- liftIO (refreshWithPreview state{statusMessage = pack message, inputMode = NormalMode, inputBuffer = ""})
            put updated

refreshWithPreview :: AppState -> IO AppState
refreshWithPreview state = do
    updated <- refreshState state
    content <- previewEntry (selectedEntry updated)
    pure updated{previewLines = content}

tryIO :: IO a -> IO (Either IOException a)
tryIO = try

dropLast :: [a] -> [a]
dropLast values = case reverse values of
    [] -> []
    _ : rest -> reverse rest

attributes :: AttrMap
attributes =
    attrMap
        V.defAttr
        [ (selectedAttr, fg V.yellow `V.withStyle` V.bold)
        , (titleAttr, fg V.cyan `V.withStyle` V.bold)
        , (dimAttr, fg V.brightBlack)
        , (statusAttr, bg V.blue)
        , (normalAttr, V.defAttr)
        ]

selectedAttr, titleAttr, dimAttr, statusAttr, normalAttr :: AttrName
selectedAttr = attrName "selected"
titleAttr = attrName "title"
dimAttr = attrName "dim"
statusAttr = attrName "status"
normalAttr = attrName "normal"
