module Mar.Config.Version (marVersion) where

import Data.Version (Version, makeVersion)

marVersion :: Version
marVersion = makeVersion [0, 1, 0, 0]
