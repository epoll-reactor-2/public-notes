module Lambda.Runtime
  ( Value(..)
  , Env(..)
  , applyValue
  , evalExpr
  , evalExprSteps
  ) where

import qualified Data.Map as M
import qualified Data.Set as S
import           Data.Map (Map)
import           Data.Set (Set)
import           Lambda.Type

-- Runtime values
data Value
  = VInt Int
  | VBool Bool
  | VList [Value]
  | VClosure String Expr Env
  | VPrim1 (Value -> Either String Value)
  | VPrim2 (Value -> Value -> Either String Value)

instance Show Value where
  show (VInt n) = show n
  show (VBool b) = show b
  show (VList vs) = "[" ++ comma vs ++ "]"
    where
      comma [] = ""
      comma [x] = show x
      comma (x:xs) = show x ++ ", " ++ comma xs
  show (VClosure {}) = "<closure>"
  show (VPrim1 {}) = "<prim1>"
  show (VPrim2 {}) = "<prim2>"

-- ===========================================
-- Runtime Environment and Evaluation
-- ===========================================

-- Env maps variable names to runtime values.
type Env = Map String Value

-- Function application at runtime:
-- 1. If we have a closure, extend its environment with the argument and evaluate.
-- 2. If we have a curried primitive (VPrim2), turn it into a unary primitive (VPrim1).
-- 3. If we have a unary primitive, apply it directly.
-- Otherwise: runtime error (cannot apply a non-function).
applyValue :: Value -> Value -> Either String Value
applyValue (VClosure x body env) v = evalExpr (M.insert x v env) body
applyValue (VPrim2 f) v1 = Right $ VPrim1 (f v1)
applyValue (VPrim1 f) v1 = f v1
applyValue other _ = Left $ "Attempt to apply non-function value: " ++ show other

-- Expression evaluator:
-- Walk the AST and produce a Value, using call-by-value semantics.
evalExpr :: Env -> Expr -> Either String Value
evalExpr env expr = case expr of
  -- Look up variable in runtime environment
  Var x -> maybe (Left $ "Unbound variable: " ++ x) Right (M.lookup x env)

  -- Build a closure: capture current environment
  Lam x _ body -> Right $ VClosure x body env

  -- Application: evaluate function and argument, then apply
  App a b -> do
    fa <- evalExpr env a
    fb <- evalExpr env b
    applyValue fa fb

  -- Let binding: evaluate e1, insert into env, then eval e2
  Let x e1 e2 -> do
    v1 <- evalExpr env e1
    evalExpr (M.insert x v1 env) e2

  LitInt n -> Right $ VInt n
  LitBool b -> Right $ VBool b
  Nil _ -> Right $ VList []

evalExprSteps :: TypeEnv -> Env -> Expr -> Int -> Either String [(Expr, Type, Value, Int)]
evalExprSteps typeEnv valEnv expr depth = go typeEnv valEnv expr depth
  where
    go tenv venv e depth = case e of
      Var x ->
        case (M.lookup x venv, M.lookup x tenv) of
          (Just v, Just scheme) -> do
            ty <- runInfer tenv (Var x)
            Right [(e, ty, v, depth)]
          (Nothing, _) -> Left $ "Unbound variable: " ++ x
          (_, Nothing) -> Left $ "No type for variable: " ++ x

      Lam x ty body -> do
        let tenv' = M.insert x (Forall [] ty) tenv
        let v = VClosure x body venv
        tyBody <- runInfer tenv' body
        Right [(e, TyFun ty tyBody, v, depth)]

      App a b -> do
        -- reduce function
        stepsA <- go tenv venv a (depth + 1)
        let (_, _, fa, _) = last stepsA
        -- reduce argument
        stepsB <- go tenv venv b (depth + 1)
        let (_, _, fb, _) = last stepsB
        -- apply
        fv <- applyValue fa fb
        ty <- runInfer tenv (App a b)
        Right (stepsA ++ stepsB ++ [(e, ty, fv, depth)])

      Let x e1 e2 -> do
        steps1 <- go tenv venv e1 depth
        let (_, t1, v1, _) = last steps1
        let tenv' = M.insert x (generalize tenv t1) tenv
        steps2 <- go tenv' (M.insert x v1 venv) e2 depth
        Right (steps1 ++ steps2)

      LitInt n  -> Right [( e, TyInt,    VInt n,   depth )]
      LitBool b -> Right [( e, TyBool,   VBool b,  depth )]
      Nil t     -> Right [( e, TyList t, VList [], depth )]
