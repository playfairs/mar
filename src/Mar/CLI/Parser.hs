module Mar.CLI.Parser (Command (..), SearchOptions (..), ListOptions (..), parseOptions) where

import Data.Text (pack)
import qualified Data.Text as Text
import Mar.Core.Types (EntryType (..))
import System.Environment (getArgs)
import System.Exit (die)

data Command
    = Help
    | Version
    | Search String SearchOptions
    | Index FilePath
    | Update
    | RootAdd FilePath
    | RootRemove FilePath
    | List FilePath ListOptions
    | Info FilePath Bool
    | Roots Bool
    | Status Bool
    deriving (Eq, Show)

data SearchOptions = SearchOptions
    { optionType :: Maybe EntryType
    , optionExtension :: Maybe Text.Text
    , optionHidden :: Bool
    , optionPath :: Maybe FilePath
    , optionJson :: Bool
    }
    deriving (Eq, Show)

data ListOptions = ListOptions
    { listFilesOnly :: Bool
    , listDirectoriesOnly :: Bool
    , listHidden :: Bool
    , listJson :: Bool
    }
    deriving (Eq, Show)

parseOptions :: IO Command
parseOptions = getArgs >>= either die pure . parseCommand

parseCommand :: [String] -> Either String Command
parseCommand [] = Right Help
parseCommand ["--help"] = Right Help
parseCommand ["-h"] = Right Help
parseCommand ["--version"] = Right Version
parseCommand ["-V"] = Right Version
parseCommand ["index"] = Right (Index ".")
parseCommand ["index", root] = Right (Index root)
parseCommand ["update"] = Right Update
parseCommand ("list" : path : rest) = List path <$> parseListOptions rest
parseCommand ("info" : path : rest) = Info path <$> parseJsonOption rest
parseCommand ["roots"] = Right (Roots False)
parseCommand ["roots", "--json"] = Right (Roots True)
parseCommand ["root", "add", path] = Right (RootAdd path)
parseCommand ["root", "remove", path] = Right (RootRemove path)
parseCommand ["status"] = Right (Status False)
parseCommand ["status", "--json"] = Right (Status True)
parseCommand ("search" : query : rest) = Search query <$> parseSearchOptions rest
parseCommand _ = Left "invalid arguments; run `mar --help`"

parseSearchOptions :: [String] -> Either String SearchOptions
parseSearchOptions = go (SearchOptions Nothing Nothing False Nothing False)
  where
    go options [] = Right options
    go options ("--hidden" : rest) = go options{optionHidden = True} rest
    go options ("--json" : rest) = go options{optionJson = True} rest
    go options ("--type" : value : rest) = case readType value of
        Just kind -> go options{optionType = Just kind} rest
        Nothing -> Left "invalid --type; use file, directory, or symlink"
    go options ("--ext" : value : rest) = go options{optionExtension = Just (pack (normalizeExtension value))} rest
    go options ("--path" : value : rest) = go options{optionPath = Just value} rest
    go _ (option : _) = Left ("unknown search option: " ++ option)

    readType value = case value of
        "file" -> Just RegularFile
        "directory" -> Just Directory
        "symlink" -> Just SymbolicLink
        _ -> Nothing

    normalizeExtension value = case value of
        '.' : _ -> value
        _ -> '.' : value

parseJsonOption :: [String] -> Either String Bool
parseJsonOption [] = Right False
parseJsonOption ["--json"] = Right True
parseJsonOption _ = Left "invalid info options; supported option: --json"

parseListOptions :: [String] -> Either String ListOptions
parseListOptions = go (ListOptions False False False False)
  where
    go options [] = Right options
    go options ("--files" : rest) = go options{listFilesOnly = True} rest
    go options ("--directories" : rest) = go options{listDirectoriesOnly = True} rest
    go options ("--hidden" : rest) = go options{listHidden = True} rest
    go options ("--json" : rest) = go options{listJson = True} rest
    go _ (option : _) = Left ("unknown list option: " ++ option)
