module Main (main) where

import SSA.Core

-- Example A from the paper
cfgMatrix :: Matrix
cfgMatrix = map (map (== 1))
    [ [0,0,0,0,0,0]
    , [1,0,0,0,1,0]
    , [0,1,0,0,0,0]
    , [0,1,0,0,0,0]
    , [0,0,1,1,0,0]
    , [1,0,0,0,1,0]
    ]

cfg :: [Bool]
cfg = map (==1) [1,0,1,0,0,0]

main :: IO ()
main = do
    _ <- ssaIO cfgMatrix cfg
    putStrLn "Finished"

