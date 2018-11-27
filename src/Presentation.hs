{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
module Presentation where

import GHC.Generics
import Config
import Crypt
import Feature
import Tests
import Data.Aeson
import Data.Aeson.Types as AT
import Data.Text (Text, pack)
import Text.DocTemplates
import Text.Pandoc as P
import Text.Pandoc.Options
import Text.Pandoc.Class
import Text.Pandoc.Readers.Markdown
import Text.Pandoc.Definition
import Control.Monad.IO.Class
import Control.Lens
import Control.Lens.Each
import Data.Foldable

data CompletedStatus = NotDefined | PartiallyDefined | Failing String | InProgress (Int, Int) | Successful
  deriving Eq

class Completed a where
  isCompleted :: a -> CompletedStatus
  klazz :: a -> String
  klazz a = klazz' $ isCompleted a
    where
      klazz' NotDefined = "danger"
      klazz' PartiallyDefined = "danger"
      klazz' (Failing _) = "danger"
      klazz' (InProgress _) = "warning"
      klazz' Successful = "success"
  label :: a -> String
  label a = label' $ isCompleted a
    where
      label' NotDefined = "not defined"
      label' PartiallyDefined = "partially defined"
      label' (Failing reason) = "failing: " ++ show reason
      label' (InProgress (d, a)) = show d ++ " / " ++ show a
      label' Successful = "success"

instance Completed Feature where
  isCompleted (Feature _ []) = NotDefined
  isCompleted (Feature _ us) = NotDefined

instance Completed UserStory where
  isCompleted (UserStory _ []) = NotDefined
  isCompleted (UserStory _ cs) = NotDefined

instance Completed Criteria where
  isCompleted (Criteria _ _ Done _ ) = Successful
  isCompleted (Criteria _ _ Missing _ ) = NotDefined
  isCompleted (Criteria _ _ (NotDone reason) _ ) = Failing $ show reason

instance ToJSON Features where
  toJSON a = object [
    "features" AT..= map toJSON (_features a)
    ]

instance ToJSON Feature where
  toJSON a = object [
    "id" AT..= encodeToString (show a),
    "featureName" AT..= _featureName a ,
    "userStories" AT..= map toJSON (_userStories a),
    "class" AT..= klazz a,
    "label" AT..= label a]

instance ToJSON UserStory where
  toJSON a = object [
    "id" AT..= encodeToString (show a),
    "description" AT..= _userStoryDesc a,
    "criteria" AT..= map toJSON (_criteria a),
    "class" AT..= klazz a,
    "label" AT..= label a]

instance ToJSON Criteria where
  toJSON a = object [
    "id" AT..= encodeToString (show a),
    "name" AT..= _criteriaName a,
    "steps" AT..= _steps a,
    "class" AT..= klazz a,
    "label" AT..= label a]

instance ToJSON Step where
  toJSON a = object [
    "id" AT..= encodeToString (show a),
    "value" AT..= show a]

instance ToJSON Status

templateIO :: IO Text
templateIO = fmap pack $ readFile "template/template.html"

present :: Features -> IO String
present f = do
  template <- templateIO
  case compileTemplate template of
         Left e    -> error e
         Right t   -> return $ renderTemplate t $ f
