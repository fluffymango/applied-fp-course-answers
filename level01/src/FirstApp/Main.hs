{-# LANGUAGE OverloadedStrings #-}
module FirstApp.Main (runApp) where

import           Network.Wai              (Application, responseLBS)
import           Network.Wai.Handler.Warp (run)

import           Network.HTTP.Types       (status200)

{-|
Our "application" will simply respond to ALL incoming requests with a 200 status
code response and the message "Hello, World!"

The Application type from Wai is a type synonym for the follwing type:

:: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived

So the first argument to our function below is the incoming Request, which we
disregard using `_`. The next input is the callback function that signals when
our request is complete.

This callback function is to signal to the Wai framework and we've completed our
part and it's free to close any resources it had and send the response.
-}
app
  :: Application
app _ cb =
  let headers = [("Content-Type", "text/plain")]
      message = "Hello, World!"
  in
    cb $ responseLBS status200 headers message

{-|
This is about as basic as it gets.
-}
runApp :: IO ()
runApp = run 3000 app
