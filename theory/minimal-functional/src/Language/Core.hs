{-# LANGUAGE LambdaCase #-}

module Language.Core
  ( EvalResult
  , Expr(..)
  , Pattern(..)
  , Value(..)
  , Env
  ) where

import qualified Data.Map.Strict as M
import           Control.Monad (foldM)

-- Simple error monad
type EvalResult a = Either String a

-- AST (minimal)
data Expr
  = EInt Int
  | EVar String
  | EUnit                  -- ()
  | ETuple Expr Expr       -- (a, b)
  | ECall Expr [Expr]      -- id(args...) or constructor call
  | ELam [Pattern] Expr    -- \p1 p2 -> body    (multiple pattern parameters)
  | ECase Expr [(Pattern, Expr)] -- Case expression: case e of p1 -> e1 | p2 -> e2 ...
  | ELet String Expr Expr  -- let <name> = expr in body  (recursive)
  deriving (Show, Eq)

-- Patterns
data Pattern
  = PVar String
  | PInt Int
  | PWild                 -- _
  | PUnitP                -- ()
  | PTupleP Pattern Pattern
  | PGuard Expr Expr
  deriving (Show, Eq)

-- Runtime values
data Value
  = VInt Int
  | VUnit
  | VPair Value Value           -- tuple / cons cell
  | VFun [Pattern] Expr Env     -- user function closure
  | VPrim String ([Value] -> EvalResult Value) -- builtin function (name, impl)
  | VRec String Expr Env        -- recursive thunk: name -> expr (evaluated when forced)

instance Show Value where
  show = \case
    VInt n     -> show n
    VUnit      -> "()"
    VPair a b  -> "(" ++ show a ++ ", " ++ show b ++ ")"
    VFun{}     -> "<fun>"
    VPrim n _  -> "<prim " ++ n ++ ">"
    VRec n _ _ -> "<rec " ++ n ++ ">"

instance Eq Value where
  VInt x       == VInt y       = x == y
  VUnit        == VUnit        = True
  VPair a b    == VPair c d    = a == c && b == d
  VFun{}       == VFun{}       = False
  VPrim{}      == VPrim{}      = False
  VRec{}       == VRec{}       = False
  _            == _            = False

-- Environment: simple map from names to Values
type Env = M.Map String Value
