{-# LANGUAGE LambdaCase #-}

module Lambda.Core
    ( Term(..)
    , eval, evalReductionSteps
    , pp
    , decodeNum
    ) where

import qualified Data.Set as S

-- =========================================
-- Abstract Syntax
-- =========================================
data Term
    = Var String
    | Lam String Term
    | App Term Term
    deriving (Eq, Show)

-- =========================================
-- Free variables
-- =========================================
freeVars :: Term -> S.Set String
freeVars = \case
    Var x     -> S.singleton x
    Lam x t   -> S.delete x (freeVars t)
    App f a   -> freeVars f `S.union` freeVars a

-- =========================================
-- Substitution with α-conversion
-- =========================================
subst :: String -> Term -> Term -> Term
subst x s = \case
    Var y
        | x == y    -> s
        | otherwise -> Var y

    Lam y body
        | x == y    -> Lam y body
        | y `S.member` freeVars s ->
            let y'    = freshVar y $ freeVars body `S.union` freeVars s
                body' = subst y (Var y') body
            in  Lam y' (subst x s body')
        | otherwise -> Lam y $ subst x s body

    App f a -> App (subst x s f) (subst x s a)

freshVar :: String -> S.Set String -> String
freshVar base used = head $ dropWhile (`S.member` used) candidates
    where candidates = base : [base ++ show n | n <- [1..]]

-- =========================================
-- β-reduction and evaluation
-- =========================================

-- (λx.body) s → [x ↦ s] body
beta :: Term -> Maybe Term
beta = \case
    App (Lam x body) s   -> Just (subst x s body)
    App f a              -> case beta f of
        Just f' -> Just (App f' a)
        Nothing -> App f <$> beta a
    Lam x body           -> Lam x <$> beta body
    _                    -> Nothing

eval :: Term -> Term
eval t = case beta t of
    Just t' -> eval t'
    Nothing -> t

evalReductionSteps :: Term -> [Term]
evalReductionSteps t = t : unfold t
    where
        unfold t' =
            case beta t' of
                Just t' -> t' : unfold t'
                Nothing -> []

-- =========================================
-- Pretty printer
-- =========================================
pp :: Term -> String
pp = \case
    Var x   -> x
    Lam x t -> "λ" ++ x ++ "." ++ pp t
    App f a -> "(" ++ pp f ++ " " ++ pp a ++ ")"

-- =========================================
-- Decode Church numerals into Int
-- =========================================
decodeNum :: Term -> Maybe Int
decodeNum t = case eval t of
    Lam "f" (Lam "x" body) -> Just (countF body)
    _ -> Nothing
    where
        -- count how many times f applied
        countF (Var "x") = 0
        countF (App (Var "f") rest) = 1 + countF rest
        countF _ = -1 -- not a pure numeral
