module Mar.Preview.Preview (
    previewEntry,
) where

import Control.Exception (IOException, try)
import Control.Monad (replicateM)
import Data.Text (Text, pack)
import Mar.Core.Types (Entry (..), EntryType (..))
import System.Directory (listDirectory)
import System.FilePath (takeFileName)
import System.IO (Handle, IOMode (ReadMode), hGetLine, hIsEOF, withFile)

previewEntry :: Maybe Entry -> IO [Text]
previewEntry Nothing = pure [pack "No selection"]
previewEntry (Just entry) = case entryType entry of
    Directory -> directoryPreview (entryPath entry)
    _ -> textPreview (entryPath entry)

directoryPreview :: FilePath -> IO [Text]
directoryPreview path = do
    result <- try (listDirectory path) :: IO (Either IOException [FilePath])
    pure
        ( case result of
            Left errorValue -> [pack (show errorValue)]
            Right names ->
                [pack ("Directory: " ++ takeFileName path), pack (show (length names) ++ " entries")]
                    ++ map pack (take 18 names)
        )

textPreview :: FilePath -> IO [Text]
textPreview path = do
    result <- try (withFile path ReadMode (readLines 40)) :: IO (Either IOException [String])
    pure
        ( case result of
            Left errorValue -> [pack (show errorValue)]
            Right [] -> [pack "Empty file"]
            Right linesRead -> map (pack . take 120) linesRead
        )

readLines :: Int -> Handle -> IO [String]
readLines count handle = do
    linesRead <- replicateM count (nextLine handle)
    pure [line | Just line <- linesRead]

nextLine :: Handle -> IO (Maybe String)
nextLine handle = do
    finished <- hIsEOF handle
    if finished then pure Nothing else Just <$> hGetLine handle
