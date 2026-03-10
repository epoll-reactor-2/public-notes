module Main (main) where

import Lambda.Core
import Lambda.Library

expr :: Term
expr = App
   (App
       (App foldScott addChurch)
       (numChurch 0))
   (App
       concatChurch
       (concatMany [[1, 2], [3], [4, 5]]))

main :: IO ()
main = do
    mapM_ (putStrLn . pp) (evalReductionSteps $ expr)
