{-# LANGUAGE OverloadedStrings #-}
module Truth where

import Config
import Feature
import Tests
import Data.Text (Text, pack)
import Text.Pandoc
import Text.Pandoc.Options
import Text.Pandoc.Class
import Text.Pandoc.Readers.Markdown
import Text.Pandoc.Definition
import Control.Monad.IO.Class
import Control.Lens
import Control.Lens.Each
import Data.Foldable

generate :: (PandocMonad m, MonadIO m) => Config -> m Features
generate config = do
  doc        <- readFeaturesDoc $ config^.featuresFile
  features   <- return $ loadFeatures doc
  tests      <- readTests $ config^.testsFile
  let result = combine features tests
  return $ result

readFeaturesDoc :: (PandocMonad m, MonadIO m) => String -> m Pandoc
readFeaturesDoc path = do
  raw <- liftIO $ readFile $ path
  readMarkdown def (pack raw)

readTests :: (MonadIO m) => String -> m Tests
readTests path = do
  raw <- liftIO $ readFile $ path
  return $ parseReport (parse raw)
  where
    parseReport :: Maybe Tests -> Tests
    parseReport (Nothing) = error "could not parse report"
    parseReport (Just ts) = ts

loadFeatures :: Pandoc -> Features
loadFeatures p = extractFeaturesFromPandoc p

combine :: Features -> Tests -> Features
combine fs (Tests []) = fs & features.traverse.userStories.traverse.criteria.traverse.status .~  Missing
combine fs ts = over allCriteria (fmap (modify (ts^.tests))) fs
  where
     modify :: [Test] -> Criteria -> Criteria
     modify ts c = case (findTest ts c) of
       Nothing  -> status .~ Missing $ c
       (Just t) -> status .~ (testToStatus (t^.testStatus)) $ c

     testToStatus Passed = Done
     testToStatus ts = NotDone ts

     findTest :: [Test] -> Criteria -> Maybe Test
     findTest ts c = find (\t -> t^.testDesc == c^.testName) ts
