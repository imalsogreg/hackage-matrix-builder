{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeSynonymInstances       #-}
module Api.Types (module Api.Types, PackageName (..), WithPackage, VersionName (..), Revision (..)) where

import           Control.Arrow
import           Data.Aeson              (FromJSON (..), ToJSON (..))
import           Data.JSON.Schema
import qualified Data.Map.Strict         as Map
import           Data.String
import           Data.String.Conversions
import           Data.String.ToString
import           Data.Time
import           Generics.Generic.Aeson

import           BuildReport
import           BuildTypes
import           Identifiers             (PackageName (..), Revision (..),
                                          TagName, VersionName (..),
                                          WithPackage)

data PackageMeta = PackageMeta
  { pmName   :: PackageName
  , pmReport :: Maybe UTCTime
  , pmTags   :: Set TagName
  } deriving (Eq, Generic, Ord, Show)
instance ToJSON     PackageMeta where toJSON    = gtoJsonWithSettings    $ strip "pm"
instance FromJSON   PackageMeta where parseJSON = gparseJsonWithSettings $ strip "pm"
instance JSONSchema PackageMeta where schema    = gSchemaWithSettings    $ strip "pm"

data ReportMeta = ReportMeta
  { rmPackageName :: PackageName
  , rmModified    :: UTCTime
  } deriving (Eq, Generic, Ord, Show)
instance ToJSON     ReportMeta where toJSON    = gtoJsonWithSettings    $ strip "rm"
instance FromJSON   ReportMeta where parseJSON = gparseJsonWithSettings $ strip "rm"
instance JSONSchema ReportMeta where schema    = gSchemaWithSettings    $ strip "rm"

data Report = Report
  { rPackageName :: PackageName
  , rModified    :: UTCTime
  , rResults     :: [GHCResult]
  } deriving (Eq, Generic, Show)
instance ToJSON     Report where toJSON    = gtoJsonWithSettings    $ strip "r"
instance FromJSON   Report where parseJSON = gparseJsonWithSettings $ strip "r"
instance JSONSchema Report where schema    = gSchemaWithSettings    $ strip "r"

toReport :: UTCTime -> ReportData -> Report
toReport md rd = Report
  { rPackageName = fromString . toString . rdPkgName $ rd
  , rModified    = md
  , rResults     = map (f $ rdVersions rd) . Map.toList . rdGVersions $ rd
  }
  where
    f :: Map PkgVer (PkgRev, Bool)
      -> (GhcVer, (PkgVer, Map PkgVer BuildResult, Map PkgVerPfx (Maybe PkgVer)))
      -> GHCResult
    f revs (w,(x,y,z)) = GHCResult
      { ghcVersion     = ghcVersionName w
      , ghcFullVersion = VersionName $ tshowPkgVer x
      , resultsA       = map (toVersionResult revs) . Map.toList $ y
      , resultsB       = map (second $ fmap (VersionName . tshowPkgVer)) . Map.toList $ z
      }
    toVersionResult :: Map PkgVer (PkgRev, Bool) -> (PkgVer,BuildResult) -> VersionResult
    toVersionResult revs (v,r) = VersionResult
      { packageVersion  = VersionName $ tshowPkgVer v
      , packageRevision = Revision . maybe 0 fst $ Map.lookup v revs
      , result          = toResult r
      }
    toResult :: BuildResult -> Result
    toResult = \case
      BuildOk            -> Ok
      BuildNop           -> Nop
      BuildNoIp          -> NoIp
      BuildNoIpBjLimit a -> NoIpBjLimit a
      BuildNoIpFail a b  -> NoIpFail a b
      BuildFail t        -> Fail t
      BuildFailDeps l    -> FailDeps . map (\((xx,xy),y) -> DepFailure
        { dfPackageName    = fromString $ toString xx
        , dfPackageVersion = VersionName $ tshowPkgVer xy
        , dfMessage        = y
        }) $ l

data VersionInfo = VersionInfo
  { version    :: VersionName
  , revision   :: Revision
  , preference :: Preference
  } deriving (Eq, Generic, Show)
instance ToJSON     VersionInfo where toJSON    = gtoJson
instance FromJSON   VersionInfo where parseJSON = gparseJson
instance JSONSchema VersionInfo where schema    = gSchema

data Preference
  = Normal
  | UnPreferred
  | Deprecated
  deriving (Eq, Generic, Show)
instance ToJSON     Preference where toJSON    = gtoJson
instance FromJSON   Preference where parseJSON = gparseJson
instance JSONSchema Preference where schema    = gSchema

data GHCResult = GHCResult
  { ghcVersion     :: VersionName
  , ghcFullVersion :: VersionName
  , resultsA       :: [VersionResult]
  , resultsB       :: [(PkgVerPfx, Maybe VersionName)]
  } deriving (Eq, Generic, Show)
instance ToJSON     GHCResult where toJSON    = gtoJson
instance FromJSON   GHCResult where parseJSON = gparseJson
instance JSONSchema GHCResult where schema    = gSchema

ghcVersionName :: GhcVer -> VersionName
ghcVersionName = VersionName . \case
  GHC_7_00 -> "7.0"
  GHC_7_02 -> "7.2"
  GHC_7_04 -> "7.4"
  GHC_7_06 -> "7.6"
  GHC_7_08 -> "7.8"
  GHC_7_10 -> "7.10"

data VersionResult = VersionResult
  { packageVersion  :: VersionName
  , packageRevision :: Revision
  , result          :: Result
  } deriving (Eq, Generic, Show)
instance ToJSON     VersionResult where toJSON    = gtoJson
instance FromJSON   VersionResult where parseJSON = gparseJson
instance JSONSchema VersionResult where schema    = gSchema

data Result
  = Ok
  | Nop
  | NoIp
  | NoIpBjLimit Word
  | NoIpFail { err :: Text, out :: Text }
  | Fail Text
  | FailDeps [DepFailure]
  deriving (Eq, Generic, Show)
instance ToJSON     Result where toJSON    = gtoJson
instance FromJSON   Result where parseJSON = gparseJson
instance JSONSchema Result where schema    = gSchema

data DepFailure = DepFailure
  { dfPackageName    :: PackageName
  , dfPackageVersion :: VersionName
  , dfMessage        :: Text
  } deriving (Eq, Generic, Show)
instance ToJSON     DepFailure where toJSON    = gtoJsonWithSettings    $ strip "df"
instance FromJSON   DepFailure where parseJSON = gparseJsonWithSettings $ strip "df"
instance JSONSchema DepFailure where schema    = gSchemaWithSettings    $ strip "df"

data Package = Package
  { pName     :: PackageName
  , pVersions :: [VersionInfo]
  } deriving (Eq, Generic ,Show)
instance ToJSON     Package where toJSON    = gtoJsonWithSettings    $ strip "p"
instance FromJSON   Package where parseJSON = gparseJsonWithSettings $ strip "p"
instance JSONSchema Package where schema    = gSchemaWithSettings    $ strip "p"

strip :: String -> Settings
strip = Settings . Just

newtype Username = Username { unUsername :: Text }
  deriving (Eq, FromJSON, Show, ToJSON, JSONSchema)

instance ConvertibleStrings Username Text   where convertString = unUsername
instance ConvertibleStrings Text Username   where convertString = Username
instance ConvertibleStrings Username String where convertString = cs . unUsername
instance ConvertibleStrings String Username where convertString = Username . cs

data User = User
  { uName     :: Username
  , uPackages :: [PackageName]
  } deriving (Eq, Generic, Show)

instance ToJSON     User where toJSON    = gtoJsonWithSettings    $ strip "u"
instance FromJSON   User where parseJSON = gparseJsonWithSettings $ strip "u"
instance JSONSchema User where schema    = gSchemaWithSettings    $ strip "u"

data HackageUserRep = HackageUserRep
  { hugroups   :: [Text]
  , huusername :: Text
  , huuserid   :: Int
  } deriving (Eq, Generic, Show)

instance ToJSON     HackageUserRep where toJSON    = gtoJsonWithSettings    $ strip "hu"
instance FromJSON   HackageUserRep where parseJSON = gparseJsonWithSettings $ strip "hu"
instance JSONSchema HackageUserRep where schema    = gSchemaWithSettings    $ strip "hu"
