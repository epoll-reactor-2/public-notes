module TestsEval
  ( testsEval
  ) where

import Test.Tasty
import Test.Tasty.HUnit
import Language.Core
import Language.Eval
import Language.Env
import Language.Parse
import Text.Megaparsec (errorBundlePretty)

-- Utils: desugar a surface list [e1,e2,...] into nested cons calls:
--   [a,b,c] -> cons(a, cons(b, cons(c, nil)))
desugarList :: [Value] -> Value
desugarList []     = VUnit
desugarList (x:xs) = VPair x (desugarList xs)

parseExpr :: String -> [Expr]
parseExpr src = case parseProgram src of
  Left err  -> error $ "Parse failed: " ++ errorBundlePretty err
  Right []  -> error "Parse returned empty AST"
  Right ast -> ast

run :: [Expr] -> Value
run decls =
  case go initialEnv decls of
    Left err        -> error $ "Runtime error: " ++ err
    Right (v, _)    -> v
  where
    go env []     = Right (VUnit, env)
    go env [e]    = eval env e
    go env (e:es) = do
      (_, newEnv) <- eval env e
      go newEnv es

testsEval :: TestTree
testsEval = testGroup "Eval"
  [ testCase "Builtin operator" $
    (run $ parseExpr (unlines
      [ "(+) (1 2)"
      ])) @?= VInt 3

  , testCase "Operator" $
    (run $ parseExpr (unlines
      [ "(@<<<@) l r = (+) (l (+) (l (+) (l r)))"
      , ""
      , "(@<<<@) (10 20)"
      ])) @?= VInt 50

  , testCase "Sum list" $
    (run $ parseExpr (unlines
      [ "foldl f acc xs ="
      , "  xs =>"
      , "    | () -> acc"
      , "    | (h, t) -> foldl (f f (acc h) t)"
      , ""
      , "sum xs = foldl ((+) 0 xs)"
      , ""
      , "sum ((1, (2, (3, nil))))"
      ])) @?= VInt 6

  , testCase "Length" $
    (run $ parseExpr (unlines
      [ "length xs ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) -> (+) (1 length (t))"
      , ""
      , "length ((1, (2, (3, nil))))"
      ])) @?= VInt 3

  , testCase "Zip" $
    (run $ parseExpr (unlines
      [ "zip xs ys ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (hx, tx) ->"
      , "        ys =>"
      , "          | () -> ()"
      , "          | (hy, ty) -> ((hx, (hy, ())), zip (tx ty))"
      , ""
      , "zip ( (1, (2, (3, nil))) (4, (5, (6, nil))) )"
      ])) @?= desugarList [
        desugarList [VInt 1, VInt 4],
        desugarList [VInt 2, VInt 5],
        desugarList [VInt 3, VInt 6]
      ]

  , testCase "Map square" $
    (run $ parseExpr (unlines
      [ "square x = (*) (x x)"
      , ""
      , "map f xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) -> (f (h), map (f t))"
      , ""
      , "map (square (1, (2, (3, nil))))"
      ])) @?= desugarList [VInt 1, VInt 4, VInt 9]

  , testCase "Map square (inlined lambda)" $
    (run $ parseExpr (unlines
      [ "map f xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) -> (f (h), map (f t))"
      , ""
      , "map ((x = (*) (x x)) (1, (2, (3, ()))))"
      ])) @?= desugarList [VInt 1, VInt 4, VInt 9]

  , testCase "Reverse" $
    (run $ parseExpr (unlines
      [ "append xs ys ="
      , "  xs =>"
      , "    | () -> ys"
      , "    | (h, t) -> (h, append (t ys))"
      , ""
      , "reverse xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) -> append (reverse (t) (h, nil))"
      , ""
      , "reverse ((1, (2, (3, nil))))"
      ])) @?= desugarList [VInt 3, VInt 2, VInt 1]

  , testCase "Factorial" $
    (run $ parseExpr (unlines
      [ "factorial n ="
      , "  n =>"
      , "    | 0 -> 1"
      , "    | _ -> (*) (n factorial ((-) (n 1)))"
      , ""
      , "factorial (5)"
      ])) @?= VInt 120

  , testCase "Contains" $
    (run $ parseExpr (unlines
      [ "contains xs val ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) ->"
      , "        h =>"
      , "          | (==) val -> 1"
      , "          | _ -> contains (t val)"
      , ""
      , "contains ( (1, (2, (3, nil))) 1)"
      ])) @?= VInt 1

  , testCase "Not contains" $
    (run $ parseExpr (unlines
      [ "contains xs val ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) ->"
      , "        h =>"
      , "          | (==) val -> 1"
      , "          | _ -> contains (t val)"
      , ""
      , "contains ( (1, (2, (3, nil))) 10)"
      ])) @?= VInt 0

  , testCase "All evens" $
    (run $ parseExpr (unlines
      [ "anyEven xs ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) ->"
      , "        h =>"
      , "          | (%) 2 -> 1"
      , "          | _ -> anyEven (t)"
      , ""
      , "anyEven ((2, (4, (5, nil))))"
      ])) @?= VInt 1

  , testCase "All evens (nested call)" $
    (run $ parseExpr (unlines
      [ "anyEven xs ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) ->"
      , "        h =>"
      , "          | (%) (+) (1 1) -> 1"
      , "          | _ -> anyEven (t)"
      , ""
      , "anyEven ((2, (4, (5, nil))))"
      ])) @?= VInt 1

  , testCase "Contains constant" $
    (run $ parseExpr (unlines
      [ "containsConst xs ="
      , "  xs =>"
      , "    | () -> 0"
      , "    | (h, t) ->"
      , "        h =>"
      , "          | 3 -> 1"
      , "          | _ -> containsConst (t)"
      , ""
      , "containsConst ((1, (2, (3, nil))))"
      ])) @?= VInt 1

  , testCase "Filter" $
    (run $ parseExpr (unlines
      [ "filter p xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) ->"
      , "      p (h) =>"
      , "        | 0 -> filter (p t)"
      , "        | _ -> (h, filter (p t))"
      , ""
      , "filter ((x = (==) ((%) (x 2) 0)) (1, (2, (3, (4, nil)))))"
      ])) @?= desugarList [VInt 2, VInt 4]

  , testCase "Quicksort" $
    (run $ parseExpr (unlines
      [ "append xs ys ="
      , "  xs =>"
      , "    | () -> ys"
      , "    | (h, t) -> (h, append (t ys))"
      , ""
      , "filter p xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) ->"
      , "      p (h) =>"
      , "        | 0 -> filter (p t)"
      , "        | _ -> (h, filter (p t))"
      , ""
      , "quicksort xs ="
      , "  xs =>"
      , "    | () -> ()"
      , "    | (h, t) ->"
      , "        append ("
      , "          quicksort ("
      , "            filter ((x = (<) (x h)) t)"
      , "          )"
      , "          (h, quicksort ("
      , "                filter ((x = (>=) (x h)) t)"
      , "          ))"
      , "        )"
      , ""
      , ""
      , "quicksort ((10, (3, (2, (7, nil)))))"
      ])) @?= desugarList [VInt 2, VInt 3, VInt 7, VInt 10]
  ]
