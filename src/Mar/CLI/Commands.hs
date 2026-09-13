module Mar.CLI.Commands (
    runCommand,
) where

import Mar.CLI.Parser (Command (..))
import Mar.TUI.Application (launch)

runCommand :: Command -> IO ()
runCommand command = case command of
    Browse path -> launch path
    Search query -> putStrLn ("search " ++ query)
    Index root -> putStrLn ("index " ++ root)
    Daemon -> putStrLn "daemon"
    Doctor -> putStrLn "doctor"
