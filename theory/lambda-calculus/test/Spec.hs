module Main ( main ) where

import Test.Tasty
import Test.Tasty.HUnit
import Lambda.Core
import Lambda.Library

main :: IO ()
main = defaultMain tests

factBody :: Term
factBody =
    Lam "f" (Lam "n"
      (App
        (App (App ifthen (App isZero (Var "n"))) (numChurch 1))
        (App (App mulChurch (Var "n"))
              (App (Var "f") (App predChurch (Var "n"))))))

factorialCombinator :: Term
factorialCombinator = App yCombinator factBody

factorial :: Int -> Term
factorial n = App factorialCombinator $ numChurch n

tests :: TestTree
tests = testGroup "Lambda calculus tests"
    [ testCase "Y combinator" $
        yCombinator @?=
            Lam "f" (App
                (Lam "x" (App (Var "f") (App (Var "x") (Var "x"))))
                (Lam "x" (App (Var "f") (App (Var "x") (Var "x")))))

    , testCase "Y combinator (string)" $
        pp yCombinator @?= "λf.(λx.(f (x x)) λx.(f (x x)))"

    , testCase "2 (generic lambda)" $
        (numChurch 2) @?= Lam "f" (Lam "x" (App (Var "f") (App (Var "f") (Var "x"))))

    , testCase "2 (generic eval)" $
        decodeNum (numChurch 2) @?= Just 2

    , testCase "10000 (generic eval)" $
        decodeNum (numChurch 10000) @?= Just 10000

    , testCase "Factorial (lambda)" $
        eval (factorial 3) @?=
            Lam "f" (
                Lam "x" (
                    App (Var "f") ( -- 1
                    App (Var "f") ( -- 2
                    App (Var "f") ( -- 3
                    App (Var "f") ( -- 4
                    App (Var "f") ( -- 5
                    App (Var "f") ( -- 6
                    Var "x"))))))))

    , testCase "4!" $
        decodeNum (eval (factorial 4)) @?= Just 24

    , testCase "1 + 2" $
        decodeNum (eval (App (App addChurch (numChurch 1)) (numChurch 2))) @?= Just 3

    , testCase "10 - 5" $
        decodeNum (eval (App (App subChurch (numChurch 10)) (numChurch 5))) @?= Just 5

    , testCase "10 / 5" $
        decodeNum (eval (App (App divChurch (numChurch 10)) (numChurch 5))) @?= Just 2

    , testCase "9 / 3" $
        decodeNum (eval (App (App divChurch (numChurch 9)) (numChurch 3))) @?= Just 3

    , testCase "10 / 3" $
        decodeNum (eval (App (App divChurch (numChurch 10)) (numChurch 3))) @?= Just 3

    , testCase "Construct list from integers" $
        listFromInt [1, 2] @?= (App (App cons (numChurch 1)) (App (App cons (numChurch 2)) nil))

    , testCase "Construct list from terms" $
        listFromTerm [(numChurch 1), (numChurch 2)]
            @?= (App (App cons (numChurch 1)) (App (App cons (numChurch 2)) nil))

    -- (+) (+) [[1, 2] [3, 4]] -> 10
    , testCase "Sum of nested list" $
        decodeNum (eval (
            App (
                App (App foldScott addChurch) (numChurch 0)
            ) (
                App (
                    App mapChurch
                       (App (App foldScott addChurch) (numChurch 0))
                ) (
                    listFromTerm [
                        listFromInt [1, 2],
                        listFromInt [3, 4]
                    ]))))
        @?= Just 10

    -- [0, 1] -> [1, 2]
    , testCase "Map successor" $
        eval (mapPredicate succChurch (listFromInt [0, 1])) @?= eval (listFromInt [1, 2])

    , testCase "Map predecessor" $
        eval (mapPredicate predChurch (listFromInt [1, 2])) @?= eval (listFromInt [0, 1])

    , testCase "Fold Sum" $
        decodeNum (eval (
            App (App (App foldScott addChurch) (numChurch 0)) (listFromInt [1, 2, 3, 4, 5])
        )) @?= Just 15

    , testCase "Concat many " $
        eval (App concatChurch (concatMany [[1, 2], [3], [4, 5]]))
            @?= eval (listFromInt [1, 2, 3, 4, 5])

    , testCase "Sum of concat" $
        decodeNum (eval (
            App
                (App
                    (App foldScott addChurch)
                    (numChurch 0))
                (App
                    concatChurch
                    (concatMany [[1, 2], [3], [4, 5]]))))
            @?= Just 15

    ]
