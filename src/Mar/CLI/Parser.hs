module Mar.CLI.Parser (
    Command (..),
    parseOptions,
) where

import System.Environment (getArgs)

data Command
    = Browse FilePath
    | Search String
    | Index FilePath
    | Daemon
    | Doctor
    deriving (Eq, Show)

parseOptions :: IO Command
parseOptions = parseCommand <$> getArgs

parseCommand :: [String] -> Command
parseCommand [] = Browse "."
parseCommand ["search", query] = Search query
parseCommand ["index"] = Index "."
parseCommand ["index", root] = Index root
parseCommand ["daemon"] = Daemon
parseCommand ["doctor"] = Doctor
parseCommand [path] = Browse path
parseCommand _ = Browse "."
