{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}
module Config where

import           Control.Monad.Except
import           Control.Monad.Reader
import           Data.Text            (Text)
import           Path

import           Paths                ()

class Monad m => MonadConfig m where
  asksConfig :: (Config -> a) -> m a

instance MonadConfig ((->) Config) where
  asksConfig = id

instance MonadConfig m => MonadConfig (ExceptT e m) where
  asksConfig = lift . asksConfig

instance {-# Overlappable #-} MonadConfig m => MonadConfig (ReaderT r m) where
  asksConfig = lift . asksConfig

instance {-# Overlapping #-} Monad m => MonadConfig (ReaderT Config m) where
  asksConfig = asks

data Config = Config
  { jsClientTarget    :: Path Rel File
  , authFile          :: Path Rel File
  , authUser          :: Text
  , authPass          :: Text
  , uiConfigFile      :: Path Rel File
  , packagesJson      :: Path Rel File
  , webServerPort     :: Int
  , webServerHostName :: Text
  , reportDir         :: Path Rel Dir
  , queueDir          :: Path Rel Dir
  , tagsFile          :: Path Rel File
  } deriving Show

defaultConfig :: IO Config
defaultConfig = return Config
  { jsClientTarget    = $(mkRelFile "ui/api.js")
  , authFile          = $(mkRelFile "auth")
  , authUser          = "trustee"
  , authPass          = "1234"
  , uiConfigFile      = $(mkRelFile "ui/config.js")
  , packagesJson      = $(mkRelFile "packages.json")
  , webServerPort     = 3000
  , webServerHostName = "127.0.0.1"
  , reportDir         = $(mkRelDir "report")
  , queueDir          = $(mkRelDir "queue")
  , tagsFile          = $(mkRelFile "tags.json")
  }
