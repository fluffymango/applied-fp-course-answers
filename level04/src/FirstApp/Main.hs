{-# LANGUAGE OverloadedStrings #-}
module FirstApp.Main (runApp, app) where

import           Network.Wai              (Application, Request, Response,
                                           pathInfo, requestMethod, responseLBS,
                                           strictRequestBody)
import           Network.Wai.Handler.Warp (run)

import           Network.HTTP.Types       (Status, hContentType, status200,
                                           status400, status404)

import qualified Data.ByteString.Lazy     as LBS

import           Data.Either              (either)

import           Data.Text                (Text)
import           Data.Text.Encoding       (decodeUtf8)

import qualified FirstApp.Conf as Conf
import           FirstApp.Types           (ContentType (PlainText),
                                           Error (EmptyCommentText, EmptyTopic, UnknownRoute),
                                           RqType (AddRq, ListRq, ViewRq),
                                           mkCommentText, mkTopic,
                                           renderContentType)

runApp :: IO ()
runApp = do
  cfgE <- Conf.parseOptions "appconfig.json"
  case cfgE of
    Left err  -> print err
    Right cfg -> run ( Conf.getPort $ Conf.port cfg ) ( app cfg )

-- | Just some helper functions to make our lives a little more DRY.
mkResponse
  :: Status
  -> ContentType
  -> LBS.ByteString
  -> Response
mkResponse sts ct msg =
  responseLBS sts [(hContentType, renderContentType ct)] msg

resp200
  :: ContentType
  -> LBS.ByteString
  -> Response
resp200 =
  mkResponse status200

resp404
  :: ContentType
  -> LBS.ByteString
  -> Response
resp404 =
  mkResponse status404

resp400
  :: ContentType
  -> LBS.ByteString
  -> Response
resp400 =
  mkResponse status400
-- |

app
  :: Conf.Conf
  -> Application
app cfg rq cb = mkRequest rq
  >>= fmap handleRespErr . handleRErr
  >>= cb
  where
    -- Does this seem clunky to you?
    handleRespErr =
      either mkErrorResponse id
    -- Because it is clunky, and we have a better solution, later.
    handleRErr =
      either ( pure . Left ) ( handleRequest cfg )

ok200Text
  :: LBS.ByteString
  -> IO (Either e Response)
ok200Text =
  pure . Right . resp200 PlainText

handleRequest
  :: Conf.Conf
  -> RqType
  -> IO (Either Error Response)
handleRequest cfg (AddRq _ _) =
  ok200Text (Conf.mkMessage cfg)
handleRequest _ (ViewRq _) =
  ok200Text "Susan was ere"
handleRequest _ ListRq =
  ok200Text "[ \"Fred wuz ere\", \"Susan was ere\" ]"

mkRequest
  :: Request
  -> IO ( Either Error RqType )
mkRequest rq =
  case ( pathInfo rq, requestMethod rq ) of
    -- Commenting on a given topic
    ( [t, "add"], "POST" ) ->
      mkAddRequest t <$> strictRequestBody rq
    -- View the comments on a given topic
    ( [t, "view"], "GET" ) ->
      pure ( mkViewRequest t )
    -- List the current topics
    ( ["list"], "GET" )    ->
      pure mkListRequest
    -- Finally we don't care about any other requests so throw your hands in the air
    _                      ->
      pure mkUnknownRouteErr

mkAddRequest
  :: Text
  -> LBS.ByteString
  -> Either Error RqType
mkAddRequest ti c = AddRq
  <$> mkTopic ti
  <*> (mkCommentText . decodeUtf8 . LBS.toStrict) c

mkViewRequest
  :: Text
  -> Either Error RqType
mkViewRequest =
  fmap ViewRq . mkTopic

mkListRequest
  :: Either Error RqType
mkListRequest =
  Right ListRq

mkUnknownRouteErr
  :: Either Error a
mkUnknownRouteErr =
  Left UnknownRoute

mkErrorResponse
  :: Error
  -> Response
mkErrorResponse UnknownRoute =
  resp404 PlainText "Unknown Route"
mkErrorResponse EmptyCommentText =
  resp400 PlainText "Empty Comment"
mkErrorResponse EmptyTopic =
  resp400 PlainText "Empty Topic"

