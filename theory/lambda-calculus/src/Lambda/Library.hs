{-# LANGUAGE LambdaCase #-}

module Lambda.Library
    ( tru, fls, ifthen
    , numChurch
    , listFromInt, listFromTerm
    , succChurch, addChurch, subChurch, mulChurch, divChurch, predChurch, isZero
    , nil, cons, foldScott, mapChurch, mapPredicate
    , appendChurch, concatChurch, concatMany
    , yCombinator
    ) where

import Lambda.Core

-- =========================================
-- Church booleans
-- =========================================
tru, fls, ifthen :: Term
tru    = Lam "x" $ Lam "y" (Var "x")
fls    = Lam "x" $ Lam "y" (Var "y")
ifthen = Lam "b" $ Lam "x" $ Lam "y" $ App (App (Var "b") (Var "x")) (Var "y")

-- =========================================
-- Church numerals
-- =========================================
numChurchApply :: Int -> Term
numChurchApply 0 = (Var "x")
numChurchApply n = App (Var "f") $ numChurchApply (n - 1)

numChurch :: Int -> Term
numChurch n = Lam "f" $ Lam "x" (numChurchApply n)

-- succ = λn.λf.λx. f (n f x)
succChurch :: Term
succChurch =
    Lam "n" $ Lam "f" $ Lam "x" $
        App (Var "f") (App (App (Var "n") (Var "f")) (Var "x"))

-- pred = λn.λf.λx. n (λg.λh. h (g f)) (λu.x) (λu.u)
predChurch :: Term
predChurch =
    Lam "n" $ Lam "f" $ Lam "x" $
        App (App (App (Var "n")
            (Lam "g" (Lam "h" (App (Var "h") (App (Var "g") (Var "f"))))))
            (Lam "u" (Var "x")))
            (Lam "u" (Var "u"))

-- add = λm.λn.λf.λx. m f (n f x)
addChurch :: Term
addChurch =
    Lam "m" $ Lam "n" $ Lam "f" $ Lam "x" $
        App (App (Var "m") (Var "f"))
            (App (App (Var "n") (Var "f")) (Var "x"))

-- sub = λm.λn. n pred m
subChurch :: Term
subChurch = Lam "m" $ Lam "n" $ App (App (Var "n") predChurch) (Var "m")

-- mul = λm.λn.λf. m (n f)
mulChurch :: Term
mulChurch = Lam "m" $ Lam "n" $ Lam "f" $ App (Var "m") (App (Var "n") (Var "f"))

-- div' = λc.λn.λm.λf.λx. (λd. isZero d (0 f x) (f (c d m f x))) (subChurch m n)
divChurch' :: Term
divChurch' =
    Lam "c" $ Lam "n" $ Lam "m" $ Lam "f" $ Lam "x" $
        App (Lam "d" (App (App (App isZero (Var "d")) (App (App (numChurch 0) (Var "f")) (Var "x")))
                  (App (Var "f") (App (App (App (Var "c") (Var "d")) (Var "m")) (Var "f") `App` Var "x"))))
            (App (App subChurch (Var "n")) (Var "m"))

-- div = λn. div' (succ n)
divChurch :: Term
divChurch = Lam "n" $ App (App yCombinator divChurch') (App succChurch (Var "n"))

-- iszero = λn. n (λx.false) true
isZero :: Term
isZero = Lam "n" $ App (App (Var "n") (Lam "x" fls)) tru

-- =========================================
-- List
-- =========================================

listFromInt :: [Int] -> Term
listFromInt = foldr (\n acc -> App (App cons (numChurch n)) acc) nil

listFromTerm :: [Term] -> Term
listFromTerm = foldr (\n acc -> App (App cons n) acc) nil

nil :: Term
nil = fls

-- cons = λh.λt.λc.λn. c h (t c n)
cons :: Term
cons = Lam "h" $ Lam "t" $ Lam "c" $ Lam "n" $
    App (App (Var "c") (Var "h"))
        (App (App (Var "t") (Var "c")) (Var "n"))

-- map = λf. λxs. xs (λh. λt. cons (f h) t) nil
mapChurch :: Term
mapChurch =
    Lam "f" $ Lam "xs" $
        App (App (Var "xs") (Lam "h" (Lam "t" (App (App cons (App (Var "f") (Var "h"))) (Var "t")))))
        nil

-- fold = λf. λd. λxs. xs f d
foldScott :: Term
foldScott =
    Lam "f" $ Lam "z" $ Lam "xs" $
        App (App (Var "xs") (Var "f")) (Var "z")

-- append = λxs. λys. fold (λh. λt. cons h t) ys xs
appendChurch :: Term
appendChurch =
    Lam "xs" $ Lam "ys" $
        App (App (App foldScott
            (Lam "h" $ Lam "t" $ App (App cons (Var "h")) (Var "t")))
            (Var "ys"))
            (Var "xs")

-- concat = λxs. fold append nil xs
concatChurch :: Term
concatChurch =
    Lam "xs" $ App (App (App foldScott appendChurch) nil) (Var "xs")

concatMany :: [[Int]] -> Term
concatMany = foldr (\n acc -> App (App cons (listFromInt n)) acc) nil

mapPredicate :: Term -> Term -> Term
mapPredicate pred' list = App (App mapChurch pred') list

-- =========================================
-- Y combinator
-- =========================================

-- Y = λf.(λx.(f (x x)) λx.(f (x x)))
yCombinator :: Term
yCombinator = Lam "f" $ App
    (Lam "x" (App (Var "f") (App (Var "x") (Var "x"))))
    (Lam "x" (App (Var "f") (App (Var "x") (Var "x"))))
