module Main (main) where

import Language.Core
import Language.Eval
import Language.Env

-- Utils: desugar a surface list [e1,e2,...] into nested cons calls:
--   [a,b,c] -> cons(a, cons(b, cons(c, nil)))
desugarList :: [Expr] -> Expr
desugarList [] = EVar "nil"
desugarList (x:xs) = ECall (EVar "cons") [x, desugarList xs]

-- map f xs =
--   xs =>
--     () -> []
--     (h, t) -> (f h, map (f, t))
mapExpr :: Expr
mapExpr =
  ELet "map"
    (ELam [PVar "f", PVar "xs"] $
      ECase (EVar "xs")
        [ (PUnitP, EUnit)  -- []
        , (PTupleP (PVar "h") (PVar "t"),
            ETuple
              (ECall (EVar "f") [EVar "h"])
              (ECall (EVar "map") [EVar "f", EVar "t"]))
        ])
    (EVar "map")

-- foldl f acc xs =
--   xs =>
--     () -> acc
--     (h, t) -> foldl f (f acc h) t
foldlExpr :: Expr
foldlExpr =
  ELet "foldl"
  (ELam [(PVar "f"), (PVar "acc"), (PVar "xs")] (
    ECase (EVar "xs")
      [ (PUnitP, EVar "acc")  -- []
      , (PTupleP (PVar "h") (PVar "t"),
          ECall (EVar "foldl")
            [ EVar "f"
            , ECall (EVar "f") [EVar "acc", EVar "h"]
            , EVar "t"
            ])
      ]))
  (EVar "foldl")

-- sum xs = foldl (+) 0 xs
sumExpr :: Expr
sumExpr =
  ELet "sum"
    (ELam [PVar "xs"] $
      ECall foldlExpr
        [ EVar "+"
        , EInt 0
        , EVar "xs"
        ])
    (EVar "sum")

-- Example: compute sum [1,2,3]
example1 :: Expr
example1 =
  ECall sumExpr [desugarList [EInt 1, EInt 2, EInt 3]]

example3 :: Expr
example3 = ECall mapExpr [ELam [PVar "x"] (ECall (EVar "*") [EVar "x", EVar "x"]), desugarList [EInt 1, EInt 2, EInt 3]]

-- small helper to run and pretty-print evaluation
runEval :: Expr -> IO ()
runEval e = case eval initialEnv e of
  Left err -> putStrLn $ "Error: " ++ err
  Right (v, _)  -> putStrLn $ show v

main :: IO ()
main = do
  putStrLn "List [1,2,3] =>"
  runEval $ desugarList [EInt 1, EInt 2, EInt 3]
  putStrLn "sum [1,2,3] =>"
  runEval example1
  putStrLn "map =>"
  runEval example3
