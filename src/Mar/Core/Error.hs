module Mar.Core.Error (
    MarError (..),
) where

data MarError
    = PathNotFound FilePath
    | PermissionDenied FilePath
    | InvalidOperation String
    | StorageFailure String
    deriving (Eq, Show)
