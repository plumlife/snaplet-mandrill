{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}

module Main where

------------------------------------------------------------------------------
import           Control.Applicative
import           Control.Lens
import           Data.ByteString.Char8 as C8
import           Data.Maybe            (fromMaybe)
import           Network.API.Mandrill  hiding (runMandrill)
import           Snap
import           Snap.Snaplet.Mandrill
import           Text.Email.Validate

------------------------------------------------------------------------------
data App = App
    { _mandrill :: Snaplet MandrillState
    }

makeLenses ''App

instance HasMandrill (Handler b App) where
    getMandrill = with mandrill getMandrill

------------------------------------------------------------------------------
-- | The application's routes.
routes :: [(ByteString, Handler App App ())]
routes = [ ("/"            , writeText "hello")
         , ("mailme/:email", fooHandler)
         ]

decodedParam :: MonadSnap m => ByteString -> m ByteString
decodedParam p = fromMaybe "" <$> getParam p

fooHandler :: Handler App App ()
fooHandler = do
    email <- decodedParam "email"
    case emailAddress email of
        Nothing -> do
            modifyResponse $ setResponseCode 400
        Just e  -> do
            res <- runMandrill $ do
                return =<< sendEmail (newTextMessage e [e] "Hello" "<p>My Html</p>")

            mandrillResponse res

    getResponse >>= finishWith

  where
    mandrillResponse (MandrillSuccess _) = modifyResponse $ setResponseCode 204
    mandrillResponse (MandrillFailure e) = do
                    modifyResponse $ setResponseCode 500
                    writeBS . C8.pack $ show e


------------------------------------------------------------------------------
-- | The application initializer.
app :: SnapletInit App App
app = makeSnaplet "app" "An snaplet example application." Nothing $ do
    m <- nestSnaplet "mandrill" mandrill $ initMandrill
    addRoutes routes
    return $ App m


main :: IO ()
main = serveSnaplet defaultConfig app
