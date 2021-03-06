{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

module Models where

import Base
import qualified Universe as U

import qualified Data.Map as M
import Data.Text (unpack)
import Database.Persist
import Database.Persist.Postgresql (SqlBackend(..), runMigration, runSqlPool, SqlPersistT)
import Util (toSqlKey)

true, false :: TValueId
true  = toSqlKey 1
false = toSqlKey 2

doMigrations :: ReaderT SqlBackend IO ()
doMigrations = runMigration migrateAll

runDB :: (MonadReader Config m, Monad m, MonadIO m) => SqlPersistT IO a -> m a
runDB q = asks getPool >>= liftIO . runSqlPool q

mkUniverse :: ReaderT SqlBackend IO U.Universe
mkUniverse = do
  spaces <- selectKeysList [] []
  pairs  <- mapM traitsFor spaces
  return $ U.fromPairs pairs

  where
    toKeyPair :: Entity Trait -> (PropertyId, TValueId)
    toKeyPair (Entity _ Trait{..}) = (traitPropertyId, traitValueId)

    traitsFor :: SpaceId -> ReaderT SqlBackend IO (SpaceId, U.Properties)
    traitsFor _sid = do
      traits <- selectList [TraitSpaceId ==. _sid] []
      let pairs = M.fromList . map toKeyPair $ traits
      return (_sid, pairs)

checkBooleans :: ReaderT SqlBackend IO ()
checkBooleans = do
  get true  >>= assertNamed "True"
  get false >>= assertNamed "False"
  liftIO $ putStrLn "Booleans are present and accounted for"
  where
    assertNamed :: Text -> Maybe TValue -> ReaderT SqlBackend IO ()
    assertNamed name mv = liftIO $ case mv of
      Nothing -> error . unpack $ name <> " not found"
      Just v  -> if name == (tValueName v)
        then return () -- putStrLn . unpack $ name <> " OK!" -- FIXME
        else error . unpack $ name <> " has the wrong id"
