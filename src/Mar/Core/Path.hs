module Mar.Core.Path (
    normalizePath,
    displayName,
    isHiddenName,
) where

import Data.Char (isSpace)
import Data.List (isPrefixOf)
import System.FilePath (FilePath, normalise, takeFileName)

normalizePath :: FilePath -> FilePath
normalizePath path = normalise path

displayName :: FilePath -> String
displayName path =
    let name = takeFileName (normalizePath path)
     in if null name then path else name

isHiddenName :: String -> Bool
isHiddenName name =
    not (null name) && "." `isPrefixOf` name && not (all isSpace name)
