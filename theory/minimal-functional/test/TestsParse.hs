module TestsParse
  ( testsParse
  ) where

import Test.Tasty
import Test.Tasty.HUnit
import Language.Core
import Language.Parse
import Text.Megaparsec (errorBundlePretty)

run :: String -> [Expr]
run src = case parseProgram src of
  Left err  -> error $ "Parse failed: " ++ errorBundlePretty err
  Right []  -> error "Parse returned empty AST"
  Right ast -> ast

testsParse :: TestTree
testsParse = testGroup "Parse"
  [ testCase "Fold" $
      run (unlines
        [ "foldl f acc xs ="
        , "  xs =>"
        , "    | () -> acc"
        , "    | (h, t) -> foldl (f f (acc h) t)"
        ]) @?=
        [ ELet "foldl"
          (ELam [(PVar "f"), (PVar "acc"), (PVar "xs")]
            (ECase (EVar "xs")
              [ (PUnitP, EVar "acc")  -- []
              , (PTupleP (PVar "h") (PVar "t"),
                  ECall (EVar "foldl")
                    [ EVar "f"
                    , ECall (EVar "f") [EVar "acc", EVar "h"]
                    , EVar "t"
                    ])
              ]))
          (EVar "foldl") ]

  , testCase "Map" $
      run (unlines
        [ "map f xs ="
        , "  xs =>"
        , "    | () -> ()"
        , "    | (h, t) -> (f (h), map (f t))"
        ]) @?=
        [ ELet "map"
          (ELam [PVar "f", PVar "xs"]
            (ECase (EVar "xs")
              [ (PUnitP, EUnit)
              , (PTupleP (PVar "h") (PVar "t"),
                  ETuple
                    (ECall (EVar "f") [EVar "h"])
                    (ECall (EVar "map") [EVar "f", EVar "t"]))]))
          (EVar "map") ]

  , testCase "Case guard" $
    run (unlines
      [ "f x assert ="
      , "  x =>"
      , "    | (==) assert -> 1"
      ]) @?=
      [ ELet "f"
          (ELam [PVar "x", PVar "assert"]
            (ECase (EVar "x")
              [ (PGuard (EVar "==")
                  (EVar "assert")
                 , EInt 1)])) (EVar "f")]

  , testCase "Case guard (nested)" $
    run (unlines
      [ "f x assert ="
      , "  x =>"
      , "    | (==) (+) (assert (%) (10 2)) -> 1"
      ]) @?=
      [ ELet "f"
          (ELam [PVar "x", PVar "assert"]
            (ECase (EVar "x")
              [ (PGuard (EVar "==")
                  (ECall (EVar "+")
                    [ EVar "assert"
                    , ECall (EVar "%")
                      [ EInt 10, EInt 2 ]])
                  , EInt 1)])) (EVar "f")]

  , testCase "Identity" $
      run "id x = x" @?=
        [ ELet "id" (ELam [PVar "x"] (EVar "x")) (EVar "id") ]

  , testCase "Some params" $
      run "f a b c = a" @?=
        [ ELet "f" (ELam [(PVar "a"), (PVar "b"), (PVar "c")] (EVar "a")) (EVar "f") ]
  
  , testCase "Operator (external)" $
      run "sum xs = foldl (x 0 xs)" @?=
        [ ELet "sum"
          (ELam [PVar "xs"]
            (ECall (EVar "foldl") [EVar "x", EInt 0, EVar "xs"]))
        (EVar "sum") ]

  , testCase "Operator (+)" $
      run "sum xs = foldl ((+) 0 xs)" @?=
        [ ELet "sum"
          (ELam [PVar "xs"]
            (ECall (EVar "foldl") [EVar "+", EInt 0, EVar "xs"]))
        (EVar "sum") ]

  , testCase "(+) function" $
      run "(+) = 1" @?=
        [ ELet "+" (ELam [] (EInt 1)) (EVar "+") ]

  , testCase "Multiple declarations" $
      run (unlines
        [ "f a = a"
        , "g b = b"
        , "g (0)"
        ]) @?=
        [ (ELet "f" (ELam [PVar "a"] (EVar "a")) (EVar "f"))
        , (ELet "g" (ELam [PVar "b"] (EVar "b")) (EVar "g"))
        , (ECall (EVar "g") [EInt 0])
        ]

  , testCase "Map call" $
      run (unlines
        [ "map f xs ="
        , "  xs =>"
        , "    | () -> ()"
        , "    | (h, t) -> (f (h), map (f t))"  
        , ""
        , "map ((+) (1, (2, (3, ()))))"
        ]) @?=
        [ ELet "map"
            (ELam [PVar "f", PVar "xs"]
              (ECase (EVar "xs")
                [ (PUnitP, EUnit)
                , (PTupleP (PVar "h") (PVar "t"),
                    ETuple
                      (ECall (EVar "f") [EVar "h"])
                      (ECall (EVar "map") [EVar "f", EVar "t"]))]))
          (EVar "map"),

          ECall (EVar "map")
            [ EVar "+"
            , ETuple (EInt 1) (ETuple (EInt 2) (ETuple (EInt 3) EUnit))
            ]
        ]

  , testCase "map inline lambda" $
      run (unlines
        [ "map f xs ="
        , "  xs =>"
        , "    | () -> ()"
        , "    | (h, t) -> (f (h), map (f t))"
        , ""
        , "map ((x = (+) (x x)) (1, (2, (3, ()))))"
        ]) @?=
        [ ELet "map"
            (ELam [PVar "f", PVar "xs"]
              (ECase (EVar "xs")
                [ (PUnitP, EUnit)
                , (PTupleP (PVar "h") (PVar "t")
                , ETuple
                    (ECall (EVar "f") [EVar "h"])
                    (ECall (EVar "map") [EVar "f",EVar "t"]))]))
              (EVar "map")

        , ECall (EVar "map")
            [ ELam [PVar "x"]
                (ECall (EVar "+") [EVar "x",EVar "x"])
            , ETuple (EInt 1) (ETuple (EInt 2) (ETuple (EInt 3) EUnit))
            ]
        ]

  , testCase "Factorial" $
      run (unlines
        [ "factorial n ="
        , "  n =>"
        , "    | 0 -> 1"
        , "    | _ -> (*) (n factorial ((-) (n 1)))"
        , ""
        , "factorial (5)"
        ]) @?=
        [ ELet "factorial"
            (ELam [PVar "n"]
              (ECase (EVar "n")
                [ (PInt 0,EInt 1)
                , (PWild, ECall (EVar "*")
                  [ EVar "n"
                  , ECall (EVar "factorial") [ ECall (EVar "-") [EVar "n", EInt 1]]
                  ])])) (EVar "factorial"),ECall (EVar "factorial") [EInt 5]]
  ]
