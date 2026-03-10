module Main (main) where

import Lambda.Runtime
import Lambda.Env
import Lambda.Type

listInts :: Expr
listInts =
  App (App (Var "cons") (LitInt 1))
    (App (App (Var "cons") (LitInt 2))
      (App (App (Var "cons") (LitInt 3))
        (Nil TyInt)))

listBools :: Expr
listBools =
  App (App (Var "cons") (LitBool True))
    (App (App (Var "cons") (LitBool True))
      (App (App (Var "cons") (LitBool False))
        (Nil TyBool)))

-- listOfLists :: Expr
-- listOfLists =
--   App (App (Var "cons") listInts)
--     (App (App (Var "cons") listInts)
--       (Nil (TyList TyInt)))

testExprInts :: Expr
testExprInts =
  App
    (App (Var "map") (Lam "x" (TyVar "a") (Var "x"))) -- map id
    listInts

testExprBools :: Expr
testExprBools =
  App
    (App (Var "map") (Lam "x" (TyVar "a") (Var "x"))) -- map id
    listBools

main :: IO ()
main = do
  putStrLn "=== Running map id on listInts ==="
  runTest testExprInts
  putStrLn ""
  putStrLn "=== Running map id on listBools ==="
  runTest testExprBools

  where
    runTest expr =
      case evalExprSteps initialTypeEnv initialValueEnv expr 0 of
        Left err -> putStrLn $ "Error: " ++ err
        Right steps ->
          mapM_ (\(ex, ty, v, d) ->
            putStrLn ((concat (replicate d " |"))
              ++ " "
              ++  show ex
              ++ " :: " ++ show ty
              ++ "  ==>  "
              ++ show v
            )) $
            filter (not . isLiteralOrNil . (\(ex,_,_,_) -> ex)) steps

    isLiteralOrNil :: Expr -> Bool
    isLiteralOrNil e = case e of
      LitBool _   -> True
      LitInt _    -> True
      Nil _       -> True
      _           -> False
