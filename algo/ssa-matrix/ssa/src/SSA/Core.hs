-- Core concept of matrix-based SSA implemented.
--
-- We could try to rewrite this to C and apply in
-- some compiler.

module SSA.Core
    ( Matrix
    , ssaPure
    , ssaIO
    ) where

import Data.List (transpose)

type Matrix = [[Bool]]

matrixAdd :: Matrix -> Matrix -> Matrix
matrixAdd = zipWith $ zipWith (||)

matrixIntersect :: Matrix -> Matrix -> Matrix
matrixIntersect = zipWith $ zipWith (&&)

matrixMul :: Matrix -> Matrix -> Matrix
matrixMul a b =
    let b' = transpose b
    in [[ or [x && y
        | (x, y) <- zip row col]
        | col <- b' ]
        | row <- a  ]

matrixSub :: Matrix -> Matrix -> Matrix
matrixSub = zipWith $ zipWith (\x y -> x && not y)

matrixNegate :: Matrix -> Matrix
matrixNegate = map $ map not

matrixIdentity :: Int -> Matrix
matrixIdentity n = [[i==j | j <- [0 .. n - 1]] | i <- [0 .. n - 1]]

transitiveClosure :: Matrix -> Matrix
transitiveClosure m = foldl step m [0 .. n - 1]
    where
        n = length m
        step mat k =
          [ [ mat !! i !! j || (mat !! i !! k && mat !! k !! j)
            | j <- [0 .. n - 1] ]
            | i <- [0 .. n - 1] ]

-- Extended transitive closure f*
extendedTransitiveClosure :: Matrix -> Matrix -> Matrix -> Matrix
extendedTransitiveClosure s a c = go s
    where
        go x =
            let step = matrixIntersect (matrixMul a x) c
                x'   = matrixAdd x step
            in if x' == x then x else go x'

-- M = ¬f*(¬M0, A, ¬I)
computeM :: Matrix -> Matrix
computeM a =
    let n  = length a
        i  = matrixIdentity n
        m0 = [ if r == 0 then [j == 0 | j <- [0 .. n - 1] ]
               else replicate n True
             | r <- [0 .. n - 1] ]
    in matrixNegate $ extendedTransitiveClosure (matrixNegate m0) a (matrixNegate i)

-- D = (A.M − M)^T
computeD :: Matrix -> Matrix -> Matrix
computeD a m = transpose (matrixSub (matrixMul a m) m)

vectorMul :: [Bool] -> Matrix -> [Bool]
vectorMul v m =
    [ or [vi && mij | (vi, mij) <- zip v col]
    | col <- transpose m ]

ssaPure :: Matrix -> [Bool] -> [Bool]
ssaPure cfgMatrix defs =
    let m    = computeM cfgMatrix
        d    = computeD cfgMatrix m
        j    = transitiveClosure d
    in vectorMul defs j

matrixShow :: Matrix -> String
matrixShow = unlines . map (unwords . map (\b -> if b then "1" else "0"))

vectorShow :: [Bool] -> String
vectorShow = unwords . map (\b -> if b then "1" else "0")

ssaIO :: Matrix -> [Bool] -> IO [Bool]
ssaIO cfgMatrix defs = do
    let m    = computeM cfgMatrix
        d    = computeD cfgMatrix m
        j    = transitiveClosure d
        out  = vectorMul defs j
    putStrLn "M matrix:"
    putStrLn $ matrixShow m
    putStrLn "\nD matrix:"
    putStrLn $ matrixShow d
    putStrLn "\nJ+ matrix:"
    putStrLn $ matrixShow j
    putStrLn "\nResult:"
    putStrLn $ vectorShow out
    return out
