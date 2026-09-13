module Main (main) where

import Mar.CLI.Commands (runCommand)
import Mar.CLI.Parser (parseOptions)

main :: IO ()
main = parseOptions >>= runCommand
