module Mar.Core.Path (
    normalizePath,
    isHiddenName,
) where

import Data.Char (isSpace)
import Data.List (isPrefixOf)
import System.FilePath (normalise)

normalizePath :: FilePath -> FilePath
normalizePath = normalise

isHiddenName :: String -> Bool
isHiddenName name =
    not (null name) && "." `isPrefixOf` name && not (all isSpace name)
