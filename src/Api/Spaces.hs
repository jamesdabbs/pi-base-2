{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE TypeOperators        #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Api.Spaces
  ( API
  , handlers
  ) where

import Base
import Data.Aeson
import Servant

import qualified Database.Persist as DB
import qualified Handlers.Helpers as H

import Models (runDB)

type API = GET [Entity Space]
      :<|> Body Space :> Authenticated :> POST (Entity Space)
      :<|> Capture "space_id" SpaceId
           :> ( GET (Entity Space)
           :<|> Body Space :> Authenticated :> PUT (Entity Space)
           :<|> Authenticated :> DELETE (Entity Space)
           :<|> "revisions" :> GET [Rev Space]
           )

handlers :: Config -> Server API
handlers = H.serve $
  index  :<|>
  create :<|>
  ( \_id ->
    H.show    _id :<|>
    update    _id :<|>
    delete    _id :<|>
    revisions _id
  )

index :: Action [Entity Space]
index = H.index

create :: Space -> AuthenticatedAction (Entity Space)
create s = H.withUser $ \_ -> do
  _id <- runDB $ DB.insert s
  -- TODO: record user / revision
  return $ Entity _id s

update :: SpaceId -> Space -> AuthenticatedAction (Entity Space)
update = error "update space"

delete :: SpaceId -> AuthenticatedAction (Entity Space)
delete = error "delete space"

revisions :: SpaceId -> Action [Rev a]
revisions = error "space revisions"

instance FromText SpaceId where
  fromText = H.idFromText

instance FromJSON Space where
  parseJSON = withObject "space" $ \o -> do
    spaceName        <- o .: "name"
    spaceDescription <- o .: "description"
    let spaceCreatedAt       = Nothing
        spaceUpdatedAt       = Nothing
        spaceProofOfTopology = Nothing
    return Space{..}

instance ToJSON [Entity Space] where
  toJSON ps = object [ "spaces" .= map fmt ps ]
    where
      fmt (Entity _id Space{..}) = object
        [ "id" .= _id
        , "name" .= spaceName
        ]

instance ToJSON (Entity Space) where
  toJSON (Entity _id Space{..}) = object
    [ "id"                .= _id
    , "name"              .= spaceName
    , "description"       .= spaceDescription
    , "proof_of_topology" .= spaceProofOfTopology
    ]
